import QtQuick
import QtTest
import "../../Common/SidebarPolicy.js" as SidebarPolicy

TestCase {
    name: "SidebarPolicy"

    function test_restorePositions() {
        compare(SidebarPolicy.restoredPositions(null), {
                    dashboard: "left",
                    quickSettings: "right"
                });
        compare(SidebarPolicy.restoredPositions({
                                                    keepLoaded: false
                                                }), {
                    dashboard: "left",
                    quickSettings: "right"
                });
        compare(SidebarPolicy.restoredPositions({
                                                    dashboardSide: "invalid",
                                                    quickSettingsSide: "left"
                                                }), {
                    dashboard: "left",
                    quickSettings: "left"
                });
        ["left", "right"].forEach(function (dashboard) {
            ["left", "right"].forEach(function (quickSettings) {
                compare(SidebarPolicy.restoredPositions({
                                                            dashboardSide: dashboard,
                                                            quickSettingsSide: quickSettings
                                                        }), {
                            dashboard: dashboard,
                            quickSettings: quickSettings
                        });
            });
        });
    }

    function test_sameEdgeLastRequestWins() {
        ["left", "right"].forEach(function (side) {
            compare(SidebarPolicy.resolveOpenState(true, true, "dashboard", side, side), {
                        dashboard: true,
                        quickSettings: false
                    });
            compare(SidebarPolicy.resolveOpenState(true, true, "quicksettings", side, side), {
                        dashboard: false,
                        quickSettings: true
                    });
            compare(SidebarPolicy.resolveOpenState(false, false, "quicksettings", side, side), {
                        dashboard: false,
                        quickSettings: false
                    });
            compare(SidebarPolicy.resolveOpenState(true, false, "quicksettings", side, side), {
                        dashboard: true,
                        quickSettings: false
                    });
        });
        compare(SidebarPolicy.resolveOpenState(true, true, "dashboard", "left", "right"), {
                    dashboard: true,
                    quickSettings: true
                });
        compare(SidebarPolicy.resolveOpenState(true, true, "quicksettings", "right", "left"), {
                    dashboard: true,
                    quickSettings: true
                });
    }

    function test_targetAliases() {
        compare(SidebarPolicy.normalizeTarget("dashboard"), "dashboard");
        compare(SidebarPolicy.normalizeTarget(" QuickSettings "), "quicksettings");
        compare(SidebarPolicy.normalizeTarget("left"), "dashboard");
        compare(SidebarPolicy.normalizeTarget("right"), "quicksettings");
        compare(SidebarPolicy.normalizeTarget("unknown"), "");
        compare(SidebarPolicy.normalizeTarget(null), "");
    }

    function test_parallaxFollowsPhysicalEdge() {
        verify(SidebarPolicy.edgeOpen("left", false, true, "right", "left"));
        verify(!SidebarPolicy.edgeOpen("right", false, true, "right", "left"));
        verify(SidebarPolicy.edgeOpen("right", true, false, "right", "left"));
        verify(!SidebarPolicy.edgeOpen("left", true, false, "right", "left"));
        verify(!SidebarPolicy.edgeOpen("left", false, false, "left", "right"));
    }
}
