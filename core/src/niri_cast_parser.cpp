#include "niri_cast_parser.h"

#include <QJsonValue>

NiriCast NiriCastParser::parse(const QJsonObject &object)
{
    NiriCast cast;
    cast.streamId = object.value(QStringLiteral("stream_id")).toInteger();
    cast.sessionId = object.value(QStringLiteral("session_id")).toString();
    cast.kind = object.value(QStringLiteral("kind")).toString();
    cast.isActive = object.value(QStringLiteral("is_active")).toBool();
    cast.isDynamicTarget = object.value(QStringLiteral("is_dynamic_target")).toBool();
    cast.pid = object.value(QStringLiteral("pid")).isNull()
        ? -1
        : object.value(QStringLiteral("pid")).toInteger(-1);
    cast.pwNodeId = object.value(QStringLiteral("pw_node_id")).isNull()
        ? -1
        : object.value(QStringLiteral("pw_node_id")).toInteger(-1);

    const QJsonObject target = object.value(QStringLiteral("target")).toObject();
    if (target.contains(QStringLiteral("Output"))) {
        cast.targetType = QStringLiteral("output");
        cast.targetName =
            target.value(QStringLiteral("Output")).toObject().value(QStringLiteral("name")).toString();
    } else if (target.contains(QStringLiteral("Window"))) {
        cast.targetType = QStringLiteral("window");
        cast.targetWindowId =
            target.value(QStringLiteral("Window")).toObject().value(QStringLiteral("id")).toInteger();
    } else {
        cast.targetType = QStringLiteral("nothing");
    }
    return cast;
}

QList<NiriCast> NiriCastParser::parseArray(const QJsonArray &array)
{
    QList<NiriCast> casts;
    casts.reserve(array.size());
    for (const QJsonValue &value : array) {
        if (value.isObject())
            casts.append(parse(value.toObject()));
    }
    return casts;
}

QJsonObject NiriCastParser::toJson(const NiriCast &cast)
{
    QJsonObject target{{QStringLiteral("type"), cast.targetType}};
    if (cast.targetType == QStringLiteral("output"))
        target.insert(QStringLiteral("name"), cast.targetName);
    else if (cast.targetType == QStringLiteral("window"))
        target.insert(QStringLiteral("id"), QJsonValue::fromVariant(cast.targetWindowId));

    return {
        {QStringLiteral("stream_id"), QJsonValue::fromVariant(cast.streamId)},
        {QStringLiteral("session_id"), cast.sessionId},
        {QStringLiteral("kind"), cast.kind},
        {QStringLiteral("target"), target},
        {QStringLiteral("is_active"), cast.isActive},
        {QStringLiteral("is_dynamic_target"), cast.isDynamicTarget},
        {QStringLiteral("pid"),
         cast.pid >= 0 ? QJsonValue(cast.pid) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("pw_node_id"),
         cast.pwNodeId >= 0 ? QJsonValue(cast.pwNodeId) : QJsonValue(QJsonValue::Null)},
    };
}

QVariantMap NiriCastParser::toVariantMap(const NiriCast &cast)
{
    return toJson(cast).toVariantMap();
}

QVariantList NiriCastParser::toVariantList(const QList<NiriCast> &casts)
{
    QVariantList result;
    result.reserve(casts.size());
    for (const NiriCast &cast : casts)
        result.append(toVariantMap(cast));
    return result;
}

int NiriCastParser::activeCount(const QList<NiriCast> &casts)
{
    int count = 0;
    for (const NiriCast &cast : casts) {
        if (cast.isActive)
            ++count;
    }
    return count;
}
