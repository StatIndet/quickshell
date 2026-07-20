#pragma once

#include <QString>
#include <QStringList>

namespace Clavis::Recording {

struct ProcessIdentity {
    qint64 pid = 0;
    quint64 startTicks = 0;
    QString executable;
    QStringList arguments;

    bool isValid() const;
};

class ProcessIdentityProbe {
public:
    static ProcessIdentity capture(qint64 pid);
    static bool isAlive(qint64 pid);
    static bool matches(const ProcessIdentity &expected, const QString &expectedExecutable,
                        const QString &requiredArgument = {});
};

} // namespace Clavis::Recording
