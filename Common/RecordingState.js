.pragma library

function isActive(state) {
    return ["starting", "recording", "paused", "stopping", "finalizing"].indexOf(state) !== -1;
}

function valid(value) {
    if (["idle", "completed", "error"].indexOf(value.state) === -1 && !isActive(value.state))
        return false;
    if (typeof value.sessionId !== "string" || (value.state !== "idle" && !value.sessionId))
        return false;
    const times = ["updatedAtMs", "startedAtMs", "completedAtMs", "processStartedAtMs", "pid"];
    for (let i = 0; i < times.length; i++) {
        const number = value[times[i]];
        if (typeof number !== "number" || !isFinite(number) || number < 0 || Math.floor(number) !== number)
            return false;
    }
    return (value.state === "idle" || value.updatedAtMs > 0)
        && typeof value.temporaryPath === "string" && typeof value.outputPath === "string"
        && (value.processStartTicks === null || typeof value.processStartTicks === "string")
        && (value.error === null || (typeof value.error === "object" && typeof value.error.code === "string" && typeof value.error.message === "string"))
        && (value.state !== "error" || value.error !== null);
}
