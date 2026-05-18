#!/usr/bin/env python3

#!/usr/bin/env python3

# Scan a text file for MediaWiki [[File:...]] references and check
# whether each file is used anywhere in the target wiki via the
# MediaWiki API.
# 
# Reports each file as referenced, unreferenced, or failed to check.

import argparse
import re
import requests
import sys

WIKI_API = "http://pi44gb.flexbl.co.uk/mediawiki/api.php"

# Matches:
#   [[File:Example.jpg]]
#   [[File:Example.jpg|thumb|caption]]
#   whitespace before [[ is allowed
#
# Captures only:
#   File:Example.jpg
FILE_RE = re.compile(
    r'^\s*\[\[\s*(File:[^\]|]+)',
    re.IGNORECASE
)


def extract_file_titles(filename):
    """
    Read an input text file and extract MediaWiki File: references
    from lines containing [[File:...]] markup.

    Leading whitespace before [[ is ignored. Extraction stops at
    the first "|" or "]" character so that additional image options
    such as thumb, alignment, captions, or sizing are ignored.

    Following text is also ignored.

    Example:
        [[File:Example.jpg|thumb|200px]]   trailing text

    Extracts:
        File:Example.jpg

    Returns:
        list[str]: A list of extracted File: titles.
    """
    titles = []

    try:
        with open(filename, "r", encoding="utf-8") as f:

            for line in f:

                match = FILE_RE.search(line)

                if match:
                    title = match.group(1).strip()

                    # Normalise namespace casing
                    if title.lower().startswith("file:"):
                        title = "File:" + title[5:]

                    titles.append(title)

    except FileNotFoundError:
        print(f"Error: Input file '{filename}' not found.", file=sys.stderr)
        sys.exit(1)

    return titles


def check_file_references(wiki_api, file_title):
    """
    Query the MediaWiki API to determine whether a given File:
    page is referenced anywhere in the wiki.

    Uses the 'fileusage' property and only checks whether at least
    one usage exists.

    Args:
        wiki_api (str):
            URL of the MediaWiki API endpoint.

        file_title (str):
            File title including namespace, e.g.
            'File:Example.jpg'.

    Returns:
        True:
            File has at least one usage/reference.

        False:
            File has no usages or does not exist.

        None:
            API request failed.
    """

    params = {
        "action": "query",
        "titles": file_title,
        "prop": "fileusage",
        "fulimit": 1,
        "format": "json"
    }

    try:
        response = requests.get(wiki_api, params=params, timeout=10)
        response.raise_for_status()

        data = response.json()

        pages = data.get("query", {}).get("pages", {})

        for page_id, page_info in pages.items():

            if "missing" in page_info:
                return False

            if "fileusage" in page_info and page_info["fileusage"]:
                return True

            return False

        return False

    except requests.exceptions.RequestException as e:
        print(f"API Request Error for {file_title}: {e}", file=sys.stderr)
        return None


def main():
    """
    Parse command-line arguments, extract File: references from
    the supplied input file, check each file for wiki usage,
    and print a formatted status line for each result.
    """
    parser = argparse.ArgumentParser(
        description="Check MediaWiki file usage references"
    )

    parser.add_argument(
        "--images",
        required=True,
        help="Input text file containing wiki image markup"
    )

    args = parser.parse_args()

    file_titles = extract_file_titles(args.images)

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