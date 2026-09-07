#pragma once

#include <QLocale>
#include <QObject>
#include <QTranslator>
#include <QtQml/qqmlregistration.h>

class I18nManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(QString systemLanguage READ systemLanguage CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

  public:
    explicit I18nManager(QObject *parent = nullptr);
    ~I18nManager() override;

    QString language() const;
    QString lastError() const;

    QString systemLanguage() const;
    Q_INVOKABLE QString normalizeLanguage(const QString &language) const;
    Q_INVOKABLE QString preferredLanguage(const QStringList &languages) const;

    Q_INVOKABLE bool setLanguage(const QString &language);

  signals:
    void languageChanged();
    void lastErrorChanged();

  private:
    void setLastError(const QString &message);

    QTranslator m_translator;
    QString m_language;
    QString m_lastError;
    bool m_installed = false;
};
