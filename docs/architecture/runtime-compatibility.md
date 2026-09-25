# 运行时边界

Shell 的原生 module 与 QML 源码由同一次 CMake 构建产生，所有自制 QML import 使用
无版本 URI。产品版本和 JSON `schemaVersion` 独立于 QML import 版本。

系统监测协议由 `key sysmon stream --format jsonl` 提供，Shell 校验
`schemaVersion`、时间戳、序列号和模块字段；失联时显示明确的 stale/error 状态。
录屏、录音和剪贴板协议由 `key-cli` 提供，Shell 只消费参数数组和机器 JSON。

天气、Cava、歌词和 Niri 状态在 Shell 进程内提供响应式模型，避免高频数据经过 CLI
或 Python 中转。
