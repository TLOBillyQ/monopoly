# 类构造写法统一与冗余清理计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。

## 目的 / 全局视角


当前多处 Lua 类通过 `__class_new` 和自定义 `new` 只做一次转发，这让创建方式不一致且啰嗦。目标是统一为 `local X = Class("X")` + `init` 的写法，并把调用点改为 `X:new(...)`，确保行为不变但代码更简单。完成后可以通过启动流程或回归脚本确认游戏与测试仍可正常运行，且代码中不再出现这些冗余包装。

## 进度


- [x] (2026-02-01 13:40+08:00) 梳理所有 `__class_new` 与冗余 `new` 包装，并列出调用点
- [x] (2026-02-01 13:40+08:00) 清理类定义中的冗余构造写法，保持行为一致
- [x] (2026-02-01 13:40+08:00) 更新所有调用点与回归脚本，完成验证（回归脚本执行失败，见“意外与发现”）

## 意外与发现


- 观察：本地执行 `lua .github/tests/regression.lua` 在加载 `Globals.ServiceKeys` 时失败。
  证据：`Globals/ServiceKeys.lua:2: unexpected symbol near '<'`

## 决策日志


- 决策：统一使用 Class 默认的 `:new(...)` 入口，删除 `__class_new` 与无逻辑的 `new` 包装；`Game` 用 `init` 承接组装逻辑并调整 `CompositionRoot.assemble` 以支持实例输入。
  理由：`__class_new` 仅用于绕过覆盖，导致调用方式混杂；把逻辑集中到 `init` 能消除冗余并保持行为不变。
  日期/作者：2026-02-01 / Codex
- 决策：在 `Game:init` 增加 `__skip_assemble` 保护，并在 `CompositionRoot.assemble` 用它创建裸实例以保持对类输入的兼容。
  理由：避免 `Game:new` 与 `CompositionRoot.assemble` 之间的递归，同时保留旧调用路径。
  日期/作者：2026-02-01 / Codex

## 结果与复盘


已移除运行时代码中的构造转发与 `__class_new`，并统一调用为 `:new(...)`，保持构造流程一致。回归脚本在当前环境加载 `Globals.ServiceKeys` 时报错，未能完成自动验证，需要在可运行环境再验证一次。

## 背景与导读


类工具位于 `Library/ClassUtils.lua`，`Class` 会为类表提供 `:new(...)`，并在内部调用 `init`。当前多处类定义通过 `__class_new` 保存原始构造函数，再用 `new` 包装转发，导致调用风格混用 `ClassName.new(...)` 与 `ClassName:new(...)`。本计划聚焦以下运行时文件（不动 `.github/docs/` 示例）：`Components/*.lua`、`Manager/TurnManager/*`、`Manager/GameManager/*`、`init.lua`、`.github/tests/regression.lua`。

## 里程碑


里程碑一：清理类定义中的冗余构造写法。范围包含 `Components/Board.lua`、`Components/Tile.lua`、`Components/Flow.lua`、`Components/Inventory.lua`、`Components/Player.lua`、`Components/Store.lua`、`Manager/TurnManager/Turn/TurnManager.lua`、`Manager/TurnManager/GUI/AutoRunner.lua`、`Manager/GameManager/Game.lua`、`Manager/GameManager/CompositionRoot.lua`。完成后不再出现 `__class_new` 与无逻辑 `new` 包装，`Game` 通过 `init` 触发组装逻辑。此里程碑无需运行命令，仅需通过代码审查确认定义写法一致。

里程碑二：更新调用点并做最小验证。范围包含 `init.lua`、`Manager/GameManager/CompositionRoot.lua`、`Manager/TurnManager/Turn/TurnManager.lua`、`Components/Player.lua`、`.github/tests/regression.lua` 等使用 `.new(...)` 的位置。完成后使用 `:new(...)` 语法，行为不变。验证阶段运行回归脚本并观察无报错结束。

## 工作计划


先按 `rg "__class_new"` 与 `rg "\.new\("` 结果逐一定位冗余类定义。对仅转发的 `new` 统一删除，保留 `init` 作为构造入口。`Tile.from_config`、`TurnManager:_build_flow` 等内部调用改为 `ClassName:new(...)`。`Game` 需要把组装逻辑接到 `init`，因此调整 `CompositionRoot.assemble` 支持传入现成实例并移除对 `__class_new` 的依赖，同时更新 `init.lua` 与 `.github/tests/regression.lua` 为 `Game:new(...)`。所有改动保持字段赋值和流程顺序不变，不引入新抽象。

## 具体步骤


在仓库根目录执行以下步骤。

1) 定位并记录冗余构造模式。

    rg "__class_new" -n
    rg "\.new\(" -n Components Manager init.lua .github/tests/regression.lua

2) 清理类定义与内部调用。

    - 在 `Components/Board.lua`、`Components/Tile.lua`、`Components/Flow.lua`、`Components/Inventory.lua`、`Components/Player.lua`、`Components/Store.lua`、`Manager/TurnManager/Turn/TurnManager.lua`、`Manager/TurnManager/GUI/AutoRunner.lua` 移除 `__class_new` 与转发的 `new`。
    - 把 `Tile.from_config` 等内部构造改为 `Tile:new(cfg)`。
    - 在 `Manager/GameManager/Game.lua` 添加 `Game:init(opts)`，把组装工作交给 `CompositionRoot.assemble(opts, self)`，并删除 `Game.__class_new` 与 `Game.new` 的覆盖。
    - 在 `Manager/GameManager/CompositionRoot.lua` 调整 `assemble` 签名，支持接收实例（优先）或类表（可选），并不再调用 `__class_new`。

3) 更新调用点为 `:new(...)` 并调整回归脚本。

    - `init.lua` 使用 `Game:new({ ... })` 与 `AutoRunner:new(...)`。
    - `Manager/GameManager/CompositionRoot.lua` 中的 `Board.new`、`Player.new`、`Inventory.new`、`Store.new`、`TurnManager.new` 改为 `:new`。
    - `Manager/TurnManager/Turn/TurnManager.lua` 中的 `Flow.new` 改为 `Flow:new`。
    - `Components/Player.lua` 中的 `Inventory.new` 改为 `Inventory:new`。
    - `.github/tests/regression.lua` 中的 `App.new` 与 `TurnManager.new` 改为 `:new`。

## 验证与验收


在仓库根目录运行：

    lua .github/tests/regression.lua

预期脚本执行完成且没有报错或断言失败。若运行环境缺少 `lua`，则在蛋仔编辑器中启动主流程，观察游戏可以正常创建棋盘与回合推进（例如进入首回合并能触发一次投骰/移动）。

## 可重复性与恢复


本变更只涉及 Lua 代码组织，步骤可重复执行。若出现异常，可按单文件回滚修改；不涉及数据迁移或资源文件变更。

## 产物与备注


预期最终代码中不再出现 `__class_new`，并将调用统一为 `:new`。示例片段（仅示意）：

    local AutoRunner = Class("AutoRunner")

    function AutoRunner:init(opts)
      ...
    end

## 接口与依赖


依赖 `Library/ClassUtils.lua` 提供的 `Class` 与默认 `:new(...)` 行为。调整后的 `CompositionRoot.assemble` 需支持以下签名语义：

    CompositionRoot.assemble(opts, game_or_class)

其中 `game_or_class` 可为实例（优先，直接填充）或类表（可选，用 `:new()` 创建后再填充）。所有调用点必须使用 `ClassName:new(...)` 语法以保证 `self` 正确传入。

变更记录：补齐各标题后的空行以符合 .github/agent/PLANS.md 的格式要求。
变更记录：更新进度、记录测试失败与新增决策，并补充结果与复盘以反映执行现状。
