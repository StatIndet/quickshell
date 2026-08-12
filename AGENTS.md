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

## Personal fork workflow

此仓库的个人 fork 同时承担“跟踪原作者更新”和“保存个人定制”两个职责。所有 AI、
自动化工具和人工操作必须遵守以下分支与远端边界：

- `origin` 是个人仓库 `ZChenW/quickshell`，是唯一允许 push 的远端。
- `upstream` 是原作者仓库 `StatIndet/quickshell`，只允许 fetch；不得向其 push。
- `main` 是上游镜像分支，只能快进到 `upstream/main`，不得直接加入个人提交。
- `personal/main` 是日常运行和开发个人功能的分支；个人提交只能进入此分支或从它派生
  的临时分支。
- `backup/*` 是迁移前保险分支。没有用户明确授权，不得删除、改写或强推。

开始任何 Git 操作前，必须检查 `git remote -v`、`git status -sb`、当前分支以及
`git rev-parse --is-shallow-repository`。如果仓库是浅克隆，在判断 merge-base、同步或
创建分支前必须先补全所需历史。工作区存在无关修改时必须保留，禁止混入当前提交。

用户要求“保存”“提交并 push”或“同步到我的 GitHub”时，默认含义是：提交到
`personal/main`（或当前个人功能分支）并只 push 到 `origin`。不得创建 Pull Request，
也不得点击或使用 GitHub 在 push 输出中自动提供的 “Create pull request” 链接。

同步上游使用以下模型：

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
git switch personal/main
git merge main
# 解决冲突并完整验证后：
git push origin personal/main
```

个人分支已发布后优先使用 merge 吸收 `main`，避免因 rebase 反复强推。任何 force-push、
删除远端分支、改写 `main` 或修改 backup 分支都属于破坏性操作，必须先创建并核对远端
备份，再取得用户针对该具体操作的明确授权。

只有用户明确表示要向原作者贡献时才可创建上游 Pull Request。创建前必须向用户展示
并确认以下四项，不得根据 fork 关系或 GitHub 默认值猜测：目标仓库、目标分支、来源仓库、
来源分支。随后必须验证与真实目标分支的 merge-base、提交范围、文件范围和冲突状态。

如果上游更新修改本节，解决冲突时应同时保留上游工程规范与本节个人 fork 安全边界；
除非用户明确改变工作流，不得静默删除本节。
