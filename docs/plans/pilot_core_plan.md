# 适配层 UI 共享与 AutoRunner 归属调整 ExecPlan

本 ExecPlan 是一份活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 四个章节必须在执行过程中持续更新。

本仓库有 ExecPlan 规范文件 `.agent/PLANS.md`，本计划必须按该规范维护。

## Purpose / Big Picture

本计划的目标是把 Eggy、Oasis、Love2D 三个平台适配层中可共享的 UI 逻辑抽到 `src/adapters/core/`，允许拆分为多个核心模块，并同步调整 AutoRunner 的归属路径。完成后，Eggy/Oasis/Love2D 的 UI 文案与状态构建由核心层统一产出，平台层只负责节点绑定与渲染，现有 UI 文本、按钮名称、选择流程与日志行为必须完全不变。验证方式是运行现有 Lua 测试脚本，并在可用环境下用最小交互确认 UI 与自动运行行为一致。

## Progress

- [x] (2026-01-21 15:10Z) 创建 ExecPlan 并明确 UI 共享抽取范围与依赖约束。
- [x] (2026-01-21 15:12Z) 扩展计划范围，纳入 Love2D 与 AutoRunner 归属调整，允许拆分多个 core 模块。
- [x] (2026-01-21 15:36Z) 盘点 Eggy/Oasis/Love2D 可共享的 UI 文案与状态构建逻辑并确定边界。
- [x] (2026-01-21 15:36Z) 抽取 UI 逻辑到 `src/adapters/core/` 并提供可复用视图数据结构。
- [x] (2026-01-21 15:36Z) 迁移 AutoRunner 到 core 并更新三平台引用，行为保持一致。
- [x] (2026-01-21 15:36Z) 改造 Eggy/Oasis/Love2D 适配层使用共享 UI 逻辑并删除重复实现。
- [x] (2026-01-21 15:36Z) 运行依赖检查与回归脚本：`lua tests/deps_check.lua`、`lua tests/regression.lua`。
- [ ] 在可用运行环境下进行最小 UI 手工验证并记录结论。

## Surprises & Discoveries

- 观察：现有日志截取是“从 #entries - max_lines 开始”，会比 max_lines 多一行；共享逻辑保持该行为以避免输出变化。
  Evidence: `src/adapters/eggy/eggy_layer.lua` 与 `src/adapters/love2d/panel_renderer.lua` 的旧逻辑皆使用 `math.max(1, #entries - max_lines)`。

## Decision Log

- Decision: UI 共享逻辑放在 `src/adapters/core/`，覆盖 Eggy、Oasis、Love2D 的文案与状态构建，不直接操作平台节点或渲染 API。
  Rationale: 三个平台在文案与状态构建上高度一致，抽到 core 能减少分叉；节点绑定与绘制逻辑属于平台特性，应留在平台层。
  Date/Author: 2026-01-21 / Codex

- Decision: 共享逻辑允许拆分为多个 core 模块，以功能边界划分，避免单文件过大或互相耦合。
  Rationale: UI 逻辑包含阶段标题、选择弹窗、面板/格子详情、日志拼装等不同职责，拆分更清晰，且均有 ≥2 调用点。
  Date/Author: 2026-01-21 / Codex

- Decision: AutoRunner 从 Love2D 归属迁移到 core，并由三平台统一引用。
  Rationale: AutoRunner 是平台无关的规则驱动逻辑，当前路径误导依赖方向，迁移后依赖更清晰且不改变行为。
  Date/Author: 2026-01-21 / Codex

- Decision: 保持 Love2D 仅使用 `body_lines` 作为选择弹窗正文，忽略 `pending.body`，同时复用共享的标题与选项构建。
  Rationale: Love2D 旧逻辑只拼接 `body_lines`，保持一致避免弹窗正文出现差异。
  Date/Author: 2026-01-21 / Codex

- Decision: 共享日志截取函数沿用 “从 #entries - max_lines 开始” 的窗口规则。
  Rationale: Eggy/Oasis/Love2D 旧逻辑都基于该规则，确保日志条数与起始行一致。
  Date/Author: 2026-01-21 / Codex

## Outcomes & Retrospective

已完成 UI 共享模块抽取、AutoRunner 迁移与三平台改造，依赖检查与回归脚本通过。尚未进行手工 UI 验证，需在可运行环境补充最小交互确认。

## Context and Orientation

当前核心模块已存在 `src/adapters/core/adapter_layer.lua` 与 `src/adapters/core/presenter.lua`。Eggy 与 Oasis 的 UI 文案与刷新逻辑在 `src/adapters/eggy/eggy_layer.lua` 和 `src/adapters/oasis/oasis_layer.lua` 中大段重复。Love2D 的 UI 文案散落在 `src/adapters/love2d/panel_renderer.lua` 与 `src/adapters/love2d/modal.lua` 的绘制/弹窗流程中，逻辑上与 Eggy/Oasis 的文本拼装一致，但当前没有共享。

AutoRunner 当前位于 `src/adapters/love2d/auto_runner.lua`，被 Eggy 与 Oasis 引用，这属于依赖方向不清晰的问题。本计划会迁移它到 core，并更新三平台引用路径。

本计划中的“UI 逻辑”仅指文案、状态与选择数据的构建，不包含节点查找、事件绑定、绘制或引擎 API。核心模块应产出可复用的视图数据结构，平台层负责把这些数据映射到节点或渲染调用。

## Plan of Work

首先盘点三平台中重复或等价的 UI 文案与状态构建逻辑，明确哪些字段可统一为“视图数据结构”。随后在 `src/adapters/core/` 下新增多个 UI 共享模块，按职责拆分，例如阶段标题与标签、选择弹窗数据、面板数据、格子详情数据、日志数据等。核心模块只返回纯 Lua 表或字符串，不调用任何平台 API。

接着迁移 AutoRunner 到 `src/adapters/core/`（或 `src/adapters/core/auto_runner.lua`），更新 Eggy/Oasis/Love2D 的引用路径，确保自动运行行为与节奏保持一致。之后改造 Eggy/Oasis/Love2D：Eggy/Oasis 继续用 UIState 接口设置节点，但文本与数据改从 core 模块获取；Love2D 仍使用渲染器绘制，但渲染时使用 core 提供的文本/数据而不是自行拼装。所有现有 UI 文本与按钮名称必须保持原样。

最后运行测试脚本，并在可用环境中进行最小交互验证，确认自动运行与选择流程不回归。

## Concrete Steps

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 下执行以下步骤。

1) 盘点可共享 UI 逻辑与字段。
   - 阅读 `src/adapters/eggy/eggy_layer.lua`、`src/adapters/oasis/oasis_layer.lua`、`src/adapters/love2d/panel_renderer.lua`、`src/adapters/love2d/modal.lua`。
   - 记录重复的文本拼装、选择弹窗数据与格子详情逻辑，更新本计划的 Progress。

2) 新增 core UI 共享模块（允许多个文件）。
   - 在 `src/adapters/core/` 新建模块，例如 `ui_phase.lua`、`ui_choice.lua`、`ui_panel.lua`、`ui_tile.lua`、`ui_log.lua`（具体拆分以职责为准）。
   - 模块只依赖 `src.config.*` 与 `src.util.logger`，输出纯 Lua 数据结构与字符串。

3) 迁移 AutoRunner 到 core。
   - 将 `src/adapters/love2d/auto_runner.lua` 迁移到 `src/adapters/core/auto_runner.lua`。
   - 更新 Eggy/Oasis/Love2D 的 `require` 路径，确保逻辑不变。

4) 改造三平台适配层使用共享 UI 逻辑。
   - Eggy/Oasis：用 core 模块输出的数据填充 UIState 节点，删除重复函数。
   - Love2D：渲染器与弹窗仍负责绘制，但其文案与状态来自 core 模块，不再在渲染器内拼装。
   - 逐项比对文本与按钮名称，确保输出完全一致。

5) 运行测试并记录结果。

    lua tests/deps_check.lua
    lua tests/regression.lua

6) 在有运行环境时做最小手工验证。
   - 触发“下一回合/自动运行”。
   - 触发一次选择弹窗并完成选择或取消。
   - 点选一个格子查看详情。记录观察结论。

## Validation and Acceptance

验收标准是行为不变且测试通过。必须满足以下条件：

- `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均通过。
- Eggy/Oasis/Love2D 的 UI 文本、按钮名称、选择流程与日志输出与改造前一致。
- 选择弹窗仍可正常选择/取消，格子详情与棋盘标签显示一致，无新增报错。

如具备 Love2D 运行环境，启动 demo 后应看到与改造前一致的面板、弹窗与日志表现。

## Idempotence and Recovery

本计划属于 UI 逻辑抽取与替换，可重复执行且不影响配置与规则层。若抽取后出现 UI 回归，可临时回退到平台原实现，再逐步缩小共享边界，优先保证行为一致。AutoRunner 迁移若引发异常，应先恢复原路径再逐步替换。

## Artifacts and Notes

建议在共享模块中保持原有日志文本与拼接逻辑不变，避免回归测试或工具依赖输出差异。测试输出示例：

    lua tests/deps_check.lua
    Dependency self-check passed

    lua tests/regression.lua
    ..........
    All regression checks passed (26)

## Interfaces and Dependencies

核心 UI 模块以“输出数据结构”为主，平台层负责应用到 UI 或渲染。建议的最小接口如下，具体名字可调整但需稳定且可复用：

- `ui_phase.build_phase_label(phase)` 返回阶段文本。
- `ui_choice.build_choice_view(game, pending_choice)` 返回选择弹窗视图数据（标题、正文、选项列表、取消文案）。
- `ui_panel.build_panel_view(view, item_name_by_id, vehicle_name_by_id)` 返回面板所有文本字段。
- `ui_tile.build_tile_detail_view(view, selected_tile)` 返回格子详情字段与道路覆盖信息。
- `ui_log.build_log_lines(entries, max_lines)` 返回日志行列表。

平台层依赖关系要求：

- `src/adapters/core/*.lua` 只依赖 `src.config.*` 与 `src.util.logger`（以及必要的 Lua 标准库），不得依赖 `src/adapters/eggy`、`src/adapters/oasis`、`src/adapters/love2d`。
- Eggy/Oasis/Love2D 依赖 core 模块，不反向依赖平台层。
- AutoRunner 迁移到 `src/adapters/core/auto_runner.lua` 后，三平台只引用 core 版本。

Plan update note: 2026-01-21 / Codex：纳入 Love2D 与 AutoRunner 归属调整，允许拆分多个 core 模块，并补充新的依赖方向与验收说明。
Plan update note: 2026-01-21 / Codex：完成 UI 共享模块与 AutoRunner 迁移并更新三平台实现，记录测试结果与关键决策，未执行手工 UI 验证。
