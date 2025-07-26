"""
This script downloads and scans notes from the DECUServe HTNOTES archive (https://decuserve.org/anon/htnotes),
specifically targeting a given forum (e.g., INDUSTRY_NEWS). It extracts any DEC licence part numbers (e.g., QL-XXXXX-XX)
along with their associated descriptions, and outputs them in CSV format along with the source URL of each note.

Features:
- Configurable forum name and range of note IDs (START_ID to END_ID)
- Optional automatic detection of the forum's actual first and last available note IDs
  using the DECUServe HTNOTES directory endpoints
- Rate-limited downloading to reduce server load and prevent accidental denial of service
- Simple CSV output including license code, description, and source link

Usage:
- Set the `FORUM`, `START_ID`, and `END_ID` constants
- Enable `DETECT_FORUM_BOUNDS = True` to automatically trim requests to the forum's actual post range
- Optionally adjust `RATE_LIMIT_SECONDS` for pacing requests
- Default output CSV file is dec-licences.csv

"""

from bs4 import BeautifulSoup
import re
import requests
import time

BASE_URL = "https://decuserve.org/anon/htnotes/note"
FORUM = "INDUSTRY_NEWS"        # The forum to scan
START_ID = 1                   # First note ID
END_ID = 1000                  # Last note ID
RATE_LIMIT_SECONDS = 3         # Configurable rate limit
DETECT_FORUM_BOUNDS = True     # Do not ask for notes that do not exist

OUTPUT_FILE = "dec-licences.csv"

licence_pattern = re.compile(r"\bQL-[A-Z0-9\*]{4,}-[A-Z0-9]+\b", re.IGNORECASE)

def get_forum_bounds(forum):
    low_url = f"https://decuserve.org/anon/htnotes/dir?f1={forum}&f2=1-L"
    high_url = f"https://decuserve.org/anon/htnotes/dir?f1={forum}&f2=L-1"
    low_id = None
    high_id = None

    try:
        r_low = requests.get(low_url, timeout=10)
        r_high = requests.get(high_url, timeout=10)
        if r_low.status_code == 200:
            match = re.search(r'note\?f1=[^&]+&f2=(\d+)\.0', r_low.text)
            if match:
                low_id = int(match.group(1))
        if r_high.status_code == 200:
            match = re.search(r'note\?f1=[^&]+&f2=(\d+)\.0', r_high.text)
            if match:
                high_id = int(match.group(1))
    except Exception as e:
        print(f"[WARN] Could not auto-detect bounds: {e}")

    return low_id, high_id


def fetch_note(note_id):
    parameters = {'f1': FORUM, 'f2': f'{note_id}.0'}
    try:
        response = requests.get(BASE_URL, params=parameters, timeout=10)
        if response.status_code == 200:
            return response.text
        return None
    except requests.RequestException:
        return None

def extract_licences(html):
    soup = BeautifulSoup(html, "html.parser")
    text = soup.get_text()
    matches = list(licence_pattern.finditer(text))
    licences = []
    for match in matches:
        start = max(text.rfind('\n', 0, match.start()), 0)
        end = text.find('\n', match.end())
        context = text[start:end].strip()
        licences.append((match.group(), context))
    return licences

def main():
    effective_start = START_ID
    effective_end = END_ID

    if DETECT_FORUM_BOUNDS:
        forum_min, forum_max = get_forum_bounds(FORUM)
        if forum_min:
            effective_start = max(START_ID, forum_min)
        if forum_max:
            effective_end = min(END_ID, forum_max)
        print(f"[INFO] Adjusted bounds to actual post range: {effective_start}–{effective_end}")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        out.write("Code,Title,SourceURL\n")
        for note_id in range(effective_start, effective_end + 1):
            url = f"{BASE_URL}?f1={FORUM}&f2={note_id}.0"
            print(f"Fetching {url} ...")
            html = fetch_note(note_id)
            if html:
                licences = extract_licences(html)
                for code, title in licences:
                    out.write(f'"{code}","{title}","{url}"\n')
            else:
                print(f"Failed or skipped {note_id}")
            time.sleep(RATE_LIMIT_SECONDS)

if __name__ == "__main__":
    main()


