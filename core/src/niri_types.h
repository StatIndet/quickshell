#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>

struct NiriWorkspace {
    quint64 id = 0;
    int index = 0;
    QString name;
    QString output;
    bool isActive = false;
    bool isFocused = false;
    bool isUrgent = false;
    quint64 activeWindowId = 0;
    int windowCount = 0;
    QVariantList icons;
};

struct NiriWindow {
    quint64 id = 0;
    QString title;
    QString appId;
    QString appName;
    qint64 pid = -1;
    quint64 workspaceId = 0;
    bool isFocused = false;
    bool isFloating = false;
    bool isUrgent = false;
    int layoutColumn = 999999;
    int layoutRow = 999999;
    QString iconPath;
};

struct NiriOutput {
    QString name;
    QString make;
    QString model;
    QString serial;
    int logicalX = 999999;
    int logicalY = 999999;
    int logicalWidth = 0;
    int logicalHeight = 0;
    double scale = 1.0;
    QString transform;
    QString currentMode;
    bool vrrEnabled = false;
};

struct NiriCast {
    quint64 streamId = 0;
    QString sessionId;
    QString kind;
    QString targetType;
    QString targetName;
    quint64 targetWindowId = 0;
    bool isActive = false;
    bool isDynamicTarget = false;
    qint64 pid = -1;
    qint64 pwNodeId = -1;
};
