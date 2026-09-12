#!/usr/bin/env bash
# Small raw-GitHub entry point. A complete, verified release installer does the work.
set -euo pipefail

main() (
    set -euo pipefail
    local command metadata tag pattern temporary hash filename expected='' found=0
    for command in curl sha256sum mktemp bash; do
        command -v "$command" >/dev/null || { printf 'Required command: %s\n' "$command" >&2; return 1; }
    done
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/clavis-bootstrap.XXXXXX")
    trap 'rm -rf -- "$temporary"' EXIT
    metadata=$(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        https://api.github.com/repos/StatIndet/quickshell/releases/latest)
    pattern='"tag_name"[[:space:]]*:[[:space:]]*"(v[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]+)?)"'
    [[ $metadata =~ $pattern ]] || { printf 'No completed Clavis date release is available.\n' >&2; return 1; }
    tag=${BASH_REMATCH[1]}
    local base="https://github.com/StatIndet/quickshell/releases/download/$tag"
    for filename in SHA256SUMS install-arch.sh; do
        curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
            "$base/$filename" --output "$temporary/$filename"
    done
    while read -r hash filename; do
        if [[ $filename == install-arch.sh && $hash =~ ^[0-9a-f]{64}$ ]]; then
            expected=$hash
            found=$((found + 1))
        fi
    done < "$temporary/SHA256SUMS"
    [[ $found == 1 ]] || { printf 'Release installer checksum is missing or ambiguous.\n' >&2; return 1; }
    (cd "$temporary" && printf '%s  install-arch.sh\n' "$expected" | sha256sum --check --status) || {
        printf 'Release installer checksum mismatch.\n' >&2; return 1;
    }
    bash "$temporary/install-arch.sh" "$@"
)

main "$@"
