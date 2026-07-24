#include "sysmon_plugin.h"
#include "sysmon_backend.h"

SysmonPlugin::SysmonPlugin(QObject *parent) 
    : QObject(parent),
      m_cpuUsage(0), m_ramUsage(0), m_ramUsedGB(0), m_ramTotalGB(0),
      m_netDownBps(0), m_netUpBps(0),
      m_coreTemp(0), m_gpuTemp(0), m_gpuUsage(0),
      m_cpuFreqGHz(0),
      m_fanRpm(0), m_batteryPercent(0), m_batteryHealth(100), m_batteryPowerW(0),
      m_diskUsage(0), m_diskUsedGB(0), m_diskTotalGB(0),
      m_processModel(new ProcessModel(this))
{
    // 四级定时器
    connect(&m_fastTimer, &QTimer::timeout, this, &SysmonPlugin::onFastTick);
    m_fastTimer.setInterval(1000);
    m_fastTimer.start();
    
    connect(&m_mediumTimer, &QTimer::timeout, this, &SysmonPlugin::onMediumTick);
    m_mediumTimer.setInterval(2000);
    m_mediumTimer.start();
    
    connect(&m_slowTimer, &QTimer::timeout, this, &SysmonPlugin::onSlowTick);
    m_slowTimer.setInterval(5000);
    m_slowTimer.start();
    
    connect(&m_glacialTimer, &QTimer::timeout, this, &SysmonPlugin::onGlacialTick);
    m_glacialTimer.setInterval(30000);
    m_glacialTimer.start();
    
    // 首次全量采集
    onFastTick();
    onMediumTick();
    onSlowTick();
    onGlacialTick();
}

// === Getters ===

// Fast
double SysmonPlugin::cpuUsage() const { return m_cpuUsage; }
double SysmonPlugin::ramUsage() const { return m_ramUsage; }
double SysmonPlugin::ramUsedGB() const { return m_ramUsedGB; }
double SysmonPlugin::ramTotalGB() const { return m_ramTotalGB; }
double SysmonPlugin::netDownBps() const { return m_netDownBps; }
double SysmonPlugin::netUpBps() const { return m_netUpBps; }
ProcessModel* SysmonPlugin::processes() const { return m_processModel; }

// Medium
double SysmonPlugin::coreTemp() const { return m_coreTemp; }
double SysmonPlugin::gpuTemp() const { return m_gpuTemp; }
double SysmonPlugin::gpuUsage() const { return m_gpuUsage; }
double SysmonPlugin::cpuFreqGHz() const { return m_cpuFreqGHz; }

// Slow
int SysmonPlugin::fanRpm() const { return m_fanRpm; }
double SysmonPlugin::batteryPercent() const { return m_batteryPercent; }
QString SysmonPlugin::batteryStatus() const { return m_batteryStatus; }
int SysmonPlugin::batteryHealth() const { return m_batteryHealth; }
double SysmonPlugin::batteryPowerW() const { return m_batteryPowerW; }
bool SysmonPlugin::hasBattery() const { return SysmonBackend::instance().hasBattery(); }

// Glacial
double SysmonPlugin::diskUsage() const { return m_diskUsage; }
double SysmonPlugin::diskUsedGB() const { return m_diskUsedGB; }
double SysmonPlugin::diskTotalGB() const { return m_diskTotalGB; }
QString SysmonPlugin::uptime() const { return m_uptime; }

QString SysmonPlugin::systemUser() const { return SysmonBackend::instance().getSystemUser(); }
QString SysmonPlugin::hostName() const { return SysmonBackend::instance().getHostName(); }
QString SysmonPlugin::wmName() const { return SysmonBackend::instance().getWmName(); }
QString SysmonPlugin::kernelRelease() const { return SysmonBackend::instance().getKernelRelease(); }
QString SysmonPlugin::shellName() const { return SysmonBackend::instance().getShellName(); }
QString SysmonPlugin::distroId() const { return SysmonBackend::instance().getDistroId(); }
QString SysmonPlugin::distroName() const { return SysmonBackend::instance().getDistroName(); }
QString SysmonPlugin::chassis() const { return SysmonBackend::instance().getChassis(); }
QString SysmonPlugin::osAgeText() const { return SysmonBackend::instance().getOsAgeText(); }

// === 分级更新槽 ===

void SysmonPlugin::onFastTick() {
    auto &be = SysmonBackend::instance();
    be.updateFast();
    
    m_cpuUsage   = be.getGlobalCpuUsage();
    m_ramUsage   = be.getRamUsagePercent();
    m_ramUsedGB  = be.getRamUsedGB();
    m_ramTotalGB = be.getRamTotalGB();
    m_netDownBps = be.getNetDownBps();
    m_netUpBps   = be.getNetUpBps();
    
    emit fastDataChanged();
}

void SysmonPlugin::onMediumTick() {
    auto &be = SysmonBackend::instance();
    be.updateMedium();
    
    m_coreTemp    = be.getCoreTempCelsius();
    m_gpuTemp     = be.getGpuTempCelsius();
    m_gpuUsage    = be.getGpuUsagePercent();
    m_cpuFreqGHz  = be.getCpuFreqGHz();
    
    emit mediumDataChanged();
}

void SysmonPlugin::onSlowTick() {
    auto &be = SysmonBackend::instance();
    be.updateSlow();
    
    m_fanRpm         = be.getFanRpm();
    m_batteryPercent = be.getBatteryPercent();
    m_batteryStatus  = be.getBatteryStatus();
    m_batteryHealth  = be.getBatteryHealth();
    m_batteryPowerW  = be.getBatteryPowerW();
    
    emit slowDataChanged();
}

void SysmonPlugin::onGlacialTick() {
    auto &be = SysmonBackend::instance();
    be.updateGlacial();
    
    m_diskUsage   = be.getDiskUsagePercent();
    m_diskUsedGB  = be.getDiskUsedGB();
    m_diskTotalGB = be.getDiskTotalGB();
    m_uptime      = be.getUptime();
    
    emit glacialDataChanged();
}
