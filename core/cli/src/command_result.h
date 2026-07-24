#pragma once

#include <QJsonObject>
#include <QString>

struct CommandResult {
    int exitCode = 0;
    bool jsonRequested = false;
    QJsonObject json;
    QString text;
    bool textIsError = false;
    bool outputHandled = false;
};
