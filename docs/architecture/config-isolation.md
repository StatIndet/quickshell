# 配置与启动所有权

Clavis 设置数据库位于 `$XDG_CONFIG_HOME/clavis/config.json`，保存 Shell 设置。
Niri 主配置、输出、布局和用户自己的片段仍由用户管理；设置中心只读有效 include
链，日常仅写以下 Clavis 托管片段，不迁移用户原有绑定。

| 片段 | 职责 | 显式入口 |
| --- | --- | --- |
| `clavis/effects.kdl` | Clavis 表面的 X-Ray 规则；默认可只有注释，不接管全局 blur | General → 透明与模糊 |
| `clavis/cursor.kdl` | 光标主题、尺寸和隐藏选项 | 主题的光标区域 |
| `clavis/layer-rules.kdl` | Overview backdrop 规则及全局透明 workspace 背景 | 壁纸的 Overview 区域 |
| `clavis/binds.kdl` | 用户在快捷键页新增的绑定及完整覆盖 | General → 系统 → 快捷键 |

没有内置 outputs/colors 片段注册或模板；历史文档的 colors.kdl 所有权说明已撤下。
正常 Matugen、colors.json、输出查询、多屏定位和按屏幕壁纸保持各自职责。
用户仍可注册自己的任意 Matugen 模板。历史用户文件及 include 不会自动清扫。

安装只部署程序与只读资源。启动、页面加载、文件监听均不初始化片段。
点击对应“设置”才创建缺失文件并在主配置末尾追加缺失的顶层 include；已有文件
即使为空也不填充。普通、可选、间接和等价路径 include 均由 KDL 解析器识别。
删除文件或 include 后停止生成并重新提示，不能用永久 firstSetupDone 标记代替状态。

默认主配置采用 XDG 路径；优先尊重 NIRI_CONFIG 和可确认的 niri 自定义启动路径。
不能确定多个会话配置时拒绝写入。主配置不存在时不另建；符号链接、硬链接、特殊
文件和不可写目标只读，不提权。片段路径相对于实际主配置的目录。

共享按需 helper `scripts/system/niri_config.py` 使用随程序部署的 KDL-py 解析器，
不执行动作。候选 include 图在临时目录中保留合并边界，用真实 `niri validate`
验证后发布。所有功能共用 flock，提交前比较读取版本；主配置修改前保存唯一命名
的备份。先发布片段，再追加 include；失败时在内容仍为本次版本的情况下回滚片段。
多文件操作不是原子事务；不遵守锁的外部编辑器仍存在最后检查后的竞争窗口。
磁盘保存、已引用及 niri 实际重载是不同状态，不主动执行 reload 或重启。

快捷键按照完整的有类型动作表达式归组；目录占位不保存到配置数据库。
内置动作始终保留，参数模板需要用户填写。首次显式接入时，缺失的 binds.kdl 使用
[默认 IPC 键位](../ipc.md)；先检查有效 include 链中的物理键位占用，有冲突时拒绝
写入并列出冲突键。已有文件不填充，升级和重新启动不补回已删除绑定。

外部绑定的标题或选项编辑会在 binds.kdl 中建立同键的完整覆盖，不修改源文件。
每颗 chip 的标题和选项独立；未设置标题、空串和 null 分别保留。
同一托管项就地更新；改键组成一次候选修改。撞上另一托管键时拒绝，不自动让位。
外部原绑定不能删除或直接改键；使用“+”添加另一个键。托管项可删除，覆盖项可
移除覆盖，之后重新展示外部回落。后续 include 可以再次覆盖 Clavis 项，UI 展示来源
及覆盖状态；不调整 include 顺序。Mod 与实际修饰键的不同拼写按 niri 的符号合并与
物理触发顺序分别判断，物理冲突不伪报成后写覆盖。鼠标、滚轮、switch-events 等范围外内容原样保留。

监听只覆盖主配置、有效 include 链及这些文件的父目录，支持原子替换和缺失文件
恢复，不扫描备份或轮询整个目录。编辑期间保留草稿，版本变化要求取消并重载。
按键录制仅在实际设置窗口获准 ShortcutInhibitor 后捕获，失焦/关闭立即释放；
无法匹配实时键盘布局时提示手工输入 XKB 键名。

会话由 niri-session 启动，Shell 与剪贴板 watcher 的 unit 跟随 niri.service。
Fcitx5、nm-applet、blueman-applet 由 XDG Autostart 管理，Polkit 代理仍由用户配置启动。

## Matugen 模板注册与启用状态

`<shell root>/matugen/config.toml` 和 `templates/` 是只读的内置资源，由包管理器
安装；`$CLAVIS_CONFIG_HOME/matugen/config.toml`（默认
`$XDG_CONFIG_HOME/clavis/matugen/config.toml`）只注册用户模板。不会在首次启动时复制
内置资源，用户目录可以不存在。模板目录里的孤立文件不构成注册。

`scripts/lib/matugen-registry.sh` 与 `scripts/theme/matugen_registry.jq` 共同读取两层
registry，解析结果供 `manage_matugen_templates.sh list` 和生成脚本共享。
`MatugenTemplateService` 提供动态模型、来源、解析后的绝对输入/输出路径、hook 和错误。
用户 ID 不得覆盖内置 ID，同层重复 ID 无效；`quickshell` 为隐藏、必需的内部模板。

支持明确的 canonical TOML 子集：

```toml
[templates.ghostty]
input_path = "templates/ghostty.conf"
output_path = "~/.config/ghostty/themes/Matugen"
post_hook = "optional command"
```

字段使用单行双引号字符串，支持 `\"`、`\\`、`\b`、`\f`、`\n`、`\r`、`\t` 和
`\uXXXX` 转义，以及空行和 `#` 注释。`post_hook` 可省略。不支持 inline table、
多行/单引号字符串、其他字段或完整 TOML 等价写法；不支持的内容会报告错误。
ID 区分大小写，由字母、数字、下划线、连字符组成，可用单个点连接这些片段。
含点 ID 必须写为 `[templates."editor.custom"]`，避免被 TOML 当作嵌套 table；管理器
统一输出带引号的 ID，不擅自改名。

输入相对路径以所属 registry 目录为基准；输出必须是绝对文件路径、`~/...` 或
`$HOME/...`。路径不执行变量/命令替换，不使用 `eval`，剩余 `$`、反引号和控制字符
会被拒绝。内置输出支持 `@CLAVIS_GENERATED_HOME@` 占位符。

`config.json` 的 `theme.matugenTemplates` 是 ID → bool map，保留未知但合法 ID 的
已有状态。首次发现内置模板记录 `true`，用户模板记录 `false`；显式状态始终优先。
无效模板不能启用，也不会被设置中心送入生成。配置文件监听加 5 秒轮询刷新负责发现
首次创建的 registry、手工编辑以及输入文件的删除/恢复。

添加窗口复用 FilePicker，接收任意普通 UTF-8 模板文件。点击添加后由管理器静态校验并调用 Matugen
`--dry-run`（使用固定验证色，移除 hook），成功才写入注册。独立 `validate` CLI 保留，
UI 不要求用户先点击验证。添加期间使用固定占位的 BrailleSpinner，失败保持窗口并显示错误。Matugen 的
`--dry-run` 不渲染模板表达式，因此语法/渲染问题仍可能在实际生成时报告。
管理器复制源文件至用户 `templates/<ID>.<原扩展名>`，临时写入同目录 config 后
rename 替换；Clavis 写入者通过 flock 串行化，提交前检查配置是否被外部编辑。
失败不会发布半套 registry；不支持的配置语法需要用户先修复，symlink config 请手工管理。
外部编辑器仍应使用原子写入；提交前比较不能消除不遵守锁的编辑器的全部竞争窗口。

删除操作只移除用户 section，随后清理 `config.json` 状态；仅清理没有被其他注册
引用、且位于托管目录直属位置的普通源文件。手工注册的外部源文件、symlink 源和共享
源保留。**任何 output_path 都不会因关闭开关或删除注册而被删除。**

“打开模板位置”通过 argv 调用 `xdg-open` 打开源文件父目录，不打开生成目标。
默认目录处理器声明 `Terminal=true` 时，使用 `xdg-terminal-exec` 提供终端，避免
`xdg-open` 通用后端直接启动终端文件管理器却没有 TTY。不修改 MIME 默认配置。

模板中的 `post_hook` 是以用户权限执行的任意命令，不是沙箱。新发现用户模板默认
关闭；设置中心显示无点击/键盘动作的 terminal 信息标记，通过 tooltip 展示命令。
开关直接控制整个模板，不存在独立 hook 权限或启用确认。
验证和添加不执行 hook。用户启用模板即信任其内容，之后应谨慎修改模板和 hook。

每次生成在 `$CLAVIS_RUNTIME_HOME/temporary/matugen.XXXXXX/config.toml` 中写入 runtime
配置，不改两层 registry。先单独生成内部配色，输出 JSONL `core-ready` 后立即通知
`Appearance.reloadColors()`；再逐个生成有效且启用的外部模板，按 output_path 创建父目录。
新增模板无需修改 service、UI 或生成脚本中的应用列表。无 `--templates` 参数的脚本
调用只默认启用内置模板；`--templates ''` 仅生成内部配色。

生成脚本 stdout 是 schemaVersion 1 的状态 JSONL（`core-ready`、`core-error`、
`external-error`、`finished`）；Matugen 诊断通过 stderr/error 字段报告。退出 0 表示
成功，3 表示核心成功但外部失败，其他非零表示核心或调用失败。外部失败仍继续后续
模板，设置中心显示错误并通过 tooltip 提供详细信息。挂起的 hook 会延迟后续外部
模板，但不会延迟已经完成的核心配色重载；这里不提供命令沙箱或 hook 超时策略。
