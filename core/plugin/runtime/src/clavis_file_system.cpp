#include "clavis_file_system.h"

#include <QDir>
#include <QFileInfo>

ClavisFileSystem::ClavisFileSystem(QObject *parent) : QObject(parent) {}

QVariantMap ClavisFileSystem::localUrlInfo(const QUrl &url) const
{
    QVariantMap result{{QStringLiteral("valid"), false}};
    if (url.scheme() != QStringLiteral("file") || !url.isLocalFile() ||
        (!url.host().isEmpty() && url.host() != QStringLiteral("localhost"))) {
        result.insert(QStringLiteral("error"), QStringLiteral("not-local"));
        return result;
    }

    const QFileInfo info(url.toLocalFile());
    if (!info.exists()) {
        result.insert(QStringLiteral("error"), QStringLiteral("not-found"));
        return result;
    }
    if (!info.isFile() && !info.isDir()) {
        result.insert(QStringLiteral("error"), QStringLiteral("unsupported-type"));
        return result;
    }

    const QString path = QDir::cleanPath(info.absoluteFilePath());
    QString displayName = info.fileName();
    if (displayName.isEmpty()) {
        displayName = QDir(path).dirName();
    }

    result.insert(QStringLiteral("valid"), true);
    result.insert(QStringLiteral("path"), path);
    result.insert(QStringLiteral("displayName"), displayName);
    result.insert(QStringLiteral("isDirectory"), info.isDir());
    return result;
}
