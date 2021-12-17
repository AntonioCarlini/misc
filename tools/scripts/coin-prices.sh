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

# ~/.config/coin-prices/coins.txt lists the required coins, in order, by symbol or symbol:id, one per line
coins_with_id=$(<~/.config/coin-prices/coins.txt)
coins=$(sed 's/:.*$//' ~/.config/coin-prices/coins.txt)
coinslist=$(echo ${coins}  | tr '[:blank:]' ',' | tr '[:upper:]' '[:lower:]')
# Grab the required data for all coins in one go via the coingecko API
result=$(curl -s -X GET "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&symbols=${coinslist}" -H "accept: application/json")

[[ "$1" == "debug" ]] && echo "${result}" | jq

# Now run through every crypto coin that the spreadsheet cares about and collect its values
for coin_with_id in ${coins_with_id}
do
    # Some coins have the same symbol but differing ID values, so for example DOGE has:
    #     "id": "dogecoin",
    #     "symbol": "doge",
    # and
    #     "id": "binance-peg-dogecoin",
    #     "symbol": "doge",
    # To handle this, while keeping the simple "symbol" approach in most cases, the
    # coins.txt file allows for an optional ID to be specified as:
    #  symbol:id
    # So FLOW can be specified as a line that just says "FLOW" but for DOGE the
    # entry reads "DOGE:DOGECOIN" and in this case the request matches against
    # the specified ID too.
    IFS=':' read -ra array <<< "${coin_with_id}"
    coin=${array[0]}
    id_lc=$(echo "${array[1]}" | tr '[:upper:]' '[:lower:]')
    [[ "${id_lc}" == "" ]] && id_lc=$(echo "${array[0]}" | tr '[:upper:]' '[:lower:]')
    # The coingecko symbols are case-sensitive and all lowercase, so ensure that that's what we ask for
    coin_lc=$(echo "${coin}" | tr '[:upper:]' '[:lower:]')
    price=$(echo "${result}" | jq ".[] | select(.symbol==\"${coin_lc}\") | select(.id==\"${id_lc}\") | .current_price")
    [[ "${price}" == "" ]] && price=$(echo "${result}" | jq ".[] | select(.symbol==\"${coin_lc}\") | .current_price")
    echo "${coin} (in $),\"${price}\""
done

# Notes:
#
# Information sources come and go. Here are some others that work at the moment (2021-NOV).
#
# curl -s https://api.coinbase.com/v2/prices/btc-USD/spot | jq
