#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
weather_views=(
    "$repo_root/Modules/Sidebars/Left/WeatherView.qml"
    "$repo_root/Modules/Sidebars/Left/WeatherViewPreview.qml"
)

for weather_view in "${weather_views[@]}"; do
    if ! rg -q 'id: currentSummary' "$weather_view"; then
        echo "missing currentSummary geometry anchor: $weather_view" >&2
        exit 1
    fi

    if ! rg -Uq \
        'height:\s*Math\.max\(\s*currentSummary\.implicitHeight \+ root\.contentMargin \* 2,' \
        "$weather_view"; then
        echo "weather hero can be shorter than its summary content: $weather_view" >&2
        exit 1
    fi
done

echo "weather hero layout tests passed"
