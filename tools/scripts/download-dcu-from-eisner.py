#!/usr/bin/python3

import datetime
import re
import requests
import sys

#
# Grabs a Digital Customer Update issue from EISNER, building up a mediawiki page as it goes

if len(sys.argv) != 2:
    sys.exit("Please supply exactly one argument: the base URL of the DCU note on EISNER")

arg = sys.argv[1]
if arg.isdigit():
    base_page_url = "https://eisner.decus.org/anon/htnotes/dir?f1=INDUSTRY_NEWS&f2=" + arg + ".*"
else:
    base_page_url = sys.argv[1].replace("/range?", "/dir?").replace("&f4=t", "")

prefix_end_pos = base_page_url.rfind("/")
url_prefix = base_page_url[:prefix_end_pos] + "/"
# print("base URL prefix: [" + url_prefix + "]")

base_page = requests.get(base_page_url)

# Look in the returned text for:
#   <td><a href="note?f1=INDUSTRY_NEWS&amp;f2=572.0">TEXT</td>
# as this will identify the individual pages we want to gather 
notes = re.findall(r'<td><a href=".*"', base_page.text)


dcu_date = ""            # The date of this Digital's Customer Update in the form YYYY-MM-DD

headings_text = ""
headings_text_lowercase = ""

accumulated_errors = []

# Build a dictionary of "bad" titles to "good" titles
# In a few places the title of the note does not exactly match the title specified in the summary (in note .0).
# Fix those up here rather than tediously fixing them up hand afterwards.
fixed_title = {
"NAS V3.0 Packages and Advance Kit" : "NAS V3.0 Packages and Advanced Kit" # 615
, "DECbridge 500/600 series-FDDI Firmware Enhancements" : "DECbridge 500/600 Series FDDI Firmware Enhancements" # 615
, "DECtransporter Mobile Communications Software" : "DECtransporter Mobil Communications Software" # 616
, "Digital Solution Library Tools Package" : "Digital Solution Library Tools Packaged" # 616
, "RZ28 3.5-Inch, 2.1 Gbyte Drive" : "RZ28 3.5-Inch 2.1 Gbyte Drive" # 618
, "Larger Memory Available for DEC 3000 Systems" : "Larger Memory Available for DEC 3000 Workstations and Servers" # 617
, "RF74 DSSI In-Cabinet Disks for VAX 7000 and 10000 Systems" : "RF74 DSSI In-Cabinet Disk for VAX 7000 and 10000 Systems" # 621
}

# Loop through the matches to build up the required notes
for note in notes:
    # Build up the note URL using the prefix and the part of note URL that is href="...". Remember to replace "&amp;" with a simple "&".
    note_page_url = url_prefix + note.split('"')[1].replace("&amp;", "&")
    this_page = requests.get(note_page_url)

    # Look for the note date:
    #  <tr><td align=left width="15%"><a rel=nofollow href="range?f1=INDUSTRY_NEWS&amp;f2=572.*&amp;f4=t">Topic 572</a><th align=left>Digital's Customer Update - June 5, 1992</tr>
    # Note that on a few occasions the date is separated by a comma rather that a hyphen.
    date_match = re.search('<th align=left>Digital\'s Customer Update(?: - |,\s+)(.*?)</tr>', this_page.text)
    note_date = date_match.group(1)                          # note date will be in the format 'June 5, 1992'
    note_date = re.sub("Special Issue,\s*", "", note_date)   # Some issues have extra leading text: "Special Issue, "

    # Look for the note title
    #  <tr><td valign=top>Reply 1 of 29<td class=by>by EISNER::DEC_NEWS_1 &quot;DEC News and Press Releases&quot; at  8-JUN-1992 11:17<br>DEC @aGlance V1.0 Integrates Desktop Applications</tr>
    title_match = re.search('<tr>.*<br>(.*?)</tr>', this_page.text)
    note_title = title_match.group(1).strip()

    # Look for the body of the note. This lies between <td><PRE> and </PRE></tr>
    body_match = re.search('<td><PRE>(.*)</PRE></tr>', this_page.text, flags = re.MULTILINE | re.DOTALL)
    body_text = body_match.group(1)

    # Strip leading and trailing lines that are only whitespace
    body_text_list = body_text.splitlines()
    # Strip leading blank lines
    while body_text_list[0].strip() == '':
        del body_text_list[0]
    # Strip trailing blank lines
    while body_text_list[-1].strip() == '':
        del body_text_list[-1]
    body_text = '\n'.join(map(str, body_text_list))

    ## print("For URL [" + note_page_url + "] the date is <" + note_date + ">")
    ## print("The title is [" + note_title + "]")
    date_time = datetime.datetime.strptime(note_date, '%B %d, %Y')
    note_issue_date = date_time.strftime("%Y-%m-%d")
    if dcu_date:
        if note_issue_date != dcu_date:
            accumulated_errors.append("BAD DATE (" + note_issue_date + " for note: [" + note_page_url + "], expected " + dcu_date)
        # "Fix" the title if necessary
        if note_title in fixed_title:
            note_title = fixed_title[note_title]
        # Find the note title in the headings_text
        index_value = -1
        try:
            index_value = headings_text_lowercase.index(note_title.lower())
        except ValueError:
            index_value = -1
        if index_value < 0:
            try:
                index_value = headings_text_lowercase.index("o " + note_title.lower())
            except ValueError:
                index_value = -1
            if index_value < 0:
                accumulated_errors.append("COULD NOT FIND TITLE: [" + note_title + "] in " + note_page_url)
                accumulated_errors.append("Searched for: [" + note_title.lower() + "]")
                for entry in headings_text_lowercase:
                    accumulated_errors.append("entry:        <" + entry + ">")
        else:
            # Print all the values before this index. Blank ones as blank. All others as either "= TEXT =" or "== TEXT =="
            if index_value > 0:
                for i in range(0, index_value):
                    text = headings_text[i].strip()
                    ## print("text   [" + text + "]")
                    ## print("text U [" + text.upper() + "]")
                    if text == '':
                        print("")
                    elif text.upper() == text:
                        print("= " + text + " =")
                    else:
                        print("== " + text + " ==")
            # Print the heading we want
            print("== " + headings_text[index_value] + " == ")
            print("")
            print("Taken from [" + note_page_url + " EISNER].")
            print("")
            # Eliminate the used entries
            del headings_text[:index_value + 1]  # needs the +1 to include the element we've just printed in the removal
            del headings_text_lowercase[:index_value + 1]  # needs the +1 to include the element we've just printed in the removal
            ## print("Remaining headings:")
            ## print('\n'.join(map(str, headings_text)))
            ## print("End of Remaining headings:")
        print("<pre>")
        print(body_text)
        print("</pre>")
    else:
        ## print("First note has the date: " + note_date)
        dcu_date = note_issue_date
        # Here do the beginning of mediawiki page processing
        print("Digital Customer Update " + note_issue_date)
        print("This is the " + date_time.strftime("%d %b %Y") + " issue of Digital's Customer Update from [" + note_page_url + " EISNER].")
        print("")
        print("__TOC__")
        print("")
        print("<pre>")
        print(body_text)
        print("</pre>")
        print("")
        headings_text = body_text.splitlines()
        # Strip leading blank lines
        while headings_text[0].strip() == '':
            del headings_text[0]
        # Strip "Digital's Customer Update" line
        if headings_text[0].strip() != "Digital's Customer Update":
            accumulated_errors.append("Expected DCU")
        else:
            del headings_text[0]
        # Strip "In This Issue" line
        if headings_text[0].strip() != "In This Issue":
            accumulated_errors.append("Expected ITI")
        else:
            del headings_text[0]
        # Strip ${note_date} line
        if headings_text[0].strip() != note_date:
            accumulated_errors.append("Expected note date " + note_date)
        else:
            del headings_text[0]
        # Strip 2nd set of leading blank lines
        while headings_text[0].strip() == '':
            del headings_text[0]
        # Strip leading "o " (i.e. "o" followed by some whitespace) and then remove leading and trailing spaces
        headings_text = [re.sub("^\s*o\s+","",x).strip() for x in headings_text]
        # Build an identical list that is all lowercase
        headings_text_lowercase = [x.lower() for x in headings_text]
        ## print("Initial headings:")
        ## print('\n'.join(map(str, headings_text)))
        ## print("End of Initial headings:")
        ## print("Initial headings (lower):")
        ## print('\n'.join(map(str, headings_text_lowercase)))
        ## print("End of Initial headings:")

print("[[Category:Digital Customer Updates]]")

if len(accumulated_errors) > 0:
    print('\n'.join(map(str, accumulated_errors)))
