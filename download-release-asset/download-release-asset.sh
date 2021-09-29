#!/usr/bin/env bash

set -e
set -o pipefail

GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
DOWNLOAD_ASSET_REPO="${DOWNLOAD_ASSET_REPO:-${GITHUB_REPOSITORY}}"
DOWNLOAD_ASSET_TAG="${DOWNLOAD_ASSET_TAG:-latest}"

function curl() {
  echo "curl " "$@" 1>&2
  command curl \
    --header "authorization: Bearer ${DOWNLOAD_ASSET_TOKEN}" \
    "$@"
}

if [[ -z "$DOWNLOAD_ASSET_REPO" ]]; then
  echo "$0:error: DOWNLOAD_ASSET_REPO empty" 1>&2
  exit 1
fi
if [[ -z "$DOWNLOAD_ASSET_TOKEN" ]]; then
  echo "$0:error: DOWNLOAD_ASSET_TOKEN empty" 1>&2
  exit 1
fi

jq_asset_filter=""
if [[ "${DOWNLOAD_ASSET_TAG}" != 'latest' ]]; then
    jq_asset_filter=". | map(select(.tag_name == \"${DOWNLOAD_ASSET_TAG}\"))[0].assets[]"
else
    jq_asset_filter='.[0].assets[]'
fi

asset_urls=(
    $(curl \
      --url "${GITHUB_API_URL}/repos/${DOWNLOAD_ASSET_REPO}/releases" \
      --header 'Accept: application/json' \
      --fail \
    | jq -r "${jq_asset_filter} | .browser_download_url | select(contains(\"${DOWNLOAD_ASSET_URL_FILTER}\"))" \
    )
)

for url in "${asset_urls[@]}"; do
    filename="$(basename "${url}")"
    curl \
      --url "${url}" \
      --location \
      --fail \
      --output "${filename}"
    echo "${PWD}/${filename}"
done
