.pragma library

function finite(value, fallback, low, high) {
    return typeof value === "number" && isFinite(value) ? Math.max(low, Math.min(high, value)) : fallback;
}

function normalize(raw) {
    const p = raw || {};
    return {
        gamma: finite(p.gamma, 1, 0.5, 2), contrast: finite(p.contrast, 1, 0.5, 2),
        dimming: finite(p.dimming, 1, 0.25, 1), nightEnabled: p.nightEnabled === true,
        nightTemperature: Math.round(finite(p.nightTemperature, 4000, 1000, 6500)),
        dayTemperature: Math.round(finite(p.dayTemperature, 6500, 1000, 10000)),
        useIP: p.useIP === true,
        mode: ["fixed", "time", "location"].indexOf(p.mode) >= 0 ? p.mode : "fixed",
        start: Math.round(finite(p.start, 1200, 0, 1439)), end: Math.round(finite(p.end, 420, 0, 1439)),
        transition: Math.round(finite(p.transition, 30, 0, 180)),
        latitude: typeof p.latitude === "number" && isFinite(p.latitude) && Math.abs(p.latitude) <= 90 ? p.latitude : null,
        longitude: typeof p.longitude === "number" && isFinite(p.longitude) && Math.abs(p.longitude) <= 180 ? p.longitude : null
    };
}

// NOAA fractional-year solar approximation. Results are UTC epoch times;
// each calculation uses its own calendar day, never adds a fixed 24h to a local event.
function solar(date, latitude, longitude) {
    const year = date.getFullYear(), month = date.getMonth(), day = date.getDate();
    const dayOfYear = Math.floor((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / 86400000) + 1;
    const yearDays = (Date.UTC(year + 1, 0, 1) - Date.UTC(year, 0, 1)) / 86400000;
    const angle = 2 * Math.PI / yearDays * (dayOfYear - 1);
    const equation = 229.18 * (0.000075 + 0.001868*Math.cos(angle) - 0.032077*Math.sin(angle)
        - 0.014615*Math.cos(2*angle) - 0.040849*Math.sin(2*angle));
    const declination = 0.006918 - 0.399912*Math.cos(angle) + 0.070257*Math.sin(angle)
        - 0.006758*Math.cos(2*angle) + 0.000907*Math.sin(2*angle)
        - 0.002697*Math.cos(3*angle) + 0.00148*Math.sin(3*angle);
    const radians = latitude*Math.PI/180;
    const hourCosine = (Math.cos(90.833*Math.PI/180) / (Math.cos(radians)*Math.cos(declination)))
        - Math.tan(radians)*Math.tan(declination);
    if (hourCosine > 1) return {condition: "polar-night"};
    if (hourCosine < -1) return {condition: "polar-day"};
    const hour = Math.acos(Math.max(-1, Math.min(1, hourCosine))) * 180/Math.PI;
    const noon = Date.UTC(year, month, day) + (720 - 4*longitude - equation)*60000;
    return {condition: "normal", rise: noon-hour*240000, set: noon+hour*240000};
}

function evaluate(preferences, nowValue) {
    const p = normalize(preferences), now = new Date(nowValue), epoch = now.getTime();
    const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate()+1).getTime();
    const result = {temperature: 6500, target: 6500, next: 0, wake: tomorrow, condition: "normal", sunrise: 0, sunset: 0, period: "day", transitioning: false};
    if (!p.nightEnabled) return result;
    result.period = "night";
    result.temperature = result.target = p.nightTemperature;
    if (p.mode === "fixed") return result;
    if (p.mode === "location" && (p.latitude === null || p.longitude === null)) {
        result.condition = "missing-location";
        return result; // Explicit fixed night temperature fallback; gamma and contrast are unaffected.
    }
    if (p.mode === "time" && p.start === p.end) {
        result.condition = "equal-times";
        return result;
    }
    const events = [];
    for (let offset=-2; offset<=2; ++offset) {
        const date = new Date(now.getFullYear(), now.getMonth(), now.getDate()+offset);
        if (p.mode === "time") {
            const eventTime = minutes => new Date(date.getFullYear(),date.getMonth(),date.getDate(),Math.floor(minutes/60),minutes%60).getTime();
            events.push({at:eventTime(p.start), target:p.nightTemperature,period:"night"});
            events.push({at:eventTime(p.end), target:p.dayTemperature,period:"day"});
        } else {
            const sun = solar(date,p.latitude,p.longitude);
            if (offset === 0) {
                result.condition = sun.condition;
                result.sunrise = sun.rise || 0;
                result.sunset = sun.set || 0;
                if (sun.condition !== "normal") {
                    result.period = sun.condition === "polar-day" ? "day" : "night";
                    result.temperature = result.target = sun.condition === "polar-day" ? p.dayTemperature : p.nightTemperature;
                    return result;
                }
            }
            if (sun.condition === "normal") {
                events.push({at:sun.rise,target:p.dayTemperature,period:"day"});
                events.push({at:sun.set,target:p.nightTemperature,period:"night"});
            }
        }
    }
    events.sort((a,b)=>a.at-b.at);
    let index=-1;
    for (let i=0;i<events.length;++i) if (events[i].at<=epoch) index=i;
    if (index<0 || index+1>=events.length) return result;
    const current=events[index], next=events[index+1];
    const previous=index>0 ? events[index-1] : {target:p.nightTemperature};
    const duration=Math.min(p.transition*60000, next.at-current.at);
    const fraction=duration===0 ? 1 : Math.min(1,(epoch-current.at)/duration);
    result.period=current.period;
    result.transitioning=fraction<1;
    result.target=current.target;
    result.temperature=Math.round(previous.target+(current.target-previous.target)*fraction);
    result.next=fraction<1 ? current.at+duration : next.at;
    // Update at most every 10K during fades, otherwise wake at the next event.
    const step=Math.max(1000,duration*10/Math.max(1,Math.abs(current.target-previous.target)));
    result.wake=Math.min(tomorrow, result.next, fraction<1 ? epoch+step : next.at);
    return result;
}
