#pragma once

#include "niri_types.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QVariantList>

class NiriCastParser {
public:
    static NiriCast parse(const QJsonObject &object);
    static QList<NiriCast> parseArray(const QJsonArray &array);
    static QJsonObject toJson(const NiriCast &cast);
    static QVariantMap toVariantMap(const NiriCast &cast);
    static QVariantList toVariantList(const QList<NiriCast> &casts);
    static int activeCount(const QList<NiriCast> &casts);
};
