#include "lyrics.h"

#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkCookieJar>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrlQuery>

#include <algorithm>
#include <cmath>

namespace {

constexpr int kLoadDebounceMs = 80;
constexpr int kNetEaseSearchLimit = 5;

constexpr auto kNetEaseUserAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0";

QString normalized(const QString &value)
{
    return value.normalized(QString::NormalizationForm_KC).simplified().toLower();
}

QString comparable(const QString &value)
{
    QString result = normalized(value);
    static const QRegularExpression separators(QStringLiteral("[^\\p{L}\\p{N}]+"));
    result.replace(separators, QStringLiteral(" "));
    return result.simplified();
}

QString sanitizePathPart(const QString &value)
{
    QString result;
    result.reserve(value.size());
    for (const QChar character : value) {
        if (character.isNull() || character.category() == QChar::Other_Control ||
            character == QLatin1Char('/') || character == QLatin1Char('\\')) {
            result.append(QLatin1Char('_'));
        } else {
            result.append(character);
        }
    }
    return result.trimmed();
}

double fractionalSeconds(const QString &fraction)
{
    if (fraction.isEmpty())
        return 0.0;

    bool ok = false;
    const int value = fraction.toInt(&ok);
    if (!ok)
        return 0.0;
    if (fraction.size() == 1)
        return value / 10.0;
    if (fraction.size() == 2)
        return value / 100.0;
    return value / 1000.0;
}

QString firstString(const QJsonObject &object, const QStringList &keys)
{
    for (const QString &key : keys) {
        const QString value = object.value(key).toString().trimmed();
        if (!value.isEmpty())
            return value;
    }
    return {};
}

QString jsonId(const QJsonValue &value)
{
    if (value.isString())
        return value.toString();
    if (value.isDouble())
        return QString::number(static_cast<qlonglong>(value.toDouble()));
    return {};
}

double jsonDurationSeconds(const QJsonObject &object)
{
    QJsonValue value = object.value(QStringLiteral("duration"));
    if (value.isUndefined() || value.isNull())
        value = object.value(QStringLiteral("dt"));
    if (value.isUndefined() || value.isNull())
        value = object.value(QStringLiteral("duration_ms"));

    double duration = value.toDouble();
    if (duration <= 0.0 && value.isString())
        duration = value.toString().toDouble();
    if (duration > 10000.0)
        duration /= 1000.0;
    return duration > 0.0 && std::isfinite(duration) ? duration : 0.0;
}

double textSimilarity(const QString &expected, const QString &actual)
{
    const QString left = comparable(expected);
    const QString right = comparable(actual);
    if (left.isEmpty() || right.isEmpty())
        return 0.0;
    if (left == right)
        return 1.0;
    if (right.contains(left) || left.contains(right))
        return 0.78;

    const QStringList leftTokens = left.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    const QStringList rightTokens = right.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (leftTokens.isEmpty() || rightTokens.isEmpty())
        return 0.0;

    int matched = 0;
    for (const QString &token : leftTokens) {
        if (rightTokens.contains(token))
            ++matched;
    }
    return static_cast<double>(matched) / static_cast<double>(leftTokens.size());
}

bool hasVersionTerm(const QString &value, const QString &term)
{
    const QString pattern = QStringLiteral("(?:^| )%1(?:$| )").arg(QRegularExpression::escape(term));
    return QRegularExpression(pattern).match(comparable(value)).hasMatch();
}

double candidateScore(const QString &artist, const QString &title, const QString &album, double duration,
                      const QVariantMap &candidate)
{
    const QString candidateTitle = candidate.value(QStringLiteral("title")).toString();
    const QString candidateArtist = candidate.value(QStringLiteral("artist")).toString();
    const QString candidateAlbum = candidate.value(QStringLiteral("album")).toString();
    const double candidateDuration = candidate.value(QStringLiteral("duration")).toDouble();

    const double titleScore = textSimilarity(title, candidateTitle);
    const double artistScore = textSimilarity(artist, candidateArtist);
    // The title is the only required identity field. A missing artist/album/
    // duration is incomplete metadata, not evidence that the candidate is
    // wrong. Only an obviously unrelated title is rejected here; the score
    // remains primarily a ranking signal for the fallback loop.
    if (titleScore < 0.45 || (!artist.isEmpty() && !candidateArtist.isEmpty() && artistScore < 0.25))
        return -1.0;

    double weightedScore = titleScore * 50.0;
    double availableWeight = 50.0;

    if (!artist.isEmpty() && !candidateArtist.isEmpty()) {
        weightedScore += artistScore * 35.0;
        availableWeight += 35.0;
    }

    if (!album.isEmpty() && !candidateAlbum.isEmpty()) {
        weightedScore += textSimilarity(album, candidateAlbum) * 10.0;
        availableWeight += 10.0;
    }

    if (duration > 0.0 && candidateDuration > 0.0) {
        const double difference = std::abs(duration - candidateDuration);
        double durationScore = 0.0;
        if (difference <= 2.0)
            durationScore = 1.0;
        else if (difference <= 5.0)
            durationScore = 0.64;
        else if (difference <= 12.0)
            durationScore = 0.24;
        weightedScore += durationScore * 25.0;
        availableWeight += 25.0;
    }

    double score = availableWeight > 0.0 ? weightedScore / availableWeight * 100.0 : 0.0;

    static const QStringList versionTerms = {
        QStringLiteral("live"),         QStringLiteral("remix"),    QStringLiteral("cover"),
        QStringLiteral("instrumental"), QStringLiteral("remaster"), QStringLiteral("acoustic"),
        QStringLiteral("karaoke"),      QStringLiteral("demo"),
    };
    for (const QString &term : versionTerms) {
        if (hasVersionTerm(candidateTitle, term) && !hasVersionTerm(title, term))
            score -= 18.0;
    }
    return score;
}

QVariantMap candidateWithIdentity(const QString &provider, const QString &id, const QString &title,
                                  const QString &artist, const QString &album, double duration)
{
    QVariantMap candidate;
    candidate.insert(QStringLiteral("provider"), provider);
    candidate.insert(QStringLiteral("id"), id);
    candidate.insert(QStringLiteral("title"), title);
    candidate.insert(QStringLiteral("artist"), artist);
    candidate.insert(QStringLiteral("album"), album);
    candidate.insert(QStringLiteral("duration"), duration);
    return candidate;
}

QString candidateIdentity(const QVariantMap &candidate)
{
    return candidate.value(QStringLiteral("provider")).toString() + QLatin1Char('\n') +
           candidate.value(QStringLiteral("id")).toString();
}

bool isMetadataLine(const QString &line)
{
    static const QRegularExpression metadata(QStringLiteral(R"(^\[(?:ar|ti|al|by|re|ve|offset)\s*:)"),
                                             QRegularExpression::CaseInsensitiveOption);
    return metadata.match(line.trimmed()).hasMatch();
}

bool looksLikeMalformedTimestamp(const QString &line)
{
    static const QRegularExpression malformed(QStringLiteral(R"(^\[\d+\s*:[^\]]+\])"));
    return malformed.match(line.trimmed()).hasMatch();
}

} // namespace

Lyrics::Lyrics(QObject *parent) : QObject(parent)
{
    m_loadDebounce.setSingleShot(true);
    m_loadDebounce.setInterval(kLoadDebounceMs);
    connect(&m_loadDebounce, &QTimer::timeout, this, [this]() {
        if (m_title.isEmpty())
            return;
        startLoad(m_generation, m_forceNetwork);
    });
}

void Lyrics::setNetworkAccessManager(QNetworkAccessManager *manager)
{
    ++m_generation;
    cancelInFlight();
    m_manager = manager ? manager : &m_defaultManager;
}

void Lyrics::setOffsetMs(double offsetMs)
{
    if (!std::isfinite(offsetMs) || qFuzzyCompare(m_offsetMs + 1.0, offsetMs + 1.0))
        return;

    m_offsetMs = offsetMs;
    emit offsetMsChanged();
    if (!m_sourceText.isEmpty())
        rebuildTimelineFromSource();
}

void Lyrics::setTrack(const QString &artist, const QString &title, const QString &album, double duration,
                      const QString &playerId)
{
    const QString nextArtist = artist.trimmed();
    const QString nextTitle = title.trimmed();
    const QString nextAlbum = album.trimmed();
    const double nextDuration = std::isfinite(duration) && duration > 0.0 ? duration : 0.0;
    const QString nextPlayerId = playerId.trimmed();

    if (m_artist == nextArtist && m_title == nextTitle && m_album == nextAlbum &&
        m_playerId == nextPlayerId && qFuzzyCompare(m_duration + 1.0, nextDuration + 1.0)) {
        return;
    }

    beginGeneration();
    m_loadDebounce.stop();
    m_artist = nextArtist;
    m_title = nextTitle;
    m_album = nextAlbum;
    m_duration = nextDuration;
    m_playerId = nextPlayerId;
    emit trackChanged();

    clearCandidates();
    clearLyrics();
    clearSource();
    setProvider({});
    setError({});
    resetProviderOutcomes();

    if (m_title.isEmpty()) {
        setLoading(false);
        setStatus(QStringLiteral("idle"));
        return;
    }

    m_forceNetwork = false;
    m_autoFallback = true;
    setLoading(true);
    setStatus(QStringLiteral("loading"));
    scheduleLoad();
}

void Lyrics::clearTrack()
{
    if (m_artist.isEmpty() && m_title.isEmpty() && m_album.isEmpty() && m_playerId.isEmpty() && !m_loading &&
        !m_reply)
        return;

    beginGeneration();
    m_loadDebounce.stop();
    m_artist.clear();
    m_title.clear();
    m_album.clear();
    m_duration = 0.0;
    m_playerId.clear();
    emit trackChanged();

    m_forceNetwork = false;
    m_autoFallback = false;
    m_netEaseCandidates.clear();
    m_pendingCandidate.clear();
    m_netEaseCandidateIndex = 0;
    resetProviderOutcomes();
    clearCandidates();
    clearLyrics();
    clearSource();
    setProvider({});
    setError({});
    setLoading(false);
    setStatus(QStringLiteral("idle"));
}

void Lyrics::refresh()
{
    if (m_title.isEmpty())
        return;

    const quint64 generation = beginGeneration();
    m_loadDebounce.stop();
    m_forceNetwork = true;
    m_autoFallback = true;
    m_netEaseCandidates.clear();
    m_pendingCandidate.clear();
    m_netEaseCandidateIndex = 0;
    resetProviderOutcomes();
    clearCandidates();
    clearLyrics();
    clearSource();
    setProvider({});
    setError({});
    setLoading(true);
    setStatus(QStringLiteral("loading"));
    startLoad(generation, true);
}

void Lyrics::requestCandidates()
{
    if (m_title.isEmpty())
        return;

    const quint64 generation = beginGeneration();
    m_loadDebounce.stop();
    m_forceNetwork = true;
    m_autoFallback = false;
    m_netEaseCandidates.clear();
    m_pendingCandidate.clear();
    m_netEaseCandidateIndex = 0;
    resetProviderOutcomes();
    clearCandidates();
    setError({});
    setLoading(true);
    setStatus(QStringLiteral("loading"));
    startLrclibSearch(generation);
}

void Lyrics::selectCandidate(int index)
{
    if (index < 0 || index >= m_candidates.size())
        return;

    const QVariantMap candidate = m_candidates.at(index).toMap();
    const QString provider = candidate.value(QStringLiteral("provider")).toString();
    const QString id = candidate.value(QStringLiteral("id")).toString();
    if (provider.isEmpty() || id.isEmpty())
        return;

    const quint64 generation = beginGeneration();
    m_loadDebounce.stop();
    m_forceNetwork = true;
    m_autoFallback = false;
    resetProviderOutcomes();
    clearLyrics();
    clearSource();
    setSelectedCandidate(candidate);
    setProvider(provider);
    setError({});
    setLoading(true);
    setStatus(QStringLiteral("loading"));

    const QString synced = candidate.value(QStringLiteral("syncedLyrics")).toString();
    const QString plain = candidate.value(QStringLiteral("plainLyrics")).toString();
    if (!synced.isEmpty() || !plain.isEmpty()) {
        if (!acceptRawLyrics(provider, synced, plain, candidate, generation, true))
            finishError(QStringLiteral("歌词内容不可用"));
        return;
    }

    if (provider.compare(QStringLiteral("LRCLIB"), Qt::CaseInsensitive) == 0) {
        startReply(QUrl(QStringLiteral("https://lrclib.net/api/get/") + id), ReplyKind::LrclibTrack,
                   generation);
    } else if (provider.compare(QStringLiteral("NetEase"), Qt::CaseInsensitive) == 0) {
        resetNetEaseSession();
        startNetEaseLyrics(candidate, generation);
    } else {
        finishError(QStringLiteral("不支持的歌词 provider"));
    }
}

QVariantList Lyrics::parseLrc(const QString &text, double offsetMs) const
{
    QVariantList result;
    if (text.trimmed().isEmpty())
        return result;

    double fileOffsetMs = 0.0;
    static const QRegularExpression offsetExpression(QStringLiteral(R"(\[offset\s*:\s*(-?\d+(?:\.\d+)?)\])"),
                                                     QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch offsetMatch = offsetExpression.match(text);
    if (offsetMatch.hasMatch())
        fileOffsetMs = offsetMatch.captured(1).toDouble();

    static const QRegularExpression timestampExpression(
        QStringLiteral(R"(\[(\d+):(\d{1,2})(?:[\.:](\d{1,3}))?\])"));
    const QStringList lines = text.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    for (const QString &line : lines) {
        QList<double> timestamps;
        QRegularExpressionMatchIterator iterator = timestampExpression.globalMatch(line);
        while (iterator.hasNext()) {
            const QRegularExpressionMatch match = iterator.next();
            const double seconds = match.captured(1).toDouble() * 60.0 + match.captured(2).toDouble() +
                                   fractionalSeconds(match.captured(3));
            timestamps.append(seconds + (fileOffsetMs + offsetMs) / 1000.0);
        }

        // Remove every timestamp from the original line in one operation.
        // This keeps match offsets valid for multi-timestamp lines.
        QString lyricText = line;
        lyricText.replace(timestampExpression, QString());
        lyricText = lyricText.trimmed();

        if (!timestamps.isEmpty()) {
            if (lyricText.isEmpty())
                continue;
            for (const double time : timestamps)
                result.append(
                    QVariantMap{{QStringLiteral("time"), time}, {QStringLiteral("text"), lyricText}});
            continue;
        }

        const QString trimmed = line.trimmed();
        if (lyricText.isEmpty() || isMetadataLine(trimmed) || looksLikeMalformedTimestamp(trimmed))
            continue;
        result.append(QVariantMap{{QStringLiteral("time"), -1.0}, {QStringLiteral("text"), lyricText}});
    }

    std::stable_sort(result.begin(), result.end(), [](const QVariant &left, const QVariant &right) {
        const double leftTime = left.toMap().value(QStringLiteral("time"), -1.0).toDouble();
        const double rightTime = right.toMap().value(QStringLiteral("time"), -1.0).toDouble();
        const bool leftSynced = leftTime >= 0.0;
        const bool rightSynced = rightTime >= 0.0;
        if (leftSynced != rightSynced)
            return leftSynced;
        return leftSynced && leftTime < rightTime;
    });
    return result;
}

int Lyrics::indexForTime(double positionSeconds) const
{
    if (!m_hasSynchronizedLyrics || !std::isfinite(positionSeconds) || positionSeconds < 0.0)
        return -1;

    int syncedCount = 0;
    while (syncedCount < m_lyrics.size() &&
           m_lyrics.at(syncedCount).toMap().value(QStringLiteral("time"), -1.0).toDouble() >= 0.0) {
        ++syncedCount;
    }

    int low = 0;
    int high = syncedCount;
    while (low < high) {
        const int middle = low + (high - low) / 2;
        const double time = m_lyrics.at(middle).toMap().value(QStringLiteral("time"), -1.0).toDouble();
        if (time <= positionSeconds)
            low = middle + 1;
        else
            high = middle;
    }
    return low - 1;
}

double Lyrics::timeForIndex(int index) const
{
    if (index < 0 || index >= m_lyrics.size())
        return -1.0;
    const double time = m_lyrics.at(index).toMap().value(QStringLiteral("time"), -1.0).toDouble();
    return time >= 0.0 && std::isfinite(time) ? time : -1.0;
}

void Lyrics::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}

void Lyrics::setLoading(bool loading)
{
    if (m_loading == loading)
        return;
    m_loading = loading;
    emit loadingChanged();
}

void Lyrics::setHasLyrics(bool value)
{
    if (m_hasLyrics == value)
        return;
    m_hasLyrics = value;
    emit hasLyricsChanged();
}

void Lyrics::setHasSynchronizedLyrics(bool value)
{
    if (m_hasSynchronizedLyrics == value)
        return;
    m_hasSynchronizedLyrics = value;
    emit synchronizedChanged();
}

void Lyrics::setProvider(const QString &provider)
{
    if (m_provider == provider)
        return;
    m_provider = provider;
    emit providerChanged();
}

void Lyrics::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void Lyrics::setSelectedCandidate(const QVariantMap &candidate)
{
    if (m_selectedCandidate == candidate)
        return;
    m_selectedCandidate = candidate;
    emit selectedCandidateChanged();
}

void Lyrics::clearLyrics()
{
    const bool hadLines = !m_lyrics.isEmpty();
    m_lyrics.clear();
    setHasLyrics(false);
    setHasSynchronizedLyrics(false);
    if (hadLines)
        emit lyricsChanged();
}

void Lyrics::clearCandidates()
{
    if (!m_candidates.isEmpty()) {
        m_candidates.clear();
        emit candidatesChanged();
    }
    setSelectedCandidate({});
}

void Lyrics::clearSource()
{
    m_sourceText.clear();
    m_sourceProvider.clear();
    m_sourceCandidate.clear();
}

void Lyrics::resetProviderOutcomes()
{
    m_lrclibOutcome = ProviderOutcome::Pending;
    m_netEaseSearchOutcome = ProviderOutcome::Pending;
    m_netEaseCandidateOutcome = ProviderOutcome::Pending;
    m_netEaseSawValidLyricResponse = false;
    m_netEaseSawNoLyrics = false;
    m_netEaseSawParseFailure = false;
}

void Lyrics::resetNetEaseSession()
{
    if (m_manager)
        m_manager->setCookieJar(new QNetworkCookieJar(m_manager));
}

quint64 Lyrics::beginGeneration()
{
    ++m_generation;
    cancelInFlight();
    return m_generation;
}

void Lyrics::cancelInFlight()
{
    if (!m_reply)
        return;

    QNetworkReply *reply = m_reply.data();
    m_reply = nullptr;
    reply->abort();
    reply->deleteLater();
}

void Lyrics::scheduleLoad() { m_loadDebounce.start(); }

void Lyrics::startLoad(quint64 generation, bool bypassCache)
{
    if (generation != m_generation || m_title.isEmpty())
        return;

    if (loadLocalLyrics(generation))
        return;
    if (!bypassCache && loadCachedLyrics(generation))
        return;

    m_forceNetwork = bypassCache;
    m_autoFallback = true;
    m_netEaseCandidates.clear();
    m_pendingCandidate.clear();
    m_netEaseCandidateIndex = 0;
    resetProviderOutcomes();
    // NetEase is preferred because it supplies translations (tlyric) that
    // LRCLIB lacks; LRCLIB remains the fallback for coverage.
    startNetEaseSearch(generation);
}

bool Lyrics::loadLocalLyrics(quint64 generation)
{
    const QString path = localLyricsPath();
    if (path.isEmpty())
        return false;

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QString text = QString::fromUtf8(file.readAll());
    QVariantMap candidate =
        candidateWithIdentity(QStringLiteral("Local"), path, m_title, m_artist, m_album, m_duration);
    return acceptRawLyrics(QStringLiteral("Local"), text, {}, candidate, generation, false);
}

bool Lyrics::loadCachedLyrics(quint64 generation)
{
    QFile indexFile(cacheIndexPath());
    if (!indexFile.open(QIODevice::ReadOnly))
        return false;

    QJsonParseError parseError;
    const QJsonDocument indexDocument = QJsonDocument::fromJson(indexFile.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !indexDocument.isObject())
        return false;

    const QJsonObject entry = indexDocument.object().value(cacheKey()).toObject();
    const QString provider = entry.value(QStringLiteral("provider")).toString();
    const QString id = entry.value(QStringLiteral("id")).toString();
    if (provider.isEmpty() || id.isEmpty())
        return false;

    QFile contentFile(cachePath(provider, id));
    if (!contentFile.open(QIODevice::ReadOnly))
        return false;
    const QJsonDocument contentDocument = QJsonDocument::fromJson(contentFile.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !contentDocument.isObject())
        return false;

    const QJsonObject content = contentDocument.object();
    if (content.value(QStringLiteral("version")).toInt() != 2)
        return false;
    const QString synced = content.value(QStringLiteral("syncedLyrics")).toString();
    const QString plain = content.value(QStringLiteral("plainLyrics")).toString();
    if (synced.isEmpty() && plain.isEmpty())
        return false;

    QVariantMap candidate = candidateWithIdentity(
        provider, id, content.value(QStringLiteral("title")).toString(),
        content.value(QStringLiteral("artist")).toString(), content.value(QStringLiteral("album")).toString(),
        content.value(QStringLiteral("duration")).toDouble());
    candidate.insert(QStringLiteral("syncedLyrics"), synced);
    candidate.insert(QStringLiteral("plainLyrics"), plain);
    return acceptRawLyrics(provider, synced, plain, candidate, generation, false);
}

bool Lyrics::acceptRawLyrics(const QString &provider, const QString &synced, const QString &plain,
                             const QVariantMap &candidate, quint64 generation, bool writeCache)
{
    if (generation != m_generation)
        return false;

    const QString raw = synced.isEmpty() ? plain : synced;
    if (raw.trimmed().isEmpty())
        return false;
    const QVariantList lines = parseLrc(raw, m_offsetMs);
    if (lines.isEmpty())
        return false;

    m_sourceText = raw;
    // When a provider supplies both a synchronized original and a translation
    // (e.g. NetEase tlyric), keep the translation source so the timeline can
    // be rebuilt (offset changes) with the translation still attached.
    m_sourceTranslation = synced.isEmpty() ? QString() : plain;
    m_sourceProvider = provider;
    m_sourceCandidate = candidate;
    m_lyrics = synced.isEmpty() ? lines : mergeTranslation(lines, m_sourceTranslation);

    bool synchronized = false;
    for (const QVariant &line : m_lyrics) {
        if (line.toMap().value(QStringLiteral("time"), -1.0).toDouble() >= 0.0) {
            synchronized = true;
            break;
        }
    }
    setHasLyrics(!m_lyrics.isEmpty());
    setHasSynchronizedLyrics(synchronized);
    setProvider(provider);
    setError({});
    setLoading(false);
    setStatus(QStringLiteral("ready"));
    emit lyricsChanged();

    if (!candidate.isEmpty()) {
        appendCandidates({candidate});
        setSelectedCandidate(candidate);
    }

    if (writeCache && provider.compare(QStringLiteral("Local"), Qt::CaseInsensitive) != 0)
        cacheLyrics(provider, candidate.value(QStringLiteral("id")).toString(), synced, plain, candidate);
    return true;
}

void Lyrics::finishEmpty(const QString &message)
{
    Q_UNUSED(message)
    clearLyrics();
    clearSource();
    setProvider({});
    setError({});
    setLoading(false);
    setStatus(QStringLiteral("empty"));
}

void Lyrics::finishError(const QString &message)
{
    clearLyrics();
    clearSource();
    setProvider({});
    setError(message);
    setLoading(false);
    setStatus(QStringLiteral("error"));
}

void Lyrics::rebuildTimelineFromSource()
{
    const QVariantList lines = parseLrc(m_sourceText, m_offsetMs);
    if (lines.isEmpty())
        return;

    m_lyrics = m_sourceTranslation.isEmpty() ? lines : mergeTranslation(lines, m_sourceTranslation);
    bool synchronized = false;
    for (const QVariant &line : m_lyrics) {
        if (line.toMap().value(QStringLiteral("time"), -1.0).toDouble() >= 0.0) {
            synchronized = true;
            break;
        }
    }
    setHasLyrics(true);
    setHasSynchronizedLyrics(synchronized);
    emit lyricsChanged();
}

QVariantList Lyrics::mergeTranslation(const QVariantList &lines, const QString &translationLrc) const
{
    if (translationLrc.trimmed().isEmpty())
        return lines;

    // Translations are usually line-aligned with the original. Build a lookup
    // from timestamp to translation text, tolerating small clock drift between
    // the two LRC payloads.
    struct Entry {
        double time;
        QString text;
    };
    QList<Entry> entries;
    const QVariantList translationLines = parseLrc(translationLrc, 0.0);
    entries.reserve(translationLines.size());
    for (const QVariant &line : translationLines) {
        const QVariantMap map = line.toMap();
        const double time = map.value(QStringLiteral("time"), -1.0).toDouble();
        const QString text = map.value(QStringLiteral("text")).toString();
        if (time < 0.0 || text.trimmed().isEmpty())
            continue;
        entries.append({time, text});
    }
    if (entries.isEmpty())
        return lines;
    std::sort(entries.begin(), entries.end(),
              [](const Entry &left, const Entry &right) { return left.time < right.time; });

    const double toleranceMs = 120.0;
    QVariantList merged;
    merged.reserve(lines.size());
    for (const QVariant &line : lines) {
        const QVariantMap map = line.toMap();
        const double time = map.value(QStringLiteral("time"), -1.0).toDouble();
        QString translation;
        if (time >= 0.0 && !entries.isEmpty()) {
            // Linear probe is fine here: translations are typically a few
            // hundred lines at most and the lists are usually aligned.
            for (const Entry &entry : entries) {
                if (entry.time >= time - toleranceMs / 1000.0 && entry.time <= time + toleranceMs / 1000.0) {
                    translation = entry.text;
                    break;
                }
            }
        }
        if (translation.isEmpty()) {
            merged.append(line);
        } else {
            QVariantMap enriched = map;
            enriched.insert(QStringLiteral("translation"), translation);
            merged.append(enriched);
        }
    }
    return merged;
}

void Lyrics::startLrclibTrack(quint64 generation)
{
    startReply(lrclibUrl(false), ReplyKind::LrclibTrack, generation);
}

void Lyrics::startLrclibSearch(quint64 generation)
{
    startReply(lrclibUrl(true), ReplyKind::LrclibSearch, generation);
}

void Lyrics::startNetEaseSearch(quint64 generation)
{
    if (generation != m_generation)
        return;

    // NetEase may reject a request carrying stale cookies. Start every
    // search/fallback chain with a fresh jar, while keeping it alive for the
    // subsequent lyric requests for the selected candidates.
    resetNetEaseSession();
    startReply(netEaseSearchUrl(), ReplyKind::NetEaseSearch, generation);
}

void Lyrics::startNetEaseLyrics(const QVariantMap &candidate, quint64 generation)
{
    const QString id = candidate.value(QStringLiteral("id")).toString();
    if (id.isEmpty()) {
        m_netEaseCandidateOutcome = ProviderOutcome::CandidateRejected;
        tryNextNetEaseCandidate(generation);
        return;
    }
    m_pendingCandidate = candidate;
    startReply(netEaseLyricsUrl(id), ReplyKind::NetEaseLyrics, generation);
}

void Lyrics::startReply(const QUrl &url, ReplyKind kind, quint64 generation)
{
    if (generation != m_generation)
        return;

    if (m_reply) {
        QNetworkReply *oldReply = m_reply.data();
        m_reply = nullptr;
        oldReply->abort();
        oldReply->deleteLater();
    }

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Cache-Control", "no-cache, no-store");
    request.setRawHeader("Pragma", "no-cache");
    request.setRawHeader("Connection", "close");
    if (url.host().contains(QStringLiteral("music.163.com"))) {
        request.setRawHeader("User-Agent", kNetEaseUserAgent);
        request.setRawHeader("Referer", "https://music.163.com/");
    } else {
        request.setRawHeader("User-Agent", "Clavis/lyrics");
    }

    QNetworkReply *reply = m_manager->get(request);
    m_reply = reply;
    QPointer<QNetworkReply> guardedReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, guardedReply, kind, generation]() {
        if (guardedReply)
            handleReply(guardedReply.data(), kind, generation);
    });
}

void Lyrics::handleReply(QNetworkReply *reply, ReplyKind kind, quint64 generation)
{
    if (!reply)
        return;
    if (generation != m_generation || m_reply != reply) {
        // A generation change or replacement already transferred deletion
        // ownership to cancelInFlight()/startReply(). abort() may emit
        // finished() synchronously, so this callback must not delete or read
        // that reply a second time.
        return;
    }

    m_reply = nullptr;

    const bool requestFailed = reply->error() != QNetworkReply::NoError;
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    reply->deleteLater();

    const bool httpFailure = statusCode >= 400;
    const bool notFound = statusCode == 404;

    if (requestFailed || httpFailure) {
        switch (kind) {
        case ReplyKind::LrclibTrack:
            m_lrclibOutcome = notFound ? ProviderOutcome::NotFound : ProviderOutcome::TransportError;
            if (notFound)
                finishEmpty();
            else
                finishError(QStringLiteral("LRCLIB 请求失败"));
            return;
        case ReplyKind::LrclibSearch:
            m_lrclibOutcome = notFound ? ProviderOutcome::NotFound : ProviderOutcome::TransportError;
            startNetEaseSearch(generation);
            return;
        case ReplyKind::NetEaseSearch:
            m_netEaseSearchOutcome = notFound ? ProviderOutcome::NotFound : ProviderOutcome::TransportError;
            if (m_autoFallback) {
                startLrclibTrack(generation);
            } else if (notFound) {
                finishEmpty();
            } else {
                finishError(QStringLiteral("NetEase 搜索请求失败"));
            }
            return;
        case ReplyKind::NetEaseLyrics:
            m_netEaseCandidateOutcome =
                notFound ? ProviderOutcome::NoLyrics : ProviderOutcome::TransportError;
            if (notFound)
                m_netEaseSawNoLyrics = true;
            if (m_autoFallback)
                startLrclibTrack(generation);
            else if (notFound)
                finishEmpty();
            else
                finishError(QStringLiteral("NetEase 歌词请求失败"));
            return;
        }
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
    const bool validJson = parseError.error == QJsonParseError::NoError;
    if (!validJson) {
        switch (kind) {
        case ReplyKind::LrclibTrack:
            m_lrclibOutcome = ProviderOutcome::InvalidResponse;
            finishError(QStringLiteral("LRCLIB 返回了无效响应"));
            return;
        case ReplyKind::LrclibSearch:
            m_lrclibOutcome = ProviderOutcome::InvalidResponse;
            startNetEaseSearch(generation);
            return;
        case ReplyKind::NetEaseSearch:
            m_netEaseSearchOutcome = ProviderOutcome::InvalidResponse;
            if (m_autoFallback) {
                startLrclibTrack(generation);
            } else {
                finishError(QStringLiteral("NetEase 搜索返回了无效响应"));
            }
            return;
        case ReplyKind::NetEaseLyrics:
            m_netEaseCandidateOutcome = ProviderOutcome::InvalidResponse;
            if (m_autoFallback)
                startLrclibTrack(generation);
            else
                finishError(QStringLiteral("NetEase 歌词返回了无效响应"));
            return;
        }
    }

    switch (kind) {
    case ReplyKind::LrclibTrack:
        if (!document.isObject()) {
            m_lrclibOutcome = ProviderOutcome::InvalidResponse;
            if (m_autoFallback)
                startNetEaseSearch(generation);
            else
                finishError(QStringLiteral("LRCLIB 返回了无效响应"));
            return;
        }
        if (handleLrclibTrack(document.object(), generation)) {
            return;
        }
        if (m_lrclibOutcome == ProviderOutcome::NotFound) {
            finishEmpty();
        } else {
            finishError(QStringLiteral("LRCLIB 歌词内容不可用"));
        }
        return;

    case ReplyKind::LrclibSearch:
        if (!document.isArray()) {
            m_lrclibOutcome = ProviderOutcome::InvalidResponse;
        } else {
            handleLrclibSearch(document, generation);
        }
        startNetEaseSearch(generation);
        return;

    case ReplyKind::NetEaseSearch:
        if (document.isObject())
            handleNetEaseSearch(document, generation);
        else
            m_netEaseSearchOutcome = ProviderOutcome::InvalidResponse;
        if (m_autoFallback) {
            m_netEaseCandidateIndex = 0;
            tryNextNetEaseCandidate(generation);
        } else {
            if (m_netEaseSearchOutcome == ProviderOutcome::TransportError ||
                m_netEaseSearchOutcome == ProviderOutcome::InvalidResponse) {
                finishError(QStringLiteral("NetEase 搜索不可用"));
            } else if (m_candidates.isEmpty()) {
                finishEmpty();
            } else {
                setLoading(false);
                setStatus(QStringLiteral("empty"));
            }
        }
        return;

    case ReplyKind::NetEaseLyrics:
        if (!document.isObject()) {
            m_netEaseCandidateOutcome = ProviderOutcome::InvalidResponse;
        } else if (handleNetEaseLyrics(document.object(), generation)) {
            return;
        }
        if (m_autoFallback)
            tryNextNetEaseCandidate(generation);
        else if (m_netEaseCandidateOutcome == ProviderOutcome::NoLyrics)
            finishEmpty();
        else
            finishError(QStringLiteral("NetEase 歌词内容不可用"));
        return;
    }
}

bool Lyrics::handleLrclibTrack(const QJsonObject &json, quint64 generation)
{
    const QString synced =
        firstString(json, {QStringLiteral("syncedLyrics"), QStringLiteral("synced_lyrics")});
    const QString plain = firstString(json, {QStringLiteral("plainLyrics"), QStringLiteral("plain_lyrics")});
    if (synced.isEmpty() && plain.isEmpty()) {
        m_lrclibOutcome = ProviderOutcome::NotFound;
        return false;
    }

    QVariantMap candidate = m_selectedCandidate;
    const QString id = jsonId(json.value(QStringLiteral("id")));
    if (candidate.value(QStringLiteral("provider")).toString().isEmpty())
        candidate.insert(QStringLiteral("provider"), QStringLiteral("LRCLIB"));
    if (candidate.value(QStringLiteral("id")).toString().isEmpty() && !id.isEmpty())
        candidate.insert(QStringLiteral("id"), id);
    candidate.insert(QStringLiteral("title"),
                     firstString(json, {QStringLiteral("trackName"), QStringLiteral("name")}));
    candidate.insert(QStringLiteral("artist"),
                     firstString(json, {QStringLiteral("artistName"), QStringLiteral("artist")}));
    candidate.insert(QStringLiteral("album"),
                     firstString(json, {QStringLiteral("albumName"), QStringLiteral("album")}));
    candidate.insert(QStringLiteral("duration"), jsonDurationSeconds(json));
    candidate.insert(QStringLiteral("syncedLyrics"), synced);
    candidate.insert(QStringLiteral("plainLyrics"), plain);

    const bool accepted =
        acceptRawLyrics(QStringLiteral("LRCLIB"), synced, plain, candidate, generation, true);
    m_lrclibOutcome = accepted ? ProviderOutcome::Success : ProviderOutcome::ParseFailure;
    return accepted;
}

void Lyrics::handleLrclibSearch(const QJsonDocument &document, quint64 generation)
{
    if (generation != m_generation || !document.isArray())
        return;
    const QVariantList candidates = parseLrclibCandidates(document);
    appendCandidates(candidates);
    m_lrclibOutcome = candidates.isEmpty() ? ProviderOutcome::NotFound : ProviderOutcome::Success;
}

void Lyrics::handleNetEaseSearch(const QJsonDocument &document, quint64 generation)
{
    if (generation != m_generation)
        return;
    const QJsonObject result = document.object().value(QStringLiteral("result")).toObject();
    const QJsonValue songsValue = result.value(QStringLiteral("songs"));
    if (!songsValue.isArray()) {
        m_netEaseSearchOutcome = ProviderOutcome::InvalidResponse;
        return;
    }

    m_netEaseCandidates = parseNetEaseCandidates(document);
    appendCandidates(m_netEaseCandidates);
    if (songsValue.toArray().isEmpty())
        m_netEaseSearchOutcome = ProviderOutcome::NotFound;
    else if (m_netEaseCandidates.isEmpty())
        m_netEaseSearchOutcome = ProviderOutcome::CandidateRejected;
    else
        m_netEaseSearchOutcome = ProviderOutcome::Success;
}

bool Lyrics::handleNetEaseLyrics(const QJsonObject &json, quint64 generation)
{
    const QJsonValue lrcValue = json.value(QStringLiteral("lrc"));
    const QJsonValue translatedValue = json.value(QStringLiteral("tlyric"));
    if ((!lrcValue.isUndefined() && !lrcValue.isObject()) ||
        (!translatedValue.isUndefined() && !translatedValue.isObject()) ||
        (lrcValue.isUndefined() && translatedValue.isUndefined())) {
        m_netEaseCandidateOutcome = ProviderOutcome::InvalidResponse;
        return false;
    }

    m_netEaseSawValidLyricResponse = true;
    const QJsonObject lrc = json.value(QStringLiteral("lrc")).toObject();
    const QJsonObject translated = json.value(QStringLiteral("tlyric")).toObject();
    const QString synced = firstString(lrc, {QStringLiteral("lyric")});
    // Keep the translation even when a synchronized original exists: the UI
    // merges it below each line instead of dropping it.
    const QString plain = firstString(translated, {QStringLiteral("lyric")});
    if (synced.isEmpty() && plain.isEmpty()) {
        m_netEaseCandidateOutcome = ProviderOutcome::NoLyrics;
        m_netEaseSawNoLyrics = true;
        return false;
    }

    const bool accepted =
        acceptRawLyrics(QStringLiteral("NetEase"), synced, plain, m_pendingCandidate, generation, true);
    m_netEaseCandidateOutcome = accepted ? ProviderOutcome::Success : ProviderOutcome::ParseFailure;
    if (!accepted)
        m_netEaseSawParseFailure = true;
    return accepted;
}

void Lyrics::tryNextNetEaseCandidate(quint64 generation)
{
    if (generation != m_generation)
        return;

    while (m_netEaseCandidateIndex < m_netEaseCandidates.size()) {
        const QVariantMap candidate = m_netEaseCandidates.at(m_netEaseCandidateIndex++).toMap();
        if (candidate.value(QStringLiteral("score")).toDouble() < 0.0)
            continue;
        startNetEaseLyrics(candidate, generation);
        return;
    }

    if (m_netEaseSearchOutcome == ProviderOutcome::TransportError ||
        m_netEaseSearchOutcome == ProviderOutcome::InvalidResponse) {
        if (m_autoFallback) {
            startLrclibTrack(generation);
        } else {
            finishError(QStringLiteral("NetEase 搜索不可用"));
        }
    } else if (m_autoFallback) {
        // NetEase found no usable lyrics for this track; fall back to LRCLIB
        // for coverage (it never carries translations, but is a reliable
        // source for the original lines).
        startLrclibTrack(generation);
    } else if (m_netEaseSawParseFailure) {
        finishError(QStringLiteral("NetEase 歌词内容不可用"));
    } else {
        // A valid search with no lyrics is a normal not-found result, even if
        // LRCLIB previously returned HTTP 404 or a candidate was rejected.
        finishEmpty();
    }
}

void Lyrics::appendCandidates(const QVariantList &candidates)
{
    bool changed = false;
    for (const QVariant &value : candidates) {
        const QVariantMap candidate = value.toMap();
        if (candidate.value(QStringLiteral("provider")).toString().isEmpty() ||
            candidate.value(QStringLiteral("id")).toString().isEmpty()) {
            continue;
        }

        const QString identity = candidateIdentity(candidate);
        int existingIndex = -1;
        for (int i = 0; i < m_candidates.size(); ++i) {
            if (candidateIdentity(m_candidates.at(i).toMap()) == identity) {
                existingIndex = i;
                break;
            }
        }
        if (existingIndex < 0) {
            m_candidates.append(candidate);
            changed = true;
        } else if (m_candidates.at(existingIndex).toMap() != candidate) {
            m_candidates[existingIndex] = candidate;
            changed = true;
        }
    }
    if (changed)
        emit candidatesChanged();
}

QVariantList Lyrics::parseLrclibCandidates(const QJsonDocument &document) const
{
    QVariantList result;
    if (!document.isArray())
        return result;

    for (const QJsonValue &value : document.array()) {
        const QJsonObject item = value.toObject();
        const QString id = jsonId(item.value(QStringLiteral("id")));
        const QString synced =
            firstString(item, {QStringLiteral("syncedLyrics"), QStringLiteral("synced_lyrics")});
        const QString plain =
            firstString(item, {QStringLiteral("plainLyrics"), QStringLiteral("plain_lyrics")});
        if (id.isEmpty() || (synced.isEmpty() && plain.isEmpty()))
            continue;

        QVariantMap candidate =
            candidateWithIdentity(QStringLiteral("LRCLIB"), id,
                                  firstString(item, {QStringLiteral("trackName"), QStringLiteral("name")}),
                                  firstString(item, {QStringLiteral("artistName"), QStringLiteral("artist")}),
                                  firstString(item, {QStringLiteral("albumName"), QStringLiteral("album")}),
                                  jsonDurationSeconds(item));
        candidate.insert(QStringLiteral("syncedLyrics"), synced);
        candidate.insert(QStringLiteral("plainLyrics"), plain);
        result.append(candidate);
    }
    return result;
}

QVariantList Lyrics::parseNetEaseCandidates(const QJsonDocument &document) const
{
    QVariantList result;
    if (!document.isObject())
        return result;

    const QJsonArray songs =
        document.object().value(QStringLiteral("result")).toObject().value(QStringLiteral("songs")).toArray();
    for (const QJsonValue &value : songs) {
        const QJsonObject item = value.toObject();
        const QString id = jsonId(item.value(QStringLiteral("id")));
        if (id.isEmpty())
            continue;

        QStringList artistNames;
        const QJsonArray artists = item.value(QStringLiteral("artists")).toArray();
        for (const QJsonValue &artist : artists)
            artistNames.append(artist.toObject().value(QStringLiteral("name")).toString());
        if (artistNames.isEmpty()) {
            const QJsonObject artist = item.value(QStringLiteral("ar")).toObject();
            if (!artist.isEmpty())
                artistNames.append(artist.value(QStringLiteral("name")).toString());
        }

        const QJsonObject albumObject = item.value(QStringLiteral("album")).toObject();
        const QJsonObject alternateAlbum = item.value(QStringLiteral("al")).toObject();
        const QString album = firstString(albumObject, {QStringLiteral("name")}).isEmpty()
                                  ? firstString(alternateAlbum, {QStringLiteral("name")})
                                  : firstString(albumObject, {QStringLiteral("name")});
        QVariantMap candidate = candidateWithIdentity(
            QStringLiteral("NetEase"), id, item.value(QStringLiteral("name")).toString(),
            artistNames.join(QStringLiteral(", ")), album, jsonDurationSeconds(item));
        const double score = candidateScore(m_artist, m_title, m_album, m_duration, candidate);
        if (score < 0.0)
            continue;
        candidate.insert(QStringLiteral("score"), score);
        result.append(candidate);
    }

    std::stable_sort(result.begin(), result.end(), [](const QVariant &left, const QVariant &right) {
        return left.toMap().value(QStringLiteral("score")).toDouble() >
               right.toMap().value(QStringLiteral("score")).toDouble();
    });
    if (result.size() > kNetEaseSearchLimit)
        result = result.mid(0, kNetEaseSearchLimit);
    return result;
}

void Lyrics::cacheLyrics(const QString &provider, const QString &id, const QString &synced,
                         const QString &plain, const QVariantMap &candidate)
{
    if (id.isEmpty() || (synced.isEmpty() && plain.isEmpty()) ||
        provider.compare(QStringLiteral("Local"), Qt::CaseInsensitive) == 0)
        return;

    const QString path = cachePath(provider, id);
    if (path.isEmpty() || !QDir().mkpath(QFileInfo(path).absolutePath()))
        return;

    QJsonObject content{
        {QStringLiteral("version"), 2},
        {QStringLiteral("provider"), provider},
        {QStringLiteral("id"), id},
        {QStringLiteral("artist"), candidate.value(QStringLiteral("artist")).toString()},
        {QStringLiteral("title"), candidate.value(QStringLiteral("title")).toString()},
        {QStringLiteral("album"), candidate.value(QStringLiteral("album")).toString()},
        {QStringLiteral("duration"), candidate.value(QStringLiteral("duration")).toDouble()},
        {QStringLiteral("syncedLyrics"), synced},
        {QStringLiteral("plainLyrics"), plain},
    };

    QSaveFile contentFile(path);
    if (contentFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QByteArray bytes = QJsonDocument(content).toJson(QJsonDocument::Compact);
        contentFile.write(bytes);
        contentFile.commit();
    }

    QJsonObject index;
    QFile indexFile(cacheIndexPath());
    if (indexFile.open(QIODevice::ReadOnly)) {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(indexFile.readAll(), &parseError);
        if (parseError.error == QJsonParseError::NoError && document.isObject())
            index = document.object();
    }
    index.insert(cacheKey(), QJsonObject{
                                 {QStringLiteral("provider"), provider},
                                 {QStringLiteral("id"), id},
                                 {QStringLiteral("duration"), m_duration},
                             });

    QDir().mkpath(cacheDirectory());
    QSaveFile indexOutput(cacheIndexPath());
    if (indexOutput.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QByteArray bytes = QJsonDocument(index).toJson(QJsonDocument::Compact);
        indexOutput.write(bytes);
        indexOutput.commit();
    }
}

QString Lyrics::cacheDirectory() const
{
    const QByteArray configured = qgetenv("XDG_CACHE_HOME");
    const QString base =
        configured.isEmpty() ? QDir::homePath() + QStringLiteral("/.cache") : QString::fromUtf8(configured);
    return QDir::cleanPath(base + QStringLiteral("/clavis/lyrics/v2"));
}

QString Lyrics::cacheIndexPath() const { return cacheDirectory() + QStringLiteral("/index.json"); }

QString Lyrics::cachePath(const QString &provider, const QString &id) const
{
    if (provider.isEmpty() || id.isEmpty())
        return {};
    const QString providerPart = sanitizePathPart(provider);
    const QString idPart = sanitizePathPart(id);
    if (providerPart.isEmpty() || idPart.isEmpty())
        return {};
    return cacheDirectory() + QLatin1Char('/') + providerPart + QLatin1Char('/') + idPart +
           QStringLiteral(".json");
}

QString Lyrics::cacheKey() const
{
    const QByteArray identity =
        (normalized(m_artist) + QLatin1Char('\n') + normalized(m_title) + QLatin1Char('\n') +
         normalized(m_album) + QLatin1Char('\n') + QString::number(qRound64(m_duration * 1000.0)))
            .toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(identity, QCryptographicHash::Sha256).toHex());
}

QString Lyrics::localDirectory() const
{
    QString directory = QString::fromUtf8(qgetenv("CLAVIS_LYRICS_DIR"));
    if (directory.isEmpty()) {
        const QByteArray dataHome = qgetenv("XDG_DATA_HOME");
        const QString base = dataHome.isEmpty() ? QDir::homePath() + QStringLiteral("/.local/share")
                                                : QString::fromUtf8(dataHome);
        directory = base + QStringLiteral("/clavis/lyrics");
    }

    if (directory == QStringLiteral("~"))
        directory = QDir::homePath();
    else if (directory.startsWith(QStringLiteral("~/")))
        directory.replace(0, 1, QDir::homePath());
    return QDir::cleanPath(directory);
}

QString Lyrics::localLyricsPath() const
{
    if (m_title.isEmpty())
        return {};
    const QString directory = localDirectory();
    if (!QDir(directory).exists())
        return {};
    return findLocalLyricsPath(directory);
}

QString Lyrics::findLocalLyricsPath(const QString &directory) const
{
    const QString artistPart = sanitizePathPart(m_artist);
    const QString titlePart = sanitizePathPart(m_title);
    const QString canonicalBase =
        artistPart.isEmpty() ? titlePart : artistPart + QStringLiteral(" - ") + titlePart;
    const QString titleOnlyBase = titlePart;
    const QStringList desired = {canonicalBase, titleOnlyBase};

    const QDir root(directory);
    const QStringList directFiles = root.entryList(QDir::Files, QDir::Name);
    for (const QString &desiredBase : desired) {
        if (desiredBase.isEmpty())
            continue;
        const QString wanted = comparable(desiredBase);
        for (const QString &fileName : directFiles) {
            const QFileInfo info(root.filePath(fileName));
            if (info.suffix().compare(QStringLiteral("lrc"), Qt::CaseInsensitive) != 0)
                continue;
            if (comparable(info.completeBaseName()) == wanted)
                return info.absoluteFilePath();
        }
    }

    QDirIterator iterator(directory, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    QString fallback;
    while (iterator.hasNext()) {
        const QString path = iterator.next();
        const QFileInfo info(path);
        if (info.suffix().compare(QStringLiteral("lrc"), Qt::CaseInsensitive) != 0)
            continue;
        const QString base = comparable(info.completeBaseName());
        if (base == comparable(canonicalBase))
            return info.absoluteFilePath();
        if (fallback.isEmpty() && base == comparable(titleOnlyBase))
            fallback = info.absoluteFilePath();
        if (fallback.isEmpty() && !artistPart.isEmpty() && base.contains(comparable(artistPart)) &&
            base.contains(comparable(titlePart)))
            fallback = info.absoluteFilePath();
    }
    return fallback;
}

QUrl Lyrics::lrclibUrl(bool search) const
{
    QUrl url(QStringLiteral("https://lrclib.net/api/") +
             (search ? QStringLiteral("search") : QStringLiteral("get")));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("track_name"), m_title);
    query.addQueryItem(QStringLiteral("artist_name"), m_artist);
    if (!m_album.isEmpty())
        query.addQueryItem(QStringLiteral("album_name"), m_album);
    if (m_duration > 0.0)
        query.addQueryItem(QStringLiteral("duration"), QString::number(qRound(m_duration)));
    url.setQuery(query);
    return url;
}

QUrl Lyrics::netEaseSearchUrl() const
{
    QUrl url(QStringLiteral("https://music.163.com/api/search/get"));
    QUrlQuery query;
    const QString searchText = m_artist.isEmpty() ? m_title : m_title + QLatin1Char(' ') + m_artist;
    query.addQueryItem(QStringLiteral("s"), searchText);
    query.addQueryItem(QStringLiteral("type"), QStringLiteral("1"));
    query.addQueryItem(QStringLiteral("limit"), QString::number(kNetEaseSearchLimit));
    url.setQuery(query);
    return url;
}

QUrl Lyrics::netEaseLyricsUrl(const QString &id) const
{
    QUrl url(QStringLiteral("https://music.163.com/api/song/lyric"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("id"), id);
    query.addQueryItem(QStringLiteral("lv"), QStringLiteral("1"));
    query.addQueryItem(QStringLiteral("kv"), QStringLiteral("1"));
    query.addQueryItem(QStringLiteral("tv"), QStringLiteral("-1"));
    url.setQuery(query);
    return url;
}
