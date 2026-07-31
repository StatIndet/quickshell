#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QUrl>

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
        const QString argumentsPath =
            qEnvironmentVariable("CLAVIS_TEST_WL_COPY_ARGUMENTS");
        if (!argumentsPath.isEmpty()) {
            QFile argumentsFile(argumentsPath);
            if (!argumentsFile.open(QIODevice::WriteOnly))
                return 1;
            argumentsFile.write(
                application.arguments().mid(1).join(QLatin1Char('\n')).toUtf8());
        }
        if (qEnvironmentVariableIsSet("CLAVIS_TEST_WL_COPY_FAIL"))
            return 1;
        return appendTrace(QByteArrayLiteral("copy:") + input) ? 0 : 1;
    }

    const QStringList arguments = application.arguments().mid(1);
    const QString command = arguments.value(0);
    if (command == QStringLiteral("list")) {
        QTextStream(stdout)
            << "9\talpha beta\n"
            << "8\t[[ binary data 68 B png 1x1 ]]\n"
            << "7\tfile reference\n"
            << "6\tmultiple files\n";
        return 0;
    }
    if (command == QStringLiteral("decode")) {
        if (qEnvironmentVariableIsSet("CLAVIS_TEST_CLIPHIST_DECODE_FAIL"))
            return 1;
        const QByteArray id = readStdin();
        const QString root = qEnvironmentVariable("CLAVIS_TEST_FILE_ROOT");
        QByteArray payload;
        if (id == QByteArrayLiteral("10")) {
            payload = QByteArrayLiteral("\x89PNG\r\n\x1a\ncorrupt");
        } else if (id == QByteArrayLiteral("9")) {
            payload = QByteArrayLiteral("alpha\nbeta");
        } else if (id == QByteArrayLiteral("8")) {
            payload = QByteArray::fromBase64(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
                "AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");
        } else if (id == QByteArrayLiteral("7")) {
            payload = QUrl::fromLocalFile(
                QDir(root).filePath(QStringLiteral("image.png")))
                          .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("6")) {
            payload = QByteArrayLiteral("copy\n")
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("video.mp4")))
                      .toString(QUrl::FullyEncoded).toUtf8()
                + '\n'
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("archive.zip")))
                      .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("5")) {
            payload = QByteArrayLiteral("cut\n")
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("main.cpp")))
                      .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("4")) {
            payload = QByteArrayLiteral("# files\n")
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("image.png")))
                      .toString(QUrl::FullyEncoded).toUtf8()
                + '\n'
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("video.mp4")))
                      .toString(QUrl::FullyEncoded).toUtf8()
                + '\n'
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("archive.zip")))
                      .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("3")) {
            payload = QUrl::fromLocalFile(
                QDir(root).filePath(QStringLiteral("folder")))
                          .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("2")) {
            payload = QByteArrayLiteral(
                "const value = items.map(item => {\n"
                "  return item.id;\n"
                "});\n");
        } else if (id == QByteArrayLiteral("1")) {
            payload = QByteArrayLiteral("https://example.com/path?q=value");
        } else {
            return 1;
        }
        fwrite(payload.constData(), 1, static_cast<size_t>(payload.size()), stdout);
        return 0;
    }
    if (command == QStringLiteral("delete")) {
        const QByteArray id = readStdin();
        if (id.isEmpty() || id.contains('\n'))
            return 1;
        return appendTrace(QByteArrayLiteral("delete:") + id + '\n')
            ? 0 : 1;
    }
    if (command == QStringLiteral("wipe"))
        return appendTrace(QByteArrayLiteral("wipe\n")) ? 0 : 1;
    return 2;
}
