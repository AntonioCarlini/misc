#!/usr/bin/python

# wget -N http://chromedriver.storage.googleapis.com/2.9/chromedriver_linux64.zip -P ~/Downloads
# unzip ~/Downloads/chromedriver_linux64.zip -d ~/Downloads
# chmod +x ~/Downloads/chromedriver
# sudo mv -f ~/Downloads/chromedriver /usr/local/share/chromedriver
# sudo ln -s /usr/local/share/chromedriver /usr/local/bin/chromedriver
# sudo ln -s /usr/local/share/chromedriver /usr/bin/chromedriver
# usename: 
# password: 

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver import ActionChains
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from os.path import expanduser

import argparse
import os
import re
import time

# Function to ensure the download area exists
def make_download_area_name(volume_number, issue_number):
    return "/home/antonioc/Downloads/IEE-V{:02d}-N{:02d}".format(volume_number, issue_number)


# Function to ensure that the magazine-specific download area exists
def create_download_area(download_area_full_path):
    # os.makedirs() raises an exception if the requested directory path already exists.
    # python 3 has os.makedirs(path, exist_ok = True) but python 2 does not so trap and ignore the error instead
    try:
        os.makedirs(download_area_full_path)
    except OSError, e:
        if e.errno != os.errno.EEXIST:
            raise   
        pass


# Configure and activate the Chrome browser
def use_chrome_browser(download_area_full_path):
    options = webdriver.ChromeOptions()
    #options.add_argument('--ignore-certificate-errors')
    #options.add_argument("--test-type")
    #options.binary_location = "/usr/bin/google-chrome"

    profile = {"plugins.plugins_list": [{"enabled":False,"name":"Chrome PDF Viewer"}], "download.default_directory" : download_area_full_path}
    options.add_experimental_option("prefs", profile)

    driver = webdriver.Chrome(chrome_options = options)
    driver = webdriver.Chrome()

    driver.command_executor._commands["send_command"] = ("POST", '/session/$sessionId/chromium/send_command')
    params = {'cmd': 'Page.setDownloadBehavior', 'params': {'behavior': 'allow', 'downloadPath': dl_tgt}}
    command_result = driver.execute("send_command", params)

    return driver

# Configure and activate the Firefox browser
def use_firefox_browser(download_area_full_path):
    mime_types = "application/pdf,application/vnd.adobe.xfdf,application/vnd.fdf,application/vnd.adobe.xdp+xml"

    profile = webdriver.FirefoxProfile()
    profile.set_preference("browser.download.folderList", 2)
    profile.set_preference("browser.download.manager.showWhenStarting", False)
    profile.set_preference("browser.download.dir", dl_tgt)
    profile.set_preference("browser.helperApps.neverAsk.saveToDisk", mime_types)
    profile.set_preference("plugin.disable_full_page_plugin_for_types", mime_types)
    profile.set_preference("pdfjs.disabled", True)
    profile.set_preference("browser.link.open_newwindow.restriction", 0)
    profile.set_preference("browser.link.open_newwindow", 1)
    profile.set_preference("plugin.scan.plid.all", False)
    profile.set_preference("plugin.scan.Acrobat", "99.0")
    profile.set_preference("plugin.disable_full_page_plugin_for_types", "application/xpdf")
    
    driver = webdriver.Firefox(firefox_profile = profile)

    return driver

def fetch_password():
    home = expanduser("~")
    pwd_file_name = home + "/.iet"
    with open(pwd_file_name) as pwd_file:
        pwd = pwd_file.readline().strip()
    return pwd

# Log in to the IET website, assuming the browser is on the journal TOC page
def login_to_iet(username, password, driver):
    # Click on the Login button to reveal the boxes
    driver.find_element(By.XPATH, '//*[@id="loginBox"]/ul/li[1]/h4/a').click();

    # Click on "remember me". This button is not always present, so allow for that possibility.
    remember_me = driver.find_elements_by_xpath('//*[@id="remember"]')
    if len(remember_me) > 0:
        # Wait for the "remember me" radio button to be visible before trying to click on it.
        WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.XPATH,'//*[@id="remember"]')))
        remember_me[0].click()

    # Enter username and password. Hit RETURN in the password box
    driver.find_element(By.XPATH, '//*[@id="signname"]').send_keys(username)
    driver.find_element(By.XPATH, '//*[@id="signpsswd"]').send_keys(password + "\n")

def volume_type(v):
    min_volume = 1
    max_volume = 12
    v = int(v)
    if (v < min_volume)  or (v > max_volume):
        raise argparse.ArgumentTypeError("Journal Volume must be {}..{}".format(min_volume, max_volume))
    return v

def issue_type(i):
    min_issue = 1
    max_issue = 14
    i = int(i)
    if (i < min_issue) or (i > max_issue):
        raise argparse.ArgumentTypeError("Journal Issue must be {}..{}".format(min_issue, max_issue))
    return i

# Parse arguments
parser = argparse.ArgumentParser(description = 'Select Volume and Issue')
parser.add_argument('--volume', required = True, type = volume_type)
parser.add_argument('--issue', required = True, type = issue_type)

args = parser.parse_args()

vol = args.volume
iss = args.issue

# Main code starts here
print("Starting IET journal retrieval for Volume {:02d} Issue {:02d}".format(vol, iss))

# Create the download area
dl_tgt = make_download_area_name(vol, iss)
create_download_area(dl_tgt)

# Start the relevant browser
driver = use_chrome_browser(dl_tgt)

# Say what's going on
print("Downloading to [" + dl_tgt + "] using " + driver.capabilities['browserName'] + " " + driver.capabilities['version'])

# Navigate to the journal page and log in
password = fetch_password()
driver.get("http://digital-library.theiet.org/content/journals/et/{:d}/{:d}".format(vol, iss))
login_to_iet("arcarlini", password, driver)

# Pick up the HTML source for the whole table of contents page
html = driver.page_source

# Drop everything after the text "Most viewed content for this Journal" because that includes further links to articles which would be erroneously downloaded
viable = re.findall(r'\A(.*)<div class="headlinelarge"><h2>Most viewed content for this Journal</h2></div>', html, re.MULTILINE | re.DOTALL)

# Pick up everything that looks like a link to an article in this journal
# The relevant HTML looks like this:
# <h5 class="browseItemTitle">
# <a href="/content/journals/10.1049/et_20070106" title="" 
# >Editor&apos;s comment</a></h5>

result = re.findall(r'<h5 class="browseItemTitle">.*?<a href="(.*?)" title="".*?>(.*?)</a></h5>', viable[0], re.MULTILINE | re.DOTALL)

# Loop through all the links to article pages
for index, rs in enumerate(result):
    link = "http://digital-library.theiet.org" + rs[0]
    print ("Fetching [{:02d}] <link> = [{}] <title> = {}".format(index + 1, link, rs[1].encode('utf-8')))
    # Move to the specific article page
    driver.get(link)
    # Within the article page there is a link to the PDF file for that article. Click that link.
    link = driver.find_element_by_link_text('PDF')
    link.click()
    #actionChains = ActionChains(driver)
    # In Firefox: right click, down arrow five times and hit RETURN to bring up the save dialog
    #print("Right clicklink ...")
    #actionChains.context_click(link).send_keys(Keys.ARROW_DOWN).send_keys(Keys.ARROW_DOWN).send_keys(Keys.ARROW_DOWN).send_keys(Keys.ARROW_DOWN).send_keys(Keys.ARROW_DOWN).send_keys(Keys.RETURN).perform()
    #actionChains.context_click(link).key_down(Keys.CONTROL).send_keys("A").key_up(Keys.CONTROL).perform()
    #print("pausing")
    #time.sleep(100)
    #print("breaking")
    #break

# For convenience, head back to the original TOC page.
driver.get("http://digital-library.theiet.org/content/journals/et/{:d}/{:d}".format(vol, iss))
