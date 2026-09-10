# 开发流程

先安装外部 QML 运行时依赖 M3Shapes（Arch：`qt6-m3shapes-git`）。
Clavis 不编译或安装它；`build/qml` 继续只为 Clavis 原生模块提供开发导入路径。
从旧 checkout 迁移时，清理旧构建目录中的 `build/qml/M3Shapes`，避免遮蔽系统模块；
不要向该目录复制系统模块或创建同名软链接。

源码开发使用 Quickshell 的 XDG 配置优先级和 CMake 生成的 import tree：

```bash
mkdir -p ~/.config/quickshell
ln -sfn ~/Projects/clavis ~/.config/quickshell/clavis

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build

QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" key shell
```

源码目录优先于 `/etc/xdg/quickshell/clavis`。QML 保存后可热重载；C++ plugin 需要
重新构建并重新加载 Shell。Shell/CLI 日志由各自工具负责，不在文档或脚本中使用
`nohup`、`disown` 或丢弃到 `/dev/null`。

正式安装由发行版打包流程负责；本仓库默认只构建和测试源码，不创建运行时版本快照。

键盘锁状态由独立的 key-cli 提供：`key keyboard status --format json` 用于诊断，
`key keyboard watch --format jsonl` 由 `KeyboardLockService` 的单个 Process 管理。
启动、设备恢复和重同步快照不弹 OSD，真实切换才触发提示；无定期查询或静默超时。
权限不足时保持不可用，由用户选择 key-cli 的独立可选键盘授权配置；已有授权包也可保留。
`Clavis.Keyboard` 仅保留依赖 Qt 输入事件的快捷键录制。libudev 仍由背光 backend 使用。
剪贴板 watcher 继续由独立的 systemd 用户服务管理，不随键盘进程退出而停止。

亮度服务直接使用 `Niri.currentOutput`，不再启动 focused-output 查询进程。内置背光由
`BacklightState` 订阅 backlight udev 事件并读取 `actual_brightness` / `max_brightness`，
设备按名称排序选择，`brightnessctl` 写入显式使用同一设备。启动、设备事件及自身写入结束
时读回，无周期轮询；驱动若不为外部硬件亮度变化发送事件，该变化不会自动同步，需人工
在对应硬件上验证。DDC 检测、读取及写入节流保持原有流程。

键盘状态服务区分 `connecting`（尚未收到可信快照）、`ready`（状态可信）、
`reconnecting`（进程退出后有限重连）和 `unavailable`（明确不可用或重连耗尽）。
`available` 仅在 `ready` 时为 true；未知的 `capsLock` / `numLock` 为 null。
`supported` 在可信快照后为 true，仅跨进程重连保留；明确不可用响应、协议错误或
重连耗尽将其清除。不通过授权包是否安装推断可信状态，也不将其持久化。
设置中心 Keyboard indicators 分区、两个锁屏的键盘状态 UI 和键盘 OSD 都使用
`available` 控制呈现；暂时重连也隐藏。隐藏不会重置 OSD 偏好，恢复快照仅更新基线。
源码安装通过 key-cli 的 `scripts/install.sh --keyboard enable --acknowledge-keyboard-access`
独立选择授权；现有 `key-cli-keyboard-access` 包可继续保留，Clavis 不安装授权规则。

## 与 key-cli 源码联调

在 key-cli checkout 中执行一次：

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
./scripts/install.sh --dev-services enable --clavis-unit ~/Projects/clavis/packaging/systemd/user/clavis-shell.service
```

没有安装 Clavis 基础 unit 时，按工具输出用 `systemctl --user link` 链接本仓库现有
unit；key-cli 只生成开发 ExecStart drop-in，不接管 Shell 服务安装。随后执行
`systemctl --user daemon-reload`，按需重启选定服务。剪贴板基础 unit 缺失时由
key-cli 复用自身 unit 补齐；它与 Shell 仍独立运行。

fish 可选择 `fish_add_path --universal --move ~/Projects/key-cli/.venv/bin`，这也会
影响 python/pip。服务不依赖 fish PATH，使用生成的绝对 `.venv/bin/key` 路径。
`key shell` 自动传播自身入口到 `CLAVIS_KEY`，剪贴板回调也使用启动它的 key。
普通 Python 修改对新进程直接生效；已有 watcher 按需重启，安装元数据改变才需
重装 editable 环境。不要重复 makepkg 或安装系统包来测试普通源码修改。

撤回时在 key-cli 运行 `./scripts/install.sh --dev-services disable`，然后 reload
用户 unit；保留自定义 drop-in。检查开发 PATH 后按需切回 `/usr/local/bin/key` 或
发行版入口。源码稳定安装由 key-cli 的 `scripts/install.sh` 提供，不依赖 checkout
持续存在；Clavis 的原生构建、QML 安装和会话管理仍由本仓库负责。
