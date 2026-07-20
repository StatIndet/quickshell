#include "process_identity.h"

#include <QFile>
#include <QFileInfo>

#include <cerrno>
#include <csignal>

namespace Clavis::Recording {

bool ProcessIdentity::isValid() const
{
    return pid > 0 && startTicks > 0 && !executable.isEmpty();
}

ProcessIdentity ProcessIdentityProbe::capture(qint64 pid)
{
    ProcessIdentity identity;
    identity.pid = pid;
    if (pid <= 0)
        return identity;

    QFile statFile(QStringLiteral("/proc/%1/stat").arg(pid));
    if (!statFile.open(QIODevice::ReadOnly))
        return {};
    const QByteArray stat = statFile.readAll().trimmed();
    const qsizetype closingParen = stat.lastIndexOf(')');
    if (closingParen < 0)
        return {};
    const QList<QByteArray> fields = stat.mid(closingParen + 1).trimmed().split(' ');
    // /proc/<pid>/stat field 3 is the first field after the command name.
    // Process start time is field 22, therefore index 19 in this list.
    if (fields.size() <= 19)
        return {};
    bool ticksOk = false;
    identity.startTicks = fields.at(19).toULongLong(&ticksOk);
    if (!ticksOk)
        return {};

    identity.executable = QFileInfo(QStringLiteral("/proc/%1/exe").arg(pid)).symLinkTarget();
    QFile cmdlineFile(QStringLiteral("/proc/%1/cmdline").arg(pid));
    if (cmdlineFile.open(QIODevice::ReadOnly)) {
        const QList<QByteArray> rawArguments = cmdlineFile.readAll().split('\0');
        for (const QByteArray &argument : rawArguments) {
            if (!argument.isEmpty())
                identity.arguments.append(QString::fromLocal8Bit(argument));
        }
    }
    return identity;
}

bool ProcessIdentityProbe::isAlive(qint64 pid)
{
    if (pid <= 0)
        return false;
    if (::kill(static_cast<pid_t>(pid), 0) == 0)
        return true;
    return errno == EPERM;
}

bool ProcessIdentityProbe::matches(const ProcessIdentity &expected,
                                   const QString &expectedExecutable,
                                   const QString &requiredArgument)
{
    if (!expected.isValid() || !isAlive(expected.pid))
        return false;

    const ProcessIdentity current = capture(expected.pid);
    if (!current.isValid() || current.startTicks != expected.startTicks)
        return false;
    if (QFileInfo(current.executable).fileName() != expectedExecutable)
        return false;
    if (!requiredArgument.isEmpty() && !current.arguments.contains(requiredArgument))
        return false;
    return true;
}

} // namespace Clavis::Recording
