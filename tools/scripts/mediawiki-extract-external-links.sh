#!/usr/bin/env bash
#
# Find all external links in a specified wiki.
#
# Usage:
#   ./mediawiki-extract-external-links.sh --client=wiki_prod --wiki=mywikidb --output=result.csv
#
# Options:
#   --client=NAME       Name of the MariaDB [client] section to use (required)
#   --wiki=DBNAME       Target MediaWiki database name (required)
#   --output=FILE       Output file to save results (required)
#
# This runs from the CLI and directly reads the MySQL database.
#
# Uses ~/.my.cnf for stored credentials because MariaDB does not support the mysql_config_editor.
#
#
# To set up a suitable 'client' add a section to ~/.my.cnf.
#  [clientwiki-prod]
#  user=WIKI-ADMIN-USER
#  password=WIKI-ADMIN-USER-PASSWORD
#
# Note that the client name immediately follows "client", so any punctuation there must appear on the CLI.
#

set -euo pipefail

# Defaults
MYSQL_CLIENT=""
WIKI_NAME=""
OUTPUT_FILE=""

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --client=*)
            MYSQL_CLIENT="${1#*=}"
            ;;
        --wiki=*)
            WIKI_NAME="${1#*=}"
            ;;
        --output=*)
            OUTPUT_FILE="${1#*=}"
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Validate required args
if [[ -z "${MYSQL_CLIENT}" || -z "${WIKI_NAME}" || -z "${OUTPUT_FILE}"  ]]; then
    echo "Usage: $0 --client=NAME --wiki=DBNAME --output=FILE" >&2
    exit 1
fi

WIKI_NAME_LC=${WIKI_NAME,,}

# Just demonstrate parsing for now
echo "Client:          ${MYSQL_CLIENT}"
echo "Wiki name:       ${WIKI_NAME}"
echo "Wiki name: (lc)  ${WIKI_NAME_LC}"
echo "Output:          ${OUTPUT_FILE}"

mysql --defaults-group-suffix=wiki-prod "${WIKI_NAME}" -e \
  "SELECT page.page_title AS 'Page', e.el_to AS 'External Link'
   FROM \`${WIKI_NAME_LC}-wikiexternallinks\` e
   JOIN \`${WIKI_NAME_LC}-wikipage\` page ON e.el_from = page.page_id
   ORDER BY page.page_title;" \
  | sed 's/\t/,/g' > "${OUTPUT_FILE}"
