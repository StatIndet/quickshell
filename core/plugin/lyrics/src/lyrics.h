#pragma once

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Lyrics : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Lyrics)
    QML_SINGLETON

    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY hasLyricsChanged)
    Q_PROPERTY(bool hasSynchronizedLyrics READ hasSynchronizedLyrics NOTIFY synchronizedChanged)
    Q_PROPERTY(QVariantList lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QVariantList candidates READ candidates NOTIFY candidatesChanged)
    Q_PROPERTY(QVariantMap selectedCandidate READ selectedCandidate NOTIFY selectedCandidateChanged)
    Q_PROPERTY(QString provider READ provider NOTIFY providerChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(double offsetMs READ offsetMs WRITE setOffsetMs NOTIFY offsetMsChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY trackChanged)
    Q_PROPERTY(QString trackAlbum READ trackAlbum NOTIFY trackChanged)
    Q_PROPERTY(double trackDuration READ trackDuration NOTIFY trackChanged)
    Q_PROPERTY(QString trackPlayerId READ trackPlayerId NOTIFY trackChanged)

  public:
    explicit Lyrics(QObject *parent = nullptr);

    // Tests and embedders may provide a deterministic HTTP transport before
    // starting a request. The QML singleton keeps the default manager.
    void setNetworkAccessManager(QNetworkAccessManager *manager);

    QString status() const { return m_status; }
    bool loading() const { return m_loading; }
    bool hasLyrics() const { return m_hasLyrics; }
    bool hasSynchronizedLyrics() const { return m_hasSynchronizedLyrics; }
    QVariantList lyrics() const { return m_lyrics; }
    QVariantList candidates() const { return m_candidates; }
    QVariantMap selectedCandidate() const { return m_selectedCandidate; }
    QString provider() const { return m_provider; }
    QString error() const { return m_error; }
    double offsetMs() const { return m_offsetMs; }
    void setOffsetMs(double offsetMs);

    QString trackArtist() const { return m_artist; }
    QString trackTitle() const { return m_title; }
    QString trackAlbum() const { return m_album; }
    double trackDuration() const { return m_duration; }
    QString trackPlayerId() const { return m_playerId; }

    Q_INVOKABLE void setTrack(const QString &artist, const QString &title, const QString &album = {},
                              double duration = 0.0, const QString &playerId = {});
    Q_INVOKABLE void clearTrack();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void requestCandidates();
    Q_INVOKABLE void selectCandidate(int index);
    Q_INVOKABLE QVariantList parseLrc(const QString &text, double offsetMs = 0.0) const;
    Q_INVOKABLE int indexForTime(double positionSeconds) const;
    Q_INVOKABLE double timeForIndex(int index) const;

  signals:
    void statusChanged();
    void loadingChanged();
    void hasLyricsChanged();
    void synchronizedChanged();
    void lyricsChanged();
    void candidatesChanged();
    void selectedCandidateChanged();
    void providerChanged();
    void errorChanged();
    void offsetMsChanged();
    void trackChanged();

  private:
    enum class ReplyKind {
        LrclibTrack,
        LrclibSearch,
        NetEaseSearch,
        NetEaseLyrics,
    };

    enum class ProviderOutcome {
        Pending,
        NotFound,
        CandidateRejected,
        NoLyrics,
        Success,
        TransportError,
        InvalidResponse,
        ParseFailure,
    };

    QNetworkAccessManager m_defaultManager;
    QNetworkAccessManager *m_manager = &m_defaultManager;
    QPointer<QNetworkReply> m_reply;
    QTimer m_loadDebounce;

    quint64 m_generation = 0;
    bool m_forceNetwork = false;
    bool m_autoFallback = false;
    int m_netEaseCandidateIndex = 0;

    ProviderOutcome m_lrclibOutcome = ProviderOutcome::Pending;
    ProviderOutcome m_netEaseSearchOutcome = ProviderOutcome::Pending;
    ProviderOutcome m_netEaseCandidateOutcome = ProviderOutcome::Pending;
    bool m_netEaseSawValidLyricResponse = false;
    bool m_netEaseSawNoLyrics = false;
    bool m_netEaseSawParseFailure = false;

    bool m_loading = false;
    bool m_hasLyrics = false;
    bool m_hasSynchronizedLyrics = false;
    QString m_status = QStringLiteral("idle");
    QVariantList m_lyrics;
    QVariantList m_candidates;
    QVariantMap m_selectedCandidate;
    QVariantList m_netEaseCandidates;
    QVariantMap m_pendingCandidate;
    QString m_provider;
    QString m_error;

    QString m_artist;
    QString m_title;
    QString m_album;
    double m_duration = 0.0;
    QString m_playerId;
    double m_offsetMs = 0.0;

    // The raw provider payload is retained so changing offset can rebuild the
    // timeline without asking a provider again.
    QString m_sourceText;
    QString m_sourceTranslation;
    QString m_sourceProvider;
    QVariantMap m_sourceCandidate;

    void setStatus(const QString &status);
    void setLoading(bool loading);
    void setHasLyrics(bool value);
    void setHasSynchronizedLyrics(bool value);
    void setProvider(const QString &provider);
    void setError(const QString &error);
    void setSelectedCandidate(const QVariantMap &candidate);
    void clearLyrics();
    void clearCandidates();
    void clearSource();
    void resetProviderOutcomes();
    void resetNetEaseSession();

    quint64 beginGeneration();
    void cancelInFlight();
    void scheduleLoad();
    void startLoad(quint64 generation, bool bypassCache);

    bool loadLocalLyrics(quint64 generation);
    bool loadCachedLyrics(quint64 generation);
    bool acceptRawLyrics(const QString &provider, const QString &synced, const QString &plain,
                         const QVariantMap &candidate, quint64 generation, bool writeCache);
    QVariantList mergeTranslation(const QVariantList &lines, const QString &translationLrc) const;
    void finishEmpty(const QString &message = {});
    void finishError(const QString &message);
    void rebuildTimelineFromSource();

    void startLrclibTrack(quint64 generation);
    void startLrclibSearch(quint64 generation);
    void startNetEaseSearch(quint64 generation);
    void startNetEaseLyrics(const QVariantMap &candidate, quint64 generation);
    void startReply(const QUrl &url, ReplyKind kind, quint64 generation);
    void handleReply(QNetworkReply *reply, ReplyKind kind, quint64 generation);

    bool handleLrclibTrack(const QJsonObject &json, quint64 generation);
    void handleLrclibSearch(const QJsonDocument &document, quint64 generation);
    void handleNetEaseSearch(const QJsonDocument &document, quint64 generation);
    bool handleNetEaseLyrics(const QJsonObject &json, quint64 generation);
    void tryNextNetEaseCandidate(quint64 generation);

    void appendCandidates(const QVariantList &candidates);
    QVariantList parseLrclibCandidates(const QJsonDocument &document) const;
    QVariantList parseNetEaseCandidates(const QJsonDocument &document) const;

    void cacheLyrics(const QString &provider, const QString &id, const QString &synced, const QString &plain,
                     const QVariantMap &candidate);
    QString cacheDirectory() const;
    QString cacheIndexPath() const;
    QString cachePath(const QString &provider, const QString &id) const;
    QString cacheKey() const;
    QString localDirectory() const;
    QString localLyricsPath() const;
    QString findLocalLyricsPath(const QString &directory) const;

    QUrl lrclibUrl(bool search) const;
    QUrl netEaseSearchUrl() const;
    QUrl netEaseLyricsUrl(const QString &id) const;
};
