#include "i18n_manager.h"

#include <QCoreApplication>
#include <QQmlEngine>

I18nManager::I18nManager(QObject *parent) : QObject(parent) {}

I18nManager::~I18nManager()
{
    if (m_installed)
        QCoreApplication::removeTranslator(&m_translator);
}

QString I18nManager::language() const { return m_language; }

QString I18nManager::lastError() const { return m_lastError; }

namespace {
QString supportedLanguage(const QString &language)
{
    const QStringList parts = language.trimmed()
                                  .toLower()
                                  .replace(QLatin1Char('-'), QLatin1Char('_'))
                                  .section(QLatin1Char('.'), 0, 0)
                                  .section(QLatin1Char('@'), 0, 0)
                                  .split(QLatin1Char('_'));
    if (parts.first() == QStringLiteral("en"))
        return QStringLiteral("en_US");
    if (parts.first() != QStringLiteral("zh"))
        return {};
    if (parts.contains(QStringLiteral("hans")))
        return QStringLiteral("zh_CN");
    if (parts.contains(QStringLiteral("hant")) || parts.contains(QStringLiteral("tw")) ||
        parts.contains(QStringLiteral("hk")) || parts.contains(QStringLiteral("mo")))
        return QStringLiteral("zh_TW");
    return QStringLiteral("zh_CN");
}
} // namespace

QString I18nManager::normalizeLanguage(const QString &language) const
{
    return preferredLanguage({language});
}

QString I18nManager::preferredLanguage(const QStringList &languages) const
{
    for (const QString &language : languages) {
        const QString supported = supportedLanguage(language);
        if (!supported.isEmpty())
            return supported;
    }
    return QStringLiteral("en_US");
}

QString I18nManager::systemLanguage() const { return preferredLanguage(QLocale::system().uiLanguages()); }

void I18nManager::setLastError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}

bool I18nManager::setLanguage(const QString &language)
{
    const QString normalized = normalizeLanguage(language);
    if (m_language == normalized && m_installed)
        return true;

    if (m_installed) {
        QCoreApplication::removeTranslator(&m_translator);
        m_installed = false;
    }

    const QString resourcePath = QStringLiteral(":/i18n/clavis_%1.qm").arg(normalized);
    if (!m_translator.load(resourcePath)) {
        setLastError(QStringLiteral("Unable to load translation catalog: %1").arg(resourcePath));
        return false;
    }

    if (!QCoreApplication::installTranslator(&m_translator)) {
        setLastError(QStringLiteral("Unable to install translation catalog: %1").arg(resourcePath));
        return false;
    }

    m_installed = true;
    m_language = normalized;
    if (QQmlEngine *engine = qmlEngine(this)) {
        engine->setUiLanguage(normalized);
        engine->retranslate();
    }

    setLastError(QString());
    emit languageChanged();
    return true;
}
