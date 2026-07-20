#pragma once

#include <atomic>
#include <mutex>
#include <string>
#include <thread>

struct AudioLevelSnapshot {
    bool available = false;
    long long timestampMs = 0;
    double rms = 0.0;
    double peak = 0.0;
    double normalizedAmplitude = 0.0;
    std::string error;
};

class AudioLevelCollector {
public:
    AudioLevelCollector();
    ~AudioLevelCollector();

    AudioLevelCollector(const AudioLevelCollector &) = delete;
    AudioLevelCollector &operator=(const AudioLevelCollector &) = delete;

    void start(const std::string &targetNode, bool captureSink);
    void stop();
    AudioLevelSnapshot snapshot() const;
    void setAvailable(bool available, const std::string &error = {});
    void consume(const int16_t *samples, unsigned int count);

private:
    mutable std::mutex m_mutex;
    std::thread m_thread;
    std::atomic_bool m_stopRequested{false};
    std::string m_targetNode;
    bool m_captureSink = false;
    AudioLevelSnapshot m_snapshot;

    void run();
};
