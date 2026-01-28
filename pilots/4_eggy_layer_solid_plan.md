# EggyLayer 按 SOLID 拆分可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角

本任务要在不改变任何行为的前提下，把 `src/adapters/eggy/eggy_layer.lua` 拆分为多个职责清晰的模块，降低维护成本并让新手能快速定位“UI 刷新、黑市 UI、棋盘/单位渲染”等不同职责。SOLID 在这里意味着：每个模块只处理单一职责，扩展时优先新增模块而非修改核心流程，接口保持小而清晰，并避免对具体实现的硬依赖。完成后，调用方仍旧只用 `EggyLayer.new`、`EggyLayer:tick`、`EggyLayer:dispatch_action` 等入口；UI 行为、黑市流程、棋盘移动、日志输出全部保持一致。验收方式是运行现有 Lua 测试并在 Demo 中完成一轮操作，观察 UI 与玩法无变化。

## 进度

- [x] (2026-01-28 02:12Z) 创建可执行计划文件，记录拆分目标与验证方式。  
- [ ] 盘点 EggyLayer 责任边界并确认最小拆分模块。  
- [ ] 按最小改动将 EggyLayer 拆分并更新文档。  
- [ ] 运行测试与手工验收，补充结果记录。  

## 意外与发现

当前 EggyLayer 同时包含 UI 查询、面板刷新、黑市 UI、棋盘锚点缓存、玩家单位移动、弹窗处理与动作分发等职责，单文件跨度大且容易误改。证据是 `src/adapters/eggy/eggy_layer.lua` 中从 UI 绑定到棋盘渲染均在同一文件内完成。

## 决策日志

- 决策：按照“UI 状态/文本刷新”“黑市 UI”“棋盘与单位渲染”三个职责域做最小拆分，其它流程（tick、dispatch_action、popup）仍保留在 EggyLayer 内。  
  理由：这三个职责域在代码中已经相对集中，拆分后可保持行为不变且不引入额外抽象层，满足 CodingDiscipline 的“无默认抽象”要求。  
  日期/作者：2026-01-28 / Codex  

## 结果与复盘

当前尚未实施，需在完成后补充结果、缺口与经验教训，并对照“目的 / 全局视角”验证行为一致性。

## 背景与导读

EggyLayer 位于 `src/adapters/eggy/eggy_layer.lua`，是 Eggy 适配层的主逻辑入口，负责生成 UI 状态、刷新面板与棋盘、处理黑市 UI、映射玩家角色单位位置，并通过 `dispatch_action` 把 UI 动作转成规则层动作。它被 `src/adapters/eggy/eggy_runtime.lua` 构建并在 Tick 中调用。当前模块的职责跨度过大，不利于按职责定位问题，因此需要在保证行为不变的前提下拆分为多个专职模块。

## 工作计划

先以“行为不变”为硬规则，把 EggyLayer 的职责分区映射到三个新模块，并保持调用路径不变。第一类是 UI 状态与文本刷新，包含 `build_ui_state`、`set_label`、`refresh_panel`、`refresh_item_slots`、`refresh_tile_detail` 等逻辑；第二类是黑市 UI 相关逻辑，包含商品解析、面板打开/关闭与选择状态刷新；第三类是棋盘与单位渲染，包含棋盘锚点缓存、玩家单位定位、楼房升级与地块渲染。EggyLayer 本体保留 `new/set_game/tick/dispatch_action/push_popup/close_popup`，并通过调用新模块函数完成原有行为。拆分时不新增接口层或抽象类型，只引入简单的 `require` 模块表，以符合“无默认抽象”和“单一实现”的要求。最后同步 `docs/adapters_design.md` 中 EggyLayer 的章节说明拆分后的文件结构。

## 具体步骤

在仓库根目录工作。先用 `rg -n "function EggyLayer" src/adapters/eggy/eggy_layer.lua` 标注现有职责边界，并在文件内标注要迁移的函数块。然后创建三个新文件：`src/adapters/eggy/eggy_layer_ui.lua`、`src/adapters/eggy/eggy_layer_market.lua`、`src/adapters/eggy/eggy_layer_board.lua`，分别导出纯函数表，函数签名保持与原实现一致（例如 `refresh_panel(layer, view)`）。接着在 `eggy_layer.lua` 中引入新模块并把原函数体替换为对新模块的委托调用，同时确保 `build_ui_state` 依旧只创建一次并挂在 `layer.ui` 上。最后更新 `docs/adapters_design.md` 的“5.2 UI 状态与节点查询”和“5.3 EggyLayer”描述，说明拆分后的文件职责。整个过程不改变任何逻辑判断、不新增字段、不改变日志内容。

示例命令与预期输出如下，需以缩进块形式记录在实施记录中：

    rg -n "function EggyLayer" src/adapters/eggy/eggy_layer.lua
    lua tests/deps_check.lua
    lua tests/regression.lua
    Dependency self-check passed
    All regression checks passed (29)

## 验证与验收

必须运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua`，两者均通过。然后运行 Demo（例如启动 `bin/windows/Game.exe` 或现有 Eggy 工程入口）完成一次 UI 操作：点击“下一回合”、切换“自动”、打开并关闭黑市与弹窗，观察 UI 文字、棋盘移动与日志输出与改动前一致。若任何按钮无响应或 UI 文本缺失，应记录具体节点名与触发步骤。

## 可重复性与恢复

拆分是纯代码重组，不涉及数据迁移，可通过 `git checkout -- src/adapters/eggy/eggy_layer.lua` 与删除新文件快速回滚。若拆分后出现行为差异，可暂时把新模块逻辑合并回原文件并在决策日志记录原因。

## 产物与备注

产物包括 `src/adapters/eggy/eggy_layer_ui.lua`、`src/adapters/eggy/eggy_layer_market.lua`、`src/adapters/eggy/eggy_layer_board.lua` 三个新文件，以及 `src/adapters/eggy/eggy_layer.lua` 与 `docs/adapters_design.md` 的改动。最终应保留一小段 diff 或调用示例，证明 EggyLayer 通过新模块委托仍能运行，例如在 EggyLayer 中保留如下结构：

    local EggyLayerUI = require("src.adapters.eggy.eggy_layer_ui")
    function EggyLayer:refresh_panel(view)
      EggyLayerUI.refresh_panel(self, view)
    end

## 接口与依赖

EggyLayer 对外接口不变，仍需保留 `EggyLayer.new(opts)`、`EggyLayer:set_game(g)`、`EggyLayer:tick(dt)`、`EggyLayer:dispatch_action(action)`、`EggyLayer:push_popup(payload)` 与 `EggyLayer:close_popup()`。新模块只负责内部职责，建议导出函数签名如下并保持纯函数风格：

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

改动说明：首次创建本计划，明确按 SOLID 拆分 EggyLayer 的职责分区、步骤与验证方式，确保后续实现时行为可证明一致。
