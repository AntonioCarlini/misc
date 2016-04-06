#!/usr/bin/env bash

# The default action is to install VMware player using the specified bundle.
# Alternatively other arguments can be passed to the bundle (use --help to see what is supported).

# The VMware Player bundle must be specified
if [[ $# < 1 ]]; then
    echo "Missing required argument"
    echo "Usage: $0 vmware-player-bundle"
    exit 1
fi

# The bundle must exist
if [[ ! -f $1 ]]; then
    echo "VMware Player bundle not found: $1"
    exit 1
fi

BUNDLE=$1

shift

OPTIONS="--eulas-agreed --required"
if [[ ! -z $1 ]]; then
    OPTIONS=$@
fi

# Install VMware player
bash $BUNDLE $OPTIONS
