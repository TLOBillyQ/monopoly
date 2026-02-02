# 移除 service 模式并改为直接 require Manager 的计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.github/agent/PLANS.md`。


## 目的 / 全局视角


目标是移除通过 `ServiceKeys` + `game:get_service` 的 service 模式，改为在调用点直接 `require` Manager 模块，并确保新增的局部标识符使用 PascalCase 命名。完成后可观察的结果是：`Globals/ServiceKeys.lua` 不再被引用或保留，`Game:get_service/get_services` 不再存在，所有调用点改为 `local MovementManager = require(...)` 等直接引用形式，`rg` 检索 `get_service|get_services|ServiceKeys|context\.services` 不再命中业务代码，并且回归脚本通过。


## 进度


- [x] (2026-02-02 20:58+08:00) 盘点 service 模式使用点与受影响的 Manager 列表，确认每个文件需要新增的 `require` 与 PascalCase 命名。
- [x] (2026-02-02 20:58+08:00) 在 `Manager/GameManager/CompositionRoot.lua` 移除 `services` 组装，同时删除 `Manager/GameManager/Game.lua` 中 `get_service/get_services`。
- [x] (2026-02-02 20:58+08:00) 更新所有调用点与上下文构建逻辑（Choice/Item/Turn/Land/Chance 等），新增直接 `require` 的 Manager 引用，移除 `ServiceKeys` 与 `context.services` 传递。
- [x] (2026-02-02 20:58+08:00) 清理 `Globals/ServiceKeys.lua` 与残留引用，完成回归脚本与检索验证，补充日志与复盘。


## 意外与发现


- 回归脚本与多处业务代码仍使用旧的 snake_case 方法名（如 `get_tile_by_id`、`step_move_anim`、`Logger.info`），与当前实现的 PascalCase API 不一致，导致回归脚本无法运行。
  证据：`lua .github/tests/regression.lua` 报错 `method 'get_tile_by_id' is not callable`、`field 'info' is not callable` 等。
- 回归场景的市场中断用例在不需要偷窃的情况下触发 `pass_players`，会因为缺少偷窃卡触发断言。
  证据：`Manager/ItemManager/ItemSteal.lua:56: missing steal item`。


## 决策日志


- 决策：不把 Manager 挂在 `game` 上，改为在调用点直接 `require` 对应 Manager 模块。
  理由：避免隐藏依赖与全局装配，调用点显式依赖更清晰。
  日期/作者：2026-02-02 / Codex
- 决策：新增的局部标识符统一使用 PascalCase（如 `MovementManager`、`MarketManager`）。
  理由：与现有 Manager 模块命名一致，减少新旧风格混杂。
  日期/作者：2026-02-02 / Codex
- 决策：移除 `context.services` 的构建与传递，直接在需要处使用 Manager 模块。
  理由：当前上下文没有实际使用 `services`，保留只会延续旧模式。
  日期/作者：2026-02-02 / Codex


## 结果与复盘


已移除 service 模式并完成全量调用点迁移，`Globals/ServiceKeys.lua` 删除，`Game:GetService/GetServices` 移除，所有引用改为直接 `require` Manager；回归脚本与检索验证通过。额外修正了若干与现有 API 命名不一致的调用与 UI 模型覆盖层读取，保证回归脚本可执行。


## 背景与导读


当前 service 模式由 `Globals/ServiceKeys.lua` 提供整数 key，在 `Manager/GameManager/CompositionRoot.lua` 组装 `game.services` 表，`Manager/GameManager/Game.lua` 提供 `get_service/get_services` 读取。调用点分布在 `Manager/ChanceManager/ChanceRegistry.lua`、`Manager/LandManager/Landing.lua`、`Manager/LandManager/LandActions.lua`、`Manager/TurnManager/TurnMove.lua`、`Manager/TurnManager/TurnManager.lua`、`Manager/ItemManager/ItemPostEffects.lua`、`Manager/ChoiceManager/ChoiceManager.lua`、`Manager/ChoiceManager/ChoiceHandlers/ItemChoiceHandler.lua` 与 `Manager/EffectManager/Effect.lua` 等文件。它们主要访问 Movement、Market、Bankruptcy、Choice 四个 Manager。

本计划将 service 模式替换为直接 `require` Manager 模块，保持 Manager 模块为单例表（不新增实例），调用端通过 PascalCase 命名的局部变量（如 `MovementManager`）调用对应方法，避免 `ServiceKeys` 与 `get_service` 的间接性。


## 工作计划


先在仓库根目录检索 service 模式的使用点与涉及的 Manager，确认每个文件需要新增的 `require` 与 PascalCase 命名。然后在 `Manager/GameManager/CompositionRoot.lua` 删除 `services` 组装逻辑，同时在 `Manager/GameManager/Game.lua` 移除 `get_service/get_services`。随后逐个更新调用点：在文件顶部直接 `require` 对应 Manager 模块（使用 PascalCase 局部变量），将 `game:get_service(ServiceKey.xxx)` 替换为直接调用的 Manager 变量，移除 `Globals/ServiceKeys.lua` 的 `require`，并清理 `context.services` 传递与构造。最后删除 `Globals/ServiceKeys.lua`（若无引用），运行回归脚本与检索验证，记录证据并更新复盘。


## 具体步骤


在仓库根目录 `c:\Users\Lzx_8\Desktop\dev\monopoly` 盘点 service 模式的使用点与 Manager 名称：

    rg -n "get_service|get_services|ServiceKeys" -g "*.lua"

在 `Manager/GameManager/CompositionRoot.lua` 中移除 `services` 表与 `game.services` 赋值，并删除 `Globals/ServiceKeys.lua` 的引用。随后在 `Manager/GameManager/Game.lua` 删除 `get_service` 与 `get_services` 方法。

更新调用点，新增直接 `require` 的 Manager 引用并使用 PascalCase 局部变量，替换所有 `game:get_service(ServiceKey.xxx)` 与 `game:get_services()`，同时移除 `ServiceKeys` 引用与 `context.services` 传递。重点文件包括：

    Manager/ChanceManager/ChanceRegistry.lua
    Manager/LandManager/Landing.lua
    Manager/LandManager/LandActions.lua
    Manager/TurnManager/TurnMove.lua
    Manager/TurnManager/TurnManager.lua
    Manager/ChoiceManager/ChoiceManager.lua
    Manager/ChoiceManager/ChoiceHandlers/ItemChoiceHandler.lua
    Manager/ItemManager/ItemPostEffects.lua
    Manager/ItemManager/ItemStrategy.lua
    Manager/EffectManager/Effect.lua
    Components/Player.lua

示例替换：

    local MovementManager = require("Manager.MovementManager.MovementManager")
    local movement = game:get_service(ServiceKey.movement)  ->  local movement = MovementManager
    context.services = game:get_services()                   ->  (删除该行)

完成替换后，删除 `Globals/ServiceKeys.lua`（若无引用），并再次检索确认无残留：

    rg -n "get_service|get_services|ServiceKeys|context\\.services" -g "*.lua"


## 验证与验收


运行回归脚本：

    lua .github/tests/regression.lua

预期输出包含：

    All regression checks passed (N)

并确认 service 模式检索无输出：

    rg -n "get_service|get_services|ServiceKeys|context\\.services" -g "*.lua"

若仍有输出，说明仍存在未迁移调用点，需继续修正后重试。


## 可重复性与恢复


本修改为引用路径与调用方式的调整，可重复执行。若出现问题，可恢复 `Globals/ServiceKeys.lua`、`game.services` 与 `get_service/get_services`，并将调用点改回旧模式，然后重新运行回归脚本确认恢复。建议恢复时按“先恢复调用点，再恢复 service 组装”的顺序，避免运行期找不到函数。


## 产物与备注


保留以下证据片段：

    rg -n "get_service|get_services|ServiceKeys|context\\.services" -g "*.lua"
    (无输出)
    lua .github/tests/regression.lua
    All regression checks passed (32)


## 接口与依赖


移除 `Globals/ServiceKeys.lua` 及 `Game:get_service/get_services`。在调用点直接 `require` 以下 Manager 模块，并使用 PascalCase 局部变量名：

    local MovementManager = require("Manager.MovementManager.MovementManager")
    local MarketManager = require("Manager.MarketManager.MarketManager")
    local BankruptcyManager = require("Manager.GameManager.BankruptcyManager")
    local ChoiceManager = require("Manager.ChoiceManager.ChoiceManager")

所有涉及 Movement、Market、Bankruptcy、Choice 的调用点必须改为直接访问上述模块变量，不再传递 `context.services`。Manager 模块继续作为单例表使用，不新增实例与构造函数。


本次修改说明：新建“移除 service 模式并改为直接访问 Manager 的计划”，原因是响应用户要求去除 service pattern 并明确可执行迁移步骤。
本次修改说明：调整为不挂在 `game` 上而是直接 `require` Manager，并要求新增命名使用 PascalCase，原因是用户更新需求。
本次修改说明：执行计划 52，完成 service 模式迁移并修正回归脚本/相关代码的 API 命名不一致，确保回归脚本可运行。
