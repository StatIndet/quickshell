.pragma library

// This is the single source of truth for every system card. Layout
// algorithms consume the metadata from here; they do not maintain a second
// list of cards of their own.
var cardDefinitions = [
    {
        id: "time",
        nameKey: "时钟",
        name: qsTr("时钟"),
        icon: "schedule",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        excludeHostBlur: true
    },
    {
        id: "battery",
        nameKey: "电池",
        name: qsTr("电池"),
        icon: "battery_full",
        columnSpan: 1,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true
    },
    {
        id: "cpu",
        nameKey: "CPU",
        name: qsTr("CPU"),
        icon: "memory",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["cpu"],
        preserveDefaultSurface: true
    },
    {
        id: "gpu",
        nameKey: "GPU",
        name: qsTr("GPU"),
        icon: "developer_board",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["gpu"],
        preserveDefaultSurface: true
    },
    {
        id: "memoryUsed",
        nameKey: "内存",
        name: qsTr("内存"),
        icon: "memory_alt",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["memory"],
        preserveDefaultSurface: true,
        excludeHostBlur: true
    },
    {
        id: "wifi",
        nameKey: "Wi-Fi",
        name: qsTr("Wi-Fi"),
        icon: "wifi",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: [],
        preserveDefaultSurface: true,
        excludeHostBlur: true
    },
    {
        id: "network",
        nameKey: "网络",
        name: qsTr("网络"),
        icon: "swap_vert",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["network"]
    },
    {
        id: "storage",
        nameKey: "磁盘 I/O",
        name: qsTr("磁盘 I/O"),
        icon: "hard_drive",
        columnSpan: 3,
        rowSpan: 1,
        monitorModules: ["disk"]
    },
    {
        id: "storageCapacity",
        nameKey: "磁盘容量",
        name: qsTr("磁盘容量"),
        icon: "data_usage",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: ["disk"],
        preserveDefaultSurface: true,
        excludeHostBlur: true
    },
    {
        id: "calendar",
        nameKey: "日历",
        name: qsTr("日历"),
        icon: "calendar_month",
        columnSpan: 1,
        rowSpan: 1,
        monitorModules: []
    },
    {
        id: "weather",
        nameKey: "天气",
        name: qsTr("天气"),
        icon: "cloud",
        columnSpan: 2,
        rowSpan: 2,
        monitorModules: [],
        preserveDefaultSurface: true,
        excludeHostBlur: true
    }
];

var defaultAnchors = {
    time: { column: 0, row: 0 },
    battery: { column: 2, row: 0 },
    cpu: { column: 0, row: 2 },
    gpu: { column: 1, row: 2 },
    memoryUsed: { column: 2, row: 2 },
    wifi: { column: 0, row: 5 },
    network: { column: 0, row: 3 },
    storage: { column: 0, row: 4 },
    storageCapacity: { column: 0, row: 7 },
    calendar: { column: 0, row: 6 },
    weather: { column: 1, row: 5 }
};

function cloneDefinition(definition) {
    var result = {};
    for (var key in definition)
        result[key] = definition[key];
    result.monitorModules = (definition.monitorModules || []).slice();
    result.requiresSystemMonitor = result.monitorModules.length > 0;
    return result;
}

function all() {
    return cardDefinitions.map(cloneDefinition);
}

function ids() {
    return cardDefinitions.map(function(definition) {
        return definition.id;
    });
}

function definitionFor(id) {
    for (var index = 0; index < cardDefinitions.length; index += 1) {
        if (cardDefinitions[index].id === id)
            return cardDefinitions[index];
    }
    return null;
}

function nameFor(id) {
    switch (String(id)) {
    case "time":
        return qsTr("时钟");
    case "battery":
        return qsTr("电池");
    case "cpu":
        return qsTr("CPU");
    case "gpu":
        return qsTr("GPU");
    case "memoryUsed":
        return qsTr("内存");
    case "wifi":
        return qsTr("Wi-Fi");
    case "network":
        return qsTr("网络");
    case "storage":
        return qsTr("磁盘 I/O");
    case "storageCapacity":
        return qsTr("磁盘容量");
    case "calendar":
        return qsTr("日历");
    case "weather":
        return qsTr("天气");
    default:
        return String(id);
    }
}

function defaultAnchorFor(id) {
    var anchor = defaultAnchors[id];
    return anchor
        ? { column: anchor.column, row: anchor.row }
        : { column: 0, row: 0 };
}

function sidebarDefinitions(activeIds) {
    var allowed = activeIds || ids();
    return cardDefinitions.filter(function(definition) {
        return allowed.indexOf(definition.id) !== -1;
    }).map(cloneDefinition);
}
