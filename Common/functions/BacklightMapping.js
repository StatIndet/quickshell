.pragma library

function normalizeConnectorName(name) {
    const raw = String(name || "").trim();
    if (raw.length === 0)
        return "";
    return raw.replace(/^card[0-9]+-/, "");
}

function pathIsWithin(parentPath, candidatePath) {
    const parent = String(parentPath || "").replace(/\/+$/, "");
    const candidate = String(candidatePath || "").replace(/\/+$/, "");
    if (parent.length === 0 || candidate.length === 0)
        return false;
    return candidate === parent || candidate.startsWith(parent + "/");
}

function uniqueDeviceName(candidates) {
    if (!Array.isArray(candidates) || candidates.length !== 1)
        return "";
    return String(candidates[0].name || "");
}

function deviceForConnector(connectorName, backlights, connectors) {
    const availableBacklights = Array.isArray(backlights) ? backlights : [];
    const availableConnectors = Array.isArray(connectors) ? connectors : [];
    const normalizedName = normalizeConnectorName(connectorName);
    const connector = availableConnectors.find(function(candidate) {
        return normalizeConnectorName(candidate.name) === normalizedName;
    });

    if (connector) {
        const attached = availableBacklights.filter(function(backlight) {
            return pathIsWithin(connector.path, backlight.devicePath);
        });
        const attachedName = uniqueDeviceName(attached);
        if (attachedName.length > 0)
            return attachedName;
        if (attached.length > 1)
            return "";

        const sameGpu = availableBacklights.filter(function(backlight) {
            return pathIsWithin(connector.gpuPath, backlight.devicePath)
                || pathIsWithin(backlight.devicePath, connector.gpuPath);
        });
        const gpuName = uniqueDeviceName(sameGpu);
        if (gpuName.length > 0)
            return gpuName;
        if (sameGpu.length > 1)
            return "";
    }

    return uniqueDeviceName(availableBacklights);
}
