# 配置与启动所有权

Clavis 设置数据库位于 `$XDG_CONFIG_HOME/clavis/config.json`，它只保存 Shell 自身
设置。Niri 的输出、布局与快捷键配置由用户直接管理，不属于 Clavis 设置中心。

| 路径或机制 | 所有者 | 职责 |
| --- | --- | --- |
| `$XDG_CONFIG_HOME/niri/config.kdl` | 用户 | 主配置与 include 顺序 |
| 用户自己的其他 `.kdl` | 用户 | Niri 输出、布局、快捷键与其他配置 |
| `$XDG_CONFIG_HOME/niri/clavis/colors.kdl` | Clavis | Matugen 生成的 Niri 配色 |
| `$XDG_CONFIG_HOME/niri/clavis/effects.kdl` | Clavis | Shell 背景模糊集成 |
| `$XDG_CONFIG_HOME/niri/clavis/cursor.kdl` | Clavis | 根据 Cursor 设置生成的 Niri 鼠标指针 fragment |
| `$XDG_CONFIG_HOME/clavis/config.json` | Clavis | 设置中心持久化 |
| 两个 `clavis-*.service` | systemd user | 与 `niri.service` 同生命周期的进程 |
| `$XDG_CONFIG_HOME/autostart/*.desktop` | 用户/XDG | 普通桌面应用启动 |

Clavis 不扫描、编辑或持久化 Niri 的输出、布局与快捷键设置，也不把这些字段写入
Shell 配置数据库。

会话由 `niri-session` 启动，`key session` 已删除。Shell 与剪贴板 watcher 的 unit
通过 `WantedBy=niri.service` 安装，且声明 `PartOf=`、`Requisite=` 和 `After=`；安装只
enable，不使用 `--now`。Fcitx5、nm-applet、blueman-applet 由 XDG Autostart 管理，
Polkit 代理仍由用户 `startup.kdl` 启动。

Matugen 颜色写入 `niri/clavis/colors.kdl`，背景效果写入
`niri/clavis/effects.kdl`，鼠标指针设置写入 `niri/clavis/cursor.kdl`。
`config.json` 是用户在 Clavis 设置中心选择的持久化 source of truth；
`cursor.kdl` 只是自动生成、供 Niri 的
`include optional=true "clavis/cursor.kdl"` 消费的 fragment，不应手工编辑。
外部应用仍读取自己的配置。

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

添加窗口复用 FilePicker，接收任意普通 UTF-8 模板文件。先静态校验并调用 Matugen
`--dry-run`（使用固定验证色，移除 hook），再允许添加；添加时重复校验。Matugen 的
`--dry-run` 不渲染模板表达式，因此语法/渲染问题仍可能在实际生成时报告。
管理器复制源文件至用户 `templates/<ID>.<原扩展名>`，临时写入同目录 config 后
rename 替换；Clavis 写入者通过 flock 串行化，提交前检查配置是否被外部编辑。
失败不会发布半套 registry；不支持的配置语法需要用户先修复，symlink config 请手工管理。
外部编辑器仍应使用原子写入；提交前比较不能消除不遵守锁的编辑器的全部竞争窗口。

删除操作只移除用户 section，随后清理 `config.json` 状态；仅清理没有被其他注册
引用、且位于托管目录直属位置的普通源文件。手工注册的外部源文件、symlink 源和共享
源保留。**任何 output_path 都不会因关闭开关或删除注册而被删除。**

模板中的 `post_hook` 是以用户权限执行的任意命令，不是沙箱。新发现用户模板默认
关闭；设置中心显示命令标记，启用带命令的用户模板前展示命令及每次生成后执行的说明。
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
