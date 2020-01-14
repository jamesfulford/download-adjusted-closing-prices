#!/bin/bash
# bash download.sh s_and_p_500.txt
# downloads alphavantage CSVs for all tickers in file
# (make sure to include )

# Rate limiting:
# 5 per minute (300/hour)
# 500 per day
ALPHAVANTAGE_API_KEY=${ALPHAVANTAGE_API_KEY:-"demo"}
OUTPUTSIZE="full"  # "compact" for quicker but less data

start_time=$(date +%s)
next_minute=$(($start_time+60))

mkdir -p output

function get_daily_csv() {
    local symbol="$1"
    local retries="${2:-"3"}"
    curl "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY_ADJUSTED&symbol=${symbol}&apikey=${ALPHAVANTAGE_API_KEY}&datatype=csv&outputsize=${OUTPUTSIZE}" > ./output/$symbol.csv
    asdf=$(head ./output/$symbol.csv | grep -c "{")
    if [[ "0" != "$asdf" ]]; then
        retries=$((retries-1))
        if [[ "0" == "$retries" ]]; then
            return 9
        fi

        seconds_wait=$((next_minute - $(date +%s)))
        echo "Hit rate limit... waiting $seconds_wait seconds... (retries left: $retries)"
        sleep $seconds_wait
        next_minute=$(($(date +%s)+60))
        get_daily_csv "$symbol" "$retries"
        return "$?"
    fi
    return 0
}

input_file="$1"
last_code="0"

rm -f $input_file.continue

while read -r line
do
    if [[ "0" == "$last_code" ]]; then
        echo "$line..."
        get_daily_csv "$line"
        last_code="$?"
    else
        echo "$line" > $input_file.continue
    fi
done < "$input_file"

if [[ "$last_code" != "0" ]]; then
    echo "Uh oh! Looks like we ran out of retries. Rate limiting gets ya every time!"
    echo "You can continue right where you left off by running:"
    echo "\tbash $input_file.continue"
fi
