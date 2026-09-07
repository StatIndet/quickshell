#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Captures keyboard events only from the focused editor's actual window.
// ShortcutInhibitor approval remains the QML caller's responsibility.
class ShortcutRecorder : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickItem *target MEMBER m_target)
    Q_PROPERTY(bool enabled MEMBER m_enabled)
    Q_PROPERTY(QVariantMap keymap MEMBER m_keymap)
  public:
    explicit ShortcutRecorder(QObject *parent = nullptr);
    ~ShortcutRecorder() override;
  signals:
    void captured(const QString &key);
    void cancelled();
    void failed(const QString &reason);

  protected:
    bool eventFilter(QObject *object, QEvent *event) override;

  private:
    QPointer<QQuickItem> m_target;
    bool m_enabled = false;
    QVariantMap m_keymap;
};
