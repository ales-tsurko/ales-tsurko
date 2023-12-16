#!/bin/sh
# Collect contributions for the past number of days specified by argument

api_endpoint="https://api.github.com/graphql"

output=contributions.csv

num_of_days=$1
num_of_args=$#

check_args() {
    if [ $num_of_args -ne 1 ]; then
        echo "\033[31mError: wrong number of arguments\033[0"
        exit 1
    fi
}

load_dotenv() {
    local dotenv=./.env

    if [ -e "$dotenv" ]; then
        . "$dotenv"
    fi
}

days_before() {
    local result=$(date -u --date="-${1} day" +"%Y-%m-%d" 2> /dev/null || \
        date -v -"$1"d -u +"%Y-%m-%d")

    echo "$result"
}

query_for_day() {
    local result="
    query {
      viewer {
        contributionsCollection(
            from: \"${1}T00:00:00\",
            to: \"${1}T23:59:59\"
        ) {
          contributionCalendar {
            totalContributions
          }
        }
      }
    }
    "

    echo "$result"
}

perform_request() {
    local q=$1 # query
    local filter=$2
    local processed=$(echo "$q" | perl -pe 's/\n/\\n/g' | perl -pe 's/"/\\"/g')

    local req="{\"query\": \"$processed\"}"

    local result=$(curl -H "Authorization: bearer $ACCESS_TOKEN" -X POST \
        -d "$req" "$api_endpoint")

    sleep 0.1
    echo "$result" | jq -c -r "$filter"
}

contributions() {
    local query=$(query_for_day "$1")
    local data=$(perform_request "$query" \
        '.data.viewer.contributionsCollection.contributionCalendar.totalContributions')

    echo "$data"
}

collect_contributions() {
    while [ "$num_of_days" -gt 0 ]; do
        num_of_days=$(( num_of_days - 1 ))
        local date=$(days_before "$num_of_days")
        local contribs=$(contributions "$date")
        echo "$date,$contribs"
    done
}

check_args
load_dotenv
echo "Date,Contributions" > "$output"
collect_contributions >> "$output"
