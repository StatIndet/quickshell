import QtQuick
import QtTest
import "../../Common/functions/BacklightMapping.js" as BacklightMapping

TestCase {
    name: "BacklightMapping"

    function test_prefersConnectorAttachedBacklight() {
        const backlights = [
            {
                name: "discrete_backlight",
                devicePath: "/devices/pci/discrete"
            },
            {
                name: "panel_backlight",
                devicePath: "/devices/pci/integrated/drm/card7/card7-eDP-9"
            }
        ];
        const connectors = [
            {
                name: "eDP-9",
                path: "/devices/pci/integrated/drm/card7/card7-eDP-9",
                gpuPath: "/devices/pci/integrated"
            }
        ];

        compare(
            BacklightMapping.deviceForConnector("card7-eDP-9", backlights, connectors),
            "panel_backlight"
        );
    }

    function test_usesUniqueBacklightOnConnectorGpu() {
        const backlights = [
            {
                name: "gpu_backlight",
                devicePath: "/devices/pci/integrated"
            },
            {
                name: "other_gpu_backlight",
                devicePath: "/devices/pci/discrete"
            }
        ];
        const connectors = [
            {
                name: "eDP-1",
                path: "/devices/pci/integrated/drm/card1/card1-eDP-1",
                gpuPath: "/devices/pci/integrated"
            }
        ];

        compare(
            BacklightMapping.deviceForConnector("eDP-1", backlights, connectors),
            "gpu_backlight"
        );
    }

    function test_usesOnlyBacklightWhenConnectorMetadataIsUnavailable() {
        compare(
            BacklightMapping.deviceForConnector(
                "Virtual-1",
                [{ name: "only_backlight", devicePath: "/devices/only" }],
                []
            ),
            "only_backlight"
        );
    }

    function test_rejectsAmbiguousBacklights() {
        const backlights = [
            { name: "first", devicePath: "/devices/gpu" },
            { name: "second", devicePath: "/devices/gpu" }
        ];
        const connectors = [
            {
                name: "eDP-1",
                path: "/devices/gpu/drm/card0/card0-eDP-1",
                gpuPath: "/devices/gpu"
            }
        ];

        compare(
            BacklightMapping.deviceForConnector("eDP-1", backlights, connectors),
            ""
        );
    }
}
