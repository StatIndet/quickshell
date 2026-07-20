.pragma library

function normalized(value) {
    return String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
}

function fuzzyScore(query, candidate) {
    const needle = normalized(query);
    const haystack = normalized(candidate);
    if (needle.length === 0)
        return 0;

    const directIndex = haystack.indexOf(needle);
    if (directIndex >= 0)
        return 100000 - directIndex * 100 - (haystack.length - needle.length);

    let needleIndex = 0;
    let previousMatch = -1;
    let streak = 0;
    let score = 0;

    for (let index = 0; index < haystack.length && needleIndex < needle.length; ++index) {
        if (haystack[index] !== needle[needleIndex])
            continue;

        streak = previousMatch === index - 1 ? streak + 1 : 1;
        const gap = previousMatch < 0 ? index : index - previousMatch - 1;
        score += 30 + streak * 15 - gap * 2;
        previousMatch = index;
        ++needleIndex;
    }

    if (needleIndex !== needle.length)
        return -1;

    return score - (haystack.length - needle.length);
}

function ranked(values, query, selector) {
    const needle = normalized(query);
    if (needle.length === 0)
        return values.slice();

    const matches = [];
    for (let index = 0; index < values.length; ++index) {
        const value = values[index];
        const label = selector ? selector(value) : value;
        const score = fuzzyScore(needle, label);
        if (score >= 0)
            matches.push({ value: value, score: score, index: index });
    }

    matches.sort((left, right) => {
        if (left.score !== right.score)
            return right.score - left.score;
        return left.index - right.index;
    });
    return matches.map(match => match.value);
}
