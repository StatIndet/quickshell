#!/usr/bin/env bash
# GitHub writes happen only in the credentialed publishing job.
set -euo pipefail
: "${GH_TOKEN:?GitHub publishing token required}"
: "${RELEASE_TAG:?Release tag required}"
[[ $RELEASE_TAG =~ ^v[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]+)?$ ]] || exit 2
root=$(git rev-parse --show-toplevel)
cd "$root"
repository=$(python3 -c 'import json; print(json.load(open("packaging/dependencies.json"))["repository"])')
export GH_REPO=$repository
assets=$root/.packaging/release
git fetch "$root/.packaging/release.bundle" "refs/tags/$RELEASE_TAG:refs/tags/$RELEASE_TAG"
# Validate the exact release assets before publishing.
commit=$(git rev-parse "$RELEASE_TAG^{commit}")
python3 scripts/release.py verify-assets "$assets" --tag "$RELEASE_TAG" --commit "$commit"
git push origin "refs/tags/$RELEASE_TAG"
gh release create "$RELEASE_TAG" --verify-tag --draft --latest=false --title "$RELEASE_TAG" --generate-notes
upload=("$assets/SHA256SUMS")
while read -r hash filename; do
    [[ $hash =~ ^[0-9a-f]{64}$ && $filename != */* && $filename != .*/* ]] || exit 2
    upload+=("$assets/$filename")
done < "$assets/SHA256SUMS"
gh release upload "$RELEASE_TAG" "${upload[@]}"
# Advance /releases/latest only after all verified assets have been uploaded.
gh release edit "$RELEASE_TAG" --draft=false --latest=true
