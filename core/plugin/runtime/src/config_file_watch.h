#pragma once
#include <QFileSystemWatcher>
#include <QObject>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// Watches a known file set and its parents, including files not created yet.
class ConfigFileWatch : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList paths READ paths WRITE setPaths NOTIFY pathsChanged)
  public:
    explicit ConfigFileWatch(QObject *parent = nullptr);
    QStringList paths() const { return m_paths; }
    void setPaths(const QStringList &paths);
  signals:
    void pathsChanged();
    void changed();

  private:
    void rearm();
    QStringList m_paths;
    QFileSystemWatcher m_watcher;
};
