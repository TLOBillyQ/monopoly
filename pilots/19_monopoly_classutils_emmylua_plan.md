# 全局格式统一：ClassUtils + EmmyLua 注释（子计划）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并作为总计划 `pilots/15_monopoly_solid_refactor_plan.md` 的子计划。


## 目的 / 全局视角


本里程碑把 monopoly 目录内所有“类封装”统一为 `ClassUtils` 提供的 `Class()` 实现，并为关键类补充精简的 EmmyLua 注释。完成后，类的构造风格一致，编辑器能稳定提供类型提示，且保留现有对外接口（尤其是 `X.new()` 的调用方式）。可观察结果是：回归测试通过，`rg` 搜索不再看到遗留的 “手写 __index + setmetatable” 模式，新增的类注释能被 Lua 注释检查工具识别。


## 进度


- [ ] (2026-01-30 00:00Z) 梳理需要迁移的类与关键类列表
- [ ] (2026-01-30 00:00Z) 将手写类迁移为 `Class()` 风格并保持 `X.new()` 兼容
- [ ] (2026-01-30 00:00Z) 为关键类补充精简 EmmyLua 注释
- [ ] (2026-01-30 00:00Z) 回归验证与格式检查


## 意外与发现


暂无。若发现某类依赖自定义 `__index` 行为或被外部脚本反射访问字段名，需要记录并给出兼容方案。


## 决策日志


- 决策：使用 `require "Library.ClassUtils"` 引入全局 `Class()`，每个类文件显式依赖。
  理由：降低隐式依赖，便于读者理解类来源。
  日期/作者：2026-01-30 / Codex

- 决策：保留 `X.new()` 作为兼容入口，内部转发到 `X:new()`。
  理由：现有调用大量使用点号调用，不改变对外接口。
  日期/作者：2026-01-30 / Codex


## 结果与复盘


尚未实施。


## 背景与导读


monopoly 中存在一批“手写类”，通常写法为：
`local X = {}; X.__index = X; function X.new(...) return setmetatable({...}, X) end`。
本里程碑要求统一为 `ClassUtils` 提供的 `Class()` 方式，即 `local X = Class("X")`，并使用 `X:init(...)` 作为构造函数。

“关键类”指核心玩法与运行流程中负责状态和行为的类。本计划暂定关键类为以下文件（只限 monopoly，不包含 `SecretOfEscaper/`）：
`Components/Board.lua`
`Components/Player.lua`
`Components/Inventory.lua`
`Components/Tile.lua`
`Components/RNG.lua`
`Components/Store.lua`
`Components/Flow.lua`
`Components/Dice.lua`
`Manager/GameManager/Game.lua`
`Manager/TurnManager/Turn/TurnManager.lua`
`Manager/TurnManager/GUI/Layer.lua`
`Manager/System/AutoRunner.lua`
`Manager/EffectManager/Effect/Effect.lua`

若在实现阶段通过搜索发现新增的类文件（含 `__index` 或 `setmetatable`），也应纳入迁移清单，并在“意外与发现”记录。


## 工作计划


先用搜索命令确认需要迁移的类清单，然后逐个改为 `Class()` 风格。改造方式：在文件顶部 `require "Library.ClassUtils"`，把 `local X = {}` 改为 `local X = Class("X")`，把 `X.new` 的构造逻辑移到 `X:init`，并新增 `X.new` 兼容包装调用 `X:new`。对于当前只有静态方法的类（例如 `Dice` 或 `Effect`），可以保留静态方法不变，但仍用 `Class("Name")` 作为容器，确保风格统一。

注释方面，对关键类补充精简 EmmyLua 注释：
- 每个关键类必须有 `---@class Name`。
- 仅为关键字段补充 `---@field`，避免重复或长段落。
- 公共构造与核心方法用 `---@param` 和 `---@return`，不需要为所有私有函数写注释。


## 具体步骤


1) 确认类清单。
   - 运行搜索：
       rg -n "__index" Components Manager
   - 记录结果，与“关键类”清单对比，补齐新增文件。

2) 逐文件迁移为 `Class()` 风格。
   - 对每个类文件执行：
     1) 添加 `require "Library.ClassUtils"`（若已有则跳过）。
     2) `local X = Class("X")` 取代 `{}` + `__index`。
     3) 把 `X.new` 的构造代码迁移到 `function X:init(...)`。
     4) 新增 `function X.new(...) return X:new(...) end` 作为兼容入口。
   - 特殊处理：
     - `Manager/GameManager/Game.lua` 保留现有 `Game.new(opts)` 逻辑（调用 `CompositionRoot.assemble`），不改变对外行为，仅将类声明切换为 `Class("Game")` 并删除 `__index`。

3) 补充 EmmyLua 注释。
   - 对“关键类”确保有 `---@class` 与关键字段 `---@field`。
   - 控制注释长度：每个方法描述不超过一行。

4) 清理遗留的 `__index` 与 `setmetatable` 构造写法。
   - 再次运行搜索确认无遗漏：
       rg -n "__index" Components Manager


## 验证与验收


运行回归测试：
    lua tests/deps_check.lua
    lua tests/regression.lua

新增一个最小测试（如 `tests/classutils_refactor_test.lua`），验证 `X.new()` 兼容入口仍可创建实例并调用方法。预期输出包含 `ok`：
    lua tests/classutils_refactor_test.lua
    ok - classutils refactor

若测试依赖引擎对象（如 `GameAPI`），测试应只覆盖不依赖引擎的类（如 `Flow`、`Store`、`Inventory`、`RNG`）。


## 可重复性与恢复


改动为增量迁移，可逐文件提交。若某类迁移后出现行为差异，先恢复该文件，再检查其 `init/new` 是否与旧逻辑一致。回退只需 `git restore <path>`。


## 产物与备注


预期改动文件（不含 SecretOfEscaper）：
`Components/Board.lua`
`Components/Player.lua`
`Components/Inventory.lua`
`Components/Tile.lua`
`Components/RNG.lua`
`Components/Store.lua`
`Components/Flow.lua`
`Components/Dice.lua`
`Manager/GameManager/Game.lua`
`Manager/TurnManager/Turn/TurnManager.lua`
`Manager/TurnManager/GUI/Layer.lua`
`Manager/System/AutoRunner.lua`
`Manager/EffectManager/Effect/Effect.lua`
`tests/classutils_refactor_test.lua`

测试输出示例：
    lua tests/classutils_refactor_test.lua
    ok - classutils refactor


## 接口与依赖


依赖 `Library/ClassUtils.lua` 提供的 `Class()`：
    require "Library.ClassUtils"
    local X = Class("X")
    function X:init(...) end
    function X.new(...) return X:new(...) end

EmmyLua 注释规范示例（精简版）：
    ---@class Player
    ---@field id number
    ---@field name string
    ---@field cash number


改动记录：本计划为首次版本，尚未实施。
