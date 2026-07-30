#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "${script_dir}/../.." && pwd)
source_file="${project_dir}/assets/shaders/launcher/frag/spotlight_mode_morph.frag"
output_dir="${project_dir}/assets/shaders/launcher/qsb"
output_file="${output_dir}/spotlight_mode_morph.frag.qsb"

if command -v qsb >/dev/null 2>&1; then
    qsb_command=$(command -v qsb)
elif [[ -x /usr/lib64/qt6/bin/qsb ]]; then
    qsb_command=/usr/lib64/qt6/bin/qsb
elif [[ -x /usr/lib/qt6/bin/qsb ]]; then
    qsb_command=/usr/lib/qt6/bin/qsb
else
    echo "Qt Shader Tools qsb was not found" >&2
    exit 1
fi

mkdir -p -- "${output_dir}"
"${qsb_command}" --qt6 -o "${output_file}" "${source_file}"
echo "Built ${output_file}"
