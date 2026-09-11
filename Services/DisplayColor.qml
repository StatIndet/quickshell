pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Gamma
import qs.Common
import "../Common/functions/DisplaySchedule.js" as Schedule

Singleton {
    id: root

    property var preferences: Schedule.normalize({})
    property bool ready: false
    property string error: ""
    property bool locating: false
    property string locationError: ""
    property var locationRequest: null
    property var ipLocation: null
    property bool locationAttempted: false
    property var schedule: Schedule.evaluate(preferences, Date.now())
    readonly property bool available: backend.available
    readonly property var outputs: backend.outputs
    readonly property real dimming: preferences.dimming
    readonly property real dimmingLowerLimit: 0.25
    readonly property real gamma: preferences.gamma
    readonly property real contrast: preferences.contrast
    readonly property string scheduleWarning: {
        switch (schedule.condition) {
        case "missing-location":
            return qsTr("Set a location. Using the fixed night temperature.");
        case "polar-day":
            return qsTr("Midnight sun: using the day temperature.");
        case "polar-night":
            return qsTr("Polar night: using the night temperature.");
        case "equal-times":
            return qsTr("Choose different start and end times. Using the fixed night temperature.");
        default:
            return "";
        }
    }

    function setPreference(key, value) {
        if (!ready)
            return;
        preferences = Schedule.normalize(Object.assign({}, preferences, {
                                                           [key]: value
                                                       }));
        config.setText(JSON.stringify(preferences, null, 2));
        if (key === "useIP") {
            locationAttempted = false;
            locationError = "";
            if (!value && locationRequest) {
                locationRequest.abort();
                locationRequest = null;
                locating = false;
            }
        }
        evaluate();
    }
    function setDimming(value) {
        setPreference("dimming", value);
    }
    function useWeatherLocation() {
        if (!WeatherPlugin.hasValidData)
            return;
        preferences = Schedule.normalize(Object.assign({}, preferences, {
                                                           latitude: WeatherPlugin.latitude,
                                                           longitude: WeatherPlugin.longitude
                                                       }));
        config.setText(JSON.stringify(preferences, null, 2));
        evaluate();
    }
    function locate() {
        if (!preferences.useIP || locating)
            return;
        locationAttempted = true;
        locating = true;
        locationError = "";
        const request = new XMLHttpRequest();
        locationRequest = request;
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || root.locationRequest !== request)
                return;
            locationTimeout.stop();
            root.locating = false;
            root.locationRequest = null;
            try {
                const data = JSON.parse(request.responseText);
                if (request.status !== 200 || !data.success || typeof data.latitude !== "number"
                        || typeof data.longitude !== "number" || !isFinite(data.latitude) || !isFinite(
                            data.longitude) || Math.abs(data.latitude) > 90 || Math.abs(data.longitude) > 180)
                    throw new Error("Invalid location response");
                root.ipLocation = {
                    latitude: data.latitude,
                    longitude: data.longitude
                };
            } catch (e) {
                root.locationError = qsTr(
                            "Location lookup failed. Using the manual location or fixed night temperature.");
            }
            root.evaluate();
        };
        // Same opt-in location provider as the existing weather client. The
        // weather location is never changed by this independent request.
        request.open("GET", "https://ipwho.is/?fields=success,latitude,longitude");
        request.send();
        locationTimeout.restart();
    }
    function evaluate() {
        if (ready && preferences.useIP && !locationAttempted)
            locate();
        const effective = preferences.useIP && ipLocation ? Object.assign({}, preferences, ipLocation) :
                                                            preferences;
        schedule = Schedule.evaluate(effective, Date.now());
        if (ready)
            backend.apply(gamma, contrast, schedule.temperature, dimming);
        deadline.interval = Math.max(100, Math.min(2147483647, schedule.wake - Date.now()));
        deadline.restart();
    }

    GammaBackend {
        id: backend
        onResumed: root.evaluate()
    }
    Timer {
        id: locationTimeout
        interval: 15000
        onTriggered: {
            const request = root.locationRequest;
            root.locationRequest = null;
            if (request)
                request.abort();
            root.locating = false;
            root.locationError = qsTr(
                        "Location lookup timed out. Using the manual location or fixed night temperature.");
        }
    }
    Timer {
        id: deadline
        onTriggered: root.evaluate()
    }
    // Clock changes and wake-up reevaluate civil time; this never enumerates outputs.
    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: root.evaluate()
    }
    Process {
        command: ["mkdir", "-p", Paths.configHome]
        running: true
        onExited: code => {
            if (code !== 0) {
                root.error = qsTr("Unable to open display preferences");
                return;
            }
            config.reload();
        }
    }
    FileView {
        id: config
        path: Paths.configHome + "/display-color.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.preferences = Schedule.normalize(JSON.parse(text()));
                root.ready = true;
                root.error = "";
                root.evaluate();
            } catch (e) {
                root.error = qsTr("Invalid display preferences: %1").arg(String(e));
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.ready = true;
                root.evaluate();
            } else
                root.error = qsTr("Unable to read display preferences");
        }
        onSaveFailed: root.error = qsTr("Unable to save display preferences")
    }
}
