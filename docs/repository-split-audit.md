# 项目职责审计

## Clavis Shell

`core/src/` 和 `core/plugin/` 提供：

- `Clavis.Niri`：Niri IPC、窗口、工作区、输出和窗口图标；
- `Clavis.Weather` / `Clavis.WeatherMap`：Open-Meteo、地图凭据和 RainViewer metadata；地图渲染与网络瓦片缓存由 MapLibre Native Qt 负责；
- `Clavis.Cava`：PipeWire 实时采集、RMS/Peak、频谱和 libcava；
- `Clavis.Lyrics`：异步 Local/LRCLIB/NetEase provider、缓存、LRC 和 seek 映射；
- `Clavis.Media`、`Clavis.Keyboard`、`Clavis.I18n`、`Clavis.Runtime`。

`M3Shapes` 由系统包提供（Arch：`qt6-m3shapes-git`），是外部 QML 运行时依赖。

## key-cli

Python 命令负责 `shell`、`ipc`、`record`、`audio`、`clipboard`、`keyboard`、`sysmon`、
`doctor` 和 `version`。`key sysmon` 使用 `exec` 切换到独立 C++ 采样进程，直接输出
JSON/JSONL。可选功耗 helper 只读取固定的 RAPL 计数文件；键盘 uaccess 授权仍属于
用户级设备权限，不能视作 Shell 与后端之间的权限隔离。

Clavis 对系统信息采用四种独立生命周期：静态 identity 在 Quickshell 进程启动时通过
`key sysmon system` 读取一次；uptime 在可见 consumer 存在时从 `/proc/uptime` 校准
一次并用本地单调时钟更新；电池直接使用 `Quickshell.Services.UPower`；CPU、GPU、
Memory、Disk、Network 则按可见 owner 的 module union 维持单个 JSONL stream，
所有 active module 共用用户配置的采样间隔。

`keytop` 已停止维护，其 TUI 不再是产品入口。

## 明确删除

Clavis 不再包含旧 C++ CLI、系统监测 plugin、录屏/录音 backend、天气 CLI bridge、
投屏 cast、应用内版本/安装/回滚管理，也不创建额外的源码运行模式编排脚本。
