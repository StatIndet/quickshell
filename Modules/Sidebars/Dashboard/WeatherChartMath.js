.pragma library

function finiteNumber(value) {
    return value !== undefined && value !== null && Number.isFinite(Number(value));
}

function temperatureDomain(values, normalDaytime, normalNighttime) {
    const candidates = values.slice();
    if (finiteNumber(normalDaytime))
        candidates.push(Number(normalDaytime));
    if (finiteNumber(normalNighttime))
        candidates.push(Number(normalNighttime));

    const finiteValues = candidates.filter(finiteNumber).map(Number);
    if (finiteValues.length === 0)
        return [0, 1];

    const rawMin = Math.min.apply(Math, finiteValues);
    const rawMax = Math.max.apply(Math, finiteValues);
    const range = Math.max(1, rawMax - rawMin);
    const padding = Math.max(1, range * 0.15);
    return [rawMin - padding, rawMax + padding];
}

function rainMaximum(values) {
    const finiteValues = values.filter(finiteNumber).map(function(value) {
        return Math.max(0, Number(value));
    });
    return finiteValues.length > 0 ? Math.max.apply(Math, finiteValues) : 0;
}

function rainBarHeight(value, maximum, bandHeight) {
    if (!finiteNumber(value) || Number(value) <= 0 || maximum <= 0 || bandHeight <= 0)
        return 0;
    return Math.min(bandHeight, Math.max(3, Number(value) / maximum * bandHeight));
}
