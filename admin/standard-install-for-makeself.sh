#!/usr/bin/env sh

# This script prepares the environment for the main ruby script.
#
# This script supports being invoked to install a git bundle or a tar archive.
#
# Parameters:
#
# $1
#    bundle:  expect a bundle, invoke standard-install.sh to build a repo from it
#    archive: unsupported at the moment

SCRIPT_DIR=$(dirname $0)

# Try to cope if no arguments are supplied.
# If bundle/archive is somehow missing but other args are supplied this will not work.
# Since bundle/archive is specified at build time, this really should never happen!
style=""
if [ "$#" = "0" ]
then
    if [ -f ./misc.bundlex ]; then
        style="bundle"
    else
        style="archive"
    fi
    echo "Installer style unknown. Guessing at '$style'"
else
    style=$1        # the first arg is the style (bundle or archive)
    shift           # do not pass on the first argument
fi

# Now perform the main action.
case $style in
    "bundle")
	BUNDLE=${SCRIPT_DIR}/misc.bundle ${SCRIPT_DIR}/standard-install.sh "$@"
        ;;
    "archive")
        echo "Archive distribution currently unsupported."
        exit 1
        ;;
esac

echo "makeself-based installer finished."
