#!/usr/bin/env bash

source .env
if [[ -z "$email" ]]; then
    echo "the 'email' env var is required"
    exit 1
fi
if [[ -z "$password" ]]; then
    echo "the 'password' env var is required"
    exit 1
fi

rm -f duke.cookies
curl "https://www.duke-energy.com/facade/api/Authentication/SignIn" \
    --fail-with-body \
    --silent \
    --compressed \
    --cookie-jar duke-initial.cookies \
    --header "content-type: application/json" \
    --data-raw "$(jq -n --arg loginIdentity "$email" --arg password "$password" '{$loginIdentity, $password}')" \
    >/dev/null
echo "logged in" >&2

# we have to load this page to get the dukeAuth cookie, which is required by the p-auth subdomain
curl 'https://www.duke-energy.com/my-account/multiple-accounts-table' \
    --fail \
    --silent \
    --cookie duke-initial.cookies \
    --cookie-jar duke.cookies \
    --compressed >/dev/null

if grep dukeAuth <duke.cookies >/dev/null; then
    echo "loaded dukeAuth cookie"
else
    echo "did not get dukeAuth cookie!"
    exit 1
fi

accountId="$(
    curl 'https://www.duke-energy.com/facade/api/AccountSelector/GetResiAccounts' \
        --cookie ./duke.cookies \
        --fail \
        --silent \
        --header 'accept: */*' \
        --header 'content-type: application/json' \
        --data-raw '{"email":""}' \
        --compressed |
        jq -r .Accounts[0].AccountNum
)"

energyRequest="$(jq -n --arg accountId "$accountId" '{"SrcAcctId": $accountId,"SrcAcctId2":"","SrcSysCd":"ISU","ServiceType":"ELECTRIC"}')"
echo "fetching usage history for account '$accountId'"
curl 'https://p-auth.duke-energy.com/form/PlanRate/GetEnergyUsage' \
    --cookie duke.cookies \
    --silent \
    --fail \
    --header 'content-type: application/json' \
    --data-raw "$(jq -n --arg request "$energyRequest" '{$request}')" \
    --compressed >usage.xml

# file usage.xml
