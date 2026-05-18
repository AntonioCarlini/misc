#!/usr/bin/env python3

import requests
import sys

WIKI_API = "http://pi44gb.flexbl.co.uk/mediawiki/api.php"
IMAGES_FILE = "/home/antonioc/Downloads/images.txt"


def check_file_references(wiki_api, file_title):
    """
    Check whether a File: page is used anywhere in the wiki.
    Returns:
        True  -> has usages
        False -> no usages or missing
        None  -> request error
    """

    # Ensure title starts with File:
    if not file_title.startswith("File:"):
        file_title = f"File:{file_title}"

    params = {
        "action": "query",
        "titles": file_title,
        "prop": "fileusage",
        "fulimit": 1,   # only need one usage to know it exists
        "format": "json"
    }

    try:
        response = requests.get(wiki_api, params=params, timeout=10)
        response.raise_for_status()

        data = response.json()

        pages = data.get("query", {}).get("pages", {})

        for page_id, page_info in pages.items():

            # Missing page
            if "missing" in page_info:
                return False

            # File usages found
            if "fileusage" in page_info and page_info["fileusage"]:
                return True

            return False

        return False

    except requests.exceptions.RequestException as e:
        print(f"API Request Error for {file_title}: {e}", file=sys.stderr)
        return None


def main():

    try:
        with open(IMAGES_FILE, "r") as f:
            file_titles = [line.strip() for line in f if line.strip()]

    except FileNotFoundError:
        print(f"Error: Input file '{IMAGES_FILE}' not found.", file=sys.stderr)
        sys.exit(1)

    for title in file_titles:

        result = check_file_references(WIKI_API, title)

        if result is True:
            print(f"HAS REFERENCES:  {title}")

        elif result is False:
            print(f"NO REFERENCES:   {title}")

        else:
            print(f"CHECK FAILED:    {title}")


if __name__ == "__main__":
    main()