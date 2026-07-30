#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>

#include <cstdio>

namespace {

bool appendTrace(const QByteArray &value)
{
    const QString path =
        qEnvironmentVariable("CLAVIS_TEST_CLIPBOARD_TRACE");
    if (path.isEmpty())
        return true;
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append))
        return false;
    return file.write(value) == value.size();
}

QByteArray readStdin()
{
    QFile input;
    if (!input.open(stdin, QIODevice::ReadOnly))
        return {};
    return input.readAll();
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    const QString executable =
        QFileInfo(QCoreApplication::applicationFilePath()).fileName();

    if (executable == QStringLiteral("wl-copy")) {
        const QByteArray input = readStdin();
        return appendTrace(QByteArrayLiteral("copy:") + input) ? 0 : 1;
    }

    const QStringList arguments = application.arguments().mid(1);
    const QString command = arguments.value(0);
    if (command == QStringLiteral("list")) {
        QTextStream(stdout)
            << "9\talpha beta\n"
            << "8\t[[ binary data 6 B png 1x1 ]]\n";
        return 0;
    }
    if (command == QStringLiteral("decode")) {
        const QByteArray id = readStdin().trimmed();
        if (id != QByteArrayLiteral("9"))
            return 1;
        fwrite("alpha\nbeta", 1, 10, stdout);
        return 0;
    }
    if (command == QStringLiteral("delete")) {
        const QByteArray id = readStdin().trimmed();
        return appendTrace(QByteArrayLiteral("delete:") + id + '\n')
            ? 0 : 1;
    }
    if (command == QStringLiteral("wipe"))
        return appendTrace(QByteArrayLiteral("wipe\n")) ? 0 : 1;
    return 2;
}
