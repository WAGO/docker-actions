#!/usr/bin/env bash

set -e
set -o pipefail

GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
DOWNLOAD_ASSET_REPO="${DOWNLOAD_ASSET_REPO:-${GITHUB_REPOSITORY}}"
DOWNLOAD_ASSET_TAG="${DOWNLOAD_ASSET_TAG:-latest}"
DOWNLOAD_ASSET_URLFILTERPATTERN="${DOWNLOAD_ASSET_URLFILTERPATTERN:-.*}"

function trace_call() {
  echo "$@" 1>&2
  "$@"
} 

function curl() {
  command curl \
    --header "authorization: Bearer ${DOWNLOAD_ASSET_TOKEN}" \
    "$@"
}

function main() {
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

  readarray -t asset_urls < <(curl \
      --url "${GITHUB_API_URL}/repos/${DOWNLOAD_ASSET_REPO}/releases" \
      --header 'Accept: application/json' \
      --silent \
      --show-error \
      --fail \
    | jq -r "${jq_asset_filter} | .browser_download_url | select(.|test(\"${DOWNLOAD_ASSET_URLFILTERPATTERN}\"))" \
  )
  
  if [[ "${#asset_urls[@]}" -lt 1 ]]; then
    echo "$0:error: No assets matching filter pattern \"${DOWNLOAD_ASSET_URLFILTERPATTERN}\"" 1>&2
    exit 2
  fi

  for url in "${asset_urls[@]}"; do
    filename="$(basename "${url}")"
    trace_call curl \
      --url "${url}" \
      --location \
      --fail \
      --output "${filename}"
    echo "${PWD}/${filename}"
  done
}

(return 0 2>/dev/null) && sourced=1 || sourced=0
if [[ "${sourced}" -ne 1 ]]; then
  main "$@"
fi