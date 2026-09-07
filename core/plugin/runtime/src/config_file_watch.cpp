#include "config_file_watch.h"
#include <QDir>
#include <QFileInfo>
#include <QSet>

ConfigFileWatch::ConfigFileWatch(QObject *parent) : QObject(parent)
{
    const auto change = [this](const QString &) {
        rearm();
        emit changed();
    };
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, change);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, change);
}
void ConfigFileWatch::setPaths(const QStringList &paths)
{
    if (m_paths == paths)
        return;
    m_paths = paths;
    rearm();
    emit pathsChanged();
}
void ConfigFileWatch::rearm()
{
    QSet<QString> wanted;
    for (const auto &path : m_paths) {
        QFileInfo file(path);
        if (file.isFile())
            wanted.insert(file.absoluteFilePath());
        QDir parent = file.absoluteDir();
        while (!parent.exists() && parent.cdUp()) {
        }
        if (parent.exists())
            wanted.insert(parent.absolutePath());
    }
    const auto current = m_watcher.files() + m_watcher.directories();
    for (const auto &path : current)
        if (!wanted.contains(path))
            m_watcher.removePath(path);
    for (const auto &path : wanted)
        if (!current.contains(path))
            m_watcher.addPath(path);
}
