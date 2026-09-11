#include "niri_ipc_client.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QPointer>
#include <QTimer>
#include <memory>

NiriIpcClient::NiriIpcClient(QObject *parent) : QObject(parent)
{
    connect(&m_eventSocket, &QLocalSocket::readyRead, this, &NiriIpcClient::onEventReadyRead);
    connect(&m_eventSocket, &QLocalSocket::connected, this, &NiriIpcClient::connectedChanged);
    connect(&m_eventSocket, &QLocalSocket::disconnected, this, &NiriIpcClient::connectedChanged);
    connect(&m_eventSocket, &QLocalSocket::errorOccurred, this, &NiriIpcClient::onSocketError);
}

NiriIpcClient::~NiriIpcClient()
{
    // Cancel child requests before derived owners destroy their state. A
    // QPointer to the owner's QObject is cleared only in its base destructor.
    for (auto *socket : findChildren<QLocalSocket *>(QString(), Qt::FindDirectChildrenOnly)) {
        socket->disconnect();
        socket->abort();
        delete socket;
    }
    QObject::disconnect(&m_eventSocket, nullptr, this, nullptr);
    QObject::disconnect(&m_requestSocket, nullptr, this, nullptr);
    m_eventSocket.abort();
    m_requestSocket.abort();
}

QString NiriIpcClient::socketPath() const { return m_socketPath; }

bool NiriIpcClient::isConnected() const { return m_eventSocket.state() == QLocalSocket::ConnectedState; }

bool NiriIpcClient::connectToNiri()
{
    if (isConnected())
        return true;

    m_socketPath = QProcessEnvironment::systemEnvironment().value(QStringLiteral("NIRI_SOCKET"));
    if (m_socketPath.isEmpty()) {
        emit errorOccurred(QStringLiteral("NIRI_SOCKET is not set"));
        return false;
    }

    m_eventSocket.connectToServer(m_socketPath);
    if (!m_eventSocket.waitForConnected(1000)) {
        emit errorOccurred(
            QStringLiteral("Failed to connect Niri event socket: %1").arg(m_eventSocket.errorString()));
        return false;
    }

    m_eventSocket.write(QByteArrayLiteral("\"EventStream\"\n"));
    m_eventSocket.flush();
    emit connectedChanged();
    return true;
}

void NiriIpcClient::disconnectFromNiri()
{
    m_eventSocket.close();
    m_requestSocket.close();
    emit connectedChanged();
}

QJsonValue NiriIpcClient::sendRequest(const QJsonValue &request, bool *ok)
{
    if (ok)
        *ok = false;
    if (!ensureRequestSocket())
        return {};

    QByteArray data;
    if (request.isString()) {
        data = QJsonDocument(QJsonArray{request}).toJson(QJsonDocument::Compact);
        data = data.mid(1, data.size() - 2);
    } else if (request.isObject()) {
        data = QJsonDocument(request.toObject()).toJson(QJsonDocument::Compact);
    } else if (request.isArray()) {
        data = QJsonDocument(request.toArray()).toJson(QJsonDocument::Compact);
    } else {
        emit errorOccurred(QStringLiteral("Unsupported Niri request type"));
        return {};
    }
    data.append('\n');

    if (m_requestSocket.write(data) != data.size()) {
        emit errorOccurred(QStringLiteral("Failed to write Niri request"));
        return {};
    }
    m_requestSocket.flush();

    if (!m_requestSocket.waitForReadyRead(1000)) {
        emit errorOccurred(QStringLiteral("Timed out waiting for Niri reply"));
        return {};
    }

    const QByteArray line = m_requestSocket.readLine().trimmed();
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        emit errorOccurred(QStringLiteral("Failed to parse Niri reply: %1").arg(parseError.errorString()));
        return {};
    }

    const QJsonObject reply = doc.object();
    if (reply.contains(QStringLiteral("Err"))) {
        emit errorOccurred(reply.value(QStringLiteral("Err")).toString());
        return {};
    }

    QJsonValue value = reply.value(QStringLiteral("Ok"));
    // Newer niri versions retain the Response enum variant inside Ok,
    // for example {"Ok":{"Workspaces":[]}}. Older versions returned the
    // payload directly, so support both wire formats in the shared client.
    if (request.isString() && value.isObject()) {
        const QJsonObject wrapped = value.toObject();
        if (wrapped.contains(request.toString()))
            value = wrapped.value(request.toString());
    }

    if (ok)
        *ok = true;
    return value;
}

void NiriIpcClient::onEventReadyRead()
{
    m_eventBuffer.append(m_eventSocket.readAll());

    int pos = -1;
    while ((pos = m_eventBuffer.indexOf('\n')) >= 0) {
        const QByteArray line = m_eventBuffer.left(pos).trimmed();
        m_eventBuffer.remove(0, pos + 1);
        if (line.isEmpty())
            continue;

        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(line, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred(
                QStringLiteral("Failed to parse Niri event: %1").arg(parseError.errorString()));
            continue;
        }

        const QJsonObject event = doc.object();
        if (event.contains(QStringLiteral("Ok")))
            continue;
        if (event.contains(QStringLiteral("Err"))) {
            emit errorOccurred(event.value(QStringLiteral("Err")).toString());
            continue;
        }

        emit eventReceived(event);
    }
}

void NiriIpcClient::onSocketError(QLocalSocket::LocalSocketError error)
{
    Q_UNUSED(error)
    emit errorOccurred(m_eventSocket.errorString());
    emit connectedChanged();
}

bool NiriIpcClient::ensureRequestSocket()
{
    if (m_socketPath.isEmpty())
        m_socketPath = QProcessEnvironment::systemEnvironment().value(QStringLiteral("NIRI_SOCKET"));
    if (m_socketPath.isEmpty()) {
        emit errorOccurred(QStringLiteral("NIRI_SOCKET is not set"));
        return false;
    }

    if (m_requestSocket.state() == QLocalSocket::ConnectedState)
        return true;

    m_requestSocket.abort();
    m_requestSocket.connectToServer(m_socketPath);
    if (!m_requestSocket.waitForConnected(1000)) {
        emit errorOccurred(
            QStringLiteral("Failed to connect Niri request socket: %1").arg(m_requestSocket.errorString()));
        return false;
    }
    return true;
}

void NiriIpcClient::requestAsync(const QJsonValue &request, QObject *context, Reply reply, int timeoutMs)
{
    auto *socket = new QLocalSocket(this);
    auto *timer = new QTimer(socket);
    timer->setSingleShot(true);
    const QPointer<QObject> guard(context);
    auto done = std::make_shared<bool>(false);
    const auto finish = [socket, timer, guard, done, reply](const QJsonValue &value, const QString &error) {
        if (*done)
            return;
        *done = true;
        timer->stop();
        socket->abort();
        socket->deleteLater();
        if (guard)
            reply(value, error);
    };
    connect(context, &QObject::destroyed, socket,
            [finish] { finish({}, QStringLiteral("Request owner was destroyed")); });
    connect(timer, &QTimer::timeout, socket,
            [finish] { finish({}, QStringLiteral("Niri request timed out")); });
    connect(socket, &QLocalSocket::errorOccurred, socket,
            [finish, socket](auto) { finish({}, socket->errorString()); });
    connect(socket, &QLocalSocket::disconnected, socket,
            [finish] { finish({}, QStringLiteral("Niri disconnected before replying")); });
    connect(socket, &QLocalSocket::connected, socket, [socket, request] {
        QByteArray bytes = QJsonDocument(QJsonArray{request}).toJson(QJsonDocument::Compact);
        bytes = bytes.mid(1, bytes.size() - 2) + '\n';
        socket->write(bytes);
    });
    connect(socket, &QLocalSocket::readyRead, socket, [socket, request, finish] {
        if (socket->bytesAvailable() > 8 * 1024 * 1024) {
            finish({}, QStringLiteral("Niri reply exceeds size limit"));
            return;
        }
        if (!socket->canReadLine())
            return;
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(socket->readLine(), &error);
        const auto object = document.object();
        if (error.error != QJsonParseError::NoError || !object.contains(QStringLiteral("Ok"))) {
            finish({}, object.value(QStringLiteral("Err")).toString(QStringLiteral("Invalid Niri reply")));
            return;
        }
        auto value = object.value(QStringLiteral("Ok"));
        if (request.isString() && value.isObject() && value.toObject().contains(request.toString()))
            value = value.toObject().value(request.toString());
        finish(value, {});
    });
    timer->start(qBound(100, timeoutMs, 30000));
    socket->connectToServer(qEnvironmentVariable("NIRI_SOCKET"));
}
