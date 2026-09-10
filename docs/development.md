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

键盘锁状态通过 evdev LED 事件读取，libudev 负责设备枚举与热插拔；编译和运行需
`libudev`（Arch：`systemd-libs`）。运行用户需要相关键盘 `/dev/input/event*` 的读取权限。
权限不足、设备不可读或事件订阅失败时，`KeyboardLockState.available` 为 false，
`error` 与日志提供原因，锁屏提示和灵动岛不把未知状态显示成切换结果。Clavis 不修改
系统权限、不启动特权代理，也不回退到周期扫描；权限变化的 udev 事件或显式 `refresh()`
会重新检查设备。多个键盘仍按任一 LED 点亮即开启汇总，丢帧后用 `EVIOCGLED` 重同步。

亮度服务直接使用 `Niri.currentOutput`，不再启动 focused-output 查询进程。内置背光由
`BacklightState` 订阅 backlight udev 事件并读取 `actual_brightness` / `max_brightness`，
设备按名称排序选择，`brightnessctl` 写入显式使用同一设备。启动、设备事件及自身写入结束
时读回，无周期轮询；驱动若不为外部硬件亮度变化发送事件，该变化不会自动同步，需人工
在对应硬件上验证。DDC 检测、读取及写入节流保持原有流程。
