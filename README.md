> [!WARNING]
> 当前项目仍未完工，仅作为demo。

## 项目说明

.

### 预览
灵动岛媒体
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif1.gif" width="500">
</p>
小工具
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif2.gif" width="500">
</p>
灵动岛 dashboard
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif3.gif" width="500">
</p>
Launcher
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif4.gif" width="500">
</p>

### 天气图标

Meteocons 资源不纳入 Git；动画图标可从 npm 包 [`@meteocons/lottie`](https://www.npmjs.com/package/@meteocons/lottie) 下载，并将包内容放入 `assets/icons/weather/meteocons/lottie/`。

## `key` 与系统监测

系统监测由 `core/src/sysmon/` 中的共享 C++ 核心提供。QML plugin
保留兼容包装，`key sysmon` 和 `key top` 直接链接同一个 collector /
sampler；左侧边栏的 `SystemMonitorService` 只消费一个长期运行的 JSONL
数据流，不在 QML 中读取 `/proc` 或计算速率。

### 构建与安装

除 Qt 6、Qt6Keychain、PipeWire 和 Cava 等原有依赖外，构建 `key top`
还需要 `pkg-config` 可发现的 `ncursesw`。从仓库根目录执行：

```bash
cmake -S core -B core/build
cmake --build core/build
env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
  ctest --test-dir core/build --output-on-failure
sudo cmake --install core/build
sudo cp -a core/build/Clavis core/build/M3Shapes /usr/lib64/qt6/qml/
```

`cmake --install` 将单一 CLI 入口 `key` 安装到 CMake 的
`CMAKE_INSTALL_BINDIR`（默认前缀下通常为 `/usr/local/bin`）。最后一条命令
按本仓库当前 Quickshell 部署方式更新 QML plugins。

### CLI

```bash
key sysmon snapshot --format json
key sysmon stream --format jsonl --interval 1000
key sysmon cpu --format json
key sysmon processes --sort cpu --limit 50 --format json
key top
```

默认 snapshot/stream 包含 system、CPU、memory、GPU、disk、network 和
battery，不包含进程；只有 `key top`、`key sysmon processes` 或显式请求
`processes` module 才会扫描进程。JSON v1 字段、单位、不可用值和 JSONL
约定见 [`docs/sysmon-schema-v1.md`](docs/sysmon-schema-v1.md)。系统页面的
Material 3 检查记录见
[`docs/system-monitor-material3-audit.md`](docs/system-monitor-material3-audit.md)。

`key top` 的主要快捷键：

| 按键 | 操作 |
| --- | --- |
| `q` | 退出 `key top` |
| `Esc` | 关闭当前弹窗或取消输入模式 |
| `?` | 帮助 |
| `↑` / `↓`、`j` / `k` | 移动进程选择 |
| `PageUp` / `PageDown` | 翻页 |
| `Tab` / `Shift+Tab` | 切换区域 |
| `/` / `f` | 筛选进程 |
| `s` / `t` | 切换排序字段 / 进程树 |
| `p` / `Space` / `r` | 暂停恢复 / 立即刷新 |
| `Enter` | 进程详情 |
| `K` | 进程信号确认；默认 SIGTERM，SIGKILL 需要二次确认 |

这里使用大写 `K` 发送信号，以保留 Vim 风格的小写 `k` 向上移动。
`NO_COLOR` 可关闭颜色，`key top --ascii` 会强制整个界面只输出 ASCII。

### QML 数据流

`Services/SystemMonitorService.qml` 在系统页位于前台时取得引用并启动一个
`key sysmon stream`，按行验证 schema v1、维护有限历史、暴露
loading/ready/stale/error 状态，并在异常退出时有限退避重连。页面离开前台
后释放引用并停止 stream。展示组件不直接启动命令；“完整监视器”操作由
Service 选择可用终端并执行 `key top`。

可重复的 QML 数据、渲染和进程生命周期 smoke：

```bash
CLAVIS_KEY="$PWD/core/build/bin/key" \
CLAVIS_SMOKE_OPEN_TOP=1 TERMINAL=/usr/bin/true \
  qs --no-color -p ./smoke_system.qml
```

测试结束会输出 `SYSMON_SMOKE_PASS`，释放页面引用并主动退出；此时不应再有
`key sysmon stream` 进程。



### 致谢



本项目在实现过程中参考并复用了多个优秀开源项目的设计、组件和实现思路，感谢这些项目及其维护者：

1. [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)：可复用组件、Quickshell 模块组织和 Material 风格界面的重要参考来源。
2. [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)：提供了成熟的 Quickshell Material Shell 模板、控制中心和交互设计参考，也是壁纸过渡shader的来源。
3. [caelestia-shell](https://github.com/caelestia-dots/shell)：锁屏界面和 Quickshell Shell 视觉风格的重要参考来源。
4. [qml-niri](https://github.com/imiric/qml-niri)：Niri IPC、工作区/窗口模型和 QML 插件封装的实现参考。
5. [Breezy Weather](https://github.com/breezy-weather/breezy-weather)：天气界面、天气信息组织和 Material 3 天气可视化设计参考。
6. [soramanew/m3shapes](https://github.com/soramanew/m3shapes)：提供 Material 3 Expressive 形状、形变算法与解析抗锯齿 QML 原生模块。



### 开源协议



本项目以 [GNU GPL-3.0](https://github.com/StatIndet/quickshell/blob/main/LICENSE) 作为主许可证发布。项目中参考、改写或复用的第三方源码、设计和资源仍遵循其原始项目许可证；相关许可证副本集中存放在 [`licenses/`](https://github.com/StatIndet/quickshell/blob/main/licenses) 目录中。

- `end-4/dots-hyprland`：GPL-3.0，见 [`licenses/end-4-dots-hyprland-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/end-4-dots-hyprland-GPL-3.0.txt)。
- `DankMaterialShell`：MIT，见 [`licenses/DankMaterialShell-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/DankMaterialShell-MIT.txt)。
- `caelestia-shell`：GPL-3.0，见 [`licenses/caelestia-shell-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/caelestia-shell-GPL-3.0.txt)。
- `qml-niri`：MIT，见 [`licenses/qml-niri-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/qml-niri-MIT.txt)。
- `Breezy Weather`：LGPL-3.0 及附加条款，见 [`licenses/BreezyWeather-LGPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/BreezyWeather-LGPL-3.0.txt) 和 [`licenses/BreezyWeather-LICENSE_ADDITIONAL.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/BreezyWeather-LICENSE_ADDITIONAL.txt)。
- `Animated Weather Cards`：MIT，见 [`licenses/AnimatedWeatherCards-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/AnimatedWeatherCards-MIT.txt)。
- `soramanew/m3shapes`：Apache-2.0，见 [`licenses/M3Shapes-Apache-2.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/M3Shapes-Apache-2.0.txt)。

若某个文件中保留了更具体的版权或许可证声明，以该文件内声明和对应上游许可证为准。
