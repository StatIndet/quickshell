import QtQuick
import QtTest
import "../../Common/SidebarPolicy.js" as SidebarPolicy

TestCase {
    name: "SidebarPolicy"

    function test_restorePositions() {
        compare(SidebarPolicy.restoredDashboardSide(null), "left");
        compare(SidebarPolicy.restoredDashboardSide({
                                                        keepLoaded: false
                                                    }), "left");
        compare(SidebarPolicy.restoredDashboardSide({
                                                        dashboardSide: "right",
                                                        quickSettingsSide: "left"
                                                    }), "right");
        compare(SidebarPolicy.restoredDashboardSide({
                                                        dashboardSide: "right",
                                                        quickSettingsSide: "right"
                                                    }), "right");
        compare(SidebarPolicy.restoredDashboardSide({
                                                        dashboardSide: "invalid",
                                                        quickSettingsSide: "left"
                                                    }), "right");
        compare(SidebarPolicy.restoredDashboardSide({
                                                        dashboardSide: 123,
                                                        quickSettingsSide: "invalid"
                                                    }), "left");
    }

    function test_swapRoundTrip() {
        ["left", "right"].forEach(function (side) {
            const other = SidebarPolicy.oppositeSide(side);
            verify(other !== side);
            compare(SidebarPolicy.oppositeSide(other), side);
            compare(SidebarPolicy.restoredDashboardSide({
                                                            dashboardSide: side,
                                                            quickSettingsSide: other
                                                        }), side);
            compare(SidebarPolicy.restoredDashboardSide({
                                                            quickSettingsSide: other
                                                        }), side);
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
