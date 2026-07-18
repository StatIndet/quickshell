#include "slurp_selector.h"

#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>

namespace Clavis::Recording {

SelectionResult SlurpSelector::selectRegion(int timeoutMs) const
{
    const QString program = QStandardPaths::findExecutable(QStringLiteral("slurp"));
    if (program.isEmpty()) {
        return {
            false,
            false,
            {},
            makeError(QStringLiteral("dependency_missing"),
                      QStringLiteral("slurp is not installed or not available in PATH"),
                      {{QStringLiteral("dependency"), QStringLiteral("slurp")}}),
        };
    }

    QProcess process;
    process.setProgram(program);
    process.setArguments(buildArguments());
    process.start();
    if (!process.waitForStarted(3000)) {
        return {
            false,
            false,
            {},
            makeError(QStringLiteral("selector_start_failed"),
                      QStringLiteral("Unable to start slurp"),
                      {{QStringLiteral("reason"), process.errorString()}}),
        };
    }
    if (!process.waitForFinished(timeoutMs)) {
        process.terminate();
        process.waitForFinished(1000);
        return {
            false,
            false,
            {},
            makeError(QStringLiteral("selector_timeout"),
                      QStringLiteral("Timed out waiting for a region selection")),
        };
    }

    const QString stdoutText = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    const QString stderrText = QString::fromUtf8(process.readAllStandardError()).trimmed();
    if (process.exitStatus() == QProcess::NormalExit && process.exitCode() != 0
        && stdoutText.isEmpty()) {
        return {false, true, {}, {}};
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return {
            false,
            false,
            {},
            makeError(QStringLiteral("selector_failed"),
                      QStringLiteral("slurp failed to select a region"),
                      {{QStringLiteral("exitCode"), process.exitCode()},
                       {QStringLiteral("stderr"), stderrText}}),
        };
    }

    QString geometry;
    if (!normalizeGeometry(stdoutText, &geometry)) {
        return {
            false,
            false,
            {},
            makeError(QStringLiteral("invalid_geometry"),
                      QStringLiteral("slurp returned an invalid region"),
                      {{QStringLiteral("output"), stdoutText}}),
        };
    }
    return {true, false, geometry, {}};
}

QStringList SlurpSelector::buildArguments()
{
    // slurp 的默认背景可以完全透明。显式设置对比色和尺寸提示，
    // 确保从无终端的 Quickshell 子进程启动时也有明确的选区反馈。
    return {
        QStringLiteral("-d"),
        QStringLiteral("-b"),
        QStringLiteral("#00000088"),
        QStringLiteral("-c"),
        QStringLiteral("#88d0ecff"),
        QStringLiteral("-s"),
        QStringLiteral("#88d0ec40"),
        QStringLiteral("-B"),
        QStringLiteral("#0f1416e6"),
        QStringLiteral("-w"),
        QStringLiteral("3"),
        QStringLiteral("-f"),
        QStringLiteral("%wx%h+%x+%y"),
    };
}

bool SlurpSelector::normalizeGeometry(const QString &value, QString *normalized)
{
    static const QRegularExpression expression(
        QStringLiteral(R"(^\s*(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\s*$)"));
    const QRegularExpressionMatch match = expression.match(value);
    if (!match.hasMatch())
        return false;

    bool widthOk = false;
    bool heightOk = false;
    const int width = match.captured(1).toInt(&widthOk);
    const int height = match.captured(2).toInt(&heightOk);
    if (!widthOk || !heightOk || width <= 0 || height <= 0)
        return false;

    if (normalized) {
        *normalized = QStringLiteral("%1x%2+%3+%4")
                          .arg(width)
                          .arg(height)
                          .arg(match.captured(3).toInt())
                          .arg(match.captured(4).toInt());
    }
    return true;
}

} // namespace Clavis::Recording
