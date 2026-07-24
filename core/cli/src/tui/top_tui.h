#pragma once

#include <QString>

#include <memory>

namespace Clavis::Sysmon {
class Sampler;
}

class TopTui {
public:
    struct Options {
        int refreshIntervalMs = 1000;
        bool forceAscii = false;
    };

    explicit TopTui(Clavis::Sysmon::Sampler &sampler);
    TopTui(Clavis::Sysmon::Sampler &sampler, const Options &options);
    ~TopTui();

    TopTui(const TopTui &) = delete;
    TopTui &operator=(const TopTui &) = delete;

    int run();
    QString errorMessage() const;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};
