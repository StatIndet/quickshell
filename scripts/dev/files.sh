#!/usr/bin/env bash
# Shared file selection. Callers set repo_root and cd there before using paths.
clavis_files() {
    local scope=$1
    if [[ ${scope} == all ]]; then
        git ls-files --cached --others --exclude-standard -z
    else
        git diff --name-only -z HEAD
        git ls-files --others --exclude-standard -z
    fi | sort -zu
}

clavis_qml_files() {
    local scope=$1 file
    while IFS= read -r -d '' file; do
        case ${file} in
            build/*|generated/*|third-party/*|vendor/*) continue ;;
            *.qml) [[ ! -f ${file} ]] || printf '%s\0' "${file}" ;;
        esac
    done < <(clavis_files "${scope}")
}

clavis_qt_tool() {
    local name=$1 override=$2 candidate version
    local candidates=("/usr/lib/qt6/bin/${name}" "${name}6" "${name}-qt6" "${name}")
    [[ -z ${override} ]] || candidates=("${override}")
    for candidate in "${candidates[@]}"; do
        command -v "${candidate}" >/dev/null 2>&1 || continue
        version=$("${candidate}" --version 2>/dev/null) || continue
        if [[ ${version} == *' 6.'* ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    printf 'error: Qt 6 %s required (Arch: qt6-declarative); override=%s\n' \
        "${name}" "${override:-unset}" >&2
    return 127
}
