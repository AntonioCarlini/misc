#!/usr/bin/env python3
"""
CDROM directory validator.

Checks directories named CDROM-xx-xxxxx-xx-YYYY-MM-text against strict rules:
  - required files: ISO, JPG, sha256sum.txt, 00README.txt
  - README must follow strict format
  - sha256sum.txt must describe exactly the required files
  - copy method logs validated (dd or ddrescue)

Options:
  --root PATH        : check all dirs under PATH
  --check-dir DIR    : check only specified dir(s)
  --verbose          : print detailed info
  --check-sha256     : verify file SHA256 checksums

"""

import argparse
import os
import re
import hashlib
import calendar
import sys

# === Constants ===
MIN_YEAR = 1990                 # No CDROM has a date earlier than this
MAX_YEAR = 2010                 # No CDROM has a date later than this
MAX_DISK_N = 12                 # Maximum number in "Disc x of N"

# regex for directory names
DIR_PATTERN = re.compile(r"^CDROM-([A-Z]{2}-[A-Z0-9]{5}-[A-Z]{2})-(\d{4})-(\d{2})-([A-Za-z][A-Za-z0-9.-]*)$")

# === Helpers ===
def verbose_print(verbose, msg):
    if verbose:
        print(msg)

# === Check functions ===
def check_directory_files(path, dirname, verbose=False, check_sha256=False):
    """Verify directory contains required files and nothing else."""
    errors = []
    full_path = os.path.join(path, dirname)
    m = DIR_PATTERN.match(dirname)
    if not m:
        return [f"ERROR: Directory name {dirname} does not match expected pattern"]
    part_number, year, month, text = m.groups()

    # Required filenames
    iso_file = f"{dirname}.iso"
    jpg_file = f"{dirname}.jpg"
    readme_file = "00README.txt"
    sha_file = "sha256sum.txt"
    required = {iso_file, jpg_file, readme_file, sha_file}

    actual = set(os.listdir(full_path))
    
    # Check required presence
    for fname in required:
        if fname in actual:
            verbose_print(verbose, f"  Found required file: {fname}")
        else:
            errors.append(f"ERROR: Missing required file {fname}")

    # Extra files check
    extras = actual - required
    for ex in extras:
        errors.append(f"ERROR: Unexpected file present: {ex}")

    # sha256sum.txt validation
    # Note that the sha file must not appear in itself!
    if sha_file in actual:
        errors.extend(check_sha256_file(full_path, dirname, required - {sha_file}, check_sha256))

    # README validation
    if readme_file in actual:
        errors.extend(check_readme_format(full_path, dirname, part_number, year, month, text, verbose))

    return errors


def check_sha256_file(full_path, dirname, required_files, check_sha256):
    """Verify sha256sum.txt contains exactly required files, and optionally validate hashes."""
    errors = []
    sha_file = os.path.join(full_path, "sha256sum.txt")
    listed = {}

    with open(sha_file, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip():
                continue  # skip blank lines

            # Try to match the two valid sha256sum formats
            if "  " in line:
                # text mode: "<hash><2 spaces><filename>"
                checksum, fname = line.split("  ", 1)
            elif " *" in line:
                # binary mode: "<hash><space><asterisk><filename>"
                checksum, fname = line.split(" *", 1)
            else:
                errors.append("Error: sha256sum.txt: malformed separator: " + line)
                continue

            checksum = checksum.strip()
            fname = fname.strip()

            if not checksum or not fname:
                errors.append("Error: sha256sum.txt: missing checksum or filename: " + line)
                continue

            listed[fname] = checksum

            
    missing_in_sha = required_files - set(listed.keys())
    extra_in_sha = set(listed.keys()) - required_files
    for f in missing_in_sha:
        errors.append(f"ERROR: sha256sum.txt: Missing entry for {f}")
    for f in extra_in_sha:
        errors.append(f"ERROR: sha256sum.txt: Extra entry for {f}")

    if check_sha256:
        for fname, checksum in listed.items():
            fpath = os.path.join(full_path, fname)
            if not os.path.exists(fpath):
                errors.append(f"ERROR: sha256sum.txt: Listed file not present: {fname}")
                continue
            h = hashlib.sha256()
            with open(fpath, "rb") as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    h.update(chunk)
            actual = h.hexdigest()
            if actual != checksum:
                errors.append(f"ERROR: sha256sum.txt: Checksum mismatch for {fname}")
    return errors


def check_readme_format(full_path, dirname, part_number, year, month, text, verbose):
    """Validate README format against strict rules."""
    errors = []
    readme_file = os.path.join(full_path, "00README.txt")
    with open(readme_file, "r", encoding="utf-8", errors="replace") as f:
        lines = [l.rstrip("\n") for l in f]

    if len(lines) < 5:
        errors.append("ERROR: README too short")
        return errors

    title = lines[0]
    disc_line = lines[1]
    date_line = lines[2]
    part_line = lines[3]
    vol_line = lines[4]

    # Title plausibility
    # Note that AXP titles are known to be difficult to match. Try our best but expect to add further mitigations.
    norm_title = re.sub(r"[\s/.-]+", "", title).lower()
    norm_title = re.sub("openvmsaxp", "axpvms", norm_title)
    norm_title = re.sub("layeredproductsonlinedocumentation", "odl", norm_title)
    norm_text = re.sub(r"[-.]", "", text).lower()
    if (norm_title != norm_text):
        errors.append(f"ERROR: README TITLE ('{title}')=>('{norm_title}') does not plausibly match text segment ('{text}')=>('{norm_text}')")

    # Disc line
    m = re.match(r"Disc (\d+) of (\d+)$", disc_line)
    if not m:
        errors.append("ERROR: README Disc line malformed")
    else:
        n, mval = map(int, m.groups())
        if not (1 <= n <= mval <= MAX_DISK_N):
            errors.append("ERROR: Disc N/M values out of range")

    # Date line
    month_name = calendar.month_name[int(month)]
    expected_date = f"{month_name} {year}"
    if date_line != expected_date:
        errors.append(f"ERROR: README Month Year mismatch: expected '{expected_date}' but found '{date_line}'")

    # Part line
    if part_line != part_number:
        errors.append(f"ERROR: README part number mismatch: expected '{part_number}' but found '{part_line}'")

    # Volume label line
    if not vol_line.startswith("Volume label: "):
        errors.append(f"ERROR: README Volume label line malformed: found '{vol_line}'")
    else:
        label = vol_line[len("Volume label: "):]
        if label.strip() == "" and label != "":
            errors.append("ERROR: Volume label is whitespace only")
        # ISO9660 label plausibility (A–Z0–9_ only, max 32)
        if label and not re.match(r"^[A-Z0-9_]{1,32}$", label):
            errors.append("ERROR: Volume label not ISO9660-compliant")

    # Blank line after header
    if len(lines) < 6 or lines[5] != "":
        errors.append("ERROR: Missing blank line after header")

    # Copy method info
    rest = "\n".join(lines[6:])
    if rest.startswith("Imaged using dd"):
        errors.extend(check_dd_information(rest, dirname))
    elif rest.startswith("Imaged using ddrescue"):
        errors.extend(check_ddrescue_information(rest, dirname))
    else:
        errors.append("ERROR: README copy method not recognized")

    return errors


def check_dd_information(block, dirname):
    """Check dd imaging block."""
    errors = []
    if "TSSTcorp CDDVDW SH-224BB (rev SB00)" not in block:
        errors.append("ERROR: dd: Device not recognized")

    # Must contain dd command
    cmd_match = re.search(r"\$ dd (.*?)\n", block)
    if not cmd_match:
        errors.append("ERROR: dd: Missing dd command line")
    else:
        cmd = cmd_match.group(1)
        if f"of={dirname}.iso" not in cmd:
            errors.append("ERROR: dd: output file mismatch")
        if "if=/dev/sr1" not in cmd:
            errors.append("ERROR: dd: missing if=/dev/sr1")

    # Check records match
    rin = re.search(r"(\d+)\+0 records in", block)
    rout = re.search(r"(\d+)\+0 records out", block)
    if rin and rout:
        if rin.group(1) != rout.group(1):
            errors.append("ERROR: dd: records in/out mismatch")

    return errors


def check_ddrescue_information(block, dirname):
    """Check ddrescue imaging block."""
    errors = []

    if "TSSTcorp CDDVDW SH-224BB (rev SB00)" not in block:
        errors.append("ERROR: ddrescue: Device not recognized")

    if "Note: some data NOT recorvered." in block:
        errors.append("Warning: Misspelling 'recorvered' detected")
    elif "Note: some data NOT recovered." in block:
        pass
    elif "Recovered without error." in block:
        if "error" in block.lower():
            errors.append("ERROR: ddrescue: claimed no error but log shows errors")
    # command line check
    if not re.search(r"\$ ddrescue .* /dev/sr1 .*\.iso", block):
        errors.append("ERROR: ddrescue: missing or malformed command line")

    return errors

# === Main ===
def main():
    parser = argparse.ArgumentParser(description="Check CDROM directories")
    parser.add_argument("--root", help="Root directory to check")
    parser.add_argument("--check-dir", action="append", help="Specific directory to check")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--check-sha256", action="store_true")
    args = parser.parse_args()

    if args.root and args.check_dir:
        print("Error: --root and --check-dir cannot be used together", file=sys.stderr)
        sys.exit(1)

    dirs_to_check = []
    if args.check_dir:
        dirs_to_check = args.check_dir
    else:
        root = args.root or os.getcwd()
        dirs_to_check = [d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d))]
        dirs_to_check = [os.path.join(root, d) for d in dirs_to_check]


    # keep track of directories with errors
    error_dirs = []     # list of DIR with at least one error (in order encountered)
    error_counts = {}   # dict of DIR to "number of errors"

    for d in dirs_to_check:
        dirname = os.path.basename(d)
        if DIR_PATTERN.match(dirname):
            verbose_print(args.verbose, f"Checking {dirname}")
        else:
            if args.verbose:
                verbose_print(True, f"Ignoring {dirname}")
            continue
        errors = check_directory_files(os.path.dirname(d), dirname, args.verbose, args.check_sha256)

        if (len(errors) > 0) and (not args.verbose):
            print(f"Checking {dirname} found:")
        for e in errors:
            print("  " + e)

        if errors:
            error_dirs.append(d)
            error_counts[d] = len(errors)
            
    # Report a summary
    if error_dirs:
        for d in error_dirs:
            count = error_counts[d]
            issue_word = "issue" if count == 1 else "issues"
            print(f"ERRORS in {d} ({count} {issue_word})")
    else:
        if args.verbose:
            print("No errors found")
            
if __name__ == "__main__":
    main()
