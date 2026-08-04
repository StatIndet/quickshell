> [!WARNING]
> 当前项目仍未完工，仅作为demo。

## 项目说明

.

### 预览
## Screenshots

<p align="center">
  <img
    src="https://raw.githubusercontent.com/StatIndet/picture/main/island1.png"
    alt="Clavis Shell dashboard"
    width="49%"
  />
  <img
    src="https://raw.githubusercontent.com/StatIndet/picture/main/island2.png"
    alt="Clavis Shell media"
    width="49%"
  />
</p>

<p align="center">
  <img
    src="https://raw.githubusercontent.com/StatIndet/picture/main/island3.png"
    alt="Clavis Shell wallpapers"
    width="49%"
  />
  <img
    src="https://raw.githubusercontent.com/StatIndet/picture/main/island4.png"
    alt="Clavis Shell weather"
    width="49%"
  />
</p>

<p align="center">
  <img
    src="https://raw.githubusercontent.com/StatIndet/picture/main/island5.png"
    alt="Clavis Shell dynamic island"
    width="49%"
  />
</p>
小工具
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/lingdongdao.gif" width="500">
</p>
天气
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/weather.gif" width="500">
</p>
卡片
<p align="center">
  <img src="https://raw.githubusercontent.com/Archirithm/picture/main/system.gif" width="500">
</p>

### 动态配色

Clavis 使用 [Matugen](https://github.com/InioX/matugen) 从当前壁纸或源颜色生成
Material 配色。项目自己的 `matugen/config.toml` 和 `matugen/templates/` 是唯一的
模板来源；运行时不会读取或修改 `~/.config/matugen/config.toml` 和
`~/.config/matugen/templates/`。

每次切换壁纸、明暗模式或 Matugen 配色方案时，会同时更新：

| 程序 | 生成文件 |
| --- | --- |
| Quickshell | `~/.cache/quickshell-dev-colorscheme/colors.json` |
| btop | `~/.config/btop/themes/matugen.theme` |
| Cava | `~/.config/cava/themes/matugen` |
| Kitty | `~/.config/kitty/themes/Matugen.conf` |
| Fcitx5 | `~/.local/share/fcitx5/themes/Matugen/theme.conf` |
| Niri | `~/.config/niri/colors.kdl` |
| Yazi | `~/.config/yazi/theme.toml` |
| Zsh prompt | `~/.cache/quickshell-dev-colorscheme/zsh-prompt-colors.zsh` |

Clavis 只生成配色文件并通知正在运行的程序重载，不会修改这些程序的主配置。
Kitty、Cava、Fcitx5 和 Niri 会在文件生成后立即热重载；Zsh prompt 会在下一次
显示提示行时读取新配色；Yazi 会在下次启动时读取新主题。
首次使用时需要手工启用以下程序：

```ini
# ~/.config/btop/btop.conf
color_theme = "matugen.theme"

# ~/.config/cava/config 的 [color] 段
theme = 'matugen'

# ~/.config/kitty/kitty.conf
include current-theme.conf

# ~/.config/fcitx5/conf/classicui.conf
Theme=Matugen
```

Niri 的 `~/.config/niri/config.kdl` 需要包含：

```kdl
include "colors.kdl"
include optional=true "clavis/cursor.kdl"
```

Clavis 将 Niri 光标设置写入 `~/.config/niri/clavis/cursor.kdl`，不会修改
`~/.config/niri/dms/` 下由其他 shell 管理的配置。

Yazi 会自动读取 `~/.config/yazi/theme.toml`，无需修改主配置。自制 Zsh prompt
需要在 `.zshrc` 的 `precmd` 中加载生成的配色片段；对应源码仓库内维护了
完整示例配置。

热重载直接由 `matugen/config.toml` 中各模板的官方 `post_hook` 处理，不需要
额外脚本：

| 程序 | 运行时重载 |
| --- | --- |
| Kitty | `kitten themes --reload-in=all Matugen` |
| Cava | `pkill -USR1 cava`，重新读取主配置和 `theme = 'matugen'` |
| Fcitx5 | 通过 D-Bus 调用 `ReloadAddonConfig("classicui")`，直接重载 ClassicUI 配置和主题 |
| Niri | 调用 `niri msg action load-config-file` 重新加载 `colors.kdl` |

Kitty 首次启用时运行一次 `kitten themes --reload-in=all Matugen`，让
themes kitten 创建 `current-theme.conf` 并维护 `kitty.conf` 的主题引用。各
hook 末尾使用 `|| true`，因此目标程序没有运行时不会阻断其他模板生成。

控制中心最后一页“高级”可以分别启用或停用 btop、Cava、Kitty、Fcitx5、
Niri、Yazi 和 Zsh prompt 的模板生成。Quickshell 配色始终生成；关闭某个
开关只会停止后续生成和热重载，不会删除该程序已有的配色文件。重新开启时会
立即使用当前壁纸和配色方案补生成。

也可以从仓库根目录手动验证生成流程：

```bash
bash scripts/theme/generate_matugen_colors.sh \
  --color '#6750a4' \
  --mode dark \
  --scheme scheme-tonal-spot \
  --templates 'kitty,fcitx5,niri' \
  --dry-run
```

### 天气图标

Meteocons 资源不纳入 Git；动画图标可从 npm 包 [`@meteocons/lottie`](https://www.npmjs.com/package/@meteocons/lottie) 下载，并将包内容放入 `assets/icons/weather/meteocons/lottie/`。

### 电源菜单

电源菜单依赖 `wlogout` 和 `envsubst`（通常由 gettext 提供）。控制中心“主题”页可在 HyDE 风格的四宫格与横向六项布局之间切换。按钮透明度跟随 Clavis 的 Shell 背景透明度；在 niri 26.04 及以上开启 Shell 背景模糊时，Clavis 会为 wlogout 的 `logout_dialog` layer surface 启用全屏背景模糊。wlogout 本身不支持提交精确的 `ext-background-effect` Region，因此其模糊范围是整个电源菜单背景，而不是每个按钮分别提交的区域。

## Spotlight 聚焦搜索

Launcher 现在使用全屏 Overlay 聚焦搜索，提供应用、壁纸、剪贴板和网页搜索。
项目只提供 IPC，不会修改用户的 niri 配置。推荐在
`~/.config/niri/config.kdl` 的 `binds` 中加入：

```kdl
binds {
    Ctrl+Space repeat=false hotkey-overlay-title="Spotlight" {
        spawn "qs" "ipc" "call" "spotlight" "toggle";
    }
}
```

可用 IPC：

```bash
qs ipc call spotlight toggle
qs ipc call spotlight open
qs ipc call spotlight close
qs ipc call spotlight web
qs ipc call spotlight openMode apps
qs ipc call spotlight openMode wallpapers
qs ipc call spotlight openMode clipboard
```

Spotlight 内使用 Tab 展开模式按钮、Shift+Tab 反向选择、Ctrl+K 进入
Google 网页搜索、Esc 分层退出。网页查询通过 Qt URL API 打开，不进入
shell。剪贴板条目可用单击或 Enter 复制并关闭；Ctrl+单击或
Shift+Enter 会复制但保持 Spotlight 打开。旧的 `launcher` IPC 已删除。

Keystone 只使用新的 `keystone` IPC target：

```bash
qs ipc call keystone hub
qs ipc call keystone tools
qs ipc call keystone closeAllOthers
qs ipc call keystone cancelRecord
qs ipc call keystone currentStyle
```

旧的 `island` IPC target 已删除。

### 剪贴板历史

剪贴板功能依赖 `cliphist` 和 `wl-clipboard`。Clavis 不会在每次打开
Spotlight 时创建 watcher。仓库提供一个 MIME-aware user service：它在浏览器
同时提供图片、纯文本和 HTML 时优先保存真实图片，其次保存纯文本，最后才
保存 HTML，并保证一次 selection 只调用一次 `cliphist store`。

先安装最新 `key` 和服务，再启用开机自启动：

```bash
sudo cmake --install core/build
mkdir -p ~/.config/systemd/user
cp systemd/user/clavis-cliphist.service ~/.config/systemd/user/

systemctl --user disable --now cliphist.service
systemctl --user disable --now \
  cliphist-watcher@text.service \
  cliphist-watcher@image.service

systemctl --user daemon-reload
systemctl --user enable --now clavis-cliphist.service
```

不要同时运行 generic、text/image 和 MIME-aware watcher，否则同一次复制
可能被重复保存。CLI
会在历史为空时检测 watcher；未运行会返回
`cliphist_watcher_inactive`，而不再把它误报为普通的“没有匹配结果”。
可用以下命令核对当前 selection 与 watcher：

```bash
wl-paste --list-types
systemctl --user is-enabled clavis-cliphist.service
systemctl --user is-active clavis-cliphist.service
systemctl --user status clavis-cliphist.service
journalctl --user -u clavis-cliphist.service --since "5 minutes ago"
```

Clipse 和 cliphist 使用不同的历史数据库，Clipse 中存在记录不代表
Spotlight 能读到它；两个 watcher 可以同时监听 Wayland 剪贴板，不构成
数据库冲突。安全包装层支持：

```bash
key clipboard status --format json
key clipboard store --format json
key clipboard list --format json --limit 100
key clipboard inspect 123 --format json
key clipboard preview 123 --format json
key clipboard restore 123 --format json
key clipboard delete 123 --format json
key clipboard clear --format json
```

`store` 由 watcher 调用，负责选择本次 selection 的首选 MIME；不要把它当作
常驻命令手工运行。`list` 只读取轻量索引；可见或被搜索的条目通过 `inspect`
按需解码。
`preview` 与 `inspect` 返回相同的结构化分类，并为原始图片生成受限尺寸的
私有缓存缩略图，不会把图片 Base64 放进 JSON。`restore` 保持
`cliphist decode` 的原始字节，并根据检查结果使用 `wl-copy --type`
恢复文本、图片、URI 列表或 GNOME 文件复制 MIME。entry id 仅接受正十进制
整数，剪贴板正文不会写入日志。旧历史中的 HTML 图片包装会安全降级：内嵌
`data:image` 和受限的本地图片可复用图片预览；远程或 `blob:` 图片不会联网
下载，也不会把原始标签直接显示出来。

可用以下命令确认 Quickshell 与终端实际使用的 CLI。开发构建可通过
`CLAVIS_KEY` 显式指定；缺少 inspect、MIME restore 或 MIME-aware store
capability 时，Spotlight 会显示 `stale_key_cli`，不会静默调用旧实现：

```bash
type -a key
"$PWD/core/build/bin/key" clipboard status --format json
CLAVIS_KEY="$PWD/core/build/bin/key" qs
```

若系统中的 `key clipboard` 仍提示未知命令或缺少必要 capability，需要安装
本仓库构建出的新版 CLI：

```bash
sudo cmake --install core/build
key clipboard status --format json
```

恢复诊断：

```bash
key clipboard restore 123 --format json
wl-paste --list-types
wl-paste --no-newline | sha256sum
```

建议把 `cliphist decode` 的输出也送入 `sha256sum` 比较，避免在终端或日志中
暴露正文。缺少 `wl-copy` 时 `canList` 仍为 true、`canRestore` 为 false，
历史可读取但激活条目会给出明确错误。Clavis 不会自动停止 Clipse、CopyQ
等其他服务；只有实际观察到恢复后 selection 被覆盖时才需要逐项停用诊断。

### Launcher shader

模式按钮和搜索药丸由同一个 SDF shader 绘制。修改 GLSL 后从仓库根目录
重新生成 qsb：

```bash
scripts/build/compile-launcher-shaders.sh
```

脚本需要 Qt Shader Tools 的 `qsb`，会同时保留
`assets/shaders/launcher/frag/` 源码和
`assets/shaders/launcher/qsb/` 运行时产物。

## `key` 与系统监测

系统监测由 `core/src/sysmon/` 中的共享 C++ 核心提供。QML plugin
保留兼容包装，`key sysmon` 和 `key top` 直接链接同一个 collector /
sampler；左侧边栏的 `SystemMonitorService` 只消费一个长期运行的 JSONL
数据流，不在 QML 中读取 `/proc` 或计算速率。

### 构建与安装

除 Qt 6、Qt6Keychain、PipeWire 和 Cava 等原有依赖外，构建 `key top`
还需要 `pkg-config` 可发现的 `ncursesw`。从仓库根目录执行：

```bash
cmake -S core -B core/build
cmake --build core/build
env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
  ctest --test-dir core/build --output-on-failure
sudo cmake --install core/build
sudo cp -a core/build/Clavis core/build/M3Shapes /usr/lib64/qt6/qml/
```

`cmake --install` 将单一 CLI 入口 `key` 安装到 CMake 的
`CMAKE_INSTALL_BINDIR`（默认前缀下通常为 `/usr/local/bin`）。最后一条命令
按本仓库当前 Quickshell 部署方式更新 QML plugins。

### CLI

```bash
key sysmon snapshot --format json
key sysmon stream --format jsonl --interval 1000
key sysmon cpu --format json
key sysmon processes --sort cpu --limit 50 --format json
key top
```

默认 snapshot/stream 包含 system、CPU、memory、GPU、disk、network 和
battery，不包含进程；只有 `key top`、`key sysmon processes` 或显式请求
`processes` module 才会扫描进程。JSON v1 字段、单位、不可用值和 JSONL
约定见 [`docs/sysmon-schema-v1.md`](docs/sysmon-schema-v1.md)。系统页面的
Material 3 检查记录见
[`docs/system-monitor-material3-audit.md`](docs/system-monitor-material3-audit.md)。

`key top` 的主要快捷键：

| 按键 | 操作 |
| --- | --- |
| `q` | 退出 `key top` |
| `Esc` | 关闭当前弹窗或取消输入模式 |
| `?` | 帮助 |
| `↑` / `↓`、`j` / `k` | 移动进程选择 |
| `PageUp` / `PageDown` | 翻页 |
| `Tab` / `Shift+Tab` | 切换区域 |
| `/` / `f` | 筛选进程 |
| `s` / `t` | 切换排序字段 / 进程树 |
| `p` / `Space` / `r` | 暂停恢复 / 立即刷新 |
| `Enter` | 进程详情 |
| `K` | 进程信号确认；默认 SIGTERM，SIGKILL 需要二次确认 |

这里使用大写 `K` 发送信号，以保留 Vim 风格的小写 `k` 向上移动。
`NO_COLOR` 可关闭颜色，`key top --ascii` 会强制整个界面只输出 ASCII。

### QML 数据流

`Services/SystemMonitorService.qml` 在系统页位于前台时取得引用并启动一个
`key sysmon stream`，按行验证 schema v1、维护有限历史、暴露
loading/ready/stale/error 状态，并在异常退出时有限退避重连。页面离开前台
后释放引用并停止 stream。展示组件不直接启动命令；“完整监视器”操作由
Service 选择可用终端并执行 `key top`。

可重复的 QML 数据、渲染和进程生命周期 smoke：

```bash
CLAVIS_KEY="$PWD/core/build/bin/key" \
CLAVIS_SMOKE_OPEN_TOP=1 TERMINAL=/usr/bin/true \
  qs --no-color -p ./smoke_system.qml
```

测试结束会输出 `SYSMON_SMOKE_PASS`，释放页面引用并主动退出；此时不应再有
`key sysmon stream` 进程。



### 致谢



本项目在实现过程中参考并复用了多个优秀开源项目的设计、组件和实现思路，感谢这些项目及其维护者：

1. [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)：可复用组件、Quickshell 模块组织和 Material 风格界面的重要参考来源。
2. [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)：提供了成熟的 Quickshell Material Shell 模板、控制中心和交互设计参考，也是壁纸过渡shader的来源。
3. [caelestia-shell](https://github.com/caelestia-dots/shell)：锁屏界面和 Quickshell Shell 视觉风格的重要参考来源。
4. [qml-niri](https://github.com/imiric/qml-niri)：Niri IPC、工作区/窗口模型和 QML 插件封装的实现参考。
5. [Breezy Weather](https://github.com/breezy-weather/breezy-weather)：天气界面、天气信息组织和 Material 3 天气可视化设计参考。
6. [soramanew/m3shapes](https://github.com/soramanew/m3shapes)：提供 Material 3 Expressive 形状、形变算法与解析抗锯齿 QML 原生模块。
7. [HyDE](https://github.com/HyDE-Project/HyDE)：电源菜单直接使用 `wlogout`，其四宫格与横向六项布局、图标和悬停形变基于 HyDE 的 wlogout 配置移植，并适配了 Clavis 配色、字体与 niri 会话动作。



### 开源协议



本项目以 [GNU GPL-3.0](https://github.com/StatIndet/quickshell/blob/main/LICENSE) 作为主许可证发布。项目中参考、改写或复用的第三方源码、设计和资源仍遵循其原始项目许可证；相关许可证副本集中存放在 [`licenses/`](https://github.com/StatIndet/quickshell/blob/main/licenses) 目录中。

- `end-4/dots-hyprland`：GPL-3.0，见 [`licenses/end-4-dots-hyprland-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/end-4-dots-hyprland-GPL-3.0.txt)。
- `DankMaterialShell`：MIT，见 [`licenses/DankMaterialShell-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/DankMaterialShell-MIT.txt)。
- `caelestia-shell`：GPL-3.0，见 [`licenses/caelestia-shell-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/caelestia-shell-GPL-3.0.txt)。
- `qml-niri`：MIT，见 [`licenses/qml-niri-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/qml-niri-MIT.txt)。
- `Breezy Weather`：LGPL-3.0 及附加条款，见 [`licenses/BreezyWeather-LGPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/BreezyWeather-LGPL-3.0.txt) 和 [`licenses/BreezyWeather-LICENSE_ADDITIONAL.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/BreezyWeather-LICENSE_ADDITIONAL.txt)。
- `Animated Weather Cards`：MIT，见 [`licenses/AnimatedWeatherCards-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/AnimatedWeatherCards-MIT.txt)。
- `soramanew/m3shapes`：Apache-2.0，见 [`licenses/M3Shapes-Apache-2.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/M3Shapes-Apache-2.0.txt)。
- `HyDE`：GPL-3.0，见 [`licenses/HyDE-GPL-3.0.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/HyDE-GPL-3.0.txt)。
- `matugen-themes`：MIT，模板基于提交
  `21c77e1d279e5f94cbdf044d55f3de0ee95c8e09`，见
  [`licenses/matugen-themes-MIT.txt`](https://github.com/StatIndet/quickshell/blob/main/licenses/matugen-themes-MIT.txt)。

若某个文件中保留了更具体的版权或许可证声明，以该文件内声明和对应上游许可证为准。
