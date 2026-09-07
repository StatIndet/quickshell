# 壁纸后端与 niri overview

Clavis 将普通桌面壁纸和 niri overview 背景视为两个独立表面。

桌面后端为 `quickshell` 时，运行结构为：

```text
Quickshell
├── Background: clavis-wallpaper
└── Background: clavis-overview-wallpaper
```

桌面后端为 `awww` 时，运行结构为：

```text
Quickshell
├── Background: clavis-wallpaper（表面常驻，壁纸内容隐藏）
└── Background: clavis-overview-wallpaper

awww-daemon --layer background --namespace clavis-desktop --no-cache
└── 普通桌面壁纸

Bottom
└── clavis-desktop-cards
```

`clavis-wallpaper` 的 PanelWindow 不随桌面后端销毁。切到 awww 时，Clavis
先等待所有输出的 `awww img` 成功，再隐藏 Quickshell 桌面内容；切回时先
恢复已加载的 Quickshell 静态壁纸，再停止 `clavis-desktop`。隐藏期间不会
运行 DMS shader 转场。

overview 表面始终按输出由 Quickshell 创建，不参与桌面后端选择，也不继承
桌面的工作区、平铺列或侧边栏视差。

## niri layer rule

壁纸页的 Overview“设置”按钮可显式创建并接入 `clavis/layer-rules.kdl`：

```kdl
layer-rule {
    match namespace="^clavis-overview-wallpaper$"
    place-within-backdrop true
}

layout {
    background-color "transparent"
}
```

如果配置中仍是旧的
`match namespace="awww-daemonoverview"`，需要由用户手动替换为上面的
`clavis-overview-wallpaper` 规则。设置中心读取有效 include 链；外部已满足规则与 Clavis 托管接入分别显示。
首次启动与打开页面不写配置，只有点击“设置”才创建缺失片段并追加 include。

透明的 workspace 背景是 backdrop 与窗口透明/模糊效果正常共存的必要条件。
如果保持 niri 默认的不透明背景色，kitty 的 `background_opacity` 仍会生效，
但其后方只会露出不透明的 workspace 背景；xray blur 也无法采样桌面壁纸。

不要对普通桌面 namespace `clavis-wallpaper` 使用
`place-within-backdrop`。

重新加载 niri 配置后运行：

```bash
niri msg layers
```

确认 overview 表面的 namespace 为 `clavis-overview-wallpaper`，并且规则已匹配。

## 多显示器映射

桌面映射保存全局壁纸、`monitorWallpapers` 和
`monitorWallpaperFillModes`。overview 另存全局壁纸、
`overviewMonitorWallpapers` 和 `overviewMonitorFillModes`。

overview 使用独立壁纸时按以下顺序解析：

1. 当前输出的 overview 壁纸；
2. 全局 overview 壁纸；
3. 当前输出的桌面壁纸；
4. 全局桌面壁纸。

选择“使用桌面壁纸”时直接读取 Clavis 的原始桌面壁纸路径，不截图 awww
表面，也不读取 awww 缓存。

## awww namespace

Clavis 只拥有 `clavis-desktop`：

```text
awww-daemon --layer background --namespace clavis-desktop --no-cache
awww query -n clavis-desktop
awww img -n clavis-desktop -o <output> ...
awww clear -n clavis-desktop -o <output> ...
awww kill -n clavis-desktop
```

所有命令都以参数数组执行。Clavis 不使用默认 namespace，不调用
`killall`，也不会停止其他 awww 实例。

awww 的 FPS 和过渡步长保存于 `wallpaper.awww`。持续时间、缓动模式和
贝塞尔曲线与 Quickshell overview 共用 `wallpaper.transition` 中的现有
配置；overview 仅单独保存转场类型。
