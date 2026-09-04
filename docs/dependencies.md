# 依赖

## Clavis Shell 构建依赖

- Qt 6 Core、Gui、Qml、Quick、Network、ShaderTools、LinguistTools
- Qt6Keychain
- MapLibre Native Qt（Arch Linux 软件包：`maplibre-native-qt`，包含 QtLocation `maplibre` plugin 与 `MapLibre 3.0` QML module）
- CMake 与 Ninja
- PipeWire `libpipewire-0.3`
- libcava/cava
- Quickshell（运行时）

Clavis 不再编译 CLI、系统监测 TUI、录屏或音频文件录制后端，因此不依赖 ncursesw、
FFmpeg、ffprobe、pactl、cliphist、wl-copy 或投屏后端。实时 Cava plugin 只使用
PipeWire/libcava。

## key-cli 运行依赖

`key-cli` 是无 Python runtime dependency 的 wheel。`key doctor --json` 检查以下系统
命令并标记受影响功能：

| 命令 | 功能 |
| --- | --- |
| `qs` | Shell 生命周期与 IPC |
| `gpu-screen-recorder` | 屏幕录制 |
| `slurp` | 区域录制选择 |
| `ffmpeg` | GIF 后处理、音频文件录制 |
| `ffprobe` | 音频文件验证 |
| `pactl` | 麦克风、默认输出和 monitor source 解析 |
| `cliphist` | 剪贴板历史 |
| `wl-copy` / `wl-paste` | MIME 恢复和监听 |

这些是发行版运行时依赖，不写入 wheel 的 Python dependencies。
