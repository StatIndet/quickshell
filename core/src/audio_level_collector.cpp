#include "audio_level_collector.h"

#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>

#include <algorithm>
#include <chrono>
#include <cmath>

namespace {

struct PipewireLevelState {
    AudioLevelCollector *collector = nullptr;
    pw_main_loop *loop = nullptr;
    pw_stream *stream = nullptr;
    spa_source *timer = nullptr;
    std::atomic_bool *stopRequested = nullptr;
};

long long nowMs()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::system_clock::now().time_since_epoch())
        .count();
}

double clamp01(double value)
{
    return std::clamp(value, 0.0, 1.0);
}

void handleStopTimer(void *data, uint64_t)
{
    auto *state = static_cast<PipewireLevelState *>(data);
    if (state->stopRequested
        && state->stopRequested->load(std::memory_order_acquire)
        && state->loop) {
        pw_main_loop_quit(state->loop);
    }
}

void handleLevelProcess(void *data)
{
    auto *state = static_cast<PipewireLevelState *>(data);
    if (!state->stream || !state->collector)
        return;

    pw_buffer *buffer = pw_stream_dequeue_buffer(state->stream);
    if (!buffer)
        return;

    const spa_buffer *spaBuffer = buffer->buffer;
    if (spaBuffer->n_datas > 0 && spaBuffer->datas[0].data
        && spaBuffer->datas[0].chunk) {
        const spa_data &dataBuffer = spaBuffer->datas[0];
        const spa_chunk *chunk = dataBuffer.chunk;
        if (chunk->offset < dataBuffer.maxsize) {
            const uint32_t byteCount =
                std::min(chunk->size, dataBuffer.maxsize - chunk->offset);
            const auto *bytes =
                static_cast<const uint8_t *>(dataBuffer.data) + chunk->offset;
            const auto *samples = reinterpret_cast<const int16_t *>(bytes);
            state->collector->consume(
                samples,
                static_cast<unsigned int>(byteCount / sizeof(int16_t)));
        }
    }

    pw_stream_queue_buffer(state->stream, buffer);
}

void handleLevelStateChanged(void *data, pw_stream_state,
                             pw_stream_state state, const char *message)
{
    auto *pwState = static_cast<PipewireLevelState *>(data);
    if (!pwState->collector)
        return;

    if (state == PW_STREAM_STATE_STREAMING
        || state == PW_STREAM_STATE_PAUSED) {
        pwState->collector->setAvailable(true);
    } else if (state == PW_STREAM_STATE_ERROR) {
        pwState->collector->setAvailable(
            false, message ? std::string(message)
                           : std::string("PipeWire audio level stream failed"));
        if (pwState->loop)
            pw_main_loop_quit(pwState->loop);
    }
}

} // namespace

AudioLevelCollector::AudioLevelCollector() = default;

AudioLevelCollector::~AudioLevelCollector()
{
    stop();
}

void AudioLevelCollector::start(const std::string &targetNode, bool captureSink)
{
    stop();
    {
        std::scoped_lock lock(m_mutex);
        m_targetNode = targetNode;
        m_captureSink = captureSink;
        m_snapshot = {};
    }
    if (targetNode.empty()) {
        setAvailable(false, "Audio source node is empty");
        return;
    }

    m_stopRequested.store(false, std::memory_order_release);
    m_thread = std::thread(&AudioLevelCollector::run, this);
}

void AudioLevelCollector::stop()
{
    if (!m_thread.joinable())
        return;
    m_stopRequested.store(true, std::memory_order_release);
    m_thread.join();
    std::scoped_lock lock(m_mutex);
    m_snapshot.available = false;
    m_snapshot.rms = 0.0;
    m_snapshot.peak = 0.0;
    m_snapshot.normalizedAmplitude = 0.0;
}

AudioLevelSnapshot AudioLevelCollector::snapshot() const
{
    std::scoped_lock lock(m_mutex);
    return m_snapshot;
}

void AudioLevelCollector::run()
{
    std::string targetNode;
    bool captureSink = false;
    {
        std::scoped_lock lock(m_mutex);
        targetNode = m_targetNode;
        captureSink = m_captureSink;
    }

    pw_init(nullptr, nullptr);
    PipewireLevelState state;
    state.collector = this;
    state.stopRequested = &m_stopRequested;
    state.loop = pw_main_loop_new(nullptr);
    if (!state.loop) {
        setAvailable(false, "Unable to create the PipeWire audio level loop");
        pw_deinit();
        return;
    }

    timespec timerInterval = {0, 25 * SPA_NSEC_PER_MSEC};
    state.timer =
        pw_loop_add_timer(pw_main_loop_get_loop(state.loop), handleStopTimer, &state);
    if (!state.timer) {
        setAvailable(false, "Unable to create the PipeWire stop timer");
        pw_main_loop_destroy(state.loop);
        pw_deinit();
        return;
    }
    pw_loop_update_timer(pw_main_loop_get_loop(state.loop), state.timer,
                         &timerInterval, &timerInterval, false);

    auto *props = pw_properties_new(
        PW_KEY_MEDIA_TYPE, "Audio",
        PW_KEY_MEDIA_CATEGORY, "Capture",
        PW_KEY_MEDIA_ROLE, "Production",
        PW_KEY_TARGET_OBJECT, targetNode.c_str(),
        PW_KEY_NODE_NAME, "clavis-shell-audio-level",
        nullptr);
    pw_properties_set(props, PW_KEY_NODE_PASSIVE, "true");
    pw_properties_set(props, PW_KEY_NODE_VIRTUAL, "true");
    pw_properties_set(props, PW_KEY_STREAM_DONT_REMIX, "false");
    if (captureSink)
        pw_properties_set(props, PW_KEY_STREAM_CAPTURE_SINK, "true");

    uint8_t paramBuffer[1024];
    spa_pod_builder builder;
    spa_pod_builder_init(&builder, paramBuffer, sizeof(paramBuffer));
    spa_audio_info_raw info{};
    info.format = SPA_AUDIO_FORMAT_S16;
    info.rate = 48000;
    info.channels = 1;
    const spa_pod *params[] = {
        spa_format_audio_raw_build(&builder, SPA_PARAM_EnumFormat, &info),
    };

    pw_stream_events events{};
    events.version = PW_VERSION_STREAM_EVENTS;
    events.state_changed = handleLevelStateChanged;
    events.process = handleLevelProcess;
    state.stream = pw_stream_new_simple(
        pw_main_loop_get_loop(state.loop), "clavis-shell-audio-level",
        props, &events, &state);
    if (!state.stream) {
        setAvailable(false, "Unable to create the PipeWire audio level stream");
        pw_main_loop_destroy(state.loop);
        pw_deinit();
        return;
    }

    const int result = pw_stream_connect(
        state.stream, PW_DIRECTION_INPUT, PW_ID_ANY,
        static_cast<pw_stream_flags>(PW_STREAM_FLAG_AUTOCONNECT
                                     | PW_STREAM_FLAG_MAP_BUFFERS
                                     | PW_STREAM_FLAG_RT_PROCESS),
        params, 1);
    if (result < 0) {
        setAvailable(false, "Unable to connect the PipeWire audio level stream");
        pw_stream_destroy(state.stream);
        pw_main_loop_destroy(state.loop);
        pw_deinit();
        return;
    }

    pw_main_loop_run(state.loop);
    pw_stream_destroy(state.stream);
    pw_main_loop_destroy(state.loop);
    pw_deinit();
}

void AudioLevelCollector::setAvailable(bool available, const std::string &error)
{
    std::scoped_lock lock(m_mutex);
    m_snapshot.available = available;
    m_snapshot.error = error;
    if (!available) {
        m_snapshot.rms = 0.0;
        m_snapshot.peak = 0.0;
        m_snapshot.normalizedAmplitude = 0.0;
    }
}

void AudioLevelCollector::consume(const int16_t *samples, unsigned int count)
{
    if (!samples || count == 0)
        return;

    double squareSum = 0.0;
    double peak = 0.0;
    for (unsigned int index = 0; index < count; ++index) {
        const double sample =
            static_cast<double>(samples[index]) / 32768.0;
        squareSum += sample * sample;
        peak = std::max(peak, std::abs(sample));
    }
    const double rms = std::sqrt(squareSum / static_cast<double>(count));
    constexpr double gate = 0.006;
    const double rmsMapped =
        std::pow(clamp01((rms - gate) / (0.25 - gate)), 0.45);
    const double peakMapped =
        std::pow(clamp01((peak - gate) / (0.90 - gate)), 0.55);
    const double target = clamp01(std::max(rmsMapped, peakMapped * 0.72));

    std::scoped_lock lock(m_mutex);
    const double alpha =
        target > m_snapshot.normalizedAmplitude ? 0.58 : 0.16;
    m_snapshot.normalizedAmplitude +=
        (target - m_snapshot.normalizedAmplitude) * alpha;
    m_snapshot.rms = rms;
    m_snapshot.peak = peak;
    m_snapshot.timestampMs = nowMs();
    m_snapshot.available = true;
    m_snapshot.error.clear();
}
