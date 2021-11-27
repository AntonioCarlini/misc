#!/usr/bin/env bash

# Start with two blank entries. This is purely to match the existing spreadsheet.
echo ","
echo ","
# Pick up the USD ($) to GBP (£) conversion rate
# floatrates.com provides this in JSON format for USD->many currencies.
# Use jq to pick out the GBP value, which gives this output:
#{
#  "code": "GBP",
#  "alphaCode": "GBP",
#  "numericCode": "826",
#  "name": "U.K. Pound Sterling",
#  "rate": 0.74218470834924,
#  "date": "Mon, 8 Nov 2021 11:55:01 GMT",
#  "inverseRate": 1.3473734890391
#}
# Then pick out the "rate" line with grep and pull out the number with cut.
usd2gbp=$(curl -s http://www.floatrates.com/daily/usd.json | jq .gbp | grep rate | cut -d: -f2 | cut -d, -f1)
echo "$ to £ conversion,${usd2gbp}"

# ~/.config/coin-prices/coins.txt lists the required coins, in order, by symbol, one per line
coins=$(echo $(<~/.config/coin-prices/coins.txt)  | tr '\n' ' ')

# Now run through every crypto coin that the spreadsheet cares about and collect its values
for coin in $coins
do
    price=$(curl -s rate.sx/1${coin})
    echo "${coin} (in $),\"${price}\""
done

# Notes:
#
# Information sources come and go. Here are some others that work at the moment (2021-NOV).
#
# curl -s https://api.coinbase.com/v2/prices/btc-USD/spot | jq
