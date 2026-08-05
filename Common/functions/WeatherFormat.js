.pragma library

function textForCode(code, fallback) {
    const normalized = Number(code)

    if (normalized === 0) return "晴"
    if (normalized === 1) return "晴间多云"
    if (normalized === 2) return "多云"
    if (normalized === 3) return "阴"
    if (normalized === 45) return "雾"
    if (normalized === 48) return "雾凇"
    if (normalized >= 51 && normalized <= 55) return "毛毛雨"
    if (normalized === 56 || normalized === 57) return "冻毛毛雨"
    if (normalized === 61) return "小雨"
    if (normalized === 63) return "中雨"
    if (normalized === 65) return "大雨"
    if (normalized === 66 || normalized === 67) return "冻雨"
    if (normalized === 71) return "小雪"
    if (normalized === 73) return "中雪"
    if (normalized === 75) return "大雪"
    if (normalized === 77) return "米雪"
    if (normalized === 80) return "阵雨"
    if (normalized === 81) return "较强阵雨"
    if (normalized === 82) return "强阵雨"
    if (normalized === 85) return "阵雪"
    if (normalized === 86) return "强阵雪"
    if (normalized === 95) return "雷暴"
    if (normalized === 96 || normalized === 99) return "雷暴伴冰雹"

    const fallbackText = String(fallback || "").trim()
    return fallbackText.length > 0 && fallbackText !== "Unknown" ? fallbackText : "未知"
}
