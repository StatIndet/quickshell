function clamp(value, fallback, minimum, maximum) {
    const numberValue = Number(value);
    if (!isFinite(numberValue))
        return fallback;
    return Math.max(minimum, Math.min(maximum, numberValue));
}

function namespaceArgs(namespaceName) {
    return ["-n", String(namespaceName || "clavis-desktop")];
}

function daemon(commandPath, namespaceName) {
    return [
        String(commandPath || "awww-daemon"),
        "--layer", "bottom",
        "--namespace", String(namespaceName || "clavis-desktop"),
        "--no-cache"
    ];
}

function query(commandPath, namespaceName) {
    return [String(commandPath || "awww"), "query"]
        .concat(namespaceArgs(namespaceName));
}

function stop(commandPath, namespaceName) {
    return [String(commandPath || "awww"), "kill"]
        .concat(namespaceArgs(namespaceName));
}

function resizeMode(fillMode) {
    switch (String(fillMode || "Fill")) {
    case "Stretch":
        return "stretch";
    case "Fit":
    case "PreserveAspectFit":
        return "fit";
    case "Pad":
        return "no";
    case "Fill":
    case "PreserveAspectCrop":
    default:
        return "crop";
    }
}

function defaultBezier() {
    return [0.43, 1.19, 1.0, 0.4];
}

function normalizedBezier(curve) {
    const fallback = defaultBezier();
    if (!Array.isArray(curve) || curve.length < 4)
        return fallback;

    const result = [];
    for (let index = 0; index < 4; index += 1) {
        const value = Number(curve[index]);
        if (!isFinite(value))
            return fallback;
        result.push(index === 0 || index === 2
            ? Math.max(0, Math.min(1, value))
            : Math.max(-4, Math.min(4, value)));
    }
    return result;
}

function effectiveBezier(easingMode, customCurve) {
    const presets = {
        linear: [0, 0, 1, 1],
        quad: [0.455, 0.03, 0.515, 0.955],
        cubic: [0.645, 0.045, 0.355, 1],
        quart: [0.77, 0, 0.175, 1],
        quint: [0.86, 0, 0.07, 1],
        sine: [0.445, 0.05, 0.55, 0.95],
        expo: [1, 0, 0, 1],
        circ: [0.785, 0.135, 0.15, 0.86]
    };
    const mode = String(easingMode || "");
    if (mode === "customBezier")
        return normalizedBezier(customCurve);
    if (presets[mode])
        return presets[mode].slice();
    return defaultBezier();
}

function bezier(curve) {
    return normalizedBezier(curve).join(",");
}

function isColorSource(source) {
    return /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/
        .test(String(source || ""));
}

function colorValue(source) {
    return String(source || "").substring(1).toLowerCase();
}

function transition(value) {
    const supported = [
        "none", "simple", "fade", "left", "right", "top",
        "bottom", "wipe", "wave", "grow", "center", "any",
        "outer", "random"
    ];
    const requested = String(value || "fade");
    return supported.indexOf(requested) !== -1
        ? requested : "fade";
}

function normalizedRandomCoordinate(value) {
    const numeric = Number(value);
    const bounded = Number.isFinite(numeric)
        ? Math.max(0, Math.min(0.999999, numeric))
        : 0.5;
    return bounded.toFixed(6);
}

function resolvedTransitionOptions(options, randomX, randomY) {
    const source = options || {};
    const resolved = {};
    for (let key in source)
        resolved[key] = source[key];

    // `any` asks every awww invocation to choose its own random point.
    // Clavis applies one wallpaper once per output, so resolve that alias
    // once for the whole batch and share one normalized desktop position.
    if (transition(source.type) === "any") {
        resolved.type = "grow";
        resolved.position = normalizedRandomCoordinate(randomX)
            + "," + normalizedRandomCoordinate(randomY);
    }
    return resolved;
}

function supportsDuration(transitionType) {
    const type = transition(transitionType);
    return type !== "none" && type !== "simple";
}

function supportsBezier(transitionType) {
    const type = transition(transitionType);
    return type !== "none" && type !== "simple";
}

function supportsStep(transitionType) {
    return transition(transitionType) !== "none";
}

function image(commandPath, namespaceName, outputName, source,
               fillMode, options) {
    const settings = options || {};
    const transitionType = transition(settings.type);
    const args = [String(commandPath || "awww"), "img"]
        .concat(namespaceArgs(namespaceName));

    if (outputName)
        args.push("-o", String(outputName));

    args.push("--resize", resizeMode(fillMode));
    args.push("--transition-type", transitionType);

    if (supportsStep(transitionType)) {
        args.push("--transition-fps",
            String(Math.round(clamp(settings.fps, 60, 10, 240))));
        args.push("--transition-step",
            String(Math.round(clamp(settings.step, 90, 0, 255))));
    }

    if (supportsDuration(transitionType)) {
        const durationMs = clamp(settings.durationMs, 1000, 0, 60000);
        args.push("--transition-duration",
            (durationMs / 1000).toFixed(3));
    }

    if (supportsBezier(transitionType)) {
        const effectiveCurve = effectiveBezier(
            settings.easingMode, settings.bezierCurve);
        args.push("--transition-bezier", bezier(effectiveCurve));
    }

    if (transitionType === "wipe" || transitionType === "wave") {
        args.push("--transition-angle",
            String(clamp(settings.angle, 45, 0, 360)));
    }

    if (transitionType === "grow" || transitionType === "outer") {
        args.push("--transition-pos",
            String(settings.position || "center"));
    }

    if (transitionType === "wave") {
        args.push("--transition-wave",
            String(settings.wave || "20,20"));
    }

    args.push("--", String(source || ""));
    return args;
}

function clear(commandPath, namespaceName, outputName, source) {
    const args = [String(commandPath || "awww"), "clear"]
        .concat(namespaceArgs(namespaceName));
    if (outputName)
        args.push("-o", String(outputName));
    args.push(colorValue(source));
    return args;
}

function apply(commandPath, namespaceName, outputName, source,
               fillMode, options) {
    if (isColorSource(source))
        return clear(commandPath, namespaceName, outputName, source);
    return image(commandPath, namespaceName, outputName, source,
        fillMode, options);
}
