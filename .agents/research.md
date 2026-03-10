# Arch-view Lua 移植研究
- 最新验证口径已经固定：先运行计划中的强相关 suite 组合，预期 `All regression checks passed (275)`；再运行 `lua tests/regression.lua`，预期 `All regression checks passed (420)`，且输出包含 `dep_rules ok`、`legacy_path_guard ok`、`gameplay_loop_no_ui ok`、`forbidden_globals ok`、`arch_view_guard ok`。如果后续再动这些目录，先复用这套口径，不要重新发明校验清单。

## 2026-03-10 arch-view Lua 移植深度研究

> 研究对象：https://github.com/unclebob/arch-view（Clojure 原版）
> 研究目标：评估当前 `scripts/architecture/arch_view` Lua 实现的移植完整性，确认已知偏差与后续行动。

### 原版模块对照表

| Clojure 原版 | Lua 对应实现 | 备注 |
|---|---|---|
| `input/source_scan.clj` | `arch_view/source_scan.lua` | 已完成；适配 Lua `require` 路径与 `init.lua` 包约定 |
| `input/dependency_extract.clj` | `arch_view/dependency_extract.lua` | 已完成；解析 4 种 Lua `require()` 语法形式，忽略动态 require |
| `input/dependency_checker.clj` | `cli.lua` 内 `_load_config` | Clojure 读 EDN 文件；Lua 直接 `loadfile()` 加载 `.lua` 配置 |
| `domain/architecture_projection.cljc` | `arch_view/projection.lua` | 已完成；Lua 版额外合并了坐标计算与边路由装饰 |
| `layout/layers.clj` | `arch_view/layers.lua` | 已完成；Tarjan SCC、反馈边最小集（精确 + 启发式）、拓扑层分配 |
| `model/classify.clj` | `arch_view/checker.lua`（部分） | 边分类：`direct` / `abstract` |
| `model/components.clj` | `arch_view/checker.lua`（部分） | 组件分类，`component_rules` 配置驱动 |
| `model/graph.clj` | 内联于 `dependency_extract.lua` / `layers.lua` | 无独立模块 |
| `render/ui/quil/` | `viewer/`（HTML + JS） | 策略完全替换：Quil 交互式 GUI → 静态 HTML 打包输出 |
| `core.clj` | `arch_view/cli.lua` + `arch_view_cli.lua` | CLI 入口；`scan / check / viewer` 三命令 |
| （无） | `arch_view/checker.lua` 中的 forbidden / cycle_baseline | Lua 版新增能力，原版无对应 |
| （无） | `arch_view/json_reader.lua` + `arch_view/json_writer.lua` | 原版用 EDN；Lua 版用 JSON |
| （无） | `arch_view/route_engine.lua` | 正交边路由；原版由 Quil 渲染层负责 |

### 移植完整性确认

- **功能链路完整**：`source_scan → dependency_extract → layers → projection → checker → build → cli` 全链路已实现。
- **回归全绿**：`lua tests/regression.lua` 输出 `All regression checks passed (420)`，包含 `arch_view_guard ok`。
- **集成测试覆盖**：`tests/suites/architecture/arch_view_contract.lua` 覆盖全部 11 个功能点，含外部项目根与外部配置场景。
- **viewer 输出完整**：`viewer` 命令输出 `index.html / script.js / styles.css / architecture_data.js`，`display_edges / route_points / indicators` 字段均已写入。

### 已落地事项

#### 1. JSON 模块已完成自包含

`json_reader.lua` 与 `json_writer.lua` 已不再依赖 `src.core.utils.number_utils`。

- 已将 `to_integer` / `is_numeric` 所需能力下沉到 `arch_view/common.lua`。
- `json_*` 现在只依赖 `arch_view` 自身模块，工具边界恢复自包含。
- 对应测试已补：`json_modules_are_self_contained`。

#### 2. 子树环传播语义已对齐

Lua 版 `projection.lua` 已不再仅依赖顶层 `layout.feedback_edges` 做子树环标记。

- 当前实现会递归聚合子视图结果，将深层子树中的环正确向父层传播。
- 深层 `alpha.beta.gamma` 环会正确反映到 `alpha.beta`、`alpha` 与 root 层节点。
- 对应测试已补：`projection_propagates_deep_subtree_cycles_to_parents`。

#### 3. `projection.lua` 的视觉职责已拆出

原先混在 `projection.lua` 中的视觉布局与 viewer 装饰逻辑，已拆到 `layout_renderer.lua`。

当前拆分结果：

- `projection.lua`：保留 scoped projection、node/module 映射、edge aggregation、view tree 递归构建
- `layout_renderer.lua`：负责 node rect、layer item、indicator、display edge decoration、canvas size

对应测试已补：

- `layout_renderer_preserves_viewer_contract_shape`

### 当前剩余观察项

#### 1. `projection.lua` 仍承担部分 view-model 组装（低风险）

虽然视觉布局已拆出，但 `projection.lua` 仍然负责：

- breadcrumb 生成
- label / full_name 组装
- node item 组装
- 子视图递归拼装

**判断**

- 当前职责边界已显著优于首版实现。
- 现阶段继续拆分收益有限，暂不作为近期动作。

#### 2. Windows shell 兼容性噪音已修复（已完成）

此前 contract suite 中出现的：

- `The system cannot find the file specified.`

并非 arch_view 核心逻辑错误，而是测试临时目录脚本在 Windows + `sh` 环境下调用了不兼容 shell 命令。

现已修复：

- `guard_scripts_contract.lua` 的临时目录创建/删除逻辑已改为跨 shell 实现
- `arch_view.common.current_dir()` 也已避免 Windows 下通过 `cd` 产生 shell 噪音

结果：

- `tests/contract.lua` 输出已恢复干净
- 全量 `tests/regression.lua` 继续通过

### 原版已有但 Lua 版有意不移植的部分

| 原版特性 | 决策 | 理由 |
|---|---|---|
| Quil 交互式 GUI（点击下钻、源码查看）| 不移植 | 已被静态 HTML viewer 策略替代 |
| EDN 序列化格式 | 不移植 | JSON 已满足 viewer 与 CI 场景需求 |
| `defprotocol` / `defmulti` 源码扫描标记抽象模块 | 不移植 | Lua 无对应语义；`abstract_rules` 配置驱动更适合 Lua 代码库 |
| `model/graph.clj` 独立模块 | 不提取 | 当前内联方式已足够，无独立的调用方 |

### 移植功能完成清单

| 功能 | 状态 | 测试入口 |
|---|---|---|
| Lua 文件扫描与模块 ID 推导（含 `init.lua` 包） | ✅ 完成 | `_test_source_scan_*` |
| 相对 source root 解析 | ✅ 完成 | `_test_source_scan_resolves_*` |
| `require()` 依赖提取（4 种语法形式） | ✅ 完成 | `_test_dependency_extract_*` |
| Tarjan SCC 强连通分量检测 | ✅ 完成 | `_test_layers_*` |
| 反馈边最小集（≤8 节点精确，超限启发式） | ✅ 完成 | `_test_layers_*` |
| 拓扑层分配 | ✅ 完成 | `_test_layers_*` |
| 命名空间投影（root / 子树视图递归构建） | ✅ 完成 | `_test_projection_*` |
| 混合叶节点（mixed-leaf `\|file` 后缀） | ✅ 完成 | 投影测试覆盖 |
| 正交边路由（跨层 / 同层分流） | ✅ 完成 | `_test_route_engine_*` |
| 禁止依赖规则检查 | ✅ 完成 | `arch_view_guard` / `_test_config_*` |
| 循环基准线校验（unexpected / missing） | ✅ 完成 | `_test_cycle_baseline_*` |
| 组件分类与 abstract 标记 | ✅ 完成 | `_test_config_classifies_*` |
| JSON 读写（含 schema_version / project_root 元数据） | ✅ 完成 | `_test_cli_scan_*` |
| CLI `scan / check / viewer` 三命令 | ✅ 完成 | `_test_cli_*` |
| 静态 HTML viewer 打包（含全局 JS payload） | ✅ 完成 | `_test_viewer_command_*` |
| `--in-json` 从已有扫描结果生成 viewer | ✅ 完成 | `_test_cli_viewer_supports_in_json` |

### 已完成动作

- 已消除 `json_reader.lua` / `json_writer.lua` 对 `src.core.utils.number_utils` 的依赖。
- 已将 viewer 视觉布局与装饰逻辑从 `projection.lua` 拆出到 `layout_renderer.lua`。
- 已修正深层子树环向父节点传播的语义偏差。
- 已补充对应 contract 测试，并维持全量回归通过。
- 已修复 Windows 下 contract suite 的 shell 噪音问题。

### 后续仅保留观察项

- 若未来 viewer 视觉层继续复杂化，再评估是否把 node item 组装继续从 `projection.lua` 细拆。
- 若未来需要把 arch_view 提取为仓库外独立工具，再评估是否抽离 `common.lua` 中与当前项目目录结构相关的辅助逻辑。

**明确不做**

- 不实现 Quil GUI 渲染（HTML viewer 已替代）。
- 不支持 EDN 格式（JSON 已满足所有场景）。
- 不移植 Clojure 源码级 `defprotocol` 扫描（`abstract_rules` 已足够）。
- 不把 `model/graph.clj` 提取为独立 Lua 模块（无独立调用方，内联已合适）。
