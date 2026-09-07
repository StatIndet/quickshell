# Clavis Shell 开发约定

## Project responsibilities

Clavis 是 CMake/Ninja + QML/Quickshell 项目。`shell.qml` 是入口，`AppShell.qml`
负责顶层装配；`Modules/` 放业务模块，`Services/` 放长期状态和系统交互，`Widgets/`
只放展示控件，`Common/` 放主题、尺寸、路径和纯工具，`core/` 放原生 backend 与 QML
plugin。

三个仓库是独立项目，测试和构建不得跨仓库依赖：

- Clavis 负责 QML UI、Quickshell 生命周期、Niri IPC、窗口/工作区/输出、天气、
  WeatherMapProvider、M3Shapes、MediaPalette、键盘锁状态、实时 Cava、MPRIS 歌词和
  同步时间轴。
- `key-cli` 负责 `key shell`、`key ipc`、录屏、音频文件录制、剪贴板 backend 以及
  对外 machine JSON protocol。
- `keytop` 唯一负责系统指标采集、解析、TUI 和 JSON/JSONL machine protocol；Clavis
  直接消费 `keytop value stream --format jsonl`，不得在 Clavis 重新实现 keytop parser。

Clavis 测试必须在单独 clone 后成立，不能依赖 `../keytop`、`../key-cli` 或它们的构建
产物。不得恢复 `cast`、`key top`、`key sysmon`、Clavis.Sysmon、天气 CLI 中转、Python
歌词脚本、内嵌 C++ key CLI、release manager、rollback、`current` 软链接、`releases/`、
`setup.sh`、`justfile` 或 Makefile。参考仓库只读，不能修改。

## Development entry

顶层 CMake/Ninja 统一构建原生 module、测试与 QML 安装；构建命令与开发入口见
[docs/development.md](docs/development.md)，仅在准备开发环境或启动 shell 时阅读。
开发入口 `~/.config/quickshell/clavis` 指向源码；外部入口使用 `${CLAVIS_KEY:-key}`。
新增快捷键直接使用 `qs -c clavis ipc call TARGET METHOD [ARGUMENTS...]`；
`key ipc` 兼容入口保留。不得将仓库或构建绝对路径写入 Niri 配置。

## QML modules

- `import qs.Common`、`import qs.Services`、`import qs.Modules.Foo` 是 Quickshell
  root-relative shell modules。纯 QML 目录不得新增手写 `qmldir`。
- `import Clavis.Weather`、`import Clavis.WeatherMap`、`import Clavis.Cava`、
  `import Clavis.Lyrics` 等 native imports 由 CMake 的 `qt_add_qml_module()` 管理，
  不添加无意义的版本号。
- Native QML module 的 build-tree 输出统一在 `build/qml/`；`qmldir`、`*.qmltypes`、
  plugin 是 CMake/Qt 生成物，不能手写或编辑。
- 展示组件不得创建 `Process` 或执行系统命令。录屏、录音和剪贴板通过带参数数组的
  `key` 调用，必须校验 machine response 的 `schemaVersion` 和错误。
- FFmpeg、pactl、ffprobe、录音 PID、临时音频文件和 finalizer 属于 `key audio`；歌词
  获取、缓存、LRC 解析和 MPRIS seek 属于 `Clavis.Lyrics`。

## Internationalization

面向用户的可翻译源文案统一使用英文，沿用 `qsTr()` / `qsTranslate()` 的 context 与
消歧机制；新增或修改文案时同步维护 `i18n/clavis_en_US.ts`、`clavis_zh_CN.ts` 和
`clavis_zh_TW.ts`。动态值使用占位符，数量使用 Qt numerus，避免拼接翻译片段。

语言选择由 `I18nManager` 统一解析：已保存的用户选择优先，否则匹配系统 UI language
偏好，无匹配时回退英文。切换界面语言不得更改全局地区 locale、单位或天气位置。
语言选项保留自称；中文注释、文档、协议值与用户数据不属于源文案迁移范围。
维护流程与术语见 `docs/internationalization.md`；不得以汉字扫描代替国际化审查。

## Task-specific guidance

仅在相关任务中阅读，不要求每轮读取所有文档：

- 修改 UI 文案、设置页布局或交互：[UI 规范](docs/ui-guidelines.md)。复用既有组件，
  保留错误与认证信息；信息密度审查只覆盖本次改动。
- 修改可翻译源文案、翻译目录或语言解析：[国际化规范](docs/internationalization.md)。
- 修改检查工具链或遇到检查失败：[开发检查](docs/development-checks.md)的相关章节。
- 应用 skill 时仅采用适用于当前平台与任务的章节；QML 任务不触发 Android/Web 的
  构建或模拟器检查。设计合规报告仅在用户要求设计审计时生成。

## Test Policy

质量检查和 tests 分开。`qmllint`、`qmlformat`、`clang-format`、`bash -n`、
`shellcheck`、Python `compileall`、compiler warnings、build 和 `git diff --check` 是
quality checks，不是 tests。

**Do not add tests automatically just because code was changed.**

**Fixing a bug does not automatically require a regression test.**

新增 test 前判断以下事项；这是选型依据，不要求每轮输出逐项论证报告：

1. 测试验证的 stable behavior 或 public contract 是什么；
2. 为什么 lint/build 无法覆盖它；
3. 为什么 unit test 或必要的 integration test 是合适层级；
4. 为什么测试不会锁死当前实现细节。

允许的 Clavis tests 主要是 deterministic C++ unit tests（parser、geometry/math、工作区
拓扑推导、坐标转换、壁纸分析、歌词解析、路径/config resolution、状态变换）、少量
纯 QML/JavaScript state/math QtTest，以及真正验证外部行为的脚本 integration test。
QML UI、Button、Loader、动画、颜色、Item hierarchy、compositor timing 和普通视觉
layout 默认不新增 QtTest。

绝对禁止通过 `grep`、`sed`、`awk`、regex、source text matching 来断言 property、
Loader、id、Item child、函数名、文件布局、当前 object hierarchy 或 feature 的实现
形状。禁止创建 `test_*_architecture.sh`、`test_*_feature.sh`、
`test_*_implementation.sh`，也不要恢复历史 smoke QML。CTest 只能注册真正的 unit 或
必要 integration test，不注册 source audit。

不要追求 coverage %，不要引入 coverage.py/gcov/lcov/codecov/threshold，也不要为了
本任务引入 clang-tidy、`-Werror`、mypy、pyright 或大型 pre-commit 体系。

## Workflow and validation

用户仅请求分析、比较或讨论时，进行回答所需的只读调查，不修改文件或运行无关检查。
用户要求实施时，完成已授权工作和必要验证；可由现有代码与约定确定的细节自行处理。
只有影响结果的重大产品选择、破坏性操作或超出授权范围的事项才询问。

日常验证入口为 `scripts/dev/check.sh`。修改 QML 后先用 `scripts/dev/format-qml.sh`
格式化改动文件，再运行所选范围的 check；不先后重复 format-check、lint 和 check。
默认范围为 HEAD 以来 staged、unstaged、未跟踪且未忽略的文件，不重排无关文件。

| 改动 | 必要验证（选择对应范围，不是串行清单） |
| --- | --- |
| 文档、静态素材 | `check.sh`，通常仅 diff 空白检查 |
| QML UI，包括共享组件内部的局部视觉或文案调整 | `check.sh`：改动 QML 格式与 lint；按需视觉检查 |
| 翻译目录或可翻译源文案 | `check.sh`，另按国际化规范更新、编译受影响目录 |
| Shell / Python | `check.sh`：改动文件语法、ShellCheck 及匹配的现有集成测试 |
| `core/`、CMake、`tests/qml/` | `check.sh` 自动 configure/build 并运行现有 CTest |
| QML/JS 纯状态或数学逻辑 | `check.sh` 加对应已有 QtTest；需原生构建时用 `--native` 替代入口 |
| 公共接口、模块解析或依赖影响 | 按下述条件界定范围 |

共享组件被多处引用本身不触发全量检查。改变公共属性、信号、required property、模块
导出或 import 解析时，先界定受影响消费者：能可靠界定则运行对应范围的检查与现有测试；
无法界定、广泛依赖升级或用户明确要求全面检查时使用 `check.sh --full`。
不得以缩小范围为由遗漏消费者；默认脚本按路径选择，不能代替这项判断。

`--native` 在改动检查外强制构建与整组现有 CTest；`--full` 扩展为全树 first-party
质量检查、构建与 CTest，但 QML 格式仍只检查改动文件。普通 UI 不触发整组 CTest。
工具参数、VFS 准备与故障处理见开发检查文档，不手写 `.qmlls.ini`、qmldir 或伪造 lint。

必要验证通过且授权工作完成后停止。只有新修改、具体失败或尚未验证的依赖影响才补跑
受影响阶段；不在末尾再跑全量流程。同一工具/环境阻断只诊断一次；确认是工具问题后，
保留阻断结果并继续可独立执行的必要检查，不伪报全部通过，不顺手迁移工具链。

默认不安装、不重启进程、不提交；这些操作需用户明确要求。检查不得 sudo、修改系统或
启动持久后台服务。不得手改 build、用户 Niri 配置、系统 Qt import 根或已安装文件来
修复源码；正常 CMake 生成构建产物除外。

最终回复说明完成内容、必要验证结果及未验证或阻断事项。QML advisory warning 报告
数量与日志位置，不称零警告通过；没有相关 tests 时如实说明。正常成功不逐条复述命令，
仅需要用户操作时提供步骤。除非用户要求，不新增开发总结或审计报告。
