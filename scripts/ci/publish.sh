#!/usr/bin/env bash
# GitHub/AUR writes happen only in the credentialed publishing job.
set -euo pipefail
: "${GH_TOKEN:?GitHub publishing token required}"
: "${AUR_SSH_PRIVATE_KEY:?AUR deploy key required}"
: "${AUR_KNOWN_HOSTS:?Verified AUR SSH host keys required}"
: "${AUR_GIT_NAME:?AUR commit author required}"
: "${AUR_GIT_EMAIL:?AUR commit email required}"
: "${RELEASE_TAG:?Release tag required}"
[[ $RELEASE_TAG =~ ^v[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]+)?$ ]] || exit 2
root=$(git rev-parse --show-toplevel)
cd "$root"
repository=$(python3 -c 'import json; print(json.load(open("packaging/dependencies.json"))["repository"])')
base=$(python3 -c 'import json; print(json.load(open("packaging/dependencies.json"))["name"])')
export GH_REPO=$repository
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
if [[ ${RETRY_AUR:-false} == true ]]; then
    state=$(gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft)
    [[ $state == false ]] || { printf 'Publish the complete draft before retrying AUR.\n' >&2; exit 1; }
    gh release download "$RELEASE_TAG" --dir "$temporary/assets"
    assets=$temporary/assets
else
    assets=$root/.packaging/release
    git fetch "$root/.packaging/release.bundle" "refs/tags/$RELEASE_TAG:refs/tags/$RELEASE_TAG"
fi
# Validate the exact release assets before either publishing or syncing AUR.
commit=$(git rev-parse "$RELEASE_TAG^{commit}")
python3 scripts/release.py verify-assets "$assets" --tag "$RELEASE_TAG" --commit "$commit"
if [[ $base == clavis-shell ]]; then
    # Check public AUR availability, without building or testing sibling repositories.
    python3 - "$assets/.SRCINFO" <<'PYTHON'
import json
from pathlib import Path
import urllib.parse
import urllib.request
import sys

requirements = []
for line in Path(sys.argv[1]).read_text().splitlines():
    if " = " in line:
        key, value = line.strip().split(" = ", 1)
        if key == "depends" and value.startswith(("key-cli>=", "keytop>=")):
            requirements.append(value)
for requirement in requirements:
    name, minimum = requirement.split(">=")
    url = "https://aur.archlinux.org/rpc/v5/info?" + urllib.parse.urlencode({"arg[]": name})
    with urllib.request.urlopen(url, timeout=30) as response:
        results = json.load(response).get("results", [])
    matches = [entry for entry in results if entry["Name"] == name]
    if len(matches) != 1:
        raise SystemExit(f"Publish {name} to AUR before Clavis")
    value = matches[0]["Version"].split(":")[-1].rsplit("-", 1)[0]
    if tuple(map(int, value.split("."))) < tuple(map(int, minimum.split("."))):
        raise SystemExit(f"AUR {name} does not satisfy {requirement}")
PYTHON
fi
if [[ ${RETRY_AUR:-false} != true ]]; then
    git push origin "refs/tags/$RELEASE_TAG"
    gh release create "$RELEASE_TAG" --verify-tag --draft --latest=false --title "$RELEASE_TAG" --generate-notes
    upload=("$assets/SHA256SUMS")
    while read -r hash filename; do
        [[ $hash =~ ^[0-9a-f]{64}$ && $filename != */* && $filename != .*/* ]] || exit 2
        upload+=("$assets/$filename")
    done < "$assets/SHA256SUMS"
    gh release upload "$RELEASE_TAG" "${upload[@]}"
    gh release edit "$RELEASE_TAG" --draft=false --latest=false
fi
umask 077
printf '%s\n' "$AUR_SSH_PRIVATE_KEY" > "$temporary/key"
printf '%s\n' "$AUR_KNOWN_HOSTS" > "$temporary/known_hosts"
printf -v GIT_SSH_COMMAND '%q ' ssh -i "$temporary/key" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$temporary/known_hosts"
export GIT_SSH_COMMAND
git clone -- "ssh://aur@aur.archlinux.org/$base.git" "$temporary/aur"
cd "$temporary/aur"
git checkout -B master
# A retry must never move AUR backwards after a newer release has shipped.
python3 - "$assets/.SRCINFO" <<'PY'
from pathlib import Path
import sys

def version(path):
    fields = {}
    for line in path.read_text().splitlines():
        if ' = ' in line:
            key, value = line.strip().split(' = ', 1)
            fields.setdefault(key, value)
    return (int(fields.get('epoch', '0')), tuple(map(int, fields['pkgver'].split('.'))), int(fields['pkgrel']))

if Path('.SRCINFO').exists() and version(Path('.SRCINFO')) > version(Path(sys.argv[1])):
    raise SystemExit('AUR already has a newer package; refusing a downgrade')
PY
git rm -r --ignore-unmatch . >/dev/null
cp "$assets/PKGBUILD" "$assets/.SRCINFO" .
for extra in "$assets"/*.install; do
    [[ ! -f $extra ]] || cp "$extra" .
done
git add --all
if ! git diff --cached --quiet; then
    git -c user.name="$AUR_GIT_NAME" -c user.email="$AUR_GIT_EMAIL" commit -m "Release $RELEASE_TAG"
    git push origin HEAD:master
fi
# /releases/latest is advanced only after the AUR transaction succeeds.
gh release edit "$RELEASE_TAG" --latest=true
