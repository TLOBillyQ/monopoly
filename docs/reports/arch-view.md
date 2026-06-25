---
kind: report
status: generated
owner: quality
last_verified: 2026-05-22
---
# Arch View

`arch_view` 是静态架构扫描器，分析 `src/**/*.lua` 的模块级 `require` 依赖。职责：生成依赖图、按层投影视图、校验声明式边界规则。

文本护栏（宿主全局 API、`src/` 运行时禁用语法与少量文本级硬边界）仍由 `spec/guards/lib/dep_rules.lua`、`spec/guards/lib/forbidden_globals.lua` 负责，arch_view 不替代它们。

如果你想先判断 `arch_view` 在整套测试/静态分析里的位置，以及本地常见耗时，先读 `docs/architecture/quality-map.md`。

默认 `~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract` 只保留快速的 in-process 结构契约；真实 `scan/viewer` CLI 导出 smoke 已挪到 `busted --run tooling`，并只保留 `scan` 与 `viewer --in-json` 两个慢路径检查。真实 `analyze(...)` 路径则由 `spec/guards/lib/arch_view_guard.lua` 常驻覆盖，不再重复保留额外 tooling smoke。

## 代码位置

- 通用工具源码与静态 viewer 资产由 `swarmforge/tools.lock` 的 `arch_view` 记录钉定，wrapper 按需 bootstrap 到 `.swarmforge/tools/arch_view@<sha>/`
- Monopoly 专属规则真源仍在 `tools/quality/arch/config.json`
- Monopoly viewer bundle 默认导出到临时或本地工作目录，不再把提交态快照入库
- Monopoly 宿主入口在 `tools/quality/arch.lua`，内部先确保 lockfile 工具缓存，再通过 `require("arch_view")` 调用参考实现
- 默认分析引擎为 `auto`：优先走 Go 核心，不可用时回退 Lua

## 真源与约束

- 结构性依赖规则唯一真源：`tools/quality/arch/config.json`
- `spec/guards/lib/dep_rules.lua` 只保留文本级硬边界（宿主全局 API、`state.ui_*` 直写、`ui_port` 旁路，以及少量跨子系统禁令）
- 零模块级循环依赖，无白名单，任意新循环直接让 `check` 失败
- 根组件语义现为：`app`、`host`、`ui`、`turn`、`player`、`computer`、`rules`、`state`、`config`、`foundation`
- 当前 canonical 命名为 `src/ui/ports/*`、`src/ui/state/*`、`src/ui/visual_hold.lua` 与 `src/ui/host_bridge.lua`

## 命令

```
lua tools/quality/arch.lua check
```
扫描 `src/`，执行边界校验，失败则非零退出。`spec/guards/lib/arch_view_guard.lua` 使用此能力；跑全部护栏用 `busted --run guards`。配置默认来自 `tools/quality/arch/config.json`。

`check` 同时校验两类循环：
- 模块级 `require` 环
- projection/view 级反馈环（即模块图无环，但聚合到 viewer 视图后形成的往返依赖）

Monopoly 当前只在 `tools/quality/arch/filter.lua` 里过滤 `root` 视图的纯命名空间折叠伪环。`ui` 视图里的命名空间投影环已经清零，不再保留额外特例。

```
lua tools/quality/arch.lua
```
无参数：生成并打开静态 viewer，等价于 `viewer --out-dir ./.arch_view/viewer --open`。

```
lua tools/quality/arch.lua viewer
lua tools/quality/arch.lua viewer --out-dir <dir> [--open]
lua tools/quality/arch.lua viewer --in-json <file> --out-dir <dir> [--open]
```
导出静态 viewer（`index.html`、`script.js`、`styles.css`、`architecture.json`、`architecture_data.js`）。有已导出 JSON 时可用 `--in-json` 跳过重扫。默认输出目录 `./.arch_view/viewer`。

复制的静态资产来自当前钉定参考实现的 `viewer/` 目录，导出产物不依赖 Google Fonts 或其他外网资源。若要保留某次导出结果，请写到 `tmp/`、`.arch_view/` 或仓库外目录，而不是重新提交到仓库。

```
lua tools/quality/arch.lua scan --out /tmp/monopoly_architecture.json
```
导出完整机器可读数据（含 `graph`、`modules`、`layout`、`classified_edges`、`views`、`check` 等）。

**扫描其他项目：**

```
lua tools/quality/arch.lua check --project-root /path/to/project --config /path/to/architecture.json
```

## Viewer 读法

根视图展示当前生效的顶层子树：`app`、`host`、`ui`、`turn`、`player`、`computer`、`rules`、`state`、`config`、`foundation`。点击非叶节点下钻；点击叶节点在右侧看到源码、内外依赖、组件、层级、抽象标记与循环标记。

如果某个 package 同时有 `init.lua` 和后代模块（例如 `src.rules.market`），viewer 交互上仍按非叶节点处理：主点击继续下钻，不把“有源码”误判成叶子。`views[*].nodes[*].leaf` 与 `drillable` 是 projection 输出给 viewer 的内部契约；viewer 只在旧 payload 缺字段时做最小兼容推断，不再重算业务语义。

**节点颜色：**
- 红色：子树或依赖条目涉及循环依赖
- 绿色：含抽象契约（主要对应 `src.foundation.ports.*` 与 `src.rules.ports.*`）

**交互：** 节点顶/底有 incoming/outgoing 依赖三角，悬浮显示聚合依赖列表；视图中央绘制 `display_edges` 正交折线路由；breadcrumb 与 Back 恢复上一视图的滚动位置与选中状态。
