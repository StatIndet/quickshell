#pragma once

#include <QtGlobal>

#include <vector>

enum class AudioVisualSource {
    Microphone,
    System,
};

class AudioVisualAnalyzer {
public:
    explicit AudioVisualAnalyzer(
        AudioVisualSource source = AudioVisualSource::Microphone);

    void reset(AudioVisualSource source);
    void addSample(double rms, double peak, bool available = true);
    double commit(qint64 timestampMs);

private:
    AudioVisualSource m_source = AudioVisualSource::Microphone;
    std::vector<double> m_windowRms;
    std::vector<double> m_windowPeaks;

    double summarizeWindow();
};
