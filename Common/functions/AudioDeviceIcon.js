// Classify output devices from stable properties before trying descriptive names.
function outputIcon(properties, description, name) {
    const props = properties || {};
    const icon = String(props["device.icon-name"] || "").toLowerCase().replace(/-/g, "_");
    // Explicit wireless/spatial icon hints take precedence over name heuristics.
    if (["earbuds_2", "spatial_audio"].indexOf(icon) >= 0)
        return icon;

    const form = String(props["device.form-factor"] || "").toLowerCase();
    if (["speaker", "hifi", "car"].indexOf(form) >= 0)
        return "speaker";
    if (form === "tv")
        return "tv";

    const descriptor = [props["device.icon-name"], props["media.icon-name"],
        props["device.product.name"], props["device.profile.name"], description, name]
        .map(value => String(value || "")).join(" ").toLowerCase();
    // AirPods Max are over-ear headphones, unlike the other AirPods models.
    if (/airpods[\s_-]*max/.test(descriptor))
        return "headphones";
    const knownWirelessEarbuds = /airpods|galaxy[\s_-]*buds|pixel[\s_-]*buds|freebuds|linkbuds/.test(descriptor);
    const bluetooth = String(props["device.bus"] || "").toLowerCase() === "bluetooth"
        || /bluez/.test(String(props["device.api"] || "").toLowerCase())
        || !!props["api.bluez5.address"] || !!props["api.bluez5.path"]
        || /bluetooth|bluez/.test(descriptor);
    if (icon === "earbuds" || knownWirelessEarbuds || /earbuds?|earphones?/.test(descriptor))
        return bluetooth || knownWirelessEarbuds ? "earbuds_2" : "earbuds";
    if (form === "headset" || form === "hands-free")
        return "headset_mic";
    if (form === "headphone")
        return "headphones";
    if (/headset|hands[\s_-]*free/.test(descriptor))
        return "headset_mic";
    if (/headphone/.test(descriptor))
        return "headphones";
    if (/hdmi|displayport/.test(descriptor))
        return "tv";
    if (/speaker/.test(descriptor) || form === "internal")
        return "speaker";
    // Bluetooth alone does not distinguish a headset from a speaker.
    return "volume_up";
}
