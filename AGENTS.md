# 仓库指南

## 项目结构与模块组织

这是一个主要使用 QML 构建的 Quickshell 桌面 shell。`shell.qml` 是主入口，只负责加载 `AppShell.qml`；`AppShell.qml` 负责挂载 Bar、Keystone、Sidebars、Launcher 与 Lock 等顶层模块。`demo.qml`、`test_list.qml` 和 `test_proc.qml` 是本地 smoke-test 入口。

## Keystone 术语约定

本项目中的 `Keystone` 是仿照 iOS Dynamic Island 制作的顶部交互区域。后续交流中出现的“灵动岛”、“Dynamic Island”、“dynamic island”、“dynamic”、“daynamic”或“钥石”，除非另有明确说明，均指当前项目的 `Modules/Keystone/` 模块。

当前目录结构约定如下：

```text
.
├── shell.qml                 # 极薄入口，只加载 AppShell
├── AppShell.qml              # 顶层模块装配
├── Common/                   # 全局基础设施
│   ├── Appearance.qml        # 主题、颜色、动画、间距
│   ├── Sizes.qml             # 字体、尺寸、锁屏尺寸 token
│   ├── WidgetState.qml       # 全局 UI 状态
│   ├── Paths.qml             # assets、scripts、cache 等路径入口
│   └── functions/            # 纯 JS/QML 工具函数
├── Components/               # 极简无状态 UI 元素
├── Widgets/                  # 可复用展示控件，不直接调用系统命令
│   ├── audio/
│   └── common/
├── Services/                 # 数据逻辑与系统状态单例
├── Modules/                  # 业务功能模块
│   ├── Bar/
│   ├── FilePicker/           # 主题化文件选择窗口
│   ├── Keystone/
│   │   ├── DashboardContent/
│   │   └── Styles/
│   │       ├── Bangs/
│   │       └── Pill/
│   ├── Launcher/
│   ├── Lock/
│   └── Sidebars/
│       ├── Left/
│       │   └── system/       # SystemView 的 Material 3 展示组件
│       └── Right/
├── assets/
│   ├── icons/
│   │   ├── apps/
│   │   └── weather/
│   └── images/
├── scripts/
│   ├── audio/
│   ├── capture/
│   ├── media/
│   ├── schedule/
│   ├── system/
│   ├── theme/
│   └── weather/
└── core/                     # Qt/C++ native plugin 与 key CLI
    ├── src/sysmon/           # 共享 collector、sampler、类型与 JSON 序列化
    └── cli/src/
        ├── commands/         # key 子命令
        └── tui/              # ncursesw key top
```

分层规则：

- `Modules/` 是业务层，存放大型、独立的功能区块；侧边栏、Keystone、启动器、锁屏等都归入这里。
- `Widgets/` 是展示层，只放可复用 UI 控件和小型面板外壳；不要在这里直接使用 `Process`、`Quickshell.execDetached` 或其他系统命令调用。
- `Common/` 是全局基础设施；主题色、尺寸 token、共享状态、路径和纯工具函数都放这里。QML 中引用静态资源或脚本时优先通过 `Common/Paths.qml`。
- `Services/` 是数据逻辑层，保持单例模式；UI 需要系统状态或系统操作时优先通过 `Services/` 暴露的属性/函数访问。
- `Components/` 只放极简、无状态基础元素，例如 SVG/icon 包装。
- `assets/` 保持在根目录，按类型归类。应用图标放 `assets/icons/apps/`，天气图标放 `assets/icons/weather/`，图片放 `assets/images/`。
- `scripts/` 按用途分组；不要把新脚本直接散放在 `scripts/` 根目录。
- 不再使用旧的 `Widget/`、`config/`、`JS/` 目录；新增代码不要恢复这些目录。

Qt/C++ plugin 统一位于 `core/`：可复用 backend 代码在 `core/src/`，QML plugin wrapper 位于 `core/plugin/` 下，构建输出位于 `core/build/`。避免编辑 `core/build/` 中的生成文件。

## Quickshell Plugin 架构

自制 plugin 使用 `qt_add_qml_module` 构建，通过 URI 向 QML 导出。通用约定如下：

- 与 UI 无关的 backend、provider、calculator 放在 `core/src/`。
- 面向 QML 的包装层放在 `core/plugin/<name>/`。
- 系统监测以 `core/src/sysmon/` 为唯一数据核心；plugin、`key sysmon`
  和 `key top` 必须复用它，不得各自重新读取 `/proc`、`/sys` 或重复计算差值。
- 左侧系统页只通过 `Services/SystemMonitorService.qml` 消费
  `key sysmon stream` 的 JSONL；展示组件不得直接 import `Clavis.Sysmon`
  或创建系统命令。
- plugin 构建完成后，如需让系统里的 Quickshell 正常 `import`，必须将构建出的 `Clavis/` 和 `M3Shapes/` 目录复制到 `/usr/lib64/qt6/qml/`：
  `sudo cp -a core/build/Clavis core/build/M3Shapes /usr/lib64/qt6/qml/`
- QML 中使用自制 plugin 时，直接按其 URI import，例如：
  `import Clavis.Sysmon 1.0`
- 若只改了 QML，不需要重编译 plugin；若改动涉及 `core/src/` 或 `core/plugin/`，则需要重新构建并重新复制安装。

## 构建、测试与开发命令

- `qs`：运行当前这套 Quickshell 配置并直接查看输出结果。
- `cmake -S core -B core/build`：配置 Qt 6/CMake plugins。
- `cmake --build core/build`：构建 C++ plugin backend。
- `env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen ctest --test-dir core/build --output-on-failure`：运行 C++ 与 CLI 测试。
- `sudo cmake --install core/build`：安装 `key` 单一 CLI 入口。
- `sudo cp -a core/build/Clavis core/build/M3Shapes /usr/lib64/qt6/qml/`：安装编译后的 plugin，以便 Quickshell 正常 import。

除非另有说明，请从仓库根目录运行这些命令。

`key top` 使用 `ncursesw`；CMake 通过 `pkg-config` 检测该依赖，缺失时会在
配置阶段明确报错。系统监测 JSON v1 协议记录在
`docs/sysmon-schema-v1.md`。

## 代码风格与命名约定

尽量不要手搓图形，优先复用已有 SVG、矢量 path 或现成资源。

## UI 主题、字体与图标约定

- 主题风格优先参考 Material Design 的设计风格。
- 所有 UI 的主题颜色优先使用 `Common/Appearance.qml` 中定义的颜色，避免在组件内重复声明或硬编码主题色。
- 字体可选 `LXGW WenKai GB Screen`、`Maple Mono NF CN`、`JetBrainsMono Nerd Font`。中文和英文优先使用 `LXGW WenKai GB Screen`，数字优先使用 `JetBrainsMono Nerd Font`。
- 图标可选 Nerd Font 图标，也可以使用 `ttf-material-symbols-variable` 中的 Material Symbols 图标；优先使用 `ttf-material-symbols-variable`。

## Material 组件优先原则

本项目中的 Quickshell UI 组件默认应优先基于 `QtQuick.Controls.Material` 实现。

在实现任何按钮、输入框、滑块、开关、进度条、菜单、弹窗等常见控件之前，应先检查 `QtQuick.Controls.Material` 是否已经提供对应组件或可通过样式属性完成需求。

禁止在没有明确理由的情况下重复手写 Material 风格控件。

允许自定义组件的情况包括：

- `QtQuick.Controls.Material` 没有提供对应组件；
- 原生控件无法实现目标动画或特殊形状；
- 需要与 Quickshell、Niri、LayerShell、ShaderEffect 等场景深度结合；
- 原生控件存在明显性能或交互问题。

自定义组件必须尽量遵循 Material Design 3 的视觉和交互规范。

## 测试指南

纯 QML 改动至少执行一次 `qmllint`；涉及 `core/` 的改动至少重新构建一次 plugin。界面验证优先直接运行 `qs`。

## Commit 与 Pull Request 指南

Git commit subject 必须使用 `type: 描述` 格式。`type` 使用小写英文类型，后接英文冒号和一个空格；描述使用简洁、明确的语言说明本次提交，例如 `feat: 新增 Keystone 样式切换` 或 `fix: 修复文件选择器导航失效`。

允许使用的类型如下：

| type | 含义 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 文档修改 |
| `style` | 代码格式、缩进或样式整理，不改变逻辑 |
| `refactor` | 重构代码，不新增功能且不修复具体 bug |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `build` | 构建系统、依赖或打包配置 |
| `ci` | GitHub Actions、Cloudflare Pages 等 CI 配置 |
| `chore` | 不属于以上类型的杂项维护 |
| `revert` | 回滚提交 |

后续所有 Git 提交均应遵循此约定。Pull request 应包含简要描述、受影响模块、运行过的命令，以及可见 UI 改动的截图或录屏。如有相关 issue 请链接，并明确说明新增 runtime dependency。

## 安全与配置提示

不要提交机器特定的 secret、token 或私有路径。脚本可能会在 `$HOME/.cache` 下写入缓存文件，或在 `/tmp` 下写入日志；这些内容应排除在版本控制之外。谨慎处理 `Modules/Lock/pam/` 中与锁屏和 PAM 相关的文件，提出改动前请先在本地测试。
