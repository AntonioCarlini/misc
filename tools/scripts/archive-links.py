#!/usr/bin/env python3
"""
Archive External Links to archive.org

This script reads a CSV file containing wiki page titles and external URLs
(columns: page_title, external_url). For each URL it attempts to ensure that
the resource is archived in the Internet Archive's Wayback Machine.

By default, every URL is submitted for archiving.

If the --verify flag is given, the script first checks whether a URL is
already archived. Only URLs not found in the Wayback Machine are submitted.

Usage:
    python archive_links.py input.csv [--verify]

Arguments:
    input.csv     CSV file with at least two columns:
                  - page_title
                  - external_url
Options:
    --limit       Only consider this many URLs; once the limit is reached, stop

    --summary     Generate summary statistics at the end 
    
    --verbose     

    --verify      Before archiving, check the availability API to avoid
                  re-submitting URLs already present in the archive.

"""

import argparse
import csv
import requests
import time


ARCHIVE_SAVE_URL = "https://web.archive.org/save/"
ARCHIVE_AVAILABILITY_URL = "https://archive.org/wayback/available"


# denylist.py

DO_NOT_ARCHIVE_LIST = {
    "archive.org",
    "web.archive.org",
    "drive.google.com",
    "docs.google.com",
    "mail.google.com",
    "accounts.google.com",
    "calendar.google.com",
    "dropbox.com",
    "facebook.com",
    "instagram.com",
    "whatsapp.com",
    "youtube.com",       # note: metadata may archive, but not video
    "youtu.be",
    "netflix.com",
    "spotify.com",
    "twitch.tv",
}

def do_not_archive(url: str, always_verify: bool = False) -> bool:
    """
    Return True if the URL is in the denylist and should be skipped.
    If always_verify=True, bypass the denylist (always return False).
    """
    if always_verify:
        return False

    from urllib.parse import urlparse
    host = urlparse(url).netloc.lower()

    # Exact or subdomain matches
    for blocked in DO_NOT_ARCHIVE_LIST:
        if host == blocked or host.endswith("." + blocked):
            return True
    return False

def check_already_archived(url: str) -> bool:
    """Return True if the URL is already archived in the Wayback Machine."""
    # First check if the request is even worth making
    if do_not_archive(url, always_verify=False):
        print(f"Skipping {url} (marked DO NOT ARCHIVE)")
        return False

    # Now see if the URL is already archived
    try:
        resp = requests.get(ARCHIVE_AVAILABILITY_URL, params={"url": url}, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        return bool(data.get("archived_snapshots", {}).get("closest"))
    except Exception as e:
        print(f"Error checking {url}: {e}")
        return False


def submit_to_archive(url: str) -> bool:
    """Submit a URL to archive.org for saving. Returns True if request succeeded."""
    # First check if the request is even worth making
    if do_not_archive(url, always_verify=False):
        print(f"Skipping {url} (denylist)")
        return False

    try:
        resp = requests.get(ARCHIVE_SAVE_URL + url, timeout=90)
        if resp.status_code in (200, 302):
            return True
        print(f"Failed to archive {url}: HTTP {resp.status_code}")
        return False
    except Exception as e:
        print(f"Error archiving {url}: {e}")
        return False


def process_csv(csv_file, summary=False, verbose=False, verify=False, limit=0, **unused):
    """Process the CSV and attempt to archive or verify URLs."""
    urls_read = 0
    urls_considered = 0
    urls_skipped = 0
    urls_archived = 0

    print(f"Processing {csv_file}")
    with open(csv_file, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            urls_read += 1

            # Honour the --limit if one was specified (and valid)
            if (limit > 0) and (urls_read > limit):
                break

            urls_considered += 1
            url = row.get("External Link")
            page = row.get("Page")
            if verbose:
                print(f"Considering Page={page}   URL={url}")
            if not url:
                continue

            already_archived = check_already_archived(url)
            if verify:
                if already_archived:
                    print(f"[SKIP] Already archived: {page} -> {url}")
                    urls_skipped += 1
                    continue
                else:
                    print(f"NOT archived:            {page} -> {url}")
                    continue

            if already_archived:
                urls_skipped += 1
            else:
                urls_archived += 1
                print(f"[ARCHIVE] Submitting: {page} -> {url}")
                ok = submit_to_archive(url)
                if ok:
                    print(f"[DONE] Archived: {url}")
                time.sleep(2)  # be polite to archive.org
    if summary:
        print("Summary")
        print("URLs considered:           ", urls_considered)
        print("URLs already archived:     ", urls_skipped)
        print("URLs submitted to archive: ", urls_archived)

def main():
    parser = argparse.ArgumentParser(description="Archive external links to archive.org")
    parser.add_argument("csv_file", help="Input CSV with page_title, external_url columns")
    parser.add_argument("--verify", action="store_true",
                        help="Check availability in archive")
    parser.add_argument("--verbose", action="store_true",
                        help="In verbose mode display more information")
    parser.add_argument("--summary", action="store_true",
                        help="Display summary statistics")
    parser.add_argument("--limit", type=int, default=0, 
                        help="Maximum number of URLs to consider")
    args = parser.parse_args()

    keywords = vars(args)

    process_csv(**keywords)

if __name__ == "__main__":
    main()
