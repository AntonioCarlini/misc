#!/usr/bin/env bash
HERALD="Perform all edits BEFORE this line otherwise they may be automatically removed"
echo "" > /tmp/hosts.herald
echo "# $HERALD" >> /tmp/hosts.herald
echo "" >> /tmp/hosts.herald
lynx -dump -nolist http://someonewhocares.org/hosts/ | sed -n -E -e '/Dan Pollock/,$ p' | grep -ve '[[:digit:]]\{4\} top$' > /tmp/hosts.advert-block
cat /etc/hosts | sed -E -e "/$HERALD/,\$d" > /tmp/hosts.minimal
cp /etc/hosts /etc/hosts.original; cat /tmp/hosts.minimal /tmp/hosts.herald /tmp/hosts.advert-block > /etc/hosts
