# Eggy 适配层按 SOLID 拆分可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角

本任务要在不改变任何行为的前提下，把整个 Eggy 适配层按职责拆分为更清晰的模块，降低维护成本并让新手能快速定位“运行时入口、事件桥接、UI 刷新、黑市 UI、棋盘/单位渲染、楼房特效、启动初始化”等不同职责。SOLID 在这里意味着：每个模块只处理单一职责，扩展时优先新增模块而非修改核心流程，接口保持小而清晰，并避免对具体实现的硬依赖。完成后，调用方仍旧只用 `EggyRuntime.install`、`EggyLayer.new`、`EggyLayer:tick`、`EggyLayer:dispatch_action` 等入口；UI 行为、黑市流程、棋盘移动、事件桥接、日志输出全部保持一致。验收方式是运行现有 Lua 测试并在 Demo 中完成一轮操作，观察 UI 与玩法无变化。

## 进度

- [x] (2026-01-28 02:12Z) 创建可执行计划文件，记录拆分目标与验证方式。  
- [x] (2026-01-28 03:20Z) 盘点 Eggy 适配层现有职责边界并确认最小拆分模块。  
- [x] (2026-01-28 03:40Z) 完成 EggyLayer UI/黑市/棋盘模块拆分并同步 `docs/adapters_design.md`。  
- [x] (2026-01-28 04:05Z) 复核运行时入口/启动初始化/渲染特效职责边界，确认无需额外拆分（记录决策）。  
- [x] (2026-01-28 04:15Z) 运行测试与手工验收，补充结果记录。（已完成：`lua tests/deps_check.lua`、`lua tests/regression.lua`；剩余：Demo 手工验收）  
- [x] (2026-01-28 18:30Z) 复跑 Lua 测试以确认当前代码状态（`lua tests/deps_check.lua`、`lua tests/regression.lua`）。

## 意外与发现

当前 Eggy 适配层职责分散在多个文件，运行时入口、事件桥接、启动初始化与 UI 渲染逻辑交错；其中 `src/adapters/eggy/eggy_layer.lua` 同时包含 UI 查询、面板刷新、黑市 UI、棋盘锚点缓存、玩家单位移动、弹窗处理与动作分发等职责，单文件跨度大且容易误改。证据是 `src/adapters/eggy/eggy_layer.lua` 中从 UI 绑定到棋盘渲染均在同一文件内完成，且入口文件 `src/adapters/eggy/eggy_runtime.lua` 同时包含 UI 安装、事件注册与 tick 逻辑。

- 观察：`src/adapters/eggy/move.lua` 不存在，当前移动动画模块是 `src/adapters/eggy/move_anim.lua`。  
  证据：`rg --files -g "move.lua"` 无输出，`ls src/adapters/eggy` 仅有 `move_anim.lua`。  

## 决策日志

- 决策：范围扩展到整个 Eggy 适配层，包含运行时入口、事件桥接、启动初始化、UI 渲染、棋盘/单位渲染与楼房特效等职责。  
  理由：单独拆分 EggyLayer 不能解决入口与桥接职责混杂的问题，需要覆盖完整适配层才能形成可维护的职责边界。  
  日期/作者：2026-01-28 / Codex  
- 决策：在 EggyLayer 内继续沿用“UI 状态/文本刷新”“黑市 UI”“棋盘与单位渲染”三个职责域做最小拆分，其它流程（tick、dispatch_action、popup）仍保留在 EggyLayer 内。  
  理由：这三个职责域在代码中已经相对集中，拆分后可保持行为不变且不引入额外抽象层，满足 CodingDiscipline 的“无默认抽象”要求。  
  日期/作者：2026-01-28 / Codex  
- 决策：先完成 EggyLayer UI/黑市/棋盘三块拆分，并保持方法名不变，通过委托模块落地。  
  理由：能在不改入口的前提下拆分职责，同时避免新增抽象层。  
  日期/作者：2026-01-28 / Codex  
- 决策：运行时入口与初始化链路保持现状，不新增拆分文件。  
  理由：`eggy_runtime.lua` 已按 UI 安装/事件注册/tick 调度分段；`init.lua`/`macro.lua`/`refs.lua`/`move_anim.lua` 无可安全合并点，新增模块会违背“无默认抽象”。  
  日期/作者：2026-01-28 / Codex  
- 决策：保留 `init.lua` 对 `Manager.Adapter.Eggy.move` 的引用，暂不更名。  
  理由：遵守“行为不变”硬规则，避免在未验证实际工程依赖的前提下改动启动脚本。  
  日期/作者：2026-01-28 / Codex  

## 结果与复盘

已完成 EggyLayer 的 UI/黑市/棋盘三块模块拆分与文档同步，并通过 `lua tests/deps_check.lua` 与 `lua tests/regression.lua`；运行时入口与启动初始化确认无需额外拆分，渲染/特效调用点已复核。当前仅剩 Demo 手工验收需要补齐，完成后需对照“目的 / 全局视角”补写复盘。

## 背景与导读

Eggy 适配层的代码集中在 `src/adapters/eggy/`，核心文件包括：`eggy_runtime.lua`（运行时入口与事件注册）、`eggy_layer.lua`（主 UI 逻辑）、`eca.lua`（事件桥接）、`init.lua`/`macro.lua`/`refs.lua`/`move_anim.lua`（启动链路与演示逻辑）、`market_ui.lua`（黑市 UI 配置）、`tile_renderer.lua` 与 `building_effects.lua`（棋盘与特效渲染）。当前这些文件的职责边界并不清晰，入口逻辑与细节实现混杂；需要在保证行为不变的前提下按职责拆分为多个专职模块。

## 工作计划

先以“行为不变”为硬规则，覆盖整个 Eggy 适配层做职责拆分，并保持所有入口调用路径不变。拆分范围按职责划分为五类：运行时入口与事件注册（`eggy_runtime.lua`）、事件桥接与引擎交互（`eca.lua`）、启动初始化与资源索引（`init.lua`/`macro.lua`/`refs.lua`/`move_anim.lua`）、UI 展示与逻辑（`eggy_layer.lua`/`market_ui.lua`）、棋盘与特效渲染（`tile_renderer.lua`/`building_effects.lua`）。在 EggyLayer 内继续按“UI 状态/文本刷新”“黑市 UI”“棋盘与单位渲染”三块拆分，并保持 `new/set_game/tick/dispatch_action/push_popup/close_popup` 入口不变。拆分时不新增接口层或抽象类型，只引入简单的 `require` 模块表，以符合“无默认抽象”和“单一实现”的要求。最后同步 `docs/adapters_design.md` 的 Eggy 章节，明确拆分后的文件职责与入口关系。

## 具体步骤

在仓库根目录工作。先用 `rg -n "function Eggy" src/adapters/eggy` 与 `rg -n "require\\(\"Manager.Adapter.Eggy" src` 标注 Eggy 适配层所有职责边界，并记录各文件的调用链。随后按职责创建或重组模块：

1. EggyLayer 拆分：创建 `src/adapters/eggy/eggy_layer_ui.lua`、`src/adapters/eggy/eggy_layer_market.lua`、`src/adapters/eggy/eggy_layer_board.lua`，分别导出纯函数表，函数签名保持与原实现一致（例如 `refresh_panel(layer, view)`），并在 `eggy_layer.lua` 中以委托方式调用。  
2. 运行时入口拆分：在 `eggy_runtime.lua` 内把 UI 安装、事件注册、tick 调度拆为三个局部模块或文件级函数（如 `eggy_runtime_ui.lua`/`eggy_runtime_events.lua`），并确保 `EggyRuntime.install` 行为不变。  
3. 启动初始化拆分：整理 `init.lua`、`macro.lua`、`refs.lua`、`move_anim.lua` 的职责，若存在互相转发的重复模块则合并或删除，并保留根目录兼容入口不变。  
4. 渲染与特效拆分：确认 `tile_renderer.lua` 与 `building_effects.lua` 的调用点，避免双路径渲染；若有未使用函数应删除。  
5. 文档同步：更新 `docs/adapters_design.md` 中 Eggy 适配层章节，列出拆分后的文件职责、入口与调用顺序。

整个过程不改变任何逻辑判断、不新增字段、不改变日志内容。

示例命令与预期输出如下，需以缩进块形式记录在实施记录中：

    rg -n "function Eggy" src/adapters/eggy
    rg -n "require\\(\"Manager.Adapter.Eggy" src
    lua tests/deps_check.lua
    lua tests/regression.lua
    Dependency self-check passed
    All regression checks passed (29)

## 验证与验收

必须运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua`，两者均通过。然后运行 Demo（例如启动 `bin/windows/Game.exe` 或现有 Eggy 工程入口）完成一次完整操作：点击“下一回合”、切换“自动”、打开并关闭黑市与弹窗、触发一次楼房升级或地块渲染（如经过地产升级流程），观察 UI 文字、棋盘移动、桥接事件与日志输出与改动前一致。若任何按钮无响应或 UI 文本缺失，应记录具体节点名与触发步骤。

## 可重复性与恢复

拆分是纯代码重组，不涉及数据迁移，可通过 `git checkout -- src/adapters/eggy` 与删除新文件快速回滚。若拆分后出现行为差异，可暂时把新模块逻辑合并回原文件并在决策日志记录原因。

## 产物与备注

产物包括 EggyLayer 拆分后的新模块文件、运行时入口拆分文件、启动初始化模块整理结果，以及 `docs/adapters_design.md` 的改动。最终应保留一小段 diff 或调用示例，证明 EggyLayer 通过新模块委托仍能运行，例如在 EggyLayer 中保留如下结构：

    local EggyLayerUI = require("Manager.Adapter.Eggy.EggyLayerUI")
    function EggyLayer:refresh_panel(view)
      EggyLayerUI.refresh_panel(self, view)
    end

    lua tests/deps_check.lua
    Dependency self-check passed
    lua tests/regression.lua
    ..............................
    All regression checks passed (30)

## 接口与依赖

Eggy 适配层对外接口不变，必须保留 `EggyRuntime.install()`、`EggyLayer.new(opts)`、`EggyLayer:set_game(g)`、`EggyLayer:tick(dt)`、`EggyLayer:dispatch_action(action)`、`EggyLayer:push_popup(payload)` 与 `EggyLayer:close_popup()`。启动链路必须继续支持根目录 `init.lua` 作为兼容入口，且 `eca.lua` 内的桥接函数签名不能改变。新模块只负责内部职责，建议导出函数签名如下并保持纯函数风格：

    EggyLayerUI.build_ui_state()
    EggyLayerUI.refresh_panel(layer, view)
    EggyLayerUI.refresh_item_slots(layer, view)
    EggyLayerUI.refresh_tile_detail(layer, view)
    EggyLayerMarket.open_market_panel(layer, pending)
    EggyLayerMarket.close_market_panel(layer)
    EggyLayerMarket.refresh_market_selection(layer, option_id)
    EggyLayerBoard.refresh_board(layer, view)
    EggyLayerBoard.on_tile_upgraded(layer, tile_id, level)
    EggyLayerBoard.on_tile_owner_changed(layer, tile_id, owner_id)

任何新增函数都必须被 EggyLayer 实际调用，否则应删除。依赖仍来自 `src/adapters/core/*`、`src/config/*` 与 `src/adapters/eggy/market_ui.lua`，不可引入新的抽象层或第三方依赖。

改动说明：扩写本计划至整个 Eggy 适配层，覆盖运行时入口、事件桥接、启动初始化、UI 展示与渲染等职责，确保后续实施时范围完整且行为可证明一致。
改动说明：记录 EggyLayer 拆分阶段性进度，补充 move_anim 命名差异并同步文档更新情况，确保后续步骤可继续执行。
改动说明：补充测试执行结果与当前未完成的验收范围，便于后续接续验证。
改动说明：为当前进度项补充时间戳，便于衡量推进节奏。
改动说明：更新进度与决策日志，记录运行时/初始化不拆分结论，并同步测试进展与复盘状态。
改动说明：补充近期复跑测试记录，保持进度与当前代码状态一致。
