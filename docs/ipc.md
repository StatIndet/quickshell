# IPC

Shell 生命周期可使用 `key-cli`；新增快捷键直接调用 Quickshell IPC：

```bash
key shell
qs -c clavis ipc show
qs -c clavis ipc call TARGET METHOD [ARGUMENTS...]
```

对应的 Quickshell 调用为：

```text
key shell                 → qs -c clavis -n
key shell --daemon        → qs -c clavis -n -d
key shell --kill          → qs -c clavis kill
key shell --log           → qs -c clavis log
key ipc show              → qs -c clavis ipc show
key ipc call A B ...      → qs -c clavis ipc call A B ...
```

Niri 快捷键和脚本不写裸 `quickshell ipc`，也不写用户源码路径。Shell 内部直接使用
Quickshell API 的地方不需要机械地经过 CLI。

托管快捷键写为独立 argv，不经过 shell 字符串或每次按键的配置 helper：

```kdl
spawn "qs" "-c" "clavis" "ipc" "call" "keystone" "hub"
```

`key ipc call` 的标准既有绑定可以识别为同一 Clavis 动作，但保留原文本。
录屏、录音、剪贴板继续使用各自的 `key` 接口。
动作目录根据实际 IpcHandler 注册维护；需参数的方法保留显式参数模板。
首次在快捷键页面点击“设置”创建缺失的 binds.kdl 时，写入以下默认键位。
全部使用 `spawn "qs" "-c" "clavis" "ipc" "call" ...`，并设置 `repeat=false`。
`Mod` 跟随 Niri 的主修饰键（通常为 Super）。

| 快捷键 | 功能 | IPC target / method / arguments |
| --- | --- | --- |
| Mod+Space | 启动器 | spotlight toggle |
| Mod+Slash | 快捷键配置图 | shortcut-map toggle |
| Mod+Shift+Space | 网页搜索 | spotlight web |
| Mod+Alt+V | 剪贴板历史 | spotlight openMode clipboard |
| Mod+Alt+W | 壁纸选择 | spotlight openMode wallpapers |
| Mod+N | 通知与信息侧栏 | sidebar toggle left |
| Mod+A | 快捷设置侧栏 | sidebar toggle right |
| Mod+Ctrl+Comma | 设置中心 | control-center toggle general |
| Mod+Shift+W | Keystone 主面板 | keystone hub |
| Mod+Shift+T | 工具面板 | keystone tools |
| Alt+Shift+L | 锁屏 | lock open |

这些键避开 Niri 常用窗口、工作区、截图和媒体控制。首次接入前按有效 include 链
检查物理键位占用（含 Mod/Super 别名），发现冲突则拒绝写入并列出键名；用户可释放
这些键，或自行创建自定义 binds.kdl 后接入。任意第三方配置都可能占用默认键，不能
保证对所有配置天然无冲突。已有文件即使为空也不补写，升级不恢复用户删改的绑定。
安装只部署程序；不会自动改写用户 Niri 配置。

目录维护依据：[niri 键绑定](https://niri-wm.github.io/niri/Configuration:-Key-Bindings.html)、
[默认配置](https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl)、
[可绑定动作定义](https://github.com/niri-wm/niri/blob/main/niri-config/src/binds.rs) 与
[Quickshell IpcHandler](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler/)。
托管片段按 [niri include 顺序](https://niri-wm.github.io/niri/Configuration:-Include.html)
处理覆盖。目录随程序部署，运行时只在本机验证动作支持，不联网下载。

快捷键配置图独立于设置中心加载，使用 `qs -c clavis ipc call shortcut-map toggle`
打开或关闭；也提供无参数的 `open` 和 `close`。账户页按钮与 IPC 共用同一个弹层。
