# 开发验证

日常只运行一次 `scripts/dev/check.sh`。它检查 HEAD 以来的 staged、unstaged 和未忽略的
未跟踪文件；文档改动不会调用 Qt、CMake 或 CTest。已提交改动不在默认范围内，需要在
提交前验证；审查整个 checkout 用 `--full`。

| 范围 | 执行内容 |
| --- | --- |
| 所有改动 | `git diff --check HEAD` |
| 改动 QML | Qt 6 qmlformat 比较、qmllint（必要时准备 native build 与真实 Quickshell VFS） |
| 改动 first-party C++ | clang-format 检查；跳过 vendored m3shapes |
| 改动 Shell | bash 语法与 ShellCheck；配置写入、Niri effects、Matugen 相关路径选已有集成测试 |
| 改动 Python | 内存编译检查，不写 `__pycache__` |
| core、CMake、QML tests | configure/build、全部现有 CTest |

QML 格式写入用 `scripts/dev/format-qml.sh`，然后只运行 check；不要再单独重复
format-check 和 lint。`--native` 强制构建/CTest；`--full` 扩展为全仓质量检查与
构建/CTest，但不要求 legacy QML 全树格式迁移。显式格式审计用
`format-qml.sh --check-all`，写入全树用 `--all`。

验证范围和扩大检查的条件统一见 [AGENTS.md](../AGENTS.md#workflow-and-validation)。
共享组件内部的视觉调整不自动触发全量检查。已有构建可用
`ctest --test-dir build -R '<test-name>' --output-on-failure --no-tests=error`
运行受影响测试；需要原生构建时先 build。QML 单元测试注册为 `qml_unit_tests`。

## QML 工具与生成物

Qt 6 工具优先使用 `/usr/lib/qt6/bin/`，可用 `QMLFORMAT` / `QMLLINT` 覆盖；
不得误用 PATH 中的 Qt 5。`.qmlformat.ini` 采用 4 空格、Unix newline，关闭 import/order
normalize。仅明确格式迁移时使用全树写入 `--all`；`--check-all` 不属于日常 gate。

`.qmlls.ini` 是 Quickshell 生成且被忽略的机器文件，不得提交。先准备 native build，
由 `lint-qml.sh` 生成或刷新真实 tooling VFS，再读取 `buildDir` / `importPaths` 并作为
`-I` 参数传给 qmllint。普通 QML 任务由脚本按需准备，不额外重复构建。

## 依赖（Arch Linux）

由人工根据缺失项安装。下列命令仅作为参考，检查脚本不会运行 pacman 或 sudo。

```bash
sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative \
  qt6-shadertools qt6-tools qtkeychain-qt6 libpipewire cava \
  clang shellcheck python git
# Matugen 集成测试需要：
sudo pacman -S --needed matugen jq
```

`base-devel` 提供编译器和 pkgconf 等构建工具；`clang` 提供 clang-format。
Qt 6 的 qmlformat、qmllint、qmltestrunner 属于
[qt6-declarative](https://archlinux.org/packages/extra/x86_64/qt6-declarative/files/)，
LinguistTools 属于 [qt6-tools](https://archlinux.org/packages/extra/x86_64/qt6-tools/)。
Quickshell 的 `qs` 也必须可用；沿用本机已有的发行版或 `quickshell-git` 安装，
不要为了检查替换正在使用的 Quickshell。Cava 必须提供 `libcava` 或 `cava` pkg-config
开发接口；只存在可执行程序还不够。

可用 `pacman -Q` 查询上述包；检查具体工具时：

```bash
/usr/lib/qt6/bin/qmlformat --version
/usr/lib/qt6/bin/qmllint --version
pkg-config --modversion libpipewire-0.3
pkg-config --modversion libcava # 或 cava
```

## 已确认的中断与开销原因（2026-09-06）

- 本机 `/usr/bin/qmlformat` 属于 Qt 5，报告 `1.0`；Qt 6 工具已安装在
  `/usr/lib/qt6/bin/qmlformat`，版本为 6.11.2。旧脚本直接依赖 PATH，选错了工具。
  同时旧参数 `--no-sort` 不被此 Qt 6 版本支持。现在统一挑选 Qt 6，使用 ini 设置，
  不传旧参数。无需卸载 Qt 5 或修改系统链接；可用 `QMLFORMAT` / `QMLLINT` 覆盖。
- 旧约定要求单独跑 format-check、lint，再跑包含它们的 check；旧 check 还无条件检查
  所有 Shell/C++、构建并测试。现已改成一次按范围选择。
- 旧 format-check 即使没有 QML 改动也查找工具，并扫描全树 tab/CRLF。现在空范围
  直接结束，格式比较只针对选中的文件。
- 旧 lint 总是扫全树。本轮基线全树 lint 退出 0，但有 5,206 条 warning；包括
  Quickshell 动态类型、unqualified access 等，尚未逐项归因或修复。保留既有
  `--max-warnings -1` advisory 策略，不能把此结果解释为无问题。新 check 只输出数量，
  保留完整日志；语法等导致 qmllint 非零退出的问题仍阻断。
- 本轮原生 configure/build 成功，11 项现有 CTest 全部通过；主要构建与格式化依赖
  均已安装。此次未修改产品源码、批量格式化、安装软件或重启 shell。

## 失败处理

`check.sh` 将输出写入临时 `clavis-check.*` 目录，失败只显示末尾 60 行和日志路径。
正常成功清理日志；QML warning 保留日志。优先读失败阶段，不反复运行整个入口。
CTest 摘要保留测试跳过信息；跳过不等于通过。单独选择 Matugen 集成测试时缺少
matugen/jq 会直接报告依赖缺失；CTest 的既有 skip 策略不变。

QML tooling 依赖 Quickshell 生成的 `.qmlls.ini` 及其 VFS；不能伪造 qmldir 或 import
路径来“修好 lint”。如果 offscreen 启动未产生有效 VFS，脚本会报告日志与图形会话
恢复命令。人工在有图形会话的终端按脚本提示运行（需要 build/qml 在 import path
中），再重试失败阶段。Qt/Quickshell 升级后可能需要重新 build 并刷新 tooling。
这类问题不是再安装一个格式化包就能解决的。

同一个环境阻断只诊断一次，报告未完成项和恢复方式。通过的阶段不为最终总结重复运行。

### 格式化工具阻断

普通格式差异应修正后继续；只有已确认的版本不兼容、格式化不收敛等工具问题才属于
阻断。`check.sh` 当前遇到失败即退出，不会自动继续其他阶段，也没有跳过格式的选项。
此时保留失败日志，按本次范围单独运行不依赖格式化的 `scripts/dev/lint-qml.sh`，以及
确有需要的语法、构建或现有测试。不要重跑已通过阶段，也不要修改脚本来隐藏失败。
最终分别说明已通过、阻断和未执行项；提供对应日志中的人工恢复命令。
