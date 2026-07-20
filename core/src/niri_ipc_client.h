#pragma once

#include <QObject>
#include <QJsonValue>
#include <QLocalSocket>

class NiriIpcClient : public QObject {
    Q_OBJECT

public:
    explicit NiriIpcClient(QObject *parent = nullptr);
    ~NiriIpcClient() override;

    QString socketPath() const;
    bool isConnected() const;

    bool connectToNiri();
    void disconnectFromNiri();
    QJsonValue sendRequest(const QJsonValue &request, bool *ok = nullptr);

signals:
    void connectedChanged();
    void eventReceived(const QJsonObject &event);
    void errorOccurred(const QString &message);

private slots:
    void onEventReadyRead();
    void onSocketError(QLocalSocket::LocalSocketError error);

private:
    bool ensureRequestSocket();

    QString m_socketPath;
    QLocalSocket m_eventSocket;
    QLocalSocket m_requestSocket;
    QByteArray m_eventBuffer;
};
