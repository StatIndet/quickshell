#include "niri_plugin.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QSet>
#include <QTimer>
#include <algorithm>

NiriPlugin::NiriPlugin(QObject *parent)
    : QObject(parent)
{
    connect(&m_client, &NiriIpcClient::connectedChanged, this, &NiriPlugin::connectedChanged);
    connect(&m_client, &NiriIpcClient::eventReceived, this, &NiriPlugin::handleEvent);
    connect(&m_client, &NiriIpcClient::errorOccurred, this, &NiriPlugin::setError);
    QTimer::singleShot(0, this, &NiriPlugin::connectToNiri);
}

NiriPlugin::~NiriPlugin()
{
    QObject::disconnect(&m_client, nullptr, this, nullptr);
    m_client.disconnectFromNiri();
}

bool NiriPlugin::connected() const { return m_client.isConnected(); }
QString NiriPlugin::socketPath() const { return m_client.socketPath(); }
QString NiriPlugin::lastError() const { return m_lastError; }
NiriWorkspaceModel *NiriPlugin::workspaces() { return &m_workspaceModel; }
NiriWindowModel *NiriPlugin::windows() { return &m_windowModel; }
NiriOutputModel *NiriPlugin::outputs() { return &m_outputModel; }
QVariantMap NiriPlugin::focusedWindow() const { return m_focusedWindow; }
QVariantMap NiriPlugin::focusedWorkspace() const { return m_focusedWorkspace; }
QString NiriPlugin::currentOutput() const { return m_currentOutput; }
bool NiriPlugin::inOverview() const { return m_inOverview; }
QStringList NiriPlugin::keyboardLayoutNames() const { return m_keyboardLayoutNames; }
QVariantList NiriPlugin::casts() const { return NiriCastParser::toVariantList(m_casts); }
bool NiriPlugin::anyCastPresent() const { return !m_casts.isEmpty(); }
bool NiriPlugin::anyCastActive() const { return activeCastCount() > 0; }
int NiriPlugin::activeCastCount() const { return NiriCastParser::activeCount(m_casts); }

QString NiriPlugin::currentKeyboardLayoutName() const
{
    if (m_currentKeyboardLayoutIndex < 0 || m_currentKeyboardLayoutIndex >= m_keyboardLayoutNames.size())
        return {};
    return m_keyboardLayoutNames.at(m_currentKeyboardLayoutIndex);
}

bool NiriPlugin::connectToNiri()
{
    const bool ok = m_client.connectToNiri();
    if (ok)
        loadInitialState();
    return ok;
}

QVariantList NiriPlugin::workspacesForOutput(const QString &outputName) const
{
    return m_workspaceModel.workspacesForOutput(outputName);
}

QVariantList NiriPlugin::windowsForWorkspace(quint64 workspaceId) const
{
    return m_windowModel.windowsForWorkspace(workspaceId);
}

QVariantList NiriPlugin::windowsForOutput(const QString &outputName) const
{
    QVariantList result;
    QSet<quint64> workspaceIds;
    for (const NiriWorkspace &workspace : m_workspaces) {
        if (workspace.output == outputName)
            workspaceIds.insert(workspace.id);
    }
    for (const NiriWindow &window : m_windows) {
        if (workspaceIds.contains(window.workspaceId))
            result.append(windowToMap(window));
    }
    return result;
}

QVariantMap NiriPlugin::activeWorkspaceForOutput(const QString &outputName) const
{
    for (const NiriWorkspace &workspace : m_workspaces) {
        if (workspace.output == outputName && workspace.isActive)
            return workspaceToMap(workspace);
    }
    return {};
}

QVariantMap NiriPlugin::workspaceById(quint64 id) const
{
    return m_workspaceModel.workspaceById(id);
}

QVariantMap NiriPlugin::windowById(quint64 id) const
{
    return m_windowModel.windowById(id);
}

QVariantList NiriPlugin::workspaceIcons(quint64 workspaceId, bool groupApps) const
{
    Q_UNUSED(groupApps)
    for (const NiriWorkspace &workspace : m_workspaces) {
        if (workspace.id == workspaceId)
            return workspace.icons;
    }
    return {};
}

QVariantList NiriPlugin::searchWindows(const QString &query) const
{
    const QString needle = query.trimmed().toLower();
    QVariantList result;
    for (const NiriWindow &window : m_windows) {
        if (needle.isEmpty() ||
            window.title.toLower().contains(needle) ||
            window.appId.toLower().contains(needle) ||
            window.appName.toLower().contains(needle)) {
            result.append(windowToMap(window));
        }
    }
    return result;
}

bool NiriPlugin::focusWorkspaceByIndex(int index)
{
    return sendAction({{QStringLiteral("FocusWorkspace"), QJsonObject{{QStringLiteral("reference"), QJsonObject{{QStringLiteral("Index"), index}}}}}});
}

bool NiriPlugin::focusWorkspaceById(quint64 id)
{
    return sendAction({{QStringLiteral("FocusWorkspace"), QJsonObject{{QStringLiteral("reference"), QJsonObject{{QStringLiteral("Id"), QJsonValue::fromVariant(id)}}}}}});
}

bool NiriPlugin::focusWorkspaceByName(const QString &name)
{
    return sendAction({{QStringLiteral("FocusWorkspace"), QJsonObject{{QStringLiteral("reference"), QJsonObject{{QStringLiteral("Name"), name}}}}}});
}

bool NiriPlugin::focusWindow(quint64 id)
{
    return sendAction({{QStringLiteral("FocusWindow"), QJsonObject{{QStringLiteral("id"), QJsonValue::fromVariant(id)}}}});
}

bool NiriPlugin::closeWindow(quint64 id)
{
    return sendAction({{QStringLiteral("CloseWindow"), QJsonObject{{QStringLiteral("id"), QJsonValue::fromVariant(id)}}}});
}

bool NiriPlugin::closeFocusedWindow()
{
    return sendAction({{QStringLiteral("CloseWindow"), QJsonObject{{QStringLiteral("id"), QJsonValue()}}}});
}

bool NiriPlugin::toggleOverview()
{
    return sendAction({{QStringLiteral("ToggleOverview"), QJsonObject{}}});
}

bool NiriPlugin::focusColumnLeft()
{
    return sendAction({{QStringLiteral("FocusColumnLeft"), QJsonObject{}}});
}

bool NiriPlugin::focusColumnRight()
{
    return sendAction({{QStringLiteral("FocusColumnRight"), QJsonObject{}}});
}

bool NiriPlugin::focusWorkspaceUp()
{
    return sendAction({{QStringLiteral("FocusWorkspaceUp"), QJsonObject{}}});
}

bool NiriPlugin::focusWorkspaceDown()
{
    return sendAction({{QStringLiteral("FocusWorkspaceDown"), QJsonObject{}}});
}

bool NiriPlugin::moveWorkspaceToIndex(int workspaceIndex, int targetIndex)
{
    return sendAction({{QStringLiteral("MoveWorkspaceToIndex"), QJsonObject{
        {QStringLiteral("index"), targetIndex},
        {QStringLiteral("reference"), QJsonObject{{QStringLiteral("Index"), workspaceIndex}}},
    }}});
}

bool NiriPlugin::setWorkspaceName(const QString &name)
{
    return sendAction({{QStringLiteral("SetWorkspaceName"), QJsonObject{{QStringLiteral("name"), name}, {QStringLiteral("workspace"), QJsonValue()}}}});
}

bool NiriPlugin::unsetWorkspaceName()
{
    return sendAction({{QStringLiteral("UnsetWorkspaceName"), QJsonObject{{QStringLiteral("workspace"), QJsonValue()}}}});
}

bool NiriPlugin::powerOffMonitors()
{
    return sendAction({{QStringLiteral("PowerOffMonitors"), QJsonObject{}}});
}

bool NiriPlugin::powerOnMonitors()
{
    return sendAction({{QStringLiteral("PowerOnMonitors"), QJsonObject{}}});
}

bool NiriPlugin::cycleKeyboardLayout()
{
    return sendAction({{QStringLiteral("SwitchLayout"), QJsonObject{{QStringLiteral("layout"), QStringLiteral("Next")}}}});
}

bool NiriPlugin::doScreenTransition(int delayMs)
{
    return sendAction({{QStringLiteral("DoScreenTransition"), QJsonObject{{QStringLiteral("delay_ms"), delayMs}}}});
}

void NiriPlugin::handleEvent(const QJsonObject &event)
{
    const QString type = event.keys().value(0);
    bool workspaceChanged = false;
    bool windowChanged = false;
    bool outputChanged = false;
    bool castChanged = false;

    if (type == QStringLiteral("WorkspacesChanged")) {
        const QJsonArray items = event.value(type).toObject().value(QStringLiteral("workspaces")).toArray();
        QHash<quint64, quint64> activeWindows;
        for (const NiriWorkspace &workspace : m_workspaces)
            activeWindows.insert(workspace.id, workspace.activeWindowId);
        m_workspaces.clear();
        for (const QJsonValue &value : items) {
            NiriWorkspace workspace = parseWorkspace(value.toObject());
            if (activeWindows.contains(workspace.id) && workspace.activeWindowId == 0)
                workspace.activeWindowId = activeWindows.value(workspace.id);
            m_workspaces.append(workspace);
        }
        workspaceChanged = true;
    } else if (type == QStringLiteral("WorkspaceActivated")) {
        const QJsonObject data = event.value(type).toObject();
        const quint64 id = data.value(QStringLiteral("id")).toInteger();
        const bool focused = data.value(QStringLiteral("focused")).toBool();
        QString output;
        for (const NiriWorkspace &workspace : m_workspaces) {
            if (workspace.id == id) {
                output = workspace.output;
                break;
            }
        }
        for (NiriWorkspace &workspace : m_workspaces) {
            if (!output.isEmpty() && workspace.output == output)
                workspace.isActive = workspace.id == id;
            if (focused)
                workspace.isFocused = workspace.id == id;
        }
        workspaceChanged = true;
    } else if (type == QStringLiteral("WorkspaceActiveWindowChanged")) {
        const QJsonObject data = event.value(type).toObject();
        const quint64 workspaceId = data.value(QStringLiteral("workspace_id")).toInteger();
        const QJsonValue activeWindowId = data.value(QStringLiteral("active_window_id"));
        const quint64 activeId =
            activeWindowId.isNull() ? 0 : activeWindowId.toInteger();
        for (NiriWorkspace &workspace : m_workspaces) {
            if (workspace.id == workspaceId)
                workspace.activeWindowId = activeId;
        }
        for (NiriWindow &window : m_windows) {
            if (window.workspaceId == workspaceId)
                window.isFocused = activeId != 0 && window.id == activeId;
        }
        workspaceChanged = true;
        windowChanged = true;
    } else if (type == QStringLiteral("WorkspaceUrgencyChanged")) {
        const QJsonObject data = event.value(type).toObject();
        const quint64 id = data.value(QStringLiteral("id")).toInteger();
        for (NiriWorkspace &workspace : m_workspaces) {
            if (workspace.id == id)
                workspace.isUrgent = data.value(QStringLiteral("urgent")).toBool();
        }
        workspaceChanged = true;
    } else if (type == QStringLiteral("WindowsChanged")) {
        const QJsonArray items = event.value(type).toObject().value(QStringLiteral("windows")).toArray();
        m_windows.clear();
        for (const QJsonValue &value : items)
            m_windows.append(parseWindow(value.toObject()));
        windowChanged = true;
    } else if (type == QStringLiteral("WindowOpenedOrChanged")) {
        const NiriWindow window = parseWindow(event.value(type).toObject().value(QStringLiteral("window")).toObject());
        auto it = std::find_if(m_windows.begin(), m_windows.end(), [window](const NiriWindow &candidate) {
            return candidate.id == window.id;
        });
        if (it == m_windows.end())
            m_windows.append(window);
        else
            *it = window;
        windowChanged = true;
    } else if (type == QStringLiteral("WindowClosed")) {
        const quint64 id = event.value(type).toObject().value(QStringLiteral("id")).toInteger();
        m_windows.erase(std::remove_if(m_windows.begin(), m_windows.end(), [id](const NiriWindow &window) {
            return window.id == id;
        }), m_windows.end());
        windowChanged = true;
    } else if (type == QStringLiteral("WindowFocusChanged")) {
        const QJsonValue value = event.value(type).toObject().value(QStringLiteral("id"));
        const quint64 id = value.isNull() ? 0 : value.toInteger();
        quint64 focusedWorkspaceId = 0;
        for (NiriWindow &window : m_windows) {
            window.isFocused = window.id == id;
            if (window.isFocused)
                focusedWorkspaceId = window.workspaceId;
        }
        if (focusedWorkspaceId != 0) {
            for (NiriWorkspace &workspace : m_workspaces) {
                if (workspace.id == focusedWorkspaceId)
                    workspace.activeWindowId = id;
            }
        }
        windowChanged = true;
        workspaceChanged = focusedWorkspaceId != 0;
    } else if (type == QStringLiteral("WindowUrgencyChanged")) {
        const QJsonObject data = event.value(type).toObject();
        const quint64 id = data.value(QStringLiteral("id")).toInteger();
        for (NiriWindow &window : m_windows) {
            if (window.id == id)
                window.isUrgent = data.value(QStringLiteral("urgent")).toBool();
        }
        windowChanged = true;
    } else if (type == QStringLiteral("WindowLayoutsChanged")) {
        const QJsonArray changes = event.value(type).toObject().value(QStringLiteral("changes")).toArray();
        for (const QJsonValue &changeValue : changes) {
            const QJsonArray change = changeValue.toArray();
            if (change.size() < 2)
                continue;
            const quint64 id = change.at(0).toInteger();
            const QJsonArray pos = change.at(1).toObject().value(QStringLiteral("pos_in_scrolling_layout")).toArray();
            for (NiriWindow &window : m_windows) {
                if (window.id == id) {
                    window.layoutColumn = pos.size() > 0 ? pos.at(0).toInt(999999) : 999999;
                    window.layoutRow = pos.size() > 1 ? pos.at(1).toInt(999999) : 999999;
                }
            }
        }
        windowChanged = true;
    } else if (type == QStringLiteral("OutputsChanged")) {
        const QJsonObject outputs = event.value(type).toObject().value(QStringLiteral("outputs")).toObject();
        m_outputs.clear();
        for (auto it = outputs.begin(); it != outputs.end(); ++it)
            m_outputs.append(parseOutput(it.key(), it.value().toObject()));
        outputChanged = true;
        windowChanged = true;
    } else if (type == QStringLiteral("OverviewOpenedOrClosed")) {
        m_inOverview = event.value(type).toObject().value(QStringLiteral("is_open")).toBool();
        emit overviewChanged();
    } else if (type == QStringLiteral("KeyboardLayoutsChanged")) {
        const QJsonObject layouts = event.value(type).toObject().value(QStringLiteral("keyboard_layouts")).toObject();
        m_keyboardLayoutNames.clear();
        for (const QJsonValue &name : layouts.value(QStringLiteral("names")).toArray())
            m_keyboardLayoutNames.append(name.toString());
        m_currentKeyboardLayoutIndex = layouts.value(QStringLiteral("current_idx")).toInt(-1);
        emit keyboardLayoutChanged();
    } else if (type == QStringLiteral("KeyboardLayoutSwitched")) {
        m_currentKeyboardLayoutIndex = event.value(type).toObject().value(QStringLiteral("idx")).toInt(-1);
        emit keyboardLayoutChanged();
    } else if (type == QStringLiteral("CastsChanged")) {
        const QJsonArray items =
            event.value(type).toObject().value(QStringLiteral("casts")).toArray();
        m_casts = NiriCastParser::parseArray(items);
        castChanged = true;
    } else if (type == QStringLiteral("CastStartedOrChanged")) {
        const NiriCast cast = NiriCastParser::parse(
            event.value(type).toObject().value(QStringLiteral("cast")).toObject());
        auto it = std::find_if(m_casts.begin(), m_casts.end(), [cast](const NiriCast &candidate) {
            return candidate.streamId == cast.streamId;
        });
        if (it == m_casts.end())
            m_casts.append(cast);
        else
            *it = cast;
        castChanged = true;
    } else if (type == QStringLiteral("CastStopped")) {
        const quint64 streamId =
            event.value(type).toObject().value(QStringLiteral("stream_id")).toInteger();
        m_casts.erase(std::remove_if(m_casts.begin(), m_casts.end(),
                                    [streamId](const NiriCast &cast) {
                                        return cast.streamId == streamId;
                                    }),
                      m_casts.end());
        castChanged = true;
    } else if (type == QStringLiteral("ConfigLoaded")) {
        fetchOutputs();
    }

    publishState(workspaceChanged, windowChanged, outputChanged);
    if (castChanged)
        emit castsChanged();
}

NiriWorkspace NiriPlugin::parseWorkspace(const QJsonObject &object) const
{
    NiriWorkspace workspace;
    workspace.id = object.value(QStringLiteral("id")).toInteger();
    workspace.index = object.value(QStringLiteral("idx")).toInt();
    workspace.name = object.value(QStringLiteral("name")).toString();
    workspace.output = object.value(QStringLiteral("output")).toString();
    workspace.isActive = object.value(QStringLiteral("is_active")).toBool();
    workspace.isFocused = object.value(QStringLiteral("is_focused")).toBool();
    workspace.isUrgent = object.value(QStringLiteral("is_urgent")).toBool();
    const QJsonValue activeWindowId = object.value(QStringLiteral("active_window_id"));
    workspace.activeWindowId = activeWindowId.isNull() ? 0 : activeWindowId.toInteger();
    return workspace;
}

NiriWindow NiriPlugin::parseWindow(const QJsonObject &object)
{
    NiriWindow window;
    window.id = object.value(QStringLiteral("id")).toInteger();
    window.title = object.value(QStringLiteral("title")).toString(QStringLiteral("Unknown"));
    window.appId = object.value(QStringLiteral("app_id")).toString(QStringLiteral("unknown"));
    window.pid = object.value(QStringLiteral("pid")).isNull() ? -1 : object.value(QStringLiteral("pid")).toInteger(-1);
    window.workspaceId = object.value(QStringLiteral("workspace_id")).isNull() ? 0 : object.value(QStringLiteral("workspace_id")).toInteger();
    window.isFocused = object.value(QStringLiteral("is_focused")).toBool();
    window.isFloating = object.value(QStringLiteral("is_floating")).toBool();
    window.isUrgent = object.value(QStringLiteral("is_urgent")).toBool();

    const QJsonArray pos = object.value(QStringLiteral("layout")).toObject().value(QStringLiteral("pos_in_scrolling_layout")).toArray();
    window.layoutColumn = pos.size() > 0 ? pos.at(0).toInt(999999) : 999999;
    window.layoutRow = pos.size() > 1 ? pos.at(1).toInt(999999) : 999999;

    const NiriIconLookup::IconInfo icon = m_iconLookup.resolve(window.appId);
    window.iconPath = icon.iconPath;
    window.appName = icon.appName;
    return window;
}

NiriOutput NiriPlugin::parseOutput(const QString &name, const QJsonObject &object) const
{
    NiriOutput output;
    output.name = name;
    output.make = object.value(QStringLiteral("make")).toString();
    output.model = object.value(QStringLiteral("model")).toString();
    output.serial = object.value(QStringLiteral("serial")).toString();
    output.vrrEnabled = object.value(QStringLiteral("vrr_enabled")).toBool();
    const QJsonObject logical = object.value(QStringLiteral("logical")).toObject();
    output.logicalX = logical.value(QStringLiteral("x")).toInt(999999);
    output.logicalY = logical.value(QStringLiteral("y")).toInt(999999);
    output.logicalWidth = logical.value(QStringLiteral("width")).toInt();
    output.logicalHeight = logical.value(QStringLiteral("height")).toInt();
    output.scale = logical.value(QStringLiteral("scale")).toDouble(1.0);
    output.transform = logical.value(QStringLiteral("transform")).toString();
    const int currentMode = object.value(QStringLiteral("current_mode")).toInt(-1);
    const QJsonArray modes = object.value(QStringLiteral("modes")).toArray();
    if (currentMode >= 0 && currentMode < modes.size()) {
        const QJsonObject mode = modes.at(currentMode).toObject();
        output.currentMode = QStringLiteral("%1x%2@%3")
            .arg(mode.value(QStringLiteral("width")).toInt())
            .arg(mode.value(QStringLiteral("height")).toInt())
            .arg(mode.value(QStringLiteral("refresh_rate")).toDouble());
    }
    return output;
}

void NiriPlugin::loadInitialState()
{
    bool ok = false;
    const QJsonValue workspaces = m_client.sendRequest(QStringLiteral("Workspaces"), &ok);
    if (ok && workspaces.isArray()) {
        m_workspaces.clear();
        for (const QJsonValue &value : workspaces.toArray())
            m_workspaces.append(parseWorkspace(value.toObject()));
    }

    const QJsonValue windows = m_client.sendRequest(QStringLiteral("Windows"), &ok);
    if (ok && windows.isArray()) {
        m_windows.clear();
        for (const QJsonValue &value : windows.toArray())
            m_windows.append(parseWindow(value.toObject()));
    }

    const QJsonValue casts = m_client.sendRequest(QStringLiteral("Casts"), &ok);
    if (ok && casts.isArray()) {
        m_casts = NiriCastParser::parseArray(casts.toArray());
        emit castsChanged();
    }

    fetchOutputs();
    publishState(true, true, true);
}

void NiriPlugin::fetchOutputs()
{
    bool ok = false;
    const QJsonValue outputs = m_client.sendRequest(QStringLiteral("Outputs"), &ok);
    if (!ok || !outputs.isObject())
        return;

    m_outputs.clear();
    const QJsonObject object = outputs.toObject();
    for (auto it = object.begin(); it != object.end(); ++it)
        m_outputs.append(parseOutput(it.key(), it.value().toObject()));
    publishState(false, true, true);
}

void NiriPlugin::setError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit errorChanged();
}

void NiriPlugin::publishState(bool workspaceChanged, bool windowChanged, bool outputChanged)
{
    if (!workspaceChanged && !windowChanged && !outputChanged)
        return;

    sortWorkspaces();
    sortWindows();
    recomputeDerivedState();

    if (workspaceChanged || windowChanged) {
        m_workspaceModel.setWorkspaces(m_workspaces);
        emit workspacesChanged();
    }
    if (windowChanged || outputChanged) {
        m_windowModel.setWindows(m_windows);
        emit windowsChanged();
    }
    if (outputChanged) {
        m_outputModel.setOutputs(m_outputs);
        emit outputsChanged();
    }
    emit focusedWindowChanged();
    emit focusedWorkspaceChanged();
}

void NiriPlugin::recomputeDerivedState()
{
    QHash<quint64, int> windowCounts;
    QHash<quint64, QVariantList> iconsByWorkspace;
    QHash<quint64, QHash<QString, int>> countsByApp;
    QHash<quint64, QHash<QString, NiriWindow>> representativeByApp;

    for (const NiriWindow &window : m_windows) {
        windowCounts[window.workspaceId]++;
        const QString key = window.appId.isEmpty() ? QStringLiteral("unknown") : window.appId;
        countsByApp[window.workspaceId][key]++;
        if (!representativeByApp[window.workspaceId].contains(key) || window.isFocused)
            representativeByApp[window.workspaceId][key] = window;
    }

    for (auto wsIt = representativeByApp.begin(); wsIt != representativeByApp.end(); ++wsIt) {
        QVariantList icons;
        for (auto appIt = wsIt.value().begin(); appIt != wsIt.value().end(); ++appIt) {
            const NiriWindow &window = appIt.value();
            icons.append(makeWorkspaceIcon(window, countsByApp.value(wsIt.key()).value(appIt.key()), window.isFocused));
        }
        iconsByWorkspace[wsIt.key()] = icons;
    }

    m_focusedWindow.clear();
    m_focusedWorkspace.clear();
    m_currentOutput.clear();
    for (NiriWorkspace &workspace : m_workspaces) {
        workspace.windowCount = windowCounts.value(workspace.id);
        workspace.icons = iconsByWorkspace.value(workspace.id);
        if (workspace.isFocused) {
            m_focusedWorkspace = workspaceToMap(workspace);
            m_currentOutput = workspace.output;
        }
    }
    for (const NiriWindow &window : m_windows) {
        if (window.isFocused) {
            m_focusedWindow = windowToMap(window);
            break;
        }
    }
}

void NiriPlugin::sortWorkspaces()
{
    std::sort(m_workspaces.begin(), m_workspaces.end(), [](const NiriWorkspace &a, const NiriWorkspace &b) {
        if (a.output != b.output)
            return a.output < b.output;
        return a.index < b.index;
    });
}

void NiriPlugin::sortWindows()
{
    QHash<QString, NiriOutput> outputsByName;
    for (const NiriOutput &output : m_outputs)
        outputsByName.insert(output.name, output);

    QHash<quint64, NiriWorkspace> workspacesById;
    for (const NiriWorkspace &workspace : m_workspaces)
        workspacesById.insert(workspace.id, workspace);

    std::sort(m_windows.begin(), m_windows.end(), [outputsByName, workspacesById](const NiriWindow &a, const NiriWindow &b) {
        const NiriWorkspace aw = workspacesById.value(a.workspaceId);
        const NiriWorkspace bw = workspacesById.value(b.workspaceId);
        const NiriOutput ao = outputsByName.value(aw.output);
        const NiriOutput bo = outputsByName.value(bw.output);
        if (ao.logicalX != bo.logicalX)
            return ao.logicalX < bo.logicalX;
        if (ao.logicalY != bo.logicalY)
            return ao.logicalY < bo.logicalY;
        if (aw.index != bw.index)
            return aw.index < bw.index;
        if (a.layoutColumn != b.layoutColumn)
            return a.layoutColumn < b.layoutColumn;
        if (a.layoutRow != b.layoutRow)
            return a.layoutRow < b.layoutRow;
        return a.id < b.id;
    });
}

bool NiriPlugin::sendAction(const QJsonObject &action)
{
    bool ok = false;
    m_client.sendRequest(QJsonObject{{QStringLiteral("Action"), action}}, &ok);
    return ok;
}

QVariantMap NiriPlugin::windowToMap(const NiriWindow &window) const
{
    return {
        {QStringLiteral("id"), QVariant::fromValue(window.id)},
        {QStringLiteral("title"), window.title},
        {QStringLiteral("appId"), window.appId},
        {QStringLiteral("appName"), window.appName},
        {QStringLiteral("pid"), window.pid},
        {QStringLiteral("workspaceId"), QVariant::fromValue(window.workspaceId)},
        {QStringLiteral("isFocused"), window.isFocused},
        {QStringLiteral("isFloating"), window.isFloating},
        {QStringLiteral("isUrgent"), window.isUrgent},
        {QStringLiteral("layoutColumn"), window.layoutColumn},
        {QStringLiteral("layoutRow"), window.layoutRow},
        {QStringLiteral("iconPath"), window.iconPath},
    };
}

QVariantMap NiriPlugin::workspaceToMap(const NiriWorkspace &workspace) const
{
    return {
        {QStringLiteral("id"), QVariant::fromValue(workspace.id)},
        {QStringLiteral("index"), workspace.index},
        {QStringLiteral("name"), workspace.name},
        {QStringLiteral("output"), workspace.output},
        {QStringLiteral("isActive"), workspace.isActive},
        {QStringLiteral("isFocused"), workspace.isFocused},
        {QStringLiteral("isUrgent"), workspace.isUrgent},
        {QStringLiteral("activeWindowId"), QVariant::fromValue(workspace.activeWindowId)},
        {QStringLiteral("windowCount"), workspace.windowCount},
        {QStringLiteral("icons"), workspace.icons},
    };
}

QVariantMap NiriPlugin::makeWorkspaceIcon(const NiriWindow &window, int count, bool active) const
{
    return {
        {QStringLiteral("appId"), window.appId},
        {QStringLiteral("appName"), window.appName},
        {QStringLiteral("iconPath"), window.iconPath},
        {QStringLiteral("active"), active},
        {QStringLiteral("count"), count},
        {QStringLiteral("windowId"), QVariant::fromValue(window.id)},
    };
}
