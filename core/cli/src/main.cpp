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
    if (result.outputHandled) {
        return result.exitCode;
    }
    FILE *destination = result.jsonRequested
        ? stdout
        : (result.textIsError ? stderr : stdout);
    QTextStream output(destination);
    if (result.jsonRequested) {
        output << QJsonDocument(result.json).toJson(QJsonDocument::Compact)
               << Qt::endl;
    } else {
        output << result.text << Qt::endl;
    }
    if (output.status() != QTextStream::Ok) {
        QTextStream(stderr) << "key: unable to write command output"
                            << Qt::endl;
        return 3;
    }
    return result.exitCode;
}
