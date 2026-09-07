# UI 文案与等待反馈

修改 UI 文案、设置页布局或交互时阅读相关章节；仅审查本次改动及直接相邻的状态表达。

## UI copy and information density

- 设置页面默认不写 supporting text。只有标题、图标、控件状态无法表达的新信息才可
  添加 supporting text，例如动态数值、当前模式、不可用原因、错误或验证要求。
- 禁止用文字重复 boolean control state；`Wi-Fi / 已开启 / switch ON` 中的“已开启”
  必须删除。正常状态通常无需说明，硬件阻止、权限失败、backend 不可用等异常状态应
  使用简短文案说明原因。
- 禁止 subtitle 改写或重复 title；例如“添加网络 / 手动添加网络”是无效文案。
- 普通 UI 不得暴露没有用户价值的 backend 实现术语，例如 `NetworkManager 配置`、
  `DBus backend`、内部 UUID；只有明确的高级诊断页面可以展示这些信息。
- 一个语义只保留一种主要表达。selected/highlighted shape、switch、icon、badge 或
  dynamic value 已完整表达状态时，不再追加一句文字重复解释。
- 信息层级和状态优先通过项目现有的 Material Design / expressive shape、icon、badge、
  state layer、tooltip、switch、slider 和 animation 表达，不得另造平行组件体系。
- Tooltip 用于 icon-only action、次要解释，以及不值得长期占据 layout 的辅助信息；
  不要为了避免 tooltip 而把所有解释永久铺在页面上。
- 面向全球用户使用简短、一致的名词或动词短语，避免完整说明句、实现术语和不必要的
  翻译负担。错误、破坏性操作警告、验证规则、认证或权限失败及歧义操作标签不得因精简
  文案而隐藏。
- Material expressive UI 应先以视觉建立 hierarchy，copy 只辅助视觉无法可靠传达的
  内容，不得依靠大量 prose 创建页面结构。
- 交付前，在本次代码审查中检查新增或修改的设置项：title/subtitle、icon/text、
  switch/status text、badge/description 是否重复，相邻 section 是否重复表达同一状态，
  是否暴露无用户价值的实现术语。不扩展为整个设置中心清理，不额外生成审计报告。

## Settings 等待反馈

Settings Center 的短暂异步等待默认复用 `BrailleSpinner`，优先通过
`Widgets/common/InlineBusyIndicator.qml` 在触发控件附近的已有空白区域中作为不参与布局的
覆盖层显示。不得为等待指示器新增布局占位，也不得因 busy 状态插入/删除整行或改变按钮、
section 的位置、间距或几何尺寸。单个操作只标记实际触发它的控件；全局操作可显示在
section header 附近的已有空白区域。`InlineStatusBanner`
保留给错误、警告和需要关注的信息，不用于单纯“正在处理”。不另建 loading 动画体系。

