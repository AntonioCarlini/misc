#!/usr/bin/env python3

"""
IET E&T Magazine Downloader

Purpose:
    This script automates the process of downloading individual article PDFs 
    for a specific volume and issue of the IET Engineering & Technology (E&T) magazine. 
    It handles the multi-step member login process.

Sequence of Actions:
    1. Parses command-line arguments to determine the target volume, issue, and delay parameters.
    2. Loads user login credentials from a local configuration file.
    3. Initialises a Chrome browser using undetected-chromedriver, configured 
       to automatically download PDFs to a designated local folder without prompting.
    4. Navigates to the issue's Table of Contents (TOC) page and attempts an automated login,
       dismissing cookie overlays and clearing pre-filled fields as necessary.
    5. Pauses to allow the user to manually verify the page state or solve any captchas.
    6. Scrapes all unique ePDF article links from the TOC.
    7. Iterates through the links, downloading each PDF sequentially.
    8. Waits for the file system to confirm the download is complete, then renames the file 
       using a standardized VxxNxx prefix
    9  Applies a randomised delay between downloads to reduce server system stress.

External Libraries Used:
    - undetected-chromedriver: A heavily optimized Selenium WebDriver patch.
    - selenium: Used for programmatic web navigation, element selection (XPath, ID, Class), 
      and interacting with the DOM (clicking, typing).
"""

import argparse
import glob
import logging
import os
import random
import re
import subprocess
import time
from pathlib import Path

# Use undetected_chromedriver instead of standard selenium
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s"
)

# ---------------------------------------------------------------------------
# CLI parsing & Formatting
# ---------------------------------------------------------------------------

# Parses user inputs from the command line, establishing the volume, issue, 
# Chrome profile directory, and the base delay to use between downloads.
def parse_cli():
    parser = argparse.ArgumentParser(description="Download IET E and T issue PDFs")
    parser.add_argument("volume", help="Volume, e.g. v4 or V04")
    parser.add_argument("issue", help="Issue, e.g. n12 or N12")
    parser.add_argument("--profile", "-p", 
                        default="Chrome_Scraper_Profile", 
                        help="Local Chrome profile folder name")
    # New Delay Argument
    parser.add_argument("--delay", "-d", 
                        type=float,
                        default=15.0, 
                        help="Base delay in seconds between downloads (default: 15)")
    
    args = parser.parse_args()

    def extract_number(text, prefix):
        text = text.strip().lower()
        if not text.startswith(prefix):
            raise ValueError(f"Expected {prefix} prefix in '{text}'")
        return int(text[1:])

    try:
        vol = extract_number(args.volume, "v")
        iss = extract_number(args.issue, "n")
        return vol, iss, args.profile, args.delay # Added delay to return
    except Exception as e:
        raise SystemExit(f"Invalid arguments: {e}")

# Generates a standardised, zero-padded string (e.g., "V04N12") used for naming folders and files.    
def format_prefix(volume, issue):
    return f"V{volume:02d}N{issue:02d}"

# Creates the target directory for the downloaded PDFs in the current working directory.
def prepare_output_dir(prefix):
    path = Path.cwd() / prefix
    path.mkdir(parents=True, exist_ok=True)
    return path

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------

# Reads the user's IET credentials from ~/.config/iet/iet.
# Gracefully ignores whitespace and formatting inconsistencies to extract the username and password.
def load_iet_config():
    config_path = os.path.expanduser("~/.config/iet/iet")
    creds = {"user": None, "password": None}
    
    if not os.path.exists(config_path):
        logging.warning(f"Config file not found at {config_path}")
        return None

    try:
        with open(config_path, 'r') as f:
            for line in f:
                # Ignore empty lines or lines without '='
                if '=' not in line:
                    continue
                parts = line.split('=', 1)
                key = parts[0].strip().lower()
                val = parts[1].strip()
                
                if key == 'user':
                    creds['user'] = val
                elif key == 'password':
                    creds['password'] = val
                    
        if creds['user'] and creds['password']:
            return creds
    except Exception as e:
        logging.error(f"Error reading config: {e}")
    return None

# ---------------------------------------------------------------------------
# Handle logging in to the website
# ---------------------------------------------------------------------------

from selenium.common.exceptions import ElementClickInterceptedException, TimeoutException

# Executes a standard click on a web element, falling back to a direct JavaScript click 
# if a transparent overlay (like a cookie banner) intercepts the standard interaction.
def safe_click(driver, element):
    """
    Attempts a standard click; if blocked by an overlay, forces a JavaScript click.
    """
    try:
        element.click()
    except ElementClickInterceptedException:
        logging.info("Click intercepted by overlay; forcing click via JavaScript.")
        driver.execute_script("arguments[0].click();", element)

# Navigates the complex IET login sequence.
# It attempts to clear cookie banners, navigates the dropdown login menu, aggressively wipes 
# pre-filled data from the input fields using keyboard shortcuts, and submits the user credentials.
def login_to_iet(driver, username, password):
    """
    Handles the login process, forcing clicks through the cookie overlay if necessary.
    """
    logging.info("Starting automated login sequence...")
    wait = WebDriverWait(driver, 15)
    
    try:
        # --- STEP 0: DISMISS COOKIE OVERLAY (if possible) ---
        try:
            # We look for the button with title="Allow Essential" you found
            cookie_btn = WebDriverWait(driver, 7).until(
                EC.element_to_be_clickable((By.XPATH, "//a[@title='Allow Essential']"))
            )
            safe_click(driver, cookie_btn)
            logging.info("Cookie overlay dismissed.")
            time.sleep(1) 
        except Exception:
            logging.info("Cookie overlay not found or already dismissed.")

        # --- STEP 1: CLICK MAIN LOGIN TRIGGER ---
        login_trigger = wait.until(EC.element_to_be_clickable((By.CLASS_NAME, "sign-in")))
        safe_click(driver, login_trigger)
        logging.info("Clicked main login trigger.")

        # --- STEP 2: CLICK LOGIN IN DROPDOWN ---
        dropdown_login = wait.until(EC.element_to_be_clickable(
            (By.XPATH, "//span[@class='head-login-popup__label' and contains(text(), 'Login')]")
        ))
        safe_click(driver, dropdown_login)
        logging.info("Clicked 'Login' from the dropdown menu.")

        # STEP 3: FILL LOGIN FIELDS
        logging.info("Waiting for login fields...")
        
        user_field = wait.until(EC.visibility_of_element_located(
            (By.XPATH, "//input[@type='email' or @type='text' or @name='loginfmt' or @id='email']")
        ))
        pass_field = driver.find_element(By.ID, "password")
        submit_button = driver.find_element(By.ID, "next")

        # --- THE ROBUST WIPE ---
        # We use Control+A followed by Backspace to ensure the field is empty
        for field, value in [(user_field, username), (pass_field, password)]:
            field.click()
            field.send_keys(Keys.CONTROL + "a")
            field.send_keys(Keys.BACKSPACE)
            field.send_keys(value)
        
        logging.info("Credentials entered into cleared fields.")

        # --- STEP 4: SUBMIT ---
        # This is where the last intercept happened; safe_click will bypass it
        safe_click(driver, submit_button)
        
        # Wait to see if login succeeds (URL changes or modal disappears)
        time.sleep(5)
        logging.info("Login form submitted.")
        
    except Exception as e:
        logging.warning(f"Automated login failed: {e}")
        logging.info("You may need to finish logging in manually.")


# ---------------------------------------------------------------------------
# Browser Setup
# ---------------------------------------------------------------------------

# Configures and launches a stealth Chrome instance.
# Sets up a persistent user profile and modifies browser preferences to force PDFs 
# to download silently to the target directory rather than opening in the browser's PDF viewer.
def setup_browser(output_dir, profile_name):
    options = uc.ChromeOptions()
    
    # Create an absolute path for the profile directory in the current working dir
    profile_path = os.path.abspath(profile_name)
    logging.info(f"Using Chrome profile at: {profile_path}")
    
    # Chrome uses --user-data-dir for profiles
    options.add_argument(f"--user-data-dir={profile_path}")
    
    # Chrome preferences for silent PDF downloads
    prefs = {
        "download.default_directory": str(output_dir),
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "plugins.always_open_pdf_externally": True  # This forces download instead of opening the viewer
    }
    options.add_experimental_option("prefs", prefs)

    # Initialize undetected-chromedriver
    driver = uc.Chrome(options=options, version_main=None)
    return driver

# ---------------------------------------------------------------------------
# Navigation & Download Logic
# ---------------------------------------------------------------------------

# Navigates to the issue's Table of Contents, pauses for human verification (to handle captchas), 
# and scrapes the DOM for all unique article PDF links, preserving their original order.
def get_pdf_links(driver, toc_url):
    logging.info(f"Navigating to TOC: {toc_url}")
    driver.get(toc_url)
    
    # --- MANUAL INTERVENTION STEP ---
    print("\n" + "="*60)
    print("ACTION REQUIRED:")
    print(f"1. Check the Chrome window.")
    print(f"2. Log in manually if required (and pass Cloudflare if it appears).")
    print(f"3. Ensure you can see the article list on the page.")
    print("="*60)
    input("Press Enter here in the terminal once you are ready to start the download...")

    # Find all 'epdf' links
    elements = driver.find_elements(By.XPATH, "//a[contains(@href, '/doi/epdf/')]")
    links = [el.get_attribute("href") for el in elements]
    
    # Deduplicate while keeping order
    unique_links = list(dict.fromkeys(links))
    logging.info(f"Found {len(unique_links)} unique PDF links.")
    return unique_links

# Iterates over the scraped links to download each PDF.
# Monitors the local file system to detect when a download finishes (ignoring Chrome's temporary 
# .crdownload files), renames the completed file to a clean format, and applies a randomised 
# delay before requesting the next file to ease server load and prevent rate-limiting.
def download_issue(driver, links, output_dir, prefix, base_delay):
    failed_indices = []  # Track IDs that didn't get renamed
    for i, epdf_url in enumerate(links, start=1):
        pdf_url = epdf_url.replace("/epdf/", "/pdf/") + "?download=true"
        
        logging.info(f"[{i:02d}] Requesting: {pdf_url}")
        
        files_before = set(os.listdir(output_dir))
        driver.get(pdf_url)

        new_file = None
        # Increased timeout to 60 seconds to be safer
        for _ in range(60):
            time.sleep(1)
            files_after = set(os.listdir(output_dir))
            added_files = files_after - files_before
            # Filter out browser temporary files
            actual_files = [f for f in added_files if not f.endswith(('.part', '.crdownload', '.tmp'))]
            if actual_files:
                new_file = actual_files[0]
                break
        
        if new_file:
            old_path = output_dir / new_file
            # Clean filename: replace spaces with dashes, remove non-alphanumeric
            clean_name = re.sub(r'[^A-Za-z0-9._-]', '', new_file.replace(" ", "-"))
            new_name = f"{prefix}-{i:02d}-{clean_name}"
            os.rename(old_path, output_dir / new_name)
            logging.info(f"[{i:02d}] Success: {new_name}")
        else:
            # FAILURE DETECTION
            logging.error(f"[{i:02d}] Rename failed: No new file detected within 60s for {pdf_url}")
            failed_indices.append(i)
        
        if i < len(links):
            wait_time = max(1, base_delay + random.uniform(-5, 5))
            logging.info(f"Sleeping for {wait_time:.2f} seconds...")
            time.sleep(wait_time)
            
    return failed_indices

#    Merge all downloaded issue PDFs into a single consolidated PDF and
#    lock the resulting file as read-only.
#
#    This function searches for PDF files matching the pattern
#    '{volume_issue}-*.pdf' within the specified output directory,
#    sorts them lexicographically to preserve article order, and merges
#    them into a single output file named '{volume_issue}.pdf'.
#
#    After successful merging, the resulting PDF permissions are set to
#    read-only (444) to prevent accidental modification.
#
#    Parameters:
#        output_dir (str): Directory containing the downloaded PDF files.
#        volume_issue (str): Prefix identifying the issue (e.g. 'V06N01').
#
#    Raises:
#        subprocess.CalledProcessError: If the pdftk merge operation fails.
#        ValueError: If no matching PDF files are found.

def merge_pdfs(output_dir, volume_issue, failed_indices):
    pattern = os.path.join(output_dir, f"{volume_issue}-*.pdf")
    pdfs = [p for p in sorted(glob.glob(pattern)) if os.path.getsize(p) > 0]

    if not pdfs:
        logging.error("No renamed PDFs found to merge.")
        return

    # Create the filename suffix for failures
    fail_suffix = ""
    if failed_indices:
        fail_tag = "-".join(map(str, failed_indices))
        fail_suffix = f"-failed-rename-{fail_tag}"
        logging.warning(f"!!! Warning: Missing indices in merge: {failed_indices}")

    output_file = os.path.join(output_dir, f"{volume_issue}{fail_suffix}.pdf")
    logging.info(f"Merging {len(pdfs)} PDFs into {output_file}")

    subprocess.run(["pdftk", *pdfs, "output", output_file], check=True)
    os.chmod(output_file, 0o444)
    
    # Provide the manual fix command if something failed
    if failed_indices:
        print("\n" + "="*60)
        print("MANUAL FIX REQUIRED")
        print(f"Indices {failed_indices} were downloaded but not renamed.")
        print(f"1. Find the files in {output_dir}")
        print(f"2. Rename them to follow the pattern: {volume_issue}-[index]-something.pdf")
        print("3. Run this command to re-merge:")
        print(f"   pdftk {output_dir}/{volume_issue}-*.pdf output {output_dir}/{volume_issue}.pdf")
        print("="*60 + "\n")

# ---------------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------------

# The primary function.
# Ties together
#   o CLI parsing,
#   o browser initialisation,
#   o credential loading,
#   o authentication, 
#   o the download loop, 
# 
# Ensures the browser safely quits upon completion or failure.
def main():
    volume, issue, profile, delay = parse_cli() # Added delay
    prefix = format_prefix(volume, issue)
    output_dir = prepare_output_dir(prefix)
    failed = []

    logging.info(f"Starting archive of {prefix} with base delay {delay}s")
    
    # Load credentials
    creds = load_iet_config()
    
    driver = setup_browser(output_dir, profile)
    
    try:
        toc_url = f"https://digital-library.theiet.org/toc/et/{volume}/{issue}"
        driver.get(toc_url)

        # Attempt the login
        if creds and driver.find_elements(By.CLASS_NAME, "sign-in"):
            login_to_iet(driver, creds['user'], creds['password'])
        else:
            logging.info("No credentials found, proceeding to manual login/check.")
        
        links = get_pdf_links(driver, toc_url)

        if links:
            failed = download_issue(driver, links, output_dir, prefix, delay) # Passed delay
        else:
            logging.warning("No links found.")
        
            
    finally:
        logging.info("Closing browser...")
        driver.quit()

    merge_pdfs(output_dir, prefix, failed)

if __name__ == "__main__":
    main()
