#include "command_router.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QTextStream>

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("key"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));

    const CommandResult result =
        CommandRouter().route(QCoreApplication::arguments().mid(1));
    if (result.jsonRequested) {
        QTextStream(stdout) << QJsonDocument(result.json).toJson(QJsonDocument::Compact)
                            << Qt::endl;
    } else {
        QTextStream stream(result.textIsError ? stderr : stdout);
        stream << result.text << Qt::endl;
    }
    return result.exitCode;
}
