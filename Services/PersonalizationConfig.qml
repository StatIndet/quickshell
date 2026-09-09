pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/functions/WallpaperSource.js" as WallpaperSource
import qs.Services

Singleton {
    id: root

    readonly property string configOverride: Quickshell.env("CLAVIS_PERSONALIZATION_CONFIG") || ""
    readonly property string filePath: root.configOverride !== "" ? root.configOverride : Paths.configHome
                                                                    + "/config.json"

    readonly property string configDir: {
        const separator = root.filePath.lastIndexOf("/");
        return separator > 0 ? root.filePath.slice(0, separator) : Paths.configHome;
    }
    readonly property var fillModes: [({
                                           "value": "Stretch",
                                           "label": qsTr("Stretch")
                                       }), ({
                                                "value": "Fit",
                                                "label": qsTr("Fit")
                                            }), ({
                                                     "value": "Fill",
                                                     "label": qsTr("Fill")
                                                 }), ({
                                                          "value": "Tile",
                                                          "label": qsTr("Tile")
                                                      }), ({
                                                               "value": "TileVertically",
                                                               "label": qsTr("Tile vertically")
                                                           }), ({
                                                                    "value": "TileHorizontally",
                                                                    "label": qsTr("Tile horizontally")
                                                                }), ({
                                                                         "value": "Pad",
                                                                         "label": qsTr("Cover")
                                                                     })]
    readonly property var desktopFillModes: root.fillModes.concat([({
                                                                        "value": "panorama",
                                                                        "label": qsTr("Panorama")
                                                                    })])
    readonly property var transitionTypes: [({
                                                 "value": "random",
                                                 "label": qsTr("Random")
                                             }), ({
                                                      "value": "none",
                                                      "label": qsTr("None")
                                                  }), ({
                                                           "value": "fade",
                                                           "label": qsTr("Crossfade")
                                                       }), ({
                                                                "value": "wipe",
                                                                "label": qsTr("Wipe")
                                                            }), ({
                                                                     "value": "disc",
                                                                     "label": qsTr("Disc")
                                                                 }), ({
                                                                          "value": "stripes",
                                                                          "label": qsTr("Stripes")
                                                                      }), ({
                                                                               "value": "iris bloom",
                                                                               "label": qsTr("Iris bloom")
                                                                           }), ({
                                                                                    "value": "pixelate",
                                                                                    "label": qsTr("Pixelate")
                                                                                }), ({
                                                                                         "value": "portal",
                                                                                         "label": qsTr(
                                                                                                      "Portal")
                                                                                     })]
    readonly property var awwwTransitionTypes: [({
                                                     "value": "none",
                                                     "label": qsTr("None")
                                                 }), ({
                                                          "value": "simple",
                                                          "label": qsTr("Simple")
                                                      }), ({
                                                               "value": "fade",
                                                               "label": qsTr("Crossfade")
                                                           }), ({
                                                                    "value": "left",
                                                                    "label": qsTr("From left")
                                                                }), ({
                                                                         "value": "right",
                                                                         "label": qsTr("From right")
                                                                     }), ({
                                                                              "value": "top",
                                                                              "label": qsTr("From top")
                                                                          }), ({
                                                                                   "value": "bottom",
                                                                                   "label": qsTr(
                                                                                                "From bottom")
                                                                               }), ({
                                                                                        "value": "wipe",
                                                                                        "label": qsTr("Wipe")
                                                                                    }), ({
                                                                                             "value": "wave",
                                                                                             "label": qsTr(
                                                                                                          "Wave")
                                                                                         }), ({
                                                                                                  "value": "grow",
                                                                                                  "label": qsTr(
                                                                                                               "Grow")
                                                                                              }), ({
                                                                                                       "value": "center",
                                                                                                       "label": qsTr(
                                                                                                                    "Grow from center")
                                                                                                   }), ({
                                                                                                            "value": "any",
                                                                                                            "label": qsTr(
                                                                                                                         "Grow from random position")
                                                                                                        }), ({
                                                                                                                 "value": "outer",
                                                                                                                 "label": qsTr(
                                                                                                                              "Shrink inward")
                                                                                                             }), ({
                                                                                                                      "value": "random",
                                                                                                                      "label": qsTr(
                                                                                                                                   "Random")
                                                                                                                  })]
    readonly property var transitionEasingModes: [({
                                                       "value": "linear",
                                                       "label": qsTr("Linear")
                                                   }), ({
                                                            "value": "quad",
                                                            "label": qsTr("Quadratic")
                                                        }), ({
                                                                 "value": "cubic",
                                                                 "label": qsTr("Cubic")
                                                             }), ({
                                                                      "value": "quart",
                                                                      "label": qsTr("Quartic")
                                                                  }), ({
                                                                           "value": "quint",
                                                                           "label": qsTr("Quintic")
                                                                       }), ({
                                                                                "value": "sine",
                                                                                "label": qsTr("Sine")
                                                                            }), ({
                                                                                     "value": "expo",
                                                                                     "label": qsTr(
                                                                                                  "Exponential")
                                                                                 }), ({
                                                                                          "value": "circ",
                                                                                          "label": qsTr(
                                                                                                       "Circular")
                                                                                      }), ({
                                                                                               "value": "customBezier",
                                                                                               "label": qsTr(
                                                                                                            "Custom Bézier")
                                                                                           })]
    readonly property var baseTransitions: ["fade", "wipe", "disc", "stripes", "iris bloom", "pixelate",
        "portal"]
    readonly property var matugenSchemes: [({
                                                "value": "scheme-tonal-spot",
                                                "label": qsTr("Tonal spot")
                                            }), ({
                                                     "value": "scheme-vibrant",
                                                     "label": qsTr("Vibrant")
                                                 }), ({
                                                          "value": "scheme-content",
                                                          "label": qsTr("Content")
                                                      }), ({
                                                               "value": "scheme-expressive",
                                                               "label": qsTr("Expressive")
                                                           }), ({
                                                                    "value": "scheme-fidelity",
                                                                    "label": qsTr("Fidelity")
                                                                }), ({
                                                                         "value": "scheme-fruit-salad",
                                                                         "label": qsTr("Fruit salad")
                                                                     }), ({
                                                                              "value": "scheme-monochrome",
                                                                              "label": qsTr("Monochrome")
                                                                          }), ({
                                                                                   "value": "scheme-neutral",
                                                                                   "label": qsTr("Neutral")
                                                                               }), ({
                                                                                        "value": "scheme-rainbow",
                                                                                        "label": qsTr(
                                                                                                     "Rainbow")
                                                                                    })]
    readonly property var keystoneStyles: [({
                                                "value": "bangs",
                                                "label": qsTr("Bangs")
                                            }), ({
                                                     "value": "pill",
                                                     "label": qsTr("Pill")
                                                 })]
    readonly property var edgePositions: [({
                                               "value": "top",
                                               "label": qsTr("Top"),
                                               "icon": "arrow_upward"
                                           }), ({
                                                    "value": "left",
                                                    "label": qsTr("Left"),
                                                    "icon": "arrow_back"
                                                }), ({
                                                         "value": "bottom",
                                                         "label": qsTr("Bottom"),
                                                         "icon": "arrow_downward"
                                                     }), ({
                                                              "value": "right",
                                                              "label": qsTr("Right"),
                                                              "icon": "arrow_forward"
                                                          })]
    property bool storeReady: false
    property bool loading: false
    property bool loaded: false
    readonly property bool ready: root.storeReady && root.loaded && !root.loading
    property string wallpaperFolder: Paths.dataHome + "/wallpapers"
    property string wallpaperPath: ""
    property string wallpaperPathLight: ""
    property string wallpaperPathDark: ""
    property bool perModeWallpaper: false
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({})
    property var monitorWallpaperFillModes: ({})
    property var recentWallpaperColors: []
    property string wallpaperFillMode: "Fill"
    property string desktopWallpaperBackend: "quickshell"
    property bool autoCycleEnabled: false
    property string autoCycleMode: "interval"
    property int autoCycleInterval: 300
    property string autoCycleTime: "06:00"
    property string wallpaperTransitionType: "fade"
    property var includedTransitions: root.baseTransitions
    property int transitionDurationMs: 1000
    property string transitionEasingMode: "customBezier"
    property var transitionBezierCurve: [0.43, 1.19, 1, 0.4, 1, 1]
    property string awwwDesktopTransitionType: "fade"
    property int awwwTransitionFps: 60
    property int awwwTransitionStep: 90
    property real awwwTransitionAngle: 45
    property string awwwTransitionPosition: "center"
    property string awwwTransitionWave: "20,20"
    property bool overviewEnabled: true
    property bool overviewUseDesktopWallpaper: true
    property string overviewWallpaperPath: ""
    property string overviewWallpaperFillMode: "Fill"
    property bool overviewPerMonitorWallpaper: false
    property var overviewMonitorWallpapers: ({})
    property var overviewMonitorFillModes: ({})
    property string overviewTransitionType: "fade"
    property real overviewBlurRadius: 0
    property real overviewDim: 0
    property real overviewSaturation: 1
    property real overviewContrast: 1
    property bool parallaxVerticalEnabled: false
    property bool parallaxFollowWorkspaces: true
    property bool parallaxFollowSidebars: false
    property bool parallaxFollowTiledColumns: false
    property real parallaxPreferredScale: 1.1
    property int parallaxTiledColumnSpan: 6
    property string matugenScheme: "scheme-tonal-spot"
    property var matugenTemplates: ({})
    readonly property var lockScreenStyles: [
        {
            value: "default",
            label: "default"
        },
        {
            value: "caelestia",
            label: "caelestia"
        }
    ]
    property string lockScreenStyle: "default"
    property string themeMode: "dark"
    property string superKeyStyle: "text"
    readonly property var superKeyStyles: [
        {
            "value": "text",
            "label": "Super"
        },
        {
            "value": "windows",
            "label": "Windows"
        },
        {
            "value": "arch",
            "label": "Arch"
        },
        {
            "value": "linux",
            "label": "Linux"
        },
        {
            "value": "ubuntu",
            "label": "Ubuntu"
        },
        {
            "value": "debian",
            "label": "Debian"
        },
        {
            "value": "fedora",
            "label": "Fedora"
        },
        {
            "value": "nixos",
            "label": "NixOS"
        },
        {
            "value": "linuxmint",
            "label": "Linux Mint"
        },
        {
            "value": "gentoo",
            "label": "Gentoo"
        },
        {
            "value": "steam",
            "label": "Steam"
        },
        {
            "value": "apple",
            "label": "Apple"
        },
        {
            "value": "googlechrome",
            "label": "Chrome"
        },
        {
            "value": "command",
            "label": "Command"
        }
    ]
    property string cursorTheme: ""
    property int cursorSize: 24
    property bool cursorHideWhenTyping: false
    property int cursorHideAfterInactiveMs: 0
    property string iconTheme: ""
    property string keystoneStyle: "bangs"
    readonly property var keystoneKeyholeCardIds: ["weather", "quickSettings", "pomodoro"]
    readonly property var defaultKeystoneKeyholeCards: root.keystoneKeyholeCardIds.slice()
    readonly property var keystoneKeyholeCardOptions: [({
                                                            "value": "weather",
                                                            "label": qsTr("Weather"),
                                                            "icon": "partly_cloudy_day"
                                                        }), ({
                                                                 "value": "quickSettings",
                                                                 "label": qsTr("Quick Settings"),
                                                                 "icon": "tune"
                                                             }), ({
                                                                      "value": "pomodoro",
                                                                      "label": qsTr("Pomodoro"),
                                                                      "icon": "timer"
                                                                  })]
    property var keystoneKeyholeCards: root.defaultKeystoneKeyholeCards.slice()
    property string barPosition: "top"
    readonly property var barComponentIds: ["workspaces", "information", "activeWindow", "tray",
        "systemMonitor", "quickSettings"]
    readonly property var defaultBarLeadingComponents: ["workspaces", "information", "activeWindow"]
    readonly property var defaultBarTrailingComponents: ["tray", "systemMonitor", "quickSettings"]
    readonly property var barComponentOptions: [({
                                                     "value": "workspaces",
                                                     "label": qsTr("Workspaces"),
                                                     "icon": "grid_view"
                                                 }), ({
                                                          "value": "information",
                                                          "label": qsTr("Information"),
                                                          "icon": "info"
                                                      }), ({
                                                               "value": "activeWindow",
                                                               "label": qsTr("Active Window"),
                                                               "icon": "web_asset"
                                                           }), ({
                                                                    "value": "tray",
                                                                    "label": qsTr("Tray"),
                                                                    "icon": "inbox"
                                                                }), ({
                                                                         "value": "systemMonitor",
                                                                         "label": qsTr("System Monitor"),
                                                                         "icon": "monitoring"
                                                                     }), ({
                                                                              "value": "quickSettings",
                                                                              "label": qsTr("Quick Settings"),
                                                                              "icon": "tune"
                                                                          })]
    readonly property var quickSettingsComponentIds: ["network", "bluetooth", "brightness", "volume",
        "microphone", "battery", "settings", "power"]
    readonly property var defaultQuickSettingsComponents: root.quickSettingsComponentIds.slice()
    readonly property var quickSettingsComponentOptions: [({
                                                               "value": "network",
                                                               "label": qsTr("Network"),
                                                               "icon": "wifi"
                                                           }), ({
                                                                    "value": "bluetooth",
                                                                    "label": qsTr("Bluetooth"),
                                                                    "icon": "bluetooth"
                                                                }), ({
                                                                         "value": "brightness",
                                                                         "label": qsTr("Brightness"),
                                                                         "icon": "brightness_6"
                                                                     }), ({
                                                                              "value": "volume",
                                                                              "label": qsTr("Volume"),
                                                                              "icon": "volume_up"
                                                                          }), ({
                                                                                   "value": "microphone",
                                                                                   "label": qsTr("Microphone"),
                                                                                   "icon": "mic"
                                                                               }), ({
                                                                                        "value": "battery",
                                                                                        "label": qsTr(
                                                                                                     "Battery"),
                                                                                        "icon": "battery_full"
                                                                                    }), ({
                                                                                             "value": "settings",
                                                                                             "label": qsTr(
                                                                                                          "Settings"),
                                                                                             "icon": "settings"
                                                                                         }), ({
                                                                                                  "value": "power",
                                                                                                  "label": qsTr(
                                                                                                               "Power"),
                                                                                                  "icon": "power_settings_new"
                                                                                              })]
    property var barLeadingComponents: root.defaultBarLeadingComponents.slice()
    property var barTrailingComponents: root.defaultBarTrailingComponents.slice()
    property var quickSettingsComponents: root.defaultQuickSettingsComponents.slice()
    property string keystonePosition: "top"
    property bool keystoneHideDate: false
    property string keystoneHoverAction: "peak"
    property string keystoneLeftClickAction: "media"
    property string keystoneMiddleClickAction: "lyrics"
    readonly property var keystoneActionOptions: [
        {
            value: "none",
            label: qsTr("Do not open")
        },
        {
            value: "media",
            label: qsTr("Media controls")
        },
        {
            value: "lyrics",
            label: qsTr("Lyrics")
        },
        {
            value: "dashboard",
            label: qsTr("Dashboard")
        },
        {
            value: "library",
            label: qsTr("Media library")
        },
        {
            value: "upload",
            label: qsTr("Upload")
        },
        {
            value: "weather",
            label: qsTr("Weather")
        },
        {
            value: "tools",
            label: qsTr("Tools")
        }
    ]

    readonly property var keystoneHoverActionOptions: [
        {
            value: "peak",
            label: qsTr("Peak")
        }
    ].concat(root.keystoneActionOptions)

    function setKeystoneAction(gesture, action) {
        const properties = {
            hover: "keystoneHoverAction",
            left: "keystoneLeftClickAction",
            middle: "keystoneMiddleClickAction"
        };
        if (!Object.prototype.hasOwnProperty.call(properties, gesture))
            return;
        setValue(properties[gesture], normalizedOption(gesture === "hover" ? root.keystoneHoverActionOptions :
                                                                             root.keystoneActionOptions,
                                                       action, gesture === "hover" ? "peak" : "none"));
    }

    readonly property var horizontalClockAxisDefaults: ({
                                                            "wght": 900,
                                                            "wdth": 85,
                                                            "opsz": 18,
                                                            "GRAD": 0,
                                                            "ROND": 25,
                                                            "slnt": 0
                                                        })
    readonly property var horizontalClockAxisMinimums: ({
                                                            "wght": 1,
                                                            "wdth": 25,
                                                            "opsz": 6,
                                                            "GRAD": 0,
                                                            "ROND": 0,
                                                            "slnt": -10
                                                        })
    readonly property var horizontalClockAxisMaximums: ({
                                                            "wght": 1000,
                                                            "wdth": 151,
                                                            "opsz": 144,
                                                            "GRAD": 100,
                                                            "ROND": 100,
                                                            "slnt": 0
                                                        })
    readonly property var horizontalClockDigitDefaults: ({
                                                             "h0": ({
                                                                        "x": 0,
                                                                        "y": -2,
                                                                        "rotation": -3,
                                                                        "colorRole": "inversePrimary",
                                                                        "customColor": ""
                                                                    }),
                                                             "h1": ({
                                                                        "x": 0,
                                                                        "y": 1,
                                                                        "rotation": 3,
                                                                        "colorRole": "primary",
                                                                        "customColor": ""
                                                                    }),
                                                             "m0": ({
                                                                        "x": 0,
                                                                        "y": -1,
                                                                        "rotation": -2,
                                                                        "colorRole": "inversePrimary",
                                                                        "customColor": ""
                                                                    }),
                                                             "m1": ({
                                                                        "x": 0,
                                                                        "y": 1,
                                                                        "rotation": 2,
                                                                        "colorRole": "primary",
                                                                        "customColor": ""
                                                                    }),
                                                             "ap": ({
                                                                        "x": 1,
                                                                        "y": -2,
                                                                        "rotation": -2,
                                                                        "colorRole": "inversePrimary",
                                                                        "customColor": ""
                                                                    }),
                                                             "periodM": ({
                                                                             "x": 1,
                                                                             "y": 1,
                                                                             "rotation": 2,
                                                                             "colorRole": "primary",
                                                                             "customColor": ""
                                                                         })
                                                         })
    property int horizontalClockFontSize: 22
    property var horizontalClockAxes: ({
                                           "wght": 900,
                                           "wdth": 85,
                                           "opsz": 18,
                                           "GRAD": 0,
                                           "ROND": 25,
                                           "slnt": 0
                                       })
    property var horizontalClockDigits: ({
                                             "h0": ({
                                                        "x": 0,
                                                        "y": -2,
                                                        "rotation": -3,
                                                        "colorRole": "inversePrimary",
                                                        "customColor": ""
                                                    }),
                                             "h1": ({
                                                        "x": 0,
                                                        "y": 1,
                                                        "rotation": 3,
                                                        "colorRole": "primary",
                                                        "customColor": ""
                                                    }),
                                             "m0": ({
                                                        "x": 0,
                                                        "y": -1,
                                                        "rotation": -2,
                                                        "colorRole": "inversePrimary",
                                                        "customColor": ""
                                                    }),
                                             "m1": ({
                                                        "x": 0,
                                                        "y": 1,
                                                        "rotation": 2,
                                                        "colorRole": "primary",
                                                        "customColor": ""
                                                    }),
                                             "ap": ({
                                                        "x": 1,
                                                        "y": -2,
                                                        "rotation": -2,
                                                        "colorRole": "inversePrimary",
                                                        "customColor": ""
                                                    }),
                                             "periodM": ({
                                                             "x": 1,
                                                             "y": 1,
                                                             "rotation": 2,
                                                             "colorRole": "primary",
                                                             "customColor": ""
                                                         })
                                         })
    readonly property string uiFontFamily: Fonts.configuredUi || Fonts.defaultUi
    readonly property string monoFontFamily: Fonts.configuredMono || Fonts.defaultMono
    readonly property string numericFontFamily: Fonts.configuredNumeric || Fonts.defaultNumeric
    readonly property string expressiveFontFamily: Fonts.configuredExpressive || Fonts.bundledFamilyName
    property real shellBackgroundOpacity: 1
    property bool shellBlurEnabled: false
    property bool shellBlurXray: true
    property bool keepSidebarsLoaded: true
    property bool desktopCardGridSnapEnabled: true
    property bool desktopCardGridVisibleWhileDragging: true

    signal settingsLoaded

    function optionExists(options, value) {
        for (let i = 0; i < options.length; i += 1) {
            if (options[i].value === value)
                return true;
        }
        return false;
    }

    function normalizedOption(options, value, fallback) {
        return optionExists(options, value) ? value : fallback;
    }

    function normalizedTransition(value) {
        return normalizedOption(root.transitionTypes, value, "fade");
    }

    function normalizedAwwwTransition(value) {
        return normalizedOption(root.awwwTransitionTypes, value, "fade");
    }

    function normalizedEasingMode(value) {
        return normalizedOption(root.transitionEasingModes, value, "customBezier");
    }

    function normalizedEdgePosition(value) {
        return normalizedOption(root.edgePositions, value, "top");
    }

    function normalizedIncluded(raw) {
        if (!Array.isArray(raw))
            return root.baseTransitions.slice();

        const result = [];
        for (let i = 0; i < raw.length; i += 1) {
            const value = raw[i];
            if (root.baseTransitions.indexOf(value) !== -1 && result.indexOf(value) === -1)
                result.push(value);
        }
        return result.length > 0 ? result : root.baseTransitions.slice();
    }

    function normalizedBezier(raw) {
        const fallback = [0.43, 1.19, 1, 0.4, 1, 1];
        if (!Array.isArray(raw) || raw.length < 4)
            return fallback.slice();

        const source = raw.length === 4 ? [raw[0], raw[1], raw[2], raw[3], 1, 1] : raw;
        const result = [];
        for (let i = 0; i < 6; i += 1) {
            const value = Number(source[i]);
            result.push(isFinite(value) ? value : fallback[i]);
        }
        return result;
    }

    function cloneMap(map) {
        const result = {};
        if (!map)
            return result;

        for (let key in map)
            result[key] = map[key];
        return result;
    }

    function normalizedStringMap(raw) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw))
            return result;

        for (let key in raw)
            result[String(key)] = String(raw[key] || "");
        return result;
    }

    function normalizedCursorTheme(value) {
        if (typeof value !== "string")
            return "";

        const result = value.trim();
        if (result.length > 256 || /[\u0000-\u001f\u007f]/.test(result))
            return "";

        return result;
    }

    function normalizedMatugenTemplates(raw) {
        const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
        const result = Object.create(null);
        for (const id of Object.keys(source)) {
            if (/^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$/.test(id) && id !== "quickshell" && typeof source[id]
                    === "boolean")

                result[id] = source[id];
        }
        return result;
    }

    function normalizedFillModeMap(raw, options) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw))
            return result;

        const validOptions = options || root.desktopFillModes;
        for (let key in raw)
            result[String(key)] = normalizedOption(validOptions, raw[key], "Fill");
        return result;
    }

    function normalizedRecentColors(raw) {
        if (!Array.isArray(raw))
            return [];

        const result = [];
        for (let i = 0; i < raw.length && result.length < 5; i += 1) {
            const value = String(raw[i] || "").trim().toLowerCase();
            if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(value) && result.indexOf(value) === -1)
                result.push(value);
        }
        return result;
    }

    function setValue(propertyName, value) {
        if (root[propertyName] === value)
            return;

        root[propertyName] = value;
        root.save();
    }

    function setWallpaperFolder(value) {
        setValue("wallpaperFolder", value || Paths.dataHome + "/wallpapers");
    }

    function setWallpaperPath(value) {
        setValue("wallpaperPath", value || "");
    }

    function setWallpaperPathForMode(mode, value) {
        if (mode === "light")
            setValue("wallpaperPathLight", value || "");
        else
            setValue("wallpaperPathDark", value || "");
    }

    function setPerModeWallpaper(value) {
        setValue("perModeWallpaper", !!value);
    }

    function setPerMonitorWallpaper(value) {
        setValue("perMonitorWallpaper", !!value);
    }

    function setDesktopWallpaperBackend(value) {
        if (value === "awww" && !WallpaperService.canUseAwww)
            return;
        setValue("desktopWallpaperBackend", value === "awww" ? "awww" : "quickshell");
    }

    function setMonitorWallpaper(screenName, value) {
        if (!screenName)
            return;

        const next = cloneMap(root.monitorWallpapers);
        next[screenName] = value || "";
        root.monitorWallpapers = next;
        root.save();
    }

    function monitorWallpaper(screenName) {
        if (!screenName || !root.monitorWallpapers)
            return "";

        return root.monitorWallpapers[screenName] || "";
    }

    function setWallpaperFillMode(value) {
        setValue("wallpaperFillMode", normalizedOption(root.desktopFillModes, value, "Fill"));
    }

    function setMonitorWallpaperFillMode(screenName, value) {
        if (!screenName)
            return;

        const next = cloneMap(root.monitorWallpaperFillModes);
        next[screenName] = normalizedOption(root.desktopFillModes, value, "Fill");
        root.monitorWallpaperFillModes = next;
        root.save();
    }

    function monitorFillMode(screenName) {
        if (!screenName || !root.monitorWallpaperFillModes)
            return root.wallpaperFillMode;

        return root.monitorWallpaperFillModes[screenName] || root.wallpaperFillMode;
    }

    function addRecentWallpaperColor(color) {
        const value = String(color || "").trim().toLowerCase();
        if (!/^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(value))
            return;

        const next = [value];
        const source = normalizedRecentColors(root.recentWallpaperColors);
        for (let i = 0; i < source.length && next.length < 5; i += 1) {
            if (source[i] !== value)
                next.push(source[i]);
        }
        root.recentWallpaperColors = next;
        root.save();
    }

    function setAutoCycleEnabled(value) {
        setValue("autoCycleEnabled", !!value);
    }

    function setAutoCycleMode(value) {
        setValue("autoCycleMode", value === "time" ? "time" : "interval");
    }

    function setAutoCycleInterval(value) {
        setValue("autoCycleInterval", Math.max(5, Math.round(Number(value) || 300)));
    }

    function setAutoCycleTime(value) {
        const next = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(value) ? value : "06:00";
        setValue("autoCycleTime", next);
    }

    function setWallpaperTransitionType(value) {
        setValue("wallpaperTransitionType", normalizedTransition(value));
    }

    function setIncludedTransitions(values) {
        root.includedTransitions = normalizedIncluded(values);
        root.save();
    }

    function setTransitionIncluded(value, enabled) {
        if (root.baseTransitions.indexOf(value) === -1)
            return;

        const next = root.includedTransitions.slice();
        const index = next.indexOf(value);
        if (enabled && index === -1)
            next.push(value);

        if (!enabled && index !== -1)
            next.splice(index, 1);

        root.setIncludedTransitions(next);
    }

    function normalizedDurationMs(value, fallback) {
        if (value === null || value === undefined || value === "")
            return fallback;

        const numberValue = Number(value);
        return !isFinite(numberValue) ? fallback : Math.max(0, Math.min(5000, Math.round(numberValue)));
    }

    function normalizedBoundedInt(value, fallback, minValue, maxValue) {
        if (value === null || value === undefined || value === "")
            return fallback;

        const numberValue = Number(value);
        if (!isFinite(numberValue))
            return fallback;

        return Math.max(minValue, Math.min(maxValue, Math.round(numberValue)));
    }

    function setTransitionDurationMs(value) {
        setValue("transitionDurationMs", normalizedDurationMs(value, 0));
    }

    function setTransitionEasingMode(value) {
        setValue("transitionEasingMode", normalizedEasingMode(value));
    }

    function setTransitionBezierCurve(value) {
        root.transitionBezierCurve = normalizedBezier(value);
        root.save();
    }

    function setTransitionBezierControlPoints(x1, y1, x2, y2) {
        root.setTransitionBezierCurve([x1, y1, x2, y2, 1, 1]);
    }

    function normalizedBoundedReal(value, fallback, minValue, maxValue) {
        if (value === null || value === undefined || value === "")
            return fallback;

        const numberValue = Number(value);
        if (!isFinite(numberValue))
            return fallback;

        return Math.max(minValue, Math.min(maxValue, numberValue));
    }

    function normalizedHorizontalClockAxes(raw) {
        const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
        const result = {};
        const names = ["wght", "wdth", "opsz", "GRAD", "ROND", "slnt"];
        for (let i = 0; i < names.length; i += 1) {
            const name = names[i];
            result[name] = root.normalizedBoundedReal(source[name], root.horizontalClockAxisDefaults[name],
                                                      root.horizontalClockAxisMinimums[name],
                                                      root.horizontalClockAxisMaximums[name]);
        }
        return result;
    }

    function normalizedHorizontalClockDigits(raw) {
        const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
        const result = {};
        const ids = ["h0", "h1", "m0", "m1", "ap", "periodM"];
        const colorRoles = ["primary", "inversePrimary", "custom"];
        for (let i = 0; i < ids.length; i += 1) {
            const id = ids[i];
            const fallback = root.horizontalClockDigitDefaults[id];
            const candidate = source[id] && typeof source[id] === "object" && !Array.isArray(source[id])
                  ? source[id] : {};
            const candidateColor = String(candidate.customColor || "").trim().toLowerCase();
            const hasCustomColor = /^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(candidateColor);
            let colorRole = colorRoles.indexOf(candidate.colorRole) !== -1 ? candidate.colorRole :
                                                                             fallback.colorRole;
            if (colorRole === "custom" && !hasCustomColor)
                colorRole = fallback.colorRole;

            result[id] = {
                "x": root.normalizedBoundedInt(candidate.x, fallback.x, -8, 8),
                "y": root.normalizedBoundedInt(candidate.y, fallback.y, -6, 6),
                "rotation": root.normalizedBoundedInt(candidate.rotation, fallback.rotation, -12, 12),
                "colorRole": colorRole,
                "customColor": hasCustomColor ? candidateColor : ""
            };
        }
        return result;
    }

    function horizontalClockDigit(id) {
        const defaults = root.horizontalClockDigitDefaults[id];
        const configured = root.horizontalClockDigits[id];
        return configured || defaults;
    }

    function horizontalClockDigitColor(id) {
        const digit = root.horizontalClockDigit(id);
        if (digit.colorRole === "custom" && /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(String(digit.customColor
                                                                                        || "")))
            return digit.customColor;

        return digit.colorRole === "inversePrimary" ? Appearance.colors.colInversePrimary :
                                                      Appearance.colors.colPrimary;
    }

    function normalizedAwwwPosition(value) {
        const position = String(value || "").trim();
        const aliases = ["center", "top", "left", "right", "bottom", "top-left", "top-right", "bottom-left",
                         "bottom-right"];
        if (aliases.indexOf(position) !== -1)
            return position;

        if (/^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/.test(position))
            return position;

        return "center";
    }

    function normalizedAwwwWave(value) {
        const match = String(value || "").trim().match(/^(\d+(\.\d+)?),(\d+(\.\d+)?)$/);
        if (!match)
            return "20,20";

        const width = normalizedBoundedReal(match[1], 20, 1, 1000);
        const height = normalizedBoundedReal(match[3], 20, 1, 1000);
        return width + "," + height;
    }

    function setAwwwDesktopTransitionType(value) {
        setValue("awwwDesktopTransitionType", normalizedAwwwTransition(value));
    }

    function setAwwwTransitionFps(value) {
        setValue("awwwTransitionFps", normalizedBoundedInt(value, 60, 10, 240));
    }

    function setAwwwTransitionStep(value) {
        setValue("awwwTransitionStep", normalizedBoundedInt(value, 90, 0, 255));
    }

    function setAwwwTransitionAngle(value) {
        setValue("awwwTransitionAngle", normalizedBoundedReal(value, 45, 0, 360));
    }

    function setAwwwTransitionPosition(value) {
        setValue("awwwTransitionPosition", normalizedAwwwPosition(value));
    }

    function setAwwwTransitionWave(value) {
        setValue("awwwTransitionWave", normalizedAwwwWave(value));
    }

    function setOverviewEnabled(value) {
        setValue("overviewEnabled", !!value);
    }

    function setOverviewUseDesktopWallpaper(value) {
        setValue("overviewUseDesktopWallpaper", !!value);
    }

    function setOverviewWallpaperPath(value) {
        setValue("overviewWallpaperPath", value || "");
    }

    function setOverviewWallpaperFillMode(value) {
        setValue("overviewWallpaperFillMode", normalizedOption(root.fillModes, value, "Fill"));
    }

    function setOverviewPerMonitorWallpaper(value) {
        setValue("overviewPerMonitorWallpaper", !!value);
    }

    function setOverviewMonitorWallpaper(screenName, value) {
        if (!screenName)
            return;

        const next = cloneMap(root.overviewMonitorWallpapers);
        next[screenName] = value || "";
        root.overviewMonitorWallpapers = next;
        root.save();
    }

    function overviewMonitorWallpaper(screenName) {
        if (!screenName || !root.overviewMonitorWallpapers)
            return "";

        return root.overviewMonitorWallpapers[screenName] || "";
    }

    function setOverviewMonitorFillMode(screenName, value) {
        if (!screenName)
            return;

        const next = cloneMap(root.overviewMonitorFillModes);
        next[screenName] = normalizedOption(root.fillModes, value, "Fill");
        root.overviewMonitorFillModes = next;
        root.save();
    }

    function overviewMonitorFillMode(screenName) {
        if (!screenName || !root.overviewMonitorFillModes)
            return root.overviewWallpaperFillMode;

        return root.overviewMonitorFillModes[screenName] || root.overviewWallpaperFillMode;
    }

    function setOverviewTransitionType(value) {
        setValue("overviewTransitionType", normalizedTransition(value));
    }

    function setOverviewBlurRadius(value) {
        setValue("overviewBlurRadius", normalizedBoundedReal(value, 0, 0, 100));
    }

    function setOverviewDim(value) {
        setValue("overviewDim", normalizedBoundedReal(value, 0, 0, 1));
    }

    function setOverviewSaturation(value) {
        setValue("overviewSaturation", normalizedBoundedReal(value, 1, 0, 2));
    }

    function setOverviewContrast(value) {
        setValue("overviewContrast", normalizedBoundedReal(value, 1, 0.5, 2));
    }

    function setParallaxVerticalEnabled(value) {
        setValue("parallaxVerticalEnabled", !!value);
    }

    function setParallaxFollowWorkspaces(value) {
        setValue("parallaxFollowWorkspaces", !!value);
    }

    function setParallaxFollowSidebars(value) {
        setValue("parallaxFollowSidebars", !!value);
    }

    function setParallaxFollowTiledColumns(value) {
        setValue("parallaxFollowTiledColumns", !!value);
    }

    function setParallaxPreferredScale(value) {
        setValue("parallaxPreferredScale", normalizedBoundedReal(value, 1.1, 1, 1.35));
    }

    function setParallaxTiledColumnSpan(value) {
        setValue("parallaxTiledColumnSpan", normalizedBoundedInt(value, 6, 2, 12));
    }

    function setMatugenScheme(value) {
        setValue("matugenScheme", normalizedOption(root.matugenSchemes, value, "scheme-tonal-spot"));
    }

    function isMatugenTemplateEnabled(id) {
        const template = MatugenTemplateService.templateById(id);
        if (!template || !template.valid)
            return false;
        if (Object.prototype.hasOwnProperty.call(root.matugenTemplates, id))
            return root.matugenTemplates[id] === true;
        return template.origin === "builtin";
    }

    function setMatugenTemplateEnabled(id, enabled) {
        const template = MatugenTemplateService.templateById(id);
        if (!root.ready || !template || !template.valid)
            return false;
        const nextEnabled = !!enabled;
        if (root.isMatugenTemplateEnabled(id) === nextEnabled)
            return false;
        const next = root.normalizedMatugenTemplates(root.matugenTemplates);
        next[id] = nextEnabled;
        root.matugenTemplates = next;
        root.save();
        return true;
    }

    function discoverMatugenTemplates(templates) {
        if (!root.ready)
            return;
        const next = root.normalizedMatugenTemplates(root.matugenTemplates);
        let changed = false;
        for (const template of templates) {
            if (!Object.prototype.hasOwnProperty.call(next, template.id)) {
                next[template.id] = template.origin === "builtin";
                changed = true;
            }
        }
        if (changed) {
            root.matugenTemplates = next;
            root.save();
        }
    }

    function removeMatugenTemplate(id) {
        const next = root.normalizedMatugenTemplates(root.matugenTemplates);
        delete next[id];
        root.matugenTemplates = next;
        root.save();
    }

    function setThemeMode(value) {
        setValue("themeMode", value === "light" ? "light" : "dark");
    }

    function setCursorTheme(value) {
        setValue("cursorTheme", root.normalizedCursorTheme(value));
    }

    function setCursorSize(value) {
        setValue("cursorSize", root.normalizedBoundedInt(value, 24, 12, 128));
    }

    function setCursorHideWhenTyping(value) {
        setValue("cursorHideWhenTyping", typeof value === "boolean" ? value : false);
    }

    function setCursorHideAfterInactiveMs(value) {
        setValue("cursorHideAfterInactiveMs", root.normalizedBoundedInt(value, 0, 0, 5000));
    }

    function setIconTheme(value) {
        setValue("iconTheme", value || "");
    }

    function setLockScreenStyle(value) {
        setValue("lockScreenStyle", normalizedOption(root.lockScreenStyles, value, "default"));
    }

    function setKeystoneStyle(value) {
        setValue("keystoneStyle", normalizedOption(root.keystoneStyles, value, "bangs"));
    }

    function setFontFamily(role, family) {
        const allowedRoles = ["ui", "mono", "numeric", "expressive"];
        if (allowedRoles.indexOf(role) === -1)
            return false;

        const value = String(family || "").trim();
        if (value === "")
            return false;

        if (!FontService.containsFamily(value))
            return false;

        if (!Fonts.setConfiguredFamily(role, value))
            return false;

        root.save();
        return true;
    }

    function setShellBackgroundOpacity(value) {
        setValue("shellBackgroundOpacity", normalizedBoundedReal(value, 1, 0, 1));
    }

    function setShellBlurEnabled(value) {
        setValue("shellBlurEnabled", !!value);
    }

    function setShellBlurXray(value) {
        setValue("shellBlurXray", !!value);
    }

    function setKeepSidebarsLoaded(value) {
        setValue("keepSidebarsLoaded", !!value);
    }

    function setDesktopCardGridSnapEnabled(value) {
        setValue("desktopCardGridSnapEnabled", !!value);
    }

    function setDesktopCardGridVisibleWhileDragging(value) {
        setValue("desktopCardGridVisibleWhileDragging", !!value);
    }

    function setBarPosition(value) {
        setValue("barPosition", normalizedEdgePosition(value));
    }

    function normalizedBarComponents(raw, excluded) {
        const source = Array.isArray(raw) ? raw : [];
        const blocked = excluded || [];
        const result = [];
        for (let index = 0; index < source.length; index += 1) {
            const componentId = String(source[index] || "");
            if (root.barComponentIds.indexOf(componentId) === -1 || blocked.indexOf(componentId) !== -1
                    || result.indexOf(componentId) !== -1)
                continue;

            result.push(componentId);
        }
        return result;
    }

    function normalizedBarLayout(leading, trailing, useDefaults) {
        const normalizedLeading = root.normalizedBarComponents(useDefaults ? root.defaultBarLeadingComponents :
                                                                             leading, []);
        const normalizedTrailing = root.normalizedBarComponents(useDefaults
                                                                ? root.defaultBarTrailingComponents : trailing,
                                                                normalizedLeading);
        return {
            "leading": normalizedLeading,
            "trailing": normalizedTrailing
        };
    }

    function barZoneComponents(zone) {
        return zone === "leading" ? root.barLeadingComponents : zone === "trailing"
                                    ? root.barTrailingComponents : [];
    }

    function moveBarComponent(componentId, targetZone, targetIndex) {
        const id = String(componentId || "");
        if (root.barComponentIds.indexOf(id) === -1 || (targetZone !== "leading" && targetZone
                                                        !== "trailing"))
            return false;

        const leading = root.normalizedBarComponents(root.barLeadingComponents, []).filter(value => {
            return value !== id;
        });
        const trailing = root.normalizedBarComponents(root.barTrailingComponents, leading).filter(value => {
            return value !== id;
        });
        const target = targetZone === "leading" ? leading : trailing;
        const numericIndex = Number(targetIndex);
        const insertionIndex = isFinite(numericIndex) ? Math.max(0, Math.min(target.length, Math.round(
                                                                                 numericIndex))) :
                                                        target.length;
        target.splice(insertionIndex, 0, id);
        root.barLeadingComponents = leading;
        root.barTrailingComponents = trailing;
        root.save();
        return true;
    }

    function removeBarComponent(componentId) {
        const id = String(componentId || "");
        if (root.barComponentIds.indexOf(id) === -1)
            return false;

        const leading = root.barLeadingComponents.filter(value => {
            return value !== id;
        });
        const trailing = root.barTrailingComponents.filter(value => {
            return value !== id;
        });
        if (leading.length === root.barLeadingComponents.length && trailing.length
                === root.barTrailingComponents.length)
            return false;

        root.barLeadingComponents = root.normalizedBarComponents(leading, []);
        root.barTrailingComponents = root.normalizedBarComponents(trailing, root.barLeadingComponents);
        root.save();
        return true;
    }

    function toggleBarComponent(componentId, zone) {
        if (zone !== "leading" && zone !== "trailing")
            return false;

        if (root.barZoneComponents(zone).indexOf(componentId) !== -1)
            return root.removeBarComponent(componentId);

        return root.moveBarComponent(componentId, zone, root.barZoneComponents(zone).length);
    }

    function normalizedQuickSettingsComponents(raw) {
        const source = Array.isArray(raw) ? raw : root.defaultQuickSettingsComponents;
        const result = [];
        for (let index = 0; index < source.length; index += 1) {
            const componentId = String(source[index] || "");
            if (root.quickSettingsComponentIds.indexOf(componentId) === -1 || result.indexOf(componentId) !==
                    -1)
                continue;

            result.push(componentId);
        }
        return result;
    }

    function moveQuickSettingsComponent(componentId, targetIndex) {
        const id = String(componentId || "");
        if (root.quickSettingsComponentIds.indexOf(id) === -1)
            return false;

        const components = root.normalizedQuickSettingsComponents(root.quickSettingsComponents).filter(value
                                                                                                       => {
                                                                                                           return value
                                                                                                                   !== id;
                                                                                                       });
        const numericIndex = Number(targetIndex);
        const insertionIndex = isFinite(numericIndex) ? Math.max(0, Math.min(components.length, Math.round(
                                                                                 numericIndex))) :
                                                        components.length;
        components.splice(insertionIndex, 0, id);
        root.quickSettingsComponents = components;
        root.save();
        return true;
    }

    function removeQuickSettingsComponent(componentId) {
        const id = String(componentId || "");
        const components = root.quickSettingsComponents.filter(value => {
            return value !== id;
        });
        if (components.length === root.quickSettingsComponents.length)
            return false;

        root.quickSettingsComponents = root.normalizedQuickSettingsComponents(components);
        root.save();
        return true;
    }

    function toggleQuickSettingsComponent(componentId) {
        const id = String(componentId || "");
        if (root.quickSettingsComponents.indexOf(id) !== -1)
            return root.removeQuickSettingsComponent(id);

        return root.moveQuickSettingsComponent(id, root.quickSettingsComponents.length);
    }

    function setKeystonePosition(value) {
        setValue("keystonePosition", normalizedEdgePosition(value));
    }

    function normalizedKeystoneKeyholeCards(raw) {
        const source = Array.isArray(raw) ? raw : root.defaultKeystoneKeyholeCards;
        const result = [];
        for (let index = 0; index < source.length; index += 1) {
            const cardId = String(source[index] || "");
            if (root.keystoneKeyholeCardIds.indexOf(cardId) === -1 || result.indexOf(cardId) !== -1)
                continue;

            result.push(cardId);
        }
        return result;
    }

    function moveKeystoneKeyholeCard(cardId, targetIndex) {
        const id = String(cardId || "");
        if (root.keystoneKeyholeCardIds.indexOf(id) === -1)
            return false;

        const cards = root.normalizedKeystoneKeyholeCards(root.keystoneKeyholeCards).filter(value => {
            return value !== id;
        });
        const numericIndex = Number(targetIndex);
        const insertionIndex = isFinite(numericIndex) ? Math.max(0, Math.min(cards.length, Math.round(
                                                                                 numericIndex))) :
                                                        cards.length;
        cards.splice(insertionIndex, 0, id);
        root.keystoneKeyholeCards = cards;
        root.save();
        return true;
    }

    function removeKeystoneKeyholeCard(cardId) {
        const id = String(cardId || "");
        const cards = root.keystoneKeyholeCards.filter(value => {
            return value !== id;
        });
        if (cards.length === root.keystoneKeyholeCards.length)
            return false;

        root.keystoneKeyholeCards = root.normalizedKeystoneKeyholeCards(cards);
        root.save();
        return true;
    }

    function toggleKeystoneKeyholeCard(cardId) {
        const id = String(cardId || "");
        if (root.keystoneKeyholeCards.indexOf(id) !== -1)
            return root.removeKeystoneKeyholeCard(id);

        return root.moveKeystoneKeyholeCard(id, root.keystoneKeyholeCards.length);
    }

    function setKeystoneHideDate(value) {
        setValue("keystoneHideDate", !!value);
    }

    function setHorizontalClockFontSize(value, persist) {
        const next = root.normalizedBoundedInt(value, 22, 16, 28);
        if (root.horizontalClockFontSize === next) {
            if (persist !== false)
                root.save();

            return;
        }
        root.horizontalClockFontSize = next;
        if (persist !== false)
            root.save();
    }

    function setHorizontalClockAxis(axis, value, persist) {
        const name = String(axis || "");
        if (root.horizontalClockAxisDefaults[name] === undefined)
            return;

        const next = root.normalizedBoundedReal(value, root.horizontalClockAxisDefaults[name],
                                                root.horizontalClockAxisMinimums[name],
                                                root.horizontalClockAxisMaximums[name]);
        const current = root.horizontalClockAxes[name];
        if (current === next) {
            if (persist !== false)
                root.save();

            return;
        }
        const axes = root.cloneMap(root.horizontalClockAxes);
        axes[name] = next;
        root.horizontalClockAxes = root.normalizedHorizontalClockAxes(axes);
        if (persist !== false)
            root.save();
    }

    function setHorizontalClockDigitValue(id, field, value, persist) {
        const name = String(id || "");
        const propertyName = String(field || "");
        const fallback = root.horizontalClockDigitDefaults[name];
        if (!fallback || ["x", "y", "rotation"].indexOf(propertyName) === -1)
            return;

        const limits = propertyName === "x" ? [-8, 8] : propertyName === "y" ? [-6, 6] : [-12, 12];
        const current = root.horizontalClockDigit(name);
        const next = root.normalizedBoundedInt(value, fallback[propertyName], limits[0], limits[1]);
        if (current[propertyName] === next) {
            if (persist !== false)
                root.save();

            return;
        }
        const digits = root.normalizedHorizontalClockDigits(root.horizontalClockDigits);
        digits[name][propertyName] = next;
        root.horizontalClockDigits = digits;
        if (persist !== false)
            root.save();
    }

    function setHorizontalClockDigitColor(id, role, customColor, persist) {
        const name = String(id || "");
        const fallback = root.horizontalClockDigitDefaults[name];
        if (!fallback)
            return;

        const candidateRole = String(role || "");
        const normalizedColor = String(customColor || "").trim().toLowerCase();
        const customValid = /^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(normalizedColor);
        const validRole = ["primary", "inversePrimary"].indexOf(candidateRole) !== -1;
        const useCandidate = validRole || (candidateRole === "custom" && customValid);
        const nextRole = useCandidate ? candidateRole : fallback.colorRole;

        const digits = root.normalizedHorizontalClockDigits(root.horizontalClockDigits);
        digits[name].colorRole = nextRole;
        digits[name].customColor = customValid ? normalizedColor : "";
        root.horizontalClockDigits = digits;
        if (persist !== false)
            root.save();
    }

    function toJson() {
        return {
            "wallpaper": {
                "folder": root.wallpaperFolder,
                "path": root.wallpaperPath,
                "pathLight": root.wallpaperPathLight,
                "pathDark": root.wallpaperPathDark,
                "perMode": root.perModeWallpaper,
                "perMonitor": root.perMonitorWallpaper,
                "monitorWallpapers": root.monitorWallpapers,
                "monitorFillModes": root.monitorWallpaperFillModes,
                "recentColors": root.recentWallpaperColors,
                "fillMode": root.wallpaperFillMode,
                "desktopBackend": root.desktopWallpaperBackend,
                "autoCycle": {
                    "enabled": root.autoCycleEnabled,
                    "mode": root.autoCycleMode,
                    "interval": root.autoCycleInterval,
                    "time": root.autoCycleTime
                },
                "transition": {
                    "type": root.wallpaperTransitionType,
                    "included": root.includedTransitions,
                    "durationMs": root.transitionDurationMs,
                    "easingMode": root.transitionEasingMode,
                    "bezierCurve": root.transitionBezierCurve
                },
                "awww": {
                    "transitionType": root.awwwDesktopTransitionType,
                    "transitionFps": root.awwwTransitionFps,
                    "transitionStep": root.awwwTransitionStep,
                    "transitionAngle": root.awwwTransitionAngle,
                    "transitionPosition": root.awwwTransitionPosition,
                    "transitionWave": root.awwwTransitionWave
                },
                "overview": {
                    "enabled": root.overviewEnabled,
                    "useDesktopWallpaper": root.overviewUseDesktopWallpaper,
                    "path": root.overviewWallpaperPath,
                    "fillMode": root.overviewWallpaperFillMode,
                    "perMonitor": root.overviewPerMonitorWallpaper,
                    "monitorWallpapers": root.overviewMonitorWallpapers,
                    "monitorFillModes": root.overviewMonitorFillModes,
                    "transitionType": root.overviewTransitionType,
                    "blurRadius": root.overviewBlurRadius,
                    "dim": root.overviewDim,
                    "saturation": root.overviewSaturation,
                    "contrast": root.overviewContrast
                },
                "parallax": {
                    "verticalEnabled": root.parallaxVerticalEnabled,
                    "followWorkspaces": root.parallaxFollowWorkspaces,
                    "followSidebars": root.parallaxFollowSidebars,
                    "followTiledColumns": root.parallaxFollowTiledColumns,
                    "preferredScale": root.parallaxPreferredScale,
                    "tiledColumnSpan": root.parallaxTiledColumnSpan
                }
            },
            "theme": {
                "matugenScheme": root.matugenScheme,
                "matugenTemplates": root.normalizedMatugenTemplates(root.matugenTemplates),
                "mode": root.themeMode,
                "superKeyStyle": root.superKeyStyle,
                "lockScreenStyle": root.lockScreenStyle,
                "cursorTheme": root.cursorTheme,
                "cursorSize": root.cursorSize,
                "cursorHideWhenTyping": root.cursorHideWhenTyping,
                "cursorHideAfterInactiveMs": root.cursorHideAfterInactiveMs,
                "iconTheme": root.iconTheme,
                "fonts": {
                    "ui": root.uiFontFamily,
                    "mono": root.monoFontFamily,
                    "numeric": root.numericFontFamily,
                    "expressive": root.expressiveFontFamily
                }
            },
            "effects": {
                "shellBackgroundOpacity": root.shellBackgroundOpacity,
                "shellBlurEnabled": root.shellBlurEnabled,
                "shellBlurXray": root.shellBlurXray
            },
            "keystone": {
                "style": root.keystoneStyle,
                "position": root.keystonePosition,
                "hideDate": root.keystoneHideDate,
                "hoverAction": root.keystoneHoverAction,
                "leftClickAction": root.keystoneLeftClickAction,
                "middleClickAction": root.keystoneMiddleClickAction,
                "keyhole": {
                    "cards": root.keystoneKeyholeCards.slice()
                },
                "horizontalClock": {
                    "fontSize": root.horizontalClockFontSize,
                    "axes": root.cloneMap(root.horizontalClockAxes),
                    "digits": root.horizontalClockDigits
                }
            },
            "bar": {
                "position": root.barPosition,
                "barLeadingComponents": root.barLeadingComponents.slice(),
                "barTrailingComponents": root.barTrailingComponents.slice(),
                "quickSettingsComponents": root.quickSettingsComponents.slice()
            },
            "sidebar": {
                "keepLoaded": root.keepSidebarsLoaded
            },
            "desktopCards": {
                "gridSnapEnabled": root.desktopCardGridSnapEnabled,
                "gridVisibleWhileDragging": root.desktopCardGridVisibleWhileDragging
            }
        };
    }

    function loadFromObject(parsed) {
        const wallpaper = parsed.wallpaper || {};
        const theme = parsed.theme || {};
        const effects = parsed.effects || {};
        const keystone = parsed.keystone || {};
        const bar = parsed.bar || {};
        const sidebar = parsed.sidebar || {};
        const desktopCards = parsed.desktopCards || {};
        const transition = wallpaper.transition || {};
        const awww = wallpaper.awww || {};
        const overview = wallpaper.overview || {};
        const parallax = wallpaper.parallax || {};
        const autoCycle = wallpaper.autoCycle || {};
        const fonts = theme.fonts || {};
        const horizontalClock = keystone.horizontalClock || {};
        const keyhole = keystone.keyhole || {};
        root.wallpaperFolder = wallpaper.folder || Paths.dataHome + "/wallpapers";
        root.wallpaperPath = wallpaper.path === Paths.currentWallpaper ? "" : (wallpaper.path || "");
        root.wallpaperPathLight = wallpaper.pathLight || "";
        root.wallpaperPathDark = wallpaper.pathDark || "";
        root.perModeWallpaper = !!wallpaper.perMode;
        root.perMonitorWallpaper = !!wallpaper.perMonitor;
        root.monitorWallpapers = normalizedStringMap(wallpaper.monitorWallpapers);
        root.monitorWallpaperFillModes = normalizedFillModeMap(wallpaper.monitorFillModes);
        root.recentWallpaperColors = normalizedRecentColors(wallpaper.recentColors);
        root.wallpaperFillMode = normalizedOption(root.desktopFillModes, wallpaper.fillMode, "Fill");
        root.desktopWallpaperBackend = wallpaper.desktopBackend === "awww" ? "awww" : "quickshell";
        root.autoCycleEnabled = !!autoCycle.enabled;
        root.autoCycleMode = autoCycle.mode === "time" ? "time" : "interval";
        root.autoCycleInterval = Math.max(5, Math.round(Number(autoCycle.interval) || 300));
        const validTime = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(autoCycle.time || "");
        root.autoCycleTime = validTime ? autoCycle.time : "06:00";

        root.wallpaperTransitionType = normalizedTransition(transition.type || "fade");
        root.includedTransitions = normalizedIncluded(transition.included);
        root.transitionDurationMs = normalizedDurationMs(transition.durationMs, 1000);
        root.transitionEasingMode = normalizedEasingMode(transition.easingMode || "customBezier");
        root.transitionBezierCurve = normalizedBezier(transition.bezierCurve);
        root.awwwDesktopTransitionType = normalizedAwwwTransition(awww.transitionType || "fade");
        root.awwwTransitionFps = normalizedBoundedInt(awww.transitionFps, 60, 10, 240);
        root.awwwTransitionStep = normalizedBoundedInt(awww.transitionStep, 90, 0, 255);
        root.awwwTransitionAngle = normalizedBoundedReal(awww.transitionAngle, 45, 0, 360);
        root.awwwTransitionPosition = normalizedAwwwPosition(awww.transitionPosition);
        root.awwwTransitionWave = normalizedAwwwWave(awww.transitionWave);
        root.overviewEnabled = overview.enabled === undefined ? true : !!overview.enabled;
        root.overviewUseDesktopWallpaper = overview.useDesktopWallpaper === undefined ? true : !
                                                                                        !overview.useDesktopWallpaper;
        root.overviewWallpaperPath = String(overview.path || "");
        root.overviewWallpaperFillMode = normalizedOption(root.fillModes, overview.fillMode, "Fill");
        root.overviewPerMonitorWallpaper = !!overview.perMonitor;
        root.overviewMonitorWallpapers = normalizedStringMap(overview.monitorWallpapers);
        root.overviewMonitorFillModes = normalizedFillModeMap(overview.monitorFillModes, root.fillModes);
        root.overviewTransitionType = normalizedTransition(overview.transitionType || "fade");
        root.overviewBlurRadius = normalizedBoundedReal(overview.blurRadius, 0, 0, 100);
        root.overviewDim = normalizedBoundedReal(overview.dim, 0, 0, 1);
        root.overviewSaturation = normalizedBoundedReal(overview.saturation, 1, 0, 2);
        root.overviewContrast = normalizedBoundedReal(overview.contrast, 1, 0.5, 2);
        root.parallaxVerticalEnabled = !!parallax.verticalEnabled;
        root.parallaxFollowWorkspaces = parallax.followWorkspaces === undefined ? true : !
                                                                                  !parallax.followWorkspaces;
        root.parallaxFollowSidebars = !!parallax.followSidebars;
        root.parallaxFollowTiledColumns = !!parallax.followTiledColumns;
        root.parallaxPreferredScale = normalizedBoundedReal(parallax.preferredScale, 1.1, 1, 1.35);
        root.parallaxTiledColumnSpan = normalizedBoundedInt(parallax.tiledColumnSpan, 6, 2, 12);
        root.matugenScheme = normalizedOption(root.matugenSchemes, theme.matugenScheme, "scheme-tonal-spot");
        root.matugenTemplates = normalizedMatugenTemplates(theme.matugenTemplates);
        root.lockScreenStyle = normalizedOption(root.lockScreenStyles, theme.lockScreenStyle, "default");
        root.themeMode = theme.mode === "light" ? "light" : "dark";
        root.superKeyStyle = root.superKeyStyles.some(style => style.value === theme.superKeyStyle)
                ? theme.superKeyStyle : "text";
        root.cursorTheme = root.normalizedCursorTheme(theme.cursorTheme);
        root.cursorSize = root.normalizedBoundedInt(theme.cursorSize, 24, 12, 128);
        root.cursorHideWhenTyping = typeof theme.cursorHideWhenTyping === "boolean"
                ? theme.cursorHideWhenTyping : false;
        root.cursorHideAfterInactiveMs = root.normalizedBoundedInt(theme.cursorHideAfterInactiveMs, 0, 0,
                                                                   5000);
        root.iconTheme = theme.iconTheme || "";
        Fonts.setConfiguredFamilies(fonts.ui, fonts.mono, fonts.numeric, fonts.expressive);
        root.shellBackgroundOpacity = normalizedBoundedReal(effects.shellBackgroundOpacity, 1, 0, 1);
        root.shellBlurEnabled = typeof effects.shellBlurEnabled === "boolean" ? effects.shellBlurEnabled :
                                                                                false;
        root.shellBlurXray = typeof effects.shellBlurXray === "boolean" ? effects.shellBlurXray : true;
        root.keystoneStyle = normalizedOption(root.keystoneStyles, keystone.style, "bangs");
        root.keystonePosition = normalizedEdgePosition(keystone.position);
        root.keystoneHideDate = typeof keystone.hideDate === "boolean" ? keystone.hideDate : false;
        root.keystoneHoverAction = normalizedOption(root.keystoneHoverActionOptions, keystone.hoverAction,
                                                    "peak");
        root.keystoneLeftClickAction = normalizedOption(root.keystoneActionOptions, keystone.leftClickAction,
                                                        "media");
        root.keystoneMiddleClickAction = normalizedOption(root.keystoneActionOptions,
                                                          keystone.middleClickAction, "lyrics");
        root.keystoneKeyholeCards = root.normalizedKeystoneKeyholeCards(keyhole.cards);
        root.horizontalClockFontSize = root.normalizedBoundedInt(horizontalClock.fontSize, 22, 16, 28);
        root.horizontalClockAxes = root.normalizedHorizontalClockAxes(horizontalClock.axes);
        root.horizontalClockDigits = root.normalizedHorizontalClockDigits(horizontalClock.digits);
        root.barPosition = normalizedEdgePosition(bar.position);
        const hasBarLayout = Array.isArray(bar.barLeadingComponents) || Array.isArray(
                  bar.barTrailingComponents);
        const barLayout = root.normalizedBarLayout(bar.barLeadingComponents, bar.barTrailingComponents,
                                                   !hasBarLayout);
        root.barLeadingComponents = barLayout.leading;
        root.barTrailingComponents = barLayout.trailing;
        root.quickSettingsComponents = root.normalizedQuickSettingsComponents(bar.quickSettingsComponents);
        root.keepSidebarsLoaded = sidebar.keepLoaded === undefined ? true : !!sidebar.keepLoaded;
        root.desktopCardGridSnapEnabled = desktopCards.gridSnapEnabled === undefined ? true : !
                                                                                       !desktopCards.gridSnapEnabled;
        root.desktopCardGridVisibleWhileDragging = desktopCards.gridVisibleWhileDragging === undefined ? true :
                                                                                                         !!desktopCards.gridVisibleWhileDragging;
    }

    function needsScrollingMigration(parsed) {
        return !!(parsed && parsed.interactions !== undefined);
    }

    function needsWallpaperMigration(parsed) {
        const wallpaper = parsed && parsed.wallpaper;
        if (!wallpaper || typeof wallpaper !== "object")
            return true;

        return wallpaper.desktopBackend === undefined || wallpaper.awww === undefined || wallpaper.overview
                === undefined || wallpaper.parallax === undefined;
    }

    function needsEffectsMigration(parsed) {
        const effects = parsed && parsed.effects;
        if (!effects || typeof effects !== "object" || Array.isArray(effects))
            return true;

        return effects.shellBackgroundOpacity === undefined || effects.shellBlurEnabled === undefined
                || effects.shellBlurXray === undefined;
    }

    function needsThemeMigration(parsed) {
        const theme = parsed && parsed.theme;
        return !theme || typeof theme !== "object" || Array.isArray(theme) || theme.matugenTemplates
                === undefined || theme.fonts === undefined;
    }

    function needsEdgePositionMigration(parsed) {
        const bar = parsed && parsed.bar;
        const keystone = parsed && parsed.keystone;
        return !bar || typeof bar !== "object" || Array.isArray(bar) || bar.position
                !== root.normalizedEdgePosition(bar.position) || !keystone || typeof keystone !== "object"
                || Array.isArray(keystone) || keystone.position !== root.normalizedEdgePosition(
                    keystone.position);
    }

    function commitPalette(scope, source) {
        if (!scope || ["desktop", "overview"].indexOf(scope.target) < 0 || ["path", "pathLight",
                                                                            "pathDark"].indexOf(scope.field)
                < 0 || (scope.target === "desktop" && root.desktopWallpaperBackend === "awww") || !root.storeReady
                || root.loading || !WallpaperSource.decode(source))
            return false;
        const candidate = JSON.parse(JSON.stringify(root.toJson()));
        const section = scope.target === "overview" ? candidate.wallpaper.overview : candidate.wallpaper;
        if (scope.monitor)
            section.monitorWallpapers[scope.monitor] = source;
        else
            section[scope.field] = source;
        const seed = WallpaperSource.primary(source);
        candidate.wallpaper.recentColors = root.normalizedRecentColors([seed].concat(
                                                                           root.recentWallpaperColors));
        // FileView suppresses identical setText() calls even after failure.
        // A fresh writer makes the same draft retryable without reloading or
        // mutating the formal configuration on a failed Save.
        const writer = paletteWriterComponent.createObject(root, {
                                                               path: root.filePath
                                                           });
        if (!writer)
            return false;
        writer.setText(JSON.stringify(candidate, null, 2));
        writer.waitForJob();
        const saved = writer.succeeded;
        writer.destroy();
        if (!saved)
            return false;
        // Publish only after the atomic write succeeded. No normal setters,
        // extra writes, or theme generation are involved in this operation.
        if (scope.monitor) {
            const propertyName = scope.target === "overview" ? "overviewMonitorWallpapers" :
                                                               "monitorWallpapers";
            const next = root.cloneMap(root[propertyName]);
            next[scope.monitor] = source;
            root[propertyName] = next;
        } else {
            const propertyName = scope.target === "overview" ? "overviewWallpaperPath" : scope.field
                                                               === "pathLight" ? "wallpaperPathLight" :
                                                                                 scope.field === "pathDark"
                                                                                 ? "wallpaperPathDark" :
                                                                                   "wallpaperPath";
            root[propertyName] = source;
        }
        root.recentWallpaperColors = candidate.wallpaper.recentColors;
        return true;
    }

    Component {
        id: paletteWriterComponent
        FileView {
            property bool succeeded: false
            blockWrites: true
            atomicWrites: true
            onSaved: succeeded = true
        }
    }

    function save() {
        if (!root.storeReady || root.loading)
            return;

        configFile.setText(JSON.stringify(root.toJson(), null, 2));
    }

    Process {
        id: ensureStoreDir

        command: ["mkdir", "-p", root.configDir]
        running: true
        onExited: {
            root.storeReady = true;
            configFile.reload();
        }
    }

    Timer {
        id: configReloadDebounce

        interval: 50
        repeat: false
        onTriggered: configFile.reload()
    }

    FileView {
        id: configFile

        path: root.filePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        onFileChanged: configReloadDebounce.restart()
        onLoaded: {
            let shouldRepair = false;
            let parsed = {};
            root.loading = true;
            try {
                parsed = JSON.parse(configFile.text().trim() || "{}");
                shouldRepair = root.needsWallpaperMigration(parsed) || root.needsEffectsMigration(parsed)
                        || root.needsThemeMigration(parsed) || root.needsEdgePositionMigration(parsed)
                        || root.needsScrollingMigration(parsed);
                root.loadFromObject(parsed);
                shouldRepair = shouldRepair || JSON.stringify(parsed.wallpaper || {}) !== JSON.stringify(
                            root.toJson().wallpaper) || JSON.stringify(parsed.effects || {})
                        !== JSON.stringify(root.toJson().effects) || JSON.stringify(parsed.theme || {})
                        !== JSON.stringify(root.toJson().theme) || JSON.stringify(parsed.bar || {}) !== JSON.stringify(
                            root.toJson().bar) || JSON.stringify(parsed.keystone || {}) !== JSON.stringify(
                            root.toJson().keystone) || JSON.stringify(parsed.desktopCards || {})
                        !== JSON.stringify(root.toJson().desktopCards);
            } catch (error) {
                console.warn("PersonalizationConfig failed to load:", error);
                shouldRepair = true;
            }
            root.loading = false;
            root.loaded = true;
            root.settingsLoaded();
            if (shouldRepair)
                root.save();
        }
        onLoadFailed: {
            root.loading = true;
            root.loadFromObject({});
            root.loading = false;
            root.loaded = true;
            root.settingsLoaded();
            root.save();
        }
    }
}
