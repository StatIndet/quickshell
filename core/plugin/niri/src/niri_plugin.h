#pragma once

#include "niri_icon_lookup.h"
#include "niri_ipc_client.h"
#include "niri_cast_parser.h"
#include "niri_output_model.h"
#include "niri_window_model.h"
#include "niri_workspace_model.h"

#include <QObject>
#include <QHash>
#include <QJsonObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class NiriPlugin : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Niri)
    QML_SINGLETON

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString socketPath READ socketPath NOTIFY connectedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)
    Q_PROPERTY(NiriWorkspaceModel* workspaces READ workspaces CONSTANT)
    Q_PROPERTY(NiriWindowModel* windows READ windows CONSTANT)
    Q_PROPERTY(NiriOutputModel* outputs READ outputs CONSTANT)
    Q_PROPERTY(QVariantMap focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
    Q_PROPERTY(QVariantMap focusedWorkspace READ focusedWorkspace NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(QString currentOutput READ currentOutput NOTIFY focusedWorkspaceChanged)
    Q_PROPERTY(bool inOverview READ inOverview NOTIFY overviewChanged)
    Q_PROPERTY(QStringList keyboardLayoutNames READ keyboardLayoutNames NOTIFY keyboardLayoutChanged)
    Q_PROPERTY(QString currentKeyboardLayoutName READ currentKeyboardLayoutName NOTIFY keyboardLayoutChanged)
    Q_PROPERTY(QVariantList casts READ casts NOTIFY castsChanged)
    Q_PROPERTY(bool anyCastPresent READ anyCastPresent NOTIFY castsChanged)
    Q_PROPERTY(bool anyCastActive READ anyCastActive NOTIFY castsChanged)
    Q_PROPERTY(int activeCastCount READ activeCastCount NOTIFY castsChanged)

public:
    explicit NiriPlugin(QObject *parent = nullptr);
    ~NiriPlugin() override;

    bool connected() const;
    QString socketPath() const;
    QString lastError() const;
    NiriWorkspaceModel *workspaces();
    NiriWindowModel *windows();
    NiriOutputModel *outputs();
    QVariantMap focusedWindow() const;
    QVariantMap focusedWorkspace() const;
    QString currentOutput() const;
    bool inOverview() const;
    QStringList keyboardLayoutNames() const;
    QString currentKeyboardLayoutName() const;
    QVariantList casts() const;
    bool anyCastPresent() const;
    bool anyCastActive() const;
    int activeCastCount() const;

    Q_INVOKABLE bool connectToNiri();
    Q_INVOKABLE QVariantList workspacesForOutput(const QString &outputName) const;
    Q_INVOKABLE QVariantList windowsForWorkspace(quint64 workspaceId) const;
    Q_INVOKABLE QVariantList windowsForOutput(const QString &outputName) const;
    Q_INVOKABLE QVariantMap activeWorkspaceForOutput(const QString &outputName) const;
    Q_INVOKABLE QVariantMap workspaceById(quint64 id) const;
    Q_INVOKABLE QVariantMap windowById(quint64 id) const;
    Q_INVOKABLE QVariantList workspaceIcons(quint64 workspaceId, bool groupApps = true) const;
    Q_INVOKABLE QVariantList searchWindows(const QString &query) const;

    Q_INVOKABLE bool focusWorkspaceByIndex(int index);
    Q_INVOKABLE bool focusWorkspaceById(quint64 id);
    Q_INVOKABLE bool focusWorkspaceByName(const QString &name);
    Q_INVOKABLE bool focusWindow(quint64 id);
    Q_INVOKABLE bool closeWindow(quint64 id);
    Q_INVOKABLE bool closeFocusedWindow();
    Q_INVOKABLE bool toggleOverview();
    Q_INVOKABLE bool focusColumnLeft();
    Q_INVOKABLE bool focusColumnRight();
    Q_INVOKABLE bool focusWorkspaceUp();
    Q_INVOKABLE bool focusWorkspaceDown();
    Q_INVOKABLE bool moveWorkspaceToIndex(int workspaceIndex, int targetIndex);
    Q_INVOKABLE bool setWorkspaceName(const QString &name);
    Q_INVOKABLE bool unsetWorkspaceName();
    Q_INVOKABLE bool powerOffMonitors();
    Q_INVOKABLE bool powerOnMonitors();
    Q_INVOKABLE bool cycleKeyboardLayout();
    Q_INVOKABLE bool doScreenTransition(int delayMs = 0);

signals:
    void connectedChanged();
    void errorChanged();
    void workspacesChanged();
    void windowsChanged();
    void outputsChanged();
    void focusedWindowChanged();
    void focusedWorkspaceChanged();
    void overviewChanged();
    void keyboardLayoutChanged();
    void castsChanged();

private slots:
    void handleEvent(const QJsonObject &event);

private:
    NiriWorkspace parseWorkspace(const QJsonObject &object) const;
    NiriWindow parseWindow(const QJsonObject &object);
    NiriOutput parseOutput(const QString &name, const QJsonObject &object) const;
    void loadInitialState();
    void fetchOutputs();
    void setError(const QString &message);
    void publishState(bool workspaceChanged, bool windowChanged, bool outputChanged);
    void recomputeDerivedState();
    void sortWorkspaces();
    void sortWindows();
    bool sendAction(const QJsonObject &action);

    QVariantMap windowToMap(const NiriWindow &window) const;
    QVariantMap workspaceToMap(const NiriWorkspace &workspace) const;
    QVariantMap makeWorkspaceIcon(const NiriWindow &window, int count, bool active) const;

    NiriIpcClient m_client;
    NiriWorkspaceModel m_workspaceModel;
    NiriWindowModel m_windowModel;
    NiriOutputModel m_outputModel;
    NiriIconLookup m_iconLookup;

    QList<NiriWorkspace> m_workspaces;
    QList<NiriWindow> m_windows;
    QList<NiriOutput> m_outputs;
    QList<NiriCast> m_casts;
    QString m_lastError;
    QString m_currentOutput;
    QVariantMap m_focusedWindow;
    QVariantMap m_focusedWorkspace;
    bool m_inOverview = false;
    QStringList m_keyboardLayoutNames;
    int m_currentKeyboardLayoutIndex = -1;
};
