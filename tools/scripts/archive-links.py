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
    --verify      Before archiving, check the availability API to avoid
                  re-submitting URLs already present in the archive.
"""

import argparse
import csv
import requests
import time


ARCHIVE_SAVE_URL = "https://web.archive.org/save/"
ARCHIVE_AVAILABILITY_URL = "https://archive.org/wayback/available"


def check_already_archived(url: str) -> bool:
    """Return True if the URL is already archived in the Wayback Machine."""
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
    try:
        resp = requests.get(ARCHIVE_SAVE_URL + url, timeout=90)
        if resp.status_code in (200, 302):
            return True
        print(f"Failed to archive {url}: HTTP {resp.status_code}")
        return False
    except Exception as e:
        print(f"Error archiving {url}: {e}")
        return False


def process_csv(csv_file: str, verify: bool):
    """Process the CSV and attempt to archive or verify URLs."""
    print(f"Processing {csv_file}")
    with open(csv_file, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            url = row.get("External Link")
            page = row.get("Page")
            print(f"Page={page}   URL={url}")
            if not url:
                continue

            already_archived = check_already_archived(url)
            if verify:
                if already_archived:
                    print(f"[SKIP] Already archived: {page} -> {url}")
                    continue
                else:
                    print(f"NOT archived:            {page} -> {url}")
                    continue

            if not already_archived:
                print(f"[ARCHIVE] Submitting: {page} -> {url}")
                ok = submit_to_archive(url)
                if ok:
                    print(f"[DONE] Archived: {url}")
                time.sleep(2)  # be polite to archive.org


def main():
    parser = argparse.ArgumentParser(description="Archive external links to archive.org")
    parser.add_argument("csvfile", help="Input CSV with page_title, external_url columns")
    parser.add_argument("--verify", action="store_true",
                        help="Check availability first, only archive if missing")
    args = parser.parse_args()

    process_csv(args.csvfile, args.verify)

if __name__ == "__main__":
    main()
