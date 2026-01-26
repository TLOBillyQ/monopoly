# Eggitor 接入与根目录工程化（LuaSource_Monopoly）

本 ExecPlan 是一个持续更新的活文档，实施过程中必须同步维护 `Progress`、`Surprises & Discoveries`、`Decision Log` 与 `Outcomes & Retrospective`。本计划遵循仓库根目录的 `.agent/PLANS.md` 规范，后续更新必须保持该规范。

## Purpose / Big Picture

完成后，仓库根目录将直接作为 Eggitor 工程（项目名 `LuaSource_Monopoly`）加载与运行，`main.lua` 成为 Eggitor 入口；Eggy 运行只走 `src/adapters/eggy/eggy_runtime.lua`，不再保留 headless 入口。UI 节点使用 `ui_data.lua`，资源索引来自 `refs.lua`。用户可以在 Eggitor 内运行并看到 UI 刷新、回合推进，并能通过“自动控制/托管”切换由 `src/gameplay/agent.lua` 进行决策。

## Progress

- [x] (2026-01-26 00:00Z) 创建初版接入计划，明确根目录工程化与 Eggy 入口迁移方向。
- [ ] (待执行) 复制必要 Eggitor 工程文件到仓库根目录，并更新 `eggy.json` 为 `LuaSource_Monopoly`。
- [ ] (待执行) 调整 `main.lua` 与 `src/adapters/eggy/eggy_runtime.lua` 以匹配 ui_data/UIManager 方案。
- [ ] (待执行) 校验 UI 节点命名与“托管”按钮事件，补齐必要映射。
- [ ] (待执行) 清理 `LuaSource_大富翁/` 与 headless 相关冗余路径，更新 README。
- [ ] (待执行) 在 Eggitor 内验证运行，运行 Lua 测试脚本做回归确认。

## Surprises & Discoveries

- 发现 `src.adapters.eggy.ui_nodes` 文件不存在，现有 `eggy_runtime.lua` 的 UIManager 构建会提前返回。
  Evidence: `rg -n "ui_nodes" -S src` 仅命中 `src/adapters/eggy/eggy_runtime.lua`。
- UIManager 依赖 `Utils/` 目录（`Utils.Frameout` / `Utils.Class` 等），仅复制 UIManager 不足以运行。
  Evidence: `LuaSource_大富翁/UIManager/Utils.lua` 中 `require "Utils.Frameout"` / `require 'Utils.Class'`。

## Decision Log

- Decision: 工程名称使用 `LuaSource_Monopoly`，仓库根目录即 Eggitor 工程根。
  Rationale: 用户明确指定，且要求根目录对应原 `LuaSource_大富翁` 工程层级。
  Date/Author: 2026-01-26 / Codex
- Decision: 运行时引用根目录，`LuaSource_大富翁/` 仅作为样板拷贝来源，不再增量修改。
  Rationale: 避免双工程并存造成维护分叉与错误引用。
  Date/Author: 2026-01-26 / Codex
- Decision: Eggy 入口使用 `src/adapters/eggy/eggy_runtime.lua`，不再保留 headless 路径。
  Rationale: 平台已确定为 Eggy，减少多平台分支和冗余入口。
  Date/Author: 2026-01-26 / Codex
- Decision: UI 节点来源以 `ui_data.lua` 为准，`Data/UINodes.lua` 不再使用。
  Rationale: 用户明确 UI 数据已转换并收敛到 ui_data。
  Date/Author: 2026-01-26 / Codex
- Decision: `EggyAPI.lua` 采用 `docs/eggy/` 中的版本，并复制到根目录供 Eggitor 使用。
  Rationale: 用户指定“用 docs/eggy/ 的”。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

- 尚未执行。本节在每个里程碑结束时更新，记录完成情况与剩余风险。

## Context and Orientation

仓库核心玩法在 `src/`，Eggy 适配层位于 `src/adapters/eggy/`，其中 `eggy_runtime.lua` 负责注册事件并驱动 UI 与回合推进。当前根目录 `main.lua` 是 headless 入口（通过 `src/entry.lua` 选择平台）。示例 Eggitor 工程在 `LuaSource_大富翁/`，包含 `UIManager/`、`Utils/`、`ui_data.lua`、`refs.lua`、`eggy.json` 等样板资源。用户要求把仓库根目录改为 Eggitor 工程根，并以 `LuaSource_Monopoly` 作为工程名；不再保留 headless 路径。

Eggy API 文档在 `docs/eggy/`，其中 `docs/eggy/api/` 是拆分文档索引；查 API 时应优先用拆分文档，不直接阅读 `docs/eggy/EggyAPI.lua`。`EggyAPI.lua` 文件本身用于 Eggitor 类型/接口提示与运行环境。

## Plan of Work

首先以样板工程为来源，将 UIManager、Utils、ui_data.lua、refs.lua、eggy.json（及 EggyAPI.lua）复制到仓库根目录，使根目录具备 Eggitor 工程最小结构。随后修改根目录 `main.lua` 为 Eggy 入口，直接调用 `src/adapters/eggy/eggy_runtime.lua` 并确保 `src/` 可被 require。删除或下线 `src/entry.lua` 与 headless 脚本，避免多平台分支残留。

接着改造 `src/adapters/eggy/eggy_runtime.lua`：用 `UIManager.Utils` 与 `ui_data.lua` 构建 UIManager，不再依赖缺失的 `ui_nodes`。在 UI 层对照 UI 资源命名清单（见 `plans/ui_naming_list.md`），校验 `EggyLayer`/`UIState`/`MarketUI` 使用的节点是否存在；若名称不一致，选择“改 UI 节点名”或“改代码节点名”其中一种并保持一致。最后，检查“托管”按钮事件能触发 `action.id == "auto"`，确保 `AutoRunner` 可以切换，且未来扩展“自动补 AI”不被阻断。

完成后清理 `LuaSource_大富翁/` 目录与 headless 相关脚本或文档，更新 README 为 Eggitor 工程说明。保留测试脚本用于核心玩法回归验证。

## Concrete Steps

以下命令均在仓库根目录执行（`/Users/billyq/Dev/Github/Lua/monopoly`）。示例命令可重复执行。

1) 复制样板工程必要文件到根目录（只拷贝，不在样板目录内修改）。

   复制 UIManager 与 Utils：

     cp -R "LuaSource_大富翁/UIManager" "./UIManager"
     cp -R "LuaSource_大富翁/Utils" "./Utils"

   复制 UI 与资源索引：

     cp "LuaSource_大富翁/ui_data.lua" "./ui_data.lua"
     cp "LuaSource_大富翁/refs.lua" "./refs.lua"

   复制 EggyAPI 与 eggy.json（并在下一步改名）：

     cp "docs/eggy/EggyAPI.lua" "./EggyAPI.lua"
     cp "LuaSource_大富翁/eggy.json" "./eggy.json"

2) 修改 `eggy.json`：

   - `projectName` 设为 `LuaSource_Monopoly`。
   - `excludePatterns` 保留 `EggyAPI.lua` 与 `.git` 等现有项。
   - 若 Eggitor 需要 `projectID`，沿用或由你指定新值（见“待确认问题”）。

3) 改造根目录入口 `main.lua`：

   - 移除 headless 入口逻辑。
   - 添加 `require("src.bootstrap")()` 以确保 `src/` 可被 require。
   - 直接调用 Eggy 入口：

       require("src.adapters.eggy.eggy_runtime").install()

   - 如需保留 ECA 转发能力，则在 main.lua 顶部 `require("eca")`。

4) 调整 `src/adapters/eggy/eggy_runtime.lua` 的 UIManager 安装逻辑：

   - 删除 `src.adapters.eggy.ui_nodes` 相关逻辑。
   - 用根目录 `UIManager.Utils` + `ui_data.lua`：

     - `pcall(require, "UIManager.Utils")`
     - `UIManager.Builder(require "ui_data")`

   - 失败时保持静默（与现有风格一致）。

5) UI 节点核对与映射确认：

   - 需要存在的节点名（至少覆盖以下）：
     - 面板：`panel_title`、`panel_turn`、`panel_current_title`、`panel_current_name`、`panel_current_role`、`panel_current_phase`、`panel_current_dice`
     - 玩家行：`panel_player_1..4`、`panel_player_1_detail..4_detail`
     - 格子详情：`panel_tile_title`、`tile_detail_name`、`tile_detail_price`、`tile_detail_level`、`tile_detail_owner`、`tile_detail_roadblock`、`tile_detail_mine`
     - 按钮：`btn_next`、`btn_auto`、`btn_restart`
     - 日志：`panel_log_title`、`panel_log_body`
     - 选择与弹窗：`modal_choice`、`choice_title`、`choice_body`、`choice_cancel`、`choice_option_1..4`、`modal_popup`、`popup_title`、`popup_body`、`popup_confirm`
     - 地图格子文本：`tile_1..tile_N`（N 为棋盘格子数）

   - 若 `ui_data.lua` 的节点命名与上述不一致，选择其一修正：
     - 改 UI 资源节点名（推荐），或
     - 在代码中替换节点名为现有 UI 名称。

6) 确保“托管/自动控制”事件链：

   - UI 事件应触发 `EVENT.UI_CUSTOM_EVENT`，payload 中 `id` 或 `button_id` 为 `auto`。
   - `EggyLayer:dispatch_action` 已处理 `action.id == "auto"`，只需保证事件映射正确。
   - 若 UI 事件名固定且无法传 `id`，则在 `eggy_runtime.lua` 中增加映射表将该事件转成 `{ type = "ui_button", id = "auto" }`。

7) 清理冗余与文档：

   - 删除 `LuaSource_大富翁/`（确认复制完成后）。
   - 删除/下线 headless 入口相关脚本与 README 描述（如 `run_all_ai.bat`、`scripts/run_all_ai.ps1`、`src/entry.lua`）。
   - 更新 `README.md` 说明 Eggitor 入口与运行方式。

## Validation and Acceptance

- Eggitor 验证：
  - 在 Eggitor 中打开仓库根目录（视为 `LuaSource_Monopoly` 工程）。
  - 进入游戏后 UI 正常显示，回合推进可点击“下一回合”，且“自动控制”可切换自动决策。
  - 日志区域能滚动显示回合事件。

- Lua 脚本回归：
  - 运行 `lua tests/deps_check.lua`，无依赖违规。
  - 运行 `lua tests/regression.lua`，用例全部通过。

验收标准：Eggitor 能直接运行根目录工程；UI 节点更新正常；自动控制可用；Lua 回归测试通过；`LuaSource_大富翁/` 与 headless 入口不再存在。

## Idempotence and Recovery

复制操作可重复执行。若发现误删或改错，可用 `git restore -- <path>` 恢复。删除 `LuaSource_大富翁/` 前建议先运行一次 Eggitor 验证，确认根目录工程可用后再清理。`eggy.json` 修改失败可直接覆盖回样板版本并重新编辑。

## Artifacts and Notes

建议保留以下核对输出：

  - `rg -n "LuaSource_大富翁" -S .` 无输出（确认已清理引用）。
  - `rg -n "headless|all-ai|MONOPOLY_PLATFORM" -S main.lua src README.md` 无输出（确认无 headless 入口残留）。

## Interfaces and Dependencies

需要明确的模块与接口如下：

- `main.lua`（根目录）：
  - 保留 `require("src.bootstrap")()` 以扩展 `package.path`。
  - 调用 `require("src.adapters.eggy.eggy_runtime").install()` 作为 Eggitor 入口。
  - 如使用 UI 事件转发，补 `require("eca")`。

- `src/adapters/eggy/eggy_runtime.lua`：
  - 保留 `EggyRuntime.install()` 接口。
  - `install_ui_manager()` 改为使用 `UIManager.Utils` + `ui_data.lua` 构建。

- `src/adapters/eggy/ui_state.lua`：
  - 使用 UIManager 的 `query_nodes_by_name` 机制，不新增新接口。

- 资源文件（根目录）：
  - `ui_data.lua`：UI 节点与类型映射。
  - `refs.lua`：资源 ID 索引。
  - `EggyAPI.lua`：来自 `docs/eggy/` 的版本。
  - `UIManager/` 与 `Utils/`：从样板工程复制。


变更记录（必须每次更新都追加）：
- 2026-01-26：创建初版接入计划，依据用户输入确定工程名、入口与 UI 资源来源。
