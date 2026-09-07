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
当前仓库没有规定初始 IPC 键位，因此首次创建的 binds.kdl 不分配快捷键。

目录维护依据：[niri 键绑定](https://niri-wm.github.io/niri/Configuration:-Key-Bindings.html)、
[默认配置](https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl)、
[可绑定动作定义](https://github.com/niri-wm/niri/blob/main/niri-config/src/binds.rs) 与
[Quickshell IpcHandler](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler/)。
托管片段按 [niri include 顺序](https://niri-wm.github.io/niri/Configuration:-Include.html)
处理覆盖。目录随程序部署，运行时只在本机验证动作支持，不联网下载。
