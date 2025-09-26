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
from datetime import date
from enum import Enum, auto
import time
from urllib.parse import urlparse

import requests

ARCHIVE_SAVE_URL = "https://web.archive.org/save/"
ARCHIVE_AVAILABILITY_URL = "https://archive.org/wayback/available"


class ArchiveResult(Enum):
    SUCCESS = auto()
    FAILURE = auto()
    BLOCKED = auto()

# Type alias for clarity: maps URL → [date, status]
HistoryData = dict[str, list[str]]

def load_history(path: str) -> HistoryData:
    """
    Load history CSV into a dictionary mapping URL to [date, status].

    CSV format: URL,date,status
    - date: YYYY-MM-DD
    - status: "archived" or ""
    """
    history: HistoryData = {}

    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            url = row["URL"].strip()
            date = row["date"].strip()
            status = row["status"].strip()
            history[url] = [date, status]

    return history

def store_history(path: str, history: HistoryData) -> bool:
    """
    Write history dict back to CSV.

    Returns True if successful, False if no history was written.
    """
    if not path or not history:
        return False

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["URL", "date", "status"])
        for url, (date, status) in history.items():
            writer.writerow([url, date, status])
    return True

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

def can_be_archived(url: str) -> bool:
    scheme = urlparse(url).scheme.lower()
    return scheme in {"http", "https"}

def check_already_archived(url: str) -> bool:
    """Return True if the URL is already archived in the Wayback Machine."""
    # First check if the request is even worth making
    if do_not_archive(url, always_verify=False):
        print(f"DO NOT ARCHIVE:          {url}")
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


def submit_to_archive(url: str) -> ArchiveResult:
    """Submit a URL to archive.org for saving. Returns True if request succeeded."""
    # First check if the request is even worth making
    if do_not_archive(url, always_verify=False):
        # No need to issue a message as check_already_archived() will have done this
        return ArchiveResult.BLOCKED

    try:
        resp = requests.get(ARCHIVE_SAVE_URL + url, timeout=90)
        if resp.status_code in (200, 302):
            return ArchiveResult.SUCCESS
        print(f"Failed to archive {url}: HTTP {resp.status_code}")
        return ArchiveResult.FAILURE
    except Exception as e:
        print(f"Error archiving {url}: {e}")
        return ArchiveResult.FAILURE


def process_csv(csv_file, history_data="", summary=False, verbose=False, verify=False, limit=0, **unused):
    """Process the CSV and attempt to archive or verify URLs."""

    history = load_history(history_data) if history_data else {}

    urls_read = 0
    urls_considered = 0
    urls_skipped = 0
    urls_archived = 0
    urls_in_history = 0
    urls_not_supported = 0

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

            if not can_be_archived(url):
                urls_not_supported += 1
                print(f"Considering Page={page}   URL={url}")
                continue
            # If URL exists in history, then skip
            if history.get(url, ["", ""])[1] == "archived":
                urls_in_history += 1
                if verbose:
                    print(f"Skipping URL archived in history: {url}")
                continue
            if history.get(url, ["", ""])[1] == "blocked":
                urls_in_history += 1
                if verbose:
                    print(f"Skipping URL blocked in history: {url}")
                continue

            already_archived = check_already_archived(url)
            if verify:
                if already_archived:
                    print(f"[SKIP] Already archived: {url}")
                    today = date.today().strftime("%Y-%m-%d")
                    history[url] = [today, "archived"]
                    urls_skipped += 1
                    continue
                else:
                    print(f"NOT archived:            {url}")
                    continue

            if already_archived:
                today = date.today().strftime("%Y-%m-%d")
                history[url] = [today, "archived"]
                urls_skipped += 1
            else:
                urls_archived += 1
                print(f"[ARCHIVE] Submitting:    {url}")
                ok = submit_to_archive(url)
                match ok:
                    case ArchiveResult.SUCCESS:
                        today = date.today().strftime("%Y-%m-%d")
                        history[url] = [today, "archived"]
                        print(f"[DONE] Archived:         {url}")
                    case ArchiveResult.BLOCKED:
                        today = date.today().strftime("%Y-%m-%d")
                        history[url] = [today, "blocked"]
                    case ArchiveResult.FAILURE:
                        # Failure doesn't log anything in the history
                        pass
                        
                time.sleep(2)  # be polite to archive.org

    # Store the history data, if --history-data was specified
    if history_data:
        store_history(history_data, history)

    if summary:
        print("Summary")
        print("URLs considered:                   ", urls_considered)
        print("URLs not supported by archive.org: ", urls_not_supported)
        print("URLs already archived:             ", urls_skipped)
        print("URLs in history data:              ", urls_in_history)
        print("URLs submitted to archive:         ", urls_archived)

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
    parser.add_argument("--history-data",  metavar="FILE",
        help="CSV file with columns URL,date,status")
    args = parser.parse_args()

    keywords = vars(args)

    process_csv(**keywords)

if __name__ == "__main__":
    main()
