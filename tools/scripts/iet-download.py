#!/usr/bin/env python3

"""
Download all PDFs from an IET E and T issue given volume and issue.

Design notes:
- Selenium is used only for authentication
- requests is used for all downloads
- BeautifulSoup is used for HTML parsing
- Errors are logged but do not stop the run unless fatal

Requirements:
    pip install selenium requests beautifulsoup4

A working WebDriver (Chrome or Firefox) is required.
"""

import argparse
import logging
import os
import re
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s"
)


# ---------------------------------------------------------------------------
# CLI parsing
# ---------------------------------------------------------------------------

def parse_cli():
    """
    Parse command line arguments of the form:
        v4 n12
        V04 N12
    """

    parser = argparse.ArgumentParser(description="Download IET E and T issue PDFs")
    parser.add_argument("volume", help="Volume, e.g. v4 or V04")
    parser.add_argument("issue", help="Issue, e.g. n12 or N12")

    args = parser.parse_args()

    def extract_number(text, prefix):
        text = text.strip().lower()
        if not text.startswith(prefix):
            raise ValueError(f"Expected {prefix} prefix in '{text}'")
        return int(text[1:])

    try:
        vol = extract_number(args.volume, "v")
        iss = extract_number(args.issue, "n")
    except Exception as e:
        raise SystemExit(f"Invalid arguments: {e}")

    if not (1 <= vol <= 99):
        raise SystemExit("Volume must be between 1 and 99")

    if not (1 <= iss <= 99):
        raise SystemExit("Issue must be between 1 and 99")

    return vol, iss


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def format_prefix(volume, issue):
    """Return VxxNyy string."""
    return f"V{volume:02d}N{issue:02d}"


def prepare_output_dir(prefix):
    """Create output directory if required."""
    path = Path.cwd() / prefix
    path.mkdir(parents=True, exist_ok=True)
    return path


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

def fetch_password():
    """
    Read password from ~/.iet
    First line only.
    """
    path = Path.home() / ".iet"
    return path.read_text().strip()


from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service as FirefoxService

def login_and_get_session(username, password, toc_url):
    logging.info("Starting Firefox with existing profile")

    options = Options()

    # IMPORTANT: set this to your real Firefox profile path
    profile_path = str(Path.home() / ".mozilla/firefox")

    # You need the actual profile directory (ends in .default-release etc.)
    profiles = list(Path(profile_path).glob("*.default*"))
    if not profiles:
        raise SystemExit("Could not find Firefox profile")

    profile_dir = str(profiles[0])
    logging.info(f"Using Firefox profile: {profile_dir}")

    options.add_argument("-profile")
    options.add_argument(profile_dir)

    driver = webdriver.Firefox(options=options)
    driver.get(toc_url)

    input("If needed, confirm you are logged in, then press Enter...")

    # Extract cookies
    session = requests.Session()
    for cookie in driver.get_cookies():
        session.cookies.set(cookie['name'], cookie['value'])

    driver.quit()

    logging.info("Session cookies captured")

    return session



# ---------------------------------------------------------------------------
# Fetch TOC
# ---------------------------------------------------------------------------

def fetch_toc(session, volume, issue):
    url = f"https://digital-library.theiet.org/toc/et/{volume}/{issue}"
    logging.info(f"Fetching TOC: {url}")

    r = session.get(url)

    if r.status_code != 200:
        raise SystemExit(f"Failed to fetch TOC page: HTTP {r.status_code}")

    return r.text


# ---------------------------------------------------------------------------
# Parse links
# ---------------------------------------------------------------------------

def extract_pdf_links(html):
    """
    Extract all /doi/epdf/ links in order.
    """

    soup = BeautifulSoup(html, "html.parser")

    links = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if "/doi/epdf/" in href:
            links.append(href)

    if not links:
        logging.warning("No PDF links found in TOC")

    return links


# ---------------------------------------------------------------------------
# URL transform
# ---------------------------------------------------------------------------

def epdf_to_pdf(epdf_url):
    return epdf_url.replace("/epdf/", "/pdf/") + "?download=true"


# ---------------------------------------------------------------------------
# Filename handling
# ---------------------------------------------------------------------------

def get_filename_from_response(response):
    cd = response.headers.get("Content-Disposition")
    if not cd:
        return None

    match = re.search(r'filename="?([^"]+)"?', cd)
    if match:
        return match.group(1)

    return None


def sanitize_filename(name):
    name = name.strip()
    name = name.replace(" ", "-")
    name = re.sub(r'[^A-Za-z0-9._-]', '', name)
    return name


def ensure_unique(path):
    counter = 1
    base = path.stem
    ext = path.suffix

    while path.exists():
        path = path.with_name(f"{base}-{counter}{ext}")
        counter += 1

    return path


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

def download_pdf(session, url, output_dir, prefix, index):
    """
    Download a single PDF.
    Returns True on success, False otherwise.
    """

    try:
        r = session.get(url, stream=True)

        if r.status_code != 200:
            logging.warning(f"[{index:02d}] HTTP {r.status_code}")
            return False

        if "application/pdf" not in r.headers.get("Content-Type", ""):
            logging.warning(f"[{index:02d}] Not a PDF response")

        original_name = get_filename_from_response(r)
        if not original_name:
            logging.warning(f"[{index:02d}] Missing filename, using fallback")
            original_name = "unknown.pdf"

        safe_name = sanitize_filename(original_name)
        final_name = f"{prefix}-{index:02d}-{safe_name}"

        path = ensure_unique(output_dir / final_name)

        with open(path, "wb") as f:
            for chunk in r.iter_content(8192):
                if chunk:
                    f.write(chunk)

        logging.info(f"[{index:02d}] Saved {path.name}")
        return True

    except Exception as e:
        logging.error(f"[{index:02d}] Error: {e}")
        return False


# ---------------------------------------------------------------------------
# Main download loop
# ---------------------------------------------------------------------------

def download_issue(session, links, output_dir, prefix):
    success = 0
    failure = 0

    for i, epdf in enumerate(links, start=1):
        full_epdf = "https://digital-library.theiet.org" + epdf
        pdf_url = epdf_to_pdf(full_epdf)

        ok = download_pdf(session, pdf_url, output_dir, prefix, i)

        if ok:
            success += 1
        else:
            failure += 1

        time.sleep(0.5)

    logging.info("Download complete")
    logging.info(f"Total: {len(links)}")
    logging.info(f"Successful: {success}")
    logging.warning(f"Failed: {failure}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    volume, issue = parse_cli()
    prefix = format_prefix(volume, issue)

    logging.info(f"Processing {prefix}")

    output_dir = prepare_output_dir(prefix)

    password = fetch_password()

    toc_url = f"https://digital-library.theiet.org/toc/et/{volume}/{issue}"

    session = login_and_get_session("your_username_here", password, toc_url)

    html = fetch_toc(session, volume, issue)

    links = extract_pdf_links(html)

    if not links:
        logging.warning("No links found, nothing to do")
        return

    download_issue(session, links, output_dir, prefix)


if __name__ == "__main__":
    main()
