#!/usr/bin/env bash

set -euo pipefail

script_dir=$(
    CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
repo_root=$(
    CDPATH='' cd -- "${script_dir}/../.." && pwd
)

mode=format
scope=changed
case "${1:-}" in
    '') ;;
    --check) mode=check ;;
    --all) scope=all ;;
    --check-all) mode=check; scope=all ;;
    -h|--help)
        printf 'Usage: %s [--check|--all|--check-all]\n' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    *)
        printf 'error: unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

if [[ $# -gt 1 ]]; then
    printf 'error: expected at most one option\n' >&2
    exit 2
fi

cd "${repo_root}"
# shellcheck source=scripts/dev/files.sh
source "${script_dir}/files.sh"
mapfile -d '' -t qml_files < <(clavis_qml_files "${scope}")
if [[ ${#qml_files[@]} -eq 0 ]]; then
    printf 'format-qml: no QML files in scope\n'
    exit 0
fi
qmlformat_bin=$(clavis_qt_tool qmlformat "${QMLFORMAT:-}")
printf 'format-qml: %s (%d files)\n' "$("${qmlformat_bin}" --version)" "${#qml_files[@]}"
# Qt 6 keeps import/property order unless normalization/sorting is requested.
if [[ "${mode}" == format ]]; then
    for file in "${qml_files[@]}"; do
        "${qmlformat_bin}" --inplace "${file}"
    done
    exit 0
fi

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/clavis-qmlformat.XXXXXX")
cleanup() {
    rm -rf -- "${temporary_dir}"
}
trap cleanup EXIT HUP INT TERM

failed=0
for file in "${qml_files[@]}"; do
    relative=${file#"${repo_root}/"}
    expected="${temporary_dir}/${relative}"
    mkdir -p -- "$(dirname -- "${expected}")"
    if ! "${qmlformat_bin}" "${file}" >"${expected}"; then
        printf 'format-qml: unable to format %s\n' "${relative}" >&2
        failed=1
        continue
    fi
    if ! cmp -s -- "${file}" "${expected}"; then
        printf 'format-qml: not formatted: %s\n' "${relative}" >&2
        diff -u -- "${file}" "${expected}" | sed -n '1,100p' || true
        failed=1
    fi
done

if [[ ${failed} -ne 0 ]]; then
    exit 1
fi
printf 'format-qml: check passed (%d files)\n' "${#qml_files[@]}"
