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

## Build

顶层 CMake 统一构建原生 module、测试和 QML 源码安装，不调用 sudo：

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
```

开发入口是 `~/.config/quickshell/clavis` 指向当前源码；稳定外部入口使用
`${CLAVIS_KEY:-key}`。开发原生 module 使用：

```bash
QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" key shell
```

不能把仓库绝对路径或构建路径写入用户 Niri 配置。IPC 文档和快捷键使用 `key ipc ...`，
不使用裸 `quickshell ipc`。

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

## QML tooling

`.qmlls.ini` 是 Quickshell 生成的机器相关文件，已加入 `.gitignore`，不得提交。正确
流程是先 configure/build native modules，再由 `scripts/dev/lint-qml.sh` 通过 Quickshell
生成或刷新 tooling VFS，读取其中的 `buildDir` 和 `importPaths`，最后把真实路径作为
`-I` 传给 `qmllint`。如果 offscreen 环境不能生成有效 VFS，脚本必须失败并报告人工
恢复命令，不得伪造 lint 成功。

```bash
scripts/dev/format-qml.sh
scripts/dev/format-qml.sh --check
scripts/dev/lint-qml.sh
```

`.qmlformat.ini` 使用 4 空格、Unix newline、禁止 tab，并关闭激进 import/order
normalize。普通 format/check 只处理当前改动的 QML，避免 legacy tree 被批量重写；只有
明确要迁移整棵树时才使用 `scripts/dev/format-qml.sh --all`。除非确有语义需要，不要
借格式化顺手重排大范围属性或对象。

## UI copy and information density

- 设置页面默认不写 supporting text。只有标题、图标、控件状态无法表达的新信息才可
  添加 supporting text，例如动态数值、当前模式、不可用原因、错误或验证要求。
- 禁止用文字重复 boolean control state；`Wi-Fi / 已开启 / switch ON` 中的“已开启”
  必须删除。正常状态通常无需说明，硬件阻止、权限失败、backend 不可用等异常状态应
  使用简短文案说明原因。
- 禁止 subtitle 改写或重复 title；例如“添加网络 / 手动添加网络”是无效文案。
- 普通 UI 不得暴露没有用户价值的 backend 实现术语，例如 `NetworkManager 配置`、
  `DBus backend`、内部 UUID；只有明确的高级诊断页面可以展示这些信息。
- 一个语义只保留一种主要表达。selected/highlighted shape、switch、icon、badge 或
  dynamic value 已完整表达状态时，不再追加一句文字重复解释。
- 信息层级和状态优先通过项目现有的 Material Design / expressive shape、icon、badge、
  state layer、tooltip、switch、slider 和 animation 表达，不得另造平行组件体系。
- Tooltip 用于 icon-only action、次要解释，以及不值得长期占据 layout 的辅助信息；
  不要为了避免 tooltip 而把所有解释永久铺在页面上。
- 面向全球用户使用简短、一致的名词或动词短语，避免完整说明句、实现术语和不必要的
  翻译负担。错误、破坏性操作警告、验证规则、认证或权限失败及歧义操作标签不得因精简
  文案而隐藏。
- Material expressive UI 应先以视觉建立 hierarchy，copy 只辅助视觉无法可靠传达的
  内容，不得依靠大量 prose 创建页面结构。
- 新增或修改设置页面时必须主动执行 semantic redundancy audit：检查 title/subtitle、
  icon/text、switch/status text、badge/description 是否重复，同一状态是否在相邻 section
  重复出现，以及 implementation detail 是否泄漏到 user-facing copy。

## Test Policy

质量检查和 tests 分开。`qmllint`、`qmlformat`、`clang-format`、`bash -n`、
`shellcheck`、Python `compileall`、compiler warnings、build 和 `git diff --check` 是
quality checks，不是 tests。

**Do not add tests automatically just because code was changed.**

**Fixing a bug does not automatically require a regression test.**

新增 test 前必须能够说明：

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

## Validation

Codex 应优先运行已有质量入口，而不是为当前任务临时发明测试：

```bash
git diff --check
scripts/dev/format-qml.sh --check
scripts/dev/lint-qml.sh
scripts/dev/check.sh
```

`check.sh` 还会运行 first-party C++ clang-format check、shell syntax/shellcheck、
Python compileall、CMake configure/build 和 CTest。它不得 install、sudo、修改系统或
启动持久后台服务。默认不安装、不重启进程、不提交；只有用户明确要求时才执行这些
外部操作。不得编辑 `build/`、用户 Niri 配置、系统 Qt import 根或已安装文件来修复
源码。
