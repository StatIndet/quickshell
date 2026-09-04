# 项目职责审计

## Clavis Shell

`core/src/` 和 `core/plugin/` 提供：

- `Clavis.Niri`：Niri IPC、窗口、工作区、输出和窗口图标；
- `Clavis.Weather` / `Clavis.WeatherMap`：Open-Meteo、地图凭据和 RainViewer metadata；地图渲染与网络瓦片缓存由 MapLibre Native Qt 负责；
- `Clavis.Cava`：PipeWire 实时采集、RMS/Peak、频谱和 libcava；
- `Clavis.Lyrics`：异步 Local/LRCLIB/NetEase provider、缓存、LRC 和 seek 映射；
- `Clavis.Media`、`Clavis.Keyboard`、`Clavis.I18n`、`Clavis.Runtime`、`M3Shapes`。

## key-cli

Python wheel 只提供 `shell`、`ipc`、`record`、`audio`、`clipboard`、`doctor` 和
`version`。它编排 `qs`、gpu-screen-recorder、slurp、FFmpeg、PulseAudio/PipeWire
兼容的 `pactl`、cliphist 和 wl-clipboard；不会读取 `/proc` 实现系统监测，也不会拥有
QML 状态或天气/歌词模型。

## keytop

`keytop` 独立拥有系统采样、TUI、JSON snapshot 和 JSONL stream。Clavis 直接启动
`keytop value stream`，不经过 `key-cli`。

Clavis 对系统信息采用四种独立生命周期：静态 identity 在 Quickshell 进程启动时通过
`keytop value system` 读取一次；uptime 在可见 consumer 存在时从 `/proc/uptime` 校准
一次并用本地单调时钟更新；电池直接使用 `Quickshell.Services.UPower`；CPU、GPU、
Memory、Disk、Network 则按可见 owner 的 module union 维持单个 keytop JSONL stream，
所有 active module 共用用户配置的采样间隔。

## 明确删除

Clavis 不再包含旧 C++ CLI、系统监测 plugin、录屏/录音 backend、天气 CLI bridge、
投屏 cast、应用内版本/安装/回滚管理，也不创建额外的源码运行模式编排脚本。
