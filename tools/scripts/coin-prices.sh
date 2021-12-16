#!/usr/bin/env bash

# A simple script that produces a set of cryptocoin values in a format that the tracking spreadsheet expects.

# Pick up a USD ($) to GBP (£) conversion rate from http://www.floatrates.com.
# Pick up the required coin values from the coingecko API.
# Write out the expected spreadsheet page in CSV format

# Start with two blank entries. This is purely to match the existing spreadsheet.
echo "Last automatic update,$(date +'%Y-%m-%d %H:%M:%S')"
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
coins=$(<~/.config/coin-prices/coins.txt)
coinslist=$(echo ${coins}  | tr ' ' ',' | tr A-Z a-z)
# Grab the required data for all coins in one go via the coingecko API
result=$(curl -s -X GET "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&symbols=${coinslist}" -H "accept: application/json")

# Now run through every crypto coin that the spreadsheet cares about and collect its values
for coin in $coins
do
    # The coingecko symbols are case-sensitive and all lowercase, so ensure that that's what we ask for
    coin_lc=$(echo ${coin} | tr A-Z a-z)
    # Some coins have the same symbol but differing ID values, so for example DOGE has:
    #     "id": "dogecoin",
    #     "symbol": "doge",
    # and
    #     "id": "binance-peg-dogecoin",
    #     "symbol": "doge",
    # As this example shows, simply requesting an identical ID will not work.
    # It may become necessary to do something more sophisticaed in the future, but for now
    # just filter out anything that has an ID that starts with "binance-peg".
    # Also drop "genesis-mana" and "san-diego-coin"
    price=$(echo ${result} | jq ".[] | select(.symbol==\"${coin_lc}\") | select(.id | startswith(\"binance-peg\") | not) | select(.id | startswith(\"genesis-mana\") | not) | select(.id | startswith(\"san-diego-coin\") | not) | .current_price")
    echo "${coin} (in $),\"${price}\""
done

# Notes:
#
# Information sources come and go. Here are some others that work at the moment (2021-NOV).
#
# curl -s https://api.coinbase.com/v2/prices/btc-USD/spot | jq
