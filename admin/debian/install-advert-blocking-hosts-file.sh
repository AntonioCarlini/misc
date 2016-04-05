#!/usr/bin/env bash
lynx -dump -nolist http://someonewhocares.org/hosts/ | sed -n -E -e '/Dan Pollock/,$ p' | grep -ve '[[:digit:]]\{4\} top$' > /tmp/hosts.advert-block
cat /etc/hosts | sed -E -e '/Dan Pollock/,$d' > /tmp/hosts.minimal
cp /etc/hosts /etc/hosts.original; cat /tmp/hosts.minimal /tmp/hosts.advert-block > /etc/hosts
