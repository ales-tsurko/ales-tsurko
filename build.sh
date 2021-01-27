#!/bin/sh

set -e

output_file="README.md"

graph_out="graph.png"

api_endpoint="https://api.github.com/graphql"

email="ales.tsurko@gmail.com"

telegram="https://t.me/alestsurko"

btc_addr="bc1q0p7tmxyyd0pn7qsfxwlm00ncazdzz24p8lagqp"

eth_addr="0x55B6805f462e19aaBdB304bc85F94099eac060CE"

pop_repos_q="
query {
  viewer {
    repositories(
        first: 5, 
        isFork: false, 
        orderBy: {field: STARGAZERS, direction: DESC}, 
        privacy: PUBLIC
    ) {
      nodes {
        name
        url
      }
    }
  }
}
"

langs_q="
query {
  viewer {
    topRepositories(first: 100, orderBy: {field: STARGAZERS, direction: ASC}) {
      nodes {
        languages(first: 2) {
          nodes {
            name
          }
        }
      }
    }
  }
}
"

yesterday=$(date --date="-1 day" -u +"%Y-%m-%d" 2> /dev/null || \
        date -v -1d -u +"%Y-%m-%d")

total_contribs_q="
query {
  viewer {
    contributionsCollection(
        from: \"${yesterday}T00:00:00\",
        to: \"${yesterday}T23:59:59\"
    ) {
      contributionCalendar {
        totalContributions
      }
    }
  }
}
"

starred_q="
query {
  viewer {
    starredRepositories(
        first: 5,
        orderBy: {field: STARRED_AT, direction: DESC}
    ) {
      nodes {
        name
        url
      }
    }
  }
}
"

load_dotenv() {
    local dotenv=./.env

    if [ -e "$dotenv" ]; then
        . "$dotenv"

        echo ".env loaded"
    fi
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

# generate list of top repos
pop_repos() {
    local data=$(perform_request \
        "$pop_repos_q" '.data.viewer.repositories.nodes[]')

    local result=""

    for obj in $data; do
        local name=$(printf '%s' "$obj" | jq -r '.name')
        local url=$(printf '%s' "$obj" | jq -r '.url')

        result+="- [$name]($url)"
        result+=$'\n'
    done
    
    echo "$result"
}

languages() {
    local data=$(perform_request "$langs_q" \
        '.data.viewer.topRepositories.nodes[].languages.nodes[].name')
    data=$(echo "$data" | tr -d '[:blank:]' | sort | uniq -c | sort -nr)
    data=$(echo "$data" | tr -d '[:digit:][:blank:]')
    data=$(echo "$data" | perl -pe 's/\n/, /g' | sed 's/,.$/\./')

    echo "$data"
}

total() {
    local data=$(perform_request "$total_contribs_q" \
        '.data.viewer.contributionsCollection.contributionCalendar.totalContributions')

    echo "$data"
}

starred() {
    local data=$(perform_request "$starred_q" \
        '.data.viewer.starredRepositories.nodes[]')

    local result=""

    for obj in $data; do
        local name=$(echo "$obj" | jq -r '.name')
        local url=$(echo "$obj" | jq -r '.url')

        result+="- [$name]($url)"
        result+=$'\n'
    done

    echo "$result"
}

plot_contributions() {
    graph contributions.csv -f '' --fontsize 10 --width 1 --marker '' \
        --xscale 15 -o "$1"
}


load_dotenv

pops=$(pop_repos)
langs=$(languages)
total=$(total)
starred=$(starred)

plot_contributions "$graph_out"

echo "
# Hello

I'm a composer and programmer from Minsk, Belarus.

## Contact

Feel free to contact me if you have any propositions.

- [e-mail](mailto:$email)
- [Telegram]($telegram)

I spend too much time for open source, but too little for commercial stuff. As
the result I always lack money. If you like some of my projects, or music, or
some of my contributions helped you, please consider donation.

- Bitcoin: **$btc_addr**
- Ethereum: **$eth_addr**

## Stats

Updated daily.

![contributions graph]($graph_out)

***Top Languages By Contributions***

$langs

Number of contributions yesterday: **$total**.

***Most Popular***

$pops

***Recently Starred***

$starred

" > "$output_file"
