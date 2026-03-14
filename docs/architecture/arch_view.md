# Arch View

`arch_view` 是静态架构扫描器，分析 `src/**/*.lua` 的模块级 `require` 依赖。职责：生成依赖图、按层投影视图、校验声明式边界规则。

文本护栏（宿主全局 API、运行时禁用语法与少量仓库级硬边界）仍由 `tests/guards/dep_rules.lua`、`tests/guards/forbidden_globals.lua` 负责，arch_view 不替代它们。

如果你想先判断 `arch_view` 在整套测试/静态分析里的位置，以及本地常见耗时，先读 `docs/architecture/quality_map.md`。

## 真源与约束

- 结构性依赖规则唯一真源：`scripts/arch/config.lua`
- `tests/guards/dep_rules.lua` 只保留文本级硬边界（宿主全局 API、`state.ui_*` 直写、`ui_port` 旁路，以及少量跨子系统禁令）
- 零模块级循环依赖，无白名单，任意新循环直接让 `check` 失败

## 命令

```
lua scripts/arch.lua check
```
扫描 `src/`，执行边界校验，失败则非零退出。`tests/guards/arch_view_guard.lua` 与 `tests/regression.lua` 均使用此能力；跑全部护栏用 `lua tests/guard.lua`。

`check` 同时校验两类循环：
- 模块级 `require` 环
- projection/view 级反馈环（即模块图无环，但聚合到 viewer 视图后形成的往返依赖）

```
lua scripts/arch.lua
```
无参数：生成并打开静态 viewer，等价于 `viewer --out-dir ./tmp/arch_view --open`。

```
lua scripts/arch.lua viewer
lua scripts/arch.lua viewer --out-dir <dir> [--open]
lua scripts/arch.lua viewer --in-json <file> --out-dir <dir> [--open]
```
导出静态 viewer（`index.html`、`script.js`、`styles.css`、`architecture.json`、`architecture_data.js`）。有已导出 JSON 时可用 `--in-json` 跳过重扫。默认输出目录 `./tmp/arch_view`。

```
lua scripts/arch.lua scan --out /tmp/monopoly_architecture.json
```
导出完整机器可读数据（含 `graph`、`modules`、`layout`、`classified_edges`、`views`、`check` 等）。

**扫描其他项目：**

```
lua scripts/arch.lua check --project-root /path/to/project --config /path/to/architecture.lua
```

## Viewer 读法

根视图展示当前生效的顶层子树：`entry`、`host`、`ui`、`turn`、`player`、`computer`、`rules`、`state`、`config`，以及仍保留的 `core`。点击非叶节点下钻；点击叶节点在右侧看到源码、内外依赖、组件、层级、抽象标记与循环标记。

如果某个 package 同时有 `init.lua` 和后代模块（例如 `src.rules.market`），viewer 交互上仍按非叶节点处理：主点击继续下钻，不把“有源码”误判成叶子。`views[*].nodes[*].leaf` 与 `drillable` 是 projection 输出给 viewer 的内部契约；viewer 只在旧 payload 缺字段时做最小兼容推断，不再重算业务语义。

**节点颜色：**
- 红色：子树或依赖条目涉及循环依赖
- 绿色：含抽象契约（主要对应 `src.core.ports.*` 与 `src.rules.ports.*`）

**交互：** 节点顶/底有 incoming/outgoing 依赖三角，悬浮显示聚合依赖列表；视图中央绘制 `display_edges` 正交折线路由；breadcrumb 与 Back 恢复上一视图的滚动位置与选中状态。
