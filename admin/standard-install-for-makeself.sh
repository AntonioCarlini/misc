#!/usr/bin/env sh

# This script prepares the environment for the main ruby script.

echo "makeself-based installer starting ..."

case $1 in
    "bundle")
	BUNDLE=${SCRIPT_DIR}/misc.bundle ${SCRIPT_DIR}/standard-install.sh
    ;;
    "archive")
    ;;
esac

echo "makeself-based installer finished."
