#include "niri_ipc_client.h"
#include <QJsonArray>
#include <QLocalServer>
#include <QTemporaryDir>
#include <QTimer>
#include <QtTest>
class NiriAsyncTest : public QObject {
    Q_OBJECT
  private slots:
    void completeMessageAndTimeout()
    {
        QTemporaryDir directory;
        QLocalServer server;
        QVERIFY(server.listen(directory.path() + "/socket"));
        const auto old = qgetenv("NIRI_SOCKET");
        qputenv("NIRI_SOCKET", server.fullServerName().toUtf8());
        NiriIpcClient client;
        int completed = 0;
        connect(&server, &QLocalServer::newConnection, &server, [&] {
            auto *peer = server.nextPendingConnection();
            connect(peer, &QLocalSocket::readyRead, peer, [peer] {
                peer->readAll();
                peer->write("{\"Ok\":{\"Outputs\":");
                QTimer::singleShot(10, peer, [peer] { peer->write("{}}}\n"); });
            });
        });
        client.requestAsync(QStringLiteral("Outputs"), this,
                            [&](const QJsonValue &value, const QString &error) {
                                QVERIFY(error.isEmpty());
                                QVERIFY(value.isObject());
                                ++completed;
                            });
        QTRY_COMPARE(completed, 1);
        server.disconnect();
        client.requestAsync(
            QStringLiteral("Outputs"), this,
            [&](const QJsonValue &, const QString &error) {
                QVERIFY(!error.isEmpty());
                ++completed;
            },
            100);
        QTRY_COMPARE(completed, 2);
        qputenv("NIRI_SOCKET", old);
    }
    void destroyedContextCancelsDelivery()
    {
        QTemporaryDir directory;
        QLocalServer server;
        QVERIFY(server.listen(directory.path() + "/socket"));
        const auto old = qgetenv("NIRI_SOCKET");
        qputenv("NIRI_SOCKET", server.fullServerName().toUtf8());
        NiriIpcClient client;
        bool called = false;
        auto *context = new QObject;
        client.requestAsync(
            QStringLiteral("Outputs"), context, [&](const QJsonValue &, const QString &) { called = true; },
            100);
        delete context;
        QTest::qWait(150);
        QVERIFY(!called);
        auto *temporaryClient = new NiriIpcClient;
        temporaryClient->requestAsync(
            QStringLiteral("Outputs"), this, [&](const QJsonValue &, const QString &) { called = true; },
            100);
        delete temporaryClient;
        QTest::qWait(150);
        QVERIFY(!called);
        qputenv("NIRI_SOCKET", old);
    }
};
QTEST_GUILESS_MAIN(NiriAsyncTest)
#include "niri_ipc_async_test.moc"
