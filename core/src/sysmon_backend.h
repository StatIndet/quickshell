#pragma once

#include <QObject>
#include <vector>
#include "sysmon_types.h"
#include "sysmon/sampler.h"

// The central HUB (Facade Pattern) for accessing isolated micro-services
class SysmonBackend : public QObject {
    Q_OBJECT

public:
    static SysmonBackend& instance();
    
    // 分级更新接口
    void updateFast();      // 1s: CPU, RAM, Net
    void updateMedium();    // 2s: Temp, GPU, CPU Freq
    void updateSlow();      // 5s: Fan, Battery
    void updateGlacial();   // 30s: Disk, Uptime
    
    // --- Existing ---
    double getGlobalCpuUsage() const;
    std::vector<ProcessInfo> getTopProcesses(int limit = 10) const;
    double getRamUsagePercent() const;
    double getRamUsedGB() const;
    double getRamTotalGB() const;
    double getDiskUsagePercent() const;
    double getDiskUsedGB() const;
    double getDiskTotalGB() const;
    double getCoreTempCelsius() const;
    
    // --- New: Network ---
    double getNetDownBps() const;
    double getNetUpBps() const;
    
    // --- New: Battery ---
    double getBatteryPercent() const;
    QString getBatteryStatus() const;
    int getBatteryHealth() const;
    double getBatteryPowerW() const;
    bool hasBattery() const;
    
    // --- New: GPU ---
    double getGpuUsagePercent() const;
    double getGpuTempCelsius() const;
    
    // --- New: Misc ---
    int getFanRpm() const;
    double getCpuFreqGHz() const;
    QString getUptime() const;
    QString getSystemUser() const;
    QString getHostName() const;
    QString getWmName() const;
    QString getKernelRelease() const;
    QString getShellName() const;
    QString getDistroId() const;
    QString getDistroName() const;
    QString getChassis() const;
    QString getOsAgeText() const;

private:
    explicit SysmonBackend(QObject* parent = nullptr);
    ~SysmonBackend() override = default;
    
    SysmonBackend(const SysmonBackend&) = delete;
    SysmonBackend& operator=(const SysmonBackend&) = delete;

    void mergeSnapshot(Clavis::Sysmon::Snapshot snapshot);

    mutable Clavis::Sysmon::Sampler m_sampler;
    Clavis::Sysmon::Snapshot m_snapshot;
};
