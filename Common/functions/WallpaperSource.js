.import "ZenPalette.js" as Zen

var prefix = "clavis-palette:v1:";
function finiteRange(value, min, max) {
    return typeof value === "number" && isFinite(value) && value >= min && value <= max;
}
function normalizePalette(value) {
    if (!value || value.version !== 1 || !Number.isInteger(value.count)
            || value.count < 1 || value.count > 3
            || Zen.algorithms(value.count).indexOf(value.algorithm) < 0
            || ["position", "explicit-lightness", "explicit-black-white"].indexOf(value.type) < 0
            || !finiteRange(value.x, -0.05, 1.05) || !finiteRange(value.y, -0.05, 1.05)
            || !finiteRange(value.lightness, 0, 100) || !finiteRange(value.opacity, 0.25, 0.8)
            || !finiteRange(value.grain, 0, 15/16)) return null;
    // Older v1 mode fields are ignored: the base follows the global theme.
    // Primary position is authoritative; secondary positions/RGB are derived.
    return {version: 1, count: value.count, algorithm: value.algorithm,
        x: value.x, y: value.y, lightness: value.lightness, type: value.type,
        opacity: value.opacity, grain: Math.round(value.grain*16)/16};
}
function encode(value) {
    var normalized = normalizePalette(value);
    return normalized ? prefix + encodeURIComponent(JSON.stringify(normalized)) : "";
}
function decode(source) {
    if (typeof source !== "string" || !source.startsWith(prefix) || source.length > 4096) return null;
    try { return normalizePalette(JSON.parse(decodeURIComponent(source.slice(prefix.length)))); }
    catch (error) { return null; }
}
function localPath(source) {
    var path = String(source || "").trim();
    if (!path.startsWith("file://")) return path;
    path = path.slice(7);
    if (path.startsWith("localhost/")) path = path.slice(9);
    if (!path.startsWith("/")) return "";
    try { return decodeURIComponent(path); } catch (error) { return ""; }
}
function kind(source) {
    if (typeof source !== "string" || source === "") return "empty";
    if (source.startsWith("clavis-palette:")) return decode(source) ? "palette" : "invalid";
    // Qt uses #AARRGGBB, not CSS #RRGGBBAA.
    if (/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(source)) return "solid";
    var path = localPath(source);
    if (path.indexOf("\u0000") >= 0 || path.indexOf("\n") >= 0 || path.startsWith("#")
            || /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(path)) return "invalid";
    return /\.(jpg|jpeg|png|webp|bmp|gif)$/i.test(path) ? "image" : "invalid";
}
function isImage(source) { return kind(source) === "image"; }
function isSolid(source) { return kind(source) === "solid"; }
function primary(source) {
    var type = kind(source);
    if (type === "palette") return Zen.primary(decode(source));
    if (type === "solid") return source.length === 9 ? "#"+source.slice(3) : source;
    return "";
}
function supported(source, backend) {
    var type = kind(source);
    return backend === "awww" ? type === "image" : ["image","solid","palette"].indexOf(type) >= 0;
}
