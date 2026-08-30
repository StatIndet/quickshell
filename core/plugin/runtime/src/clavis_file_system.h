#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include <QVariantMap>

class ClavisFileSystem : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ClavisFileSystem)
    QML_SINGLETON

  public:
    explicit ClavisFileSystem(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap localUrlInfo(const QUrl &url) const;
};
