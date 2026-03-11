# Arch View

`arch_view` 是静态架构扫描器，分析 `src/**/*.lua` 的模块级 `require` 依赖。职责：生成依赖图、按层投影视图、校验声明式边界规则。

文本护栏（旧路径、宿主全局 API、运行时禁用语法）仍由 `tests/guards/legacy_path_guard.lua`、`tests/guards/forbidden_globals.lua` 负责，arch_view 不替代它们。

## 真源与约束

- 结构性依赖规则唯一真源：`scripts/arch/config.lua`
- `tests/guards/dep_rules.lua` 只保留文本级硬边界（退休路径、宿主全局 API、`state.ui_*` 直写、`ui_port` 旁路）
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

根视图展示 `app`、`core`、`game`、`infrastructure`、`presentation` 五个顶层子树。点击非叶节点下钻；点击叶节点在右侧看到源码、内外依赖、组件、层级、抽象标记与循环标记。

**节点颜色：**
- 红色：子树或依赖条目涉及循环依赖
- 绿色：含抽象契约（主要对应 `src.core.ports.*` 与 `src.game.ports.*`）

**交互：** 节点顶/底有 incoming/outgoing 依赖三角，悬浮显示聚合依赖列表；视图中央绘制 `display_edges` 正交折线路由；breadcrumb 与 Back 恢复上一视图的滚动位置与选中状态。
