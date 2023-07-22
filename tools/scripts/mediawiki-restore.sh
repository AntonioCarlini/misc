#!/bin/bash
#+
# This script restores the latest wiki backup onto an alternate system.
# This both checks that the latest backup is viable and also provides a current read-only wiki that
# can easily become live in the event of a failure of the system on which the main wiki runs.
#
# In addition to being a nearly live backup, the script also checks that the most recent backup
# has happened withing roughly the last 24 hours. This provides a check that the main wiki is
# being backed up in a timely manner.
#
# Requirements for the system performing the restore:
# o This script should be run as root using sudo
# o A reasonably current version of mediawiki installed and related software (e.g. mysql) must be installed.
# o The root account needs a .my.cnf file granting access to the mysql database
# o The mysql database user account (by default, root) and its password on the alternate system should match those of the live system.
#   If this is not the case, LocalSettings.php will need to be updated
# o borgbackup and llfuse must be installed.
#
# Requirements the original wiki must satisfy:
# o the images directory must contain a an image carlini-wiki-read-only-warning.png which shows  alogo that indicates this is a read-only wiki

set -x trace

PATH_TO_WIKI_BACKUP=/mnt/Antonio/Backups/borg/pi44gb
REPO_PREFIX=pi44gb-full-
BORG_MNT_POINT=/tmp/borg-restore
SQL_RESTORE_DIR=/tmp/sql-restore
BACKUP_TOO_LONG_AGO_HOURS=30

#+
# This function checks for the age of the specified backup, which should be the most recent,
# and issues a warning if the backup is too old (typically older than 24 hours plus a small
# margin to avoid too many false positives).
#
# Parameters:
# $1 The date and time of the backup in question, in the form "YYYY-MM-DD HH:MM:SS"
#
# Returns:
# 0 - backup is not too long ago
# 1 - backup is from too long ago, so something has probably gone wrong; a warning is output
#-
function check_for_missing_backups {
    backup_age_in_hours=$(( ( $(date +%s) - $(date --date="${1}" +%s)) / (60*60) ))
    echo "check performed for newest backup: ${1} ... age of backup in hours: ${backup_age_in_hours}"
    if  (( ${backup_age_in_hours} > ${BACKUP_TOO_LONG_AGO_HOURS} ))
    then
	echo "WARNING: most recent backup is more than ${BACKUP_TOO_LONG_AGO_HOURS} hours old."
	return 1
    fi
    
    return 0
}

#+
# Removes the existing wiki and restores the most recent backup
#
# - uses "borg list" to find the most recent backup
# - issues a warning if the backup is too old (in case backups have failed)
# - uses "borg mount" to make the most recent backup appear in the file system as a set of files
# - replaces /var/lib/mediawiki with the contents of the most recent backup
# - restores the most recent wiki MySQL database backup
# - edits LocalSettings.php to:
#     use the restore system's FQDN
#     note this is a read-only wiki
#     use a logo that makes it clear that this is not the original wiki
#-
function restore_wiki {
    # Display the borg version number in case it is needed for debug
    echo "borgbackup version: $(borg --version)"

    # The output from "borg list" looks like this:
    # pi44gb-full-202210290245             Sat, 2022-10-29 02:45:15 [68c0dd19ebf33e6869e4988db5a1cc8d2790a928616da24174e65d484536d89e]
    #
    # The first logical field (everything before the first space) is the repo name 
    # The second logical field (after the multiple spaces and terminated by a comma) is the 3 character English day name
    # The third logical field (before the ID in square brackets] is the archive start date/time
    # The fourth logical field is the archive internal ID (in square brackets)
    #
    latest_backup_info=$(borg list "${PATH_TO_WIKI_BACKUP}" --last 1)

    # Take everything up to the first space as a repo name
    repo_name=$(echo "${latest_backup_info}" | cut -f 1 -d' ')

    # Isolate the repo start (creation) time, without the day name
    # The first cut picks everything after the comma that follows the day name.
    # The second cut removes everything from the "[" that starts the internal ID.
    # The awk trims the leading whitespace (possibly unnecessary, as 'date' seems not to care)
    repo_creation_time=$(echo "${latest_backup_info}" | cut -f 2 -d',' | cut -f 1 -d'[' | awk '{$1=$1};1' ) 

    if [[ ${repo_name} != ${REPO_PREFIX}* ]]; then
        echo "Latest repository name not in expected format."
        echo "Expected a name starting in: ${REPO_PREFIX}"
        echo "Found repo name            : ${repo_name}"
        exit 1
    fi

    # Issue a warning if the most recent backup is more than about a day old
    check_for_missing_backups "${repo_creation_time}"

    # Mount the most recent backup so that it can be accessed as a directory tree
    mkdir -p "${BORG_MNT_POINT}"
    borg mount "${PATH_TO_WIKI_BACKUP}::${repo_name}" "${BORG_MNT_POINT}"


    # Replace /var/lib/mediawiki tree with the one from the most recent backup
    rm -r /var/lib/mediawiki/*
    cp -r ${BORG_MNT_POINT}/var/lib/mediawiki/* /var/lib/mediawiki/

    # Restore the most recent SQL backup and import it into mysql
    most_recent_sql_backup=$(ls -A1 ${BORG_MNT_POINT}/var/lib/automysqlbackup/daily/Carlini | tail -n 1)
    mkdir -p "${SQL_RESTORE_DIR}"
    cp "${BORG_MNT_POINT}/var/lib/automysqlbackup/daily/Carlini/${most_recent_sql_backup}" "${SQL_RESTORE_DIR}/."
    (cd "${SQL_RESTORE_DIR}" || exit; gunzip < "${most_recent_sql_backup}" | mysql)

    # TODO: set things up so this happens on error?
    borg umount ${BORG_MNT_POINT}

    # Replace the $wgServer line with one that reflects the host that is performing the restore (and will host the read-only wiki backup)
    local_fqdn=$(hostname -f)
    sed -i "s/^\s*\$wgServer\s*=\s*.*/\$wgServer = \"http:\/\/${local_fqdn}\";/" /var/lib/mediawiki/LocalSettings.php

    # Set wiki to be read-only ($wgReadOnly='This wiki is a restored nightly backup and new pages cannot be created';)
    sed -i "s/^\s*#\$wgReadOnly\s*=.*/\$wgReadOnly = \"This wiki is a read-only restored backup from ${repo_creation_time}\";/" /var/lib/mediawiki/LocalSettings.php

    # Set wiki image to one that indicates this is a backup
    sed -i "s/^\s*\$wgLogo\s*=.*/\$wgLogo = \"\$wgResourceBasePath\/images\/carlini-wiki-read-only-warning.png\";/" /var/lib/mediawiki/LocalSettings.php
}

#+
# Performs a restore of the latest wiki backup to this system's wiki (replacing whatever is there).
# Logs start and end times to help with debug and system management.
#-
function main {

    echo "Starting wiki restore at $(date +"%Y-%m-%d %H:%M:%S")"

    # This does the bulk of the work
    restore_wiki

    echo "Wiki restore completed at $(date +"%Y-%m-%d %H:%M:%S")"
}

# Invoke the function that does everything
main
