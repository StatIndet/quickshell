> [!WARNING]
> 当前项目仍未完工，仅作为demo。

## 项目说明

这是我的 Quickshell 桌面 shell 配置目录，放置在标准的 `~/.config/quickshell` 路径下。仓库包含主入口 `shell.qml`、`AppShell.qml`、`Modules/` 业务模块、`Widgets/` 可复用控件、`Common/` 全局基础设施、共享资源，以及 `core/` 下用于向 QML 暴露系统监控和天气数据的 Qt/C++ 自制插件源码。

### 预览
灵动岛媒体
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif1.gif" width="500">
</p>
小工具
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif2.gif" width="500">
</p>
灵动岛dashboard
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif3.gif" width="500">
</p>
Launcher
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/gif4.gif" width="500">
</p>

### 致谢
本项目在实现过程中参考并复用了多个优秀开源项目的设计、组件和实现思路，感谢这些项目及其维护者：

1. [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)：可复用组件、Quickshell 模块组织和 Material 风格界面的重要参考来源。
2. [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)：提供了成熟的 Quickshell Material Shell 模板、控制中心和交互设计参考。
3. [caelestia-shell](https://github.com/caelestia-dots/shell)：锁屏界面和 Quickshell Shell 视觉风格的重要参考来源。
4. [qml-niri](https://github.com/imiric/qml-niri)：Niri IPC、工作区/窗口模型和 QML 插件封装的实现参考。
5. [Breezy Weather](https://github.com/breezy-weather/breezy-weather)：左侧边栏天气界面、天气信息组织和 Material 3 天气可视化设计参考。

### 开源协议

本项目以 [GNU GPL-3.0](./LICENSE) 作为主许可证发布。项目中参考、改写或复用的第三方源码、设计和资源仍遵循其原始项目许可证；相关许可证副本集中存放在 [`licenses/`](./licenses/) 目录中。

- `end-4/dots-hyprland`：GPL-3.0，见 [`licenses/end-4-dots-hyprland-GPL-3.0.txt`](./licenses/end-4-dots-hyprland-GPL-3.0.txt)。
- `DankMaterialShell`：MIT，见 [`licenses/DankMaterialShell-MIT.txt`](./licenses/DankMaterialShell-MIT.txt)。
- `caelestia-shell`：GPL-3.0，见 [`licenses/caelestia-shell-GPL-3.0.txt`](./licenses/caelestia-shell-GPL-3.0.txt)。
- `qml-niri`：MIT，见 [`licenses/qml-niri-MIT.txt`](./licenses/qml-niri-MIT.txt)。
- `Breezy Weather`：LGPL-3.0 及附加条款，见 [`licenses/BreezyWeather-LGPL-3.0.txt`](./licenses/BreezyWeather-LGPL-3.0.txt) 和 [`licenses/BreezyWeather-LICENSE_ADDITIONAL.txt`](./licenses/BreezyWeather-LICENSE_ADDITIONAL.txt)。
- `Animated Weather Cards`：MIT，见 [`licenses/AnimatedWeatherCards-MIT.txt`](./licenses/AnimatedWeatherCards-MIT.txt)。

若某个文件中保留了更具体的版权或许可证声明，以该文件内声明和对应上游许可证为准。
