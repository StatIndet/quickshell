#include "i18n_manager.h"

#include <QCoreApplication>
#include <QLocale>
#include <QTest>

class I18nManagerTest : public QObject {
    Q_OBJECT

  private slots:
    void resolvesLanguagePreferences_data();
    void resolvesLanguagePreferences();
    void switchesCatalogsWithoutChangingRegionalSettings();
};

void I18nManagerTest::resolvesLanguagePreferences_data()
{
    QTest::addColumn<QStringList>("preferences");
    QTest::addColumn<QString>("expected");
    QTest::newRow("english-variant") << QStringList{"en-GB"} << "en_US";
    QTest::newRow("simplified") << QStringList{"zh_CN.UTF-8"} << "zh_CN";
    QTest::newRow("chinese-default") << QStringList{"zh"} << "zh_CN";
    QTest::newRow("singapore") << QStringList{"zh-SG"} << "zh_CN";
    QTest::newRow("taiwan") << QStringList{"zh-TW"} << "zh_TW";
    QTest::newRow("hong-kong") << QStringList{"zh_HK.UTF-8"} << "zh_TW";
    QTest::newRow("macao") << QStringList{"zh-MO"} << "zh_TW";
    QTest::newRow("hant") << QStringList{"zh-Hant-US"} << "zh_TW";
    QTest::newRow("hans-before-region") << QStringList{"zh-Hans-HK"} << "zh_CN";
    QTest::newRow("case-and-whitespace") << QStringList{" ZH-hant "} << "zh_TW";
    QTest::newRow("unsupported") << QStringList{"ja-JP", "fr-FR"} << "en_US";
    QTest::newRow("supported-secondary") << QStringList{"fr-FR", "zh-Hant", "en-US"} << "zh_TW";
    QTest::newRow("first-supported") << QStringList{"zh-CN", "en-US"} << "zh_CN";
    QTest::newRow("empty") << QStringList{} << "en_US";
    QTest::newRow("posix") << QStringList{"C.UTF-8"} << "en_US";
    QTest::newRow("invalid") << QStringList{"unknown-hant"} << "en_US";
}

void I18nManagerTest::resolvesLanguagePreferences()
{
    QFETCH(QStringList, preferences);
    QFETCH(QString, expected);
    I18nManager manager;
    QCOMPARE(manager.preferredLanguage(preferences), expected);
    if (preferences.size() == 1)
        QCOMPARE(manager.normalizeLanguage(preferences.first()), expected);
}

void I18nManagerTest::switchesCatalogsWithoutChangingRegionalSettings()
{
    const QLocale originalLocale;
    const QLocale regionalLocale(QStringLiteral("de_DE"));
    QLocale::setDefault(regionalLocale);
    // Restore the process locale even if an assertion returns early.
    struct LocaleRestorer {
        QLocale locale;
        ~LocaleRestorer() { QLocale::setDefault(locale); }
    } restorer{originalLocale};

    I18nManager manager;
    const auto translate = [](const char *context, const char *source, int n = -1) {
        return QCoreApplication::translate(context, source, nullptr, n);
    };
    QVERIFY(manager.setLanguage(QStringLiteral("zh_CN")));
    QCOMPARE(translate("AccountPage", "Unknown"), QStringLiteral("未知"));
    QCOMPARE(translate("TimeUtils", "%n minute(s) ago", 2), QStringLiteral("2 分钟以前"));
    QCOMPARE(translate("DashboardPomodoroCard", "Round %1 / %2").arg(1).arg(4),
             QStringLiteral("第 1 / 4 轮"));
    QCOMPARE(QLocale().name(), regionalLocale.name());

    QVERIFY(manager.setLanguage(QStringLiteral("zh-Hant")));
    QCOMPARE(manager.language(), QStringLiteral("zh_TW"));
    QCOMPARE(translate("AccountPage", "Unknown"), QStringLiteral("未知"));
    QCOMPARE(translate("TimeUtils", "%n minute(s) ago", 2), QStringLiteral("2 分鐘以前"));
    QCOMPARE(translate("DashboardPomodoroCard", "Round %1 / %2").arg(1).arg(4),
             QStringLiteral("第 1 / 4 輪"));

    QVERIFY(manager.setLanguage(QStringLiteral("en-GB")));
    QCOMPARE(manager.language(), QStringLiteral("en_US"));
    QCOMPARE(translate("AccountPage", "Unknown"), QStringLiteral("Unknown"));
    QCOMPARE(translate("TimeUtils", "%n minute(s) ago", 1), QStringLiteral("1 minute ago"));
    QCOMPARE(translate("TimeUtils", "%n minute(s) ago", 2), QStringLiteral("2 minutes ago"));
    QCOMPARE(
        QCoreApplication::translate("SpotlightClipboardProvider", "%n file(s)", "clipboard file count", 2),
        QStringLiteral("2 files"));
    QCOMPARE(translate("UntranslatedContext", "English fallback"), QStringLiteral("English fallback"));
    QCOMPARE(QLocale().name(), regionalLocale.name());
    QCOMPARE(QLocale().toString(1234.5, 'f', 1), regionalLocale.toString(1234.5, 'f', 1));

    QVERIFY(manager.setLanguage(QStringLiteral("fr-FR")));
    QCOMPARE(manager.language(), QStringLiteral("en_US"));
    QVERIFY(manager.lastError().isEmpty());
}

QTEST_GUILESS_MAIN(I18nManagerTest)
#include "i18n_manager_test.moc"
