# 全局格式统一：ClassUtils + EmmyLua 注释（子计划）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并作为总计划 `pilots/15_monopoly_solid_refactor_plan.md` 的子计划。


## 目的 / 全局视角


本里程碑把 monopoly 目录内所有“类封装”统一为 `ClassUtils` 提供的 `Class()` 实现，并为关键类补充精简的 EmmyLua 注释。完成后，类的构造风格一致，编辑器能稳定提供类型提示，且保留现有对外接口（尤其是 `X.new()` 的调用方式）。可观察结果是：回归测试通过，`rg` 搜索不再看到遗留的 “手写 __index + setmetatable” 模式，新增的类注释能被 Lua 注释检查工具识别。


## 进度


- [x] (2026-01-30 10:09Z) 梳理需要迁移的类与关键类列表（Components/ 与 Manager/ 的 __index 扫描已完成）
- [x] (2026-01-30 10:09Z) 将手写类迁移为 `Class()` 风格并保持 `X.new()` 兼容（含 Game 与 GUI 层）
- [x] (2026-01-30 10:09Z) 为关键类补充精简 EmmyLua 注释
- [x] (2026-01-30 10:18Z) 回归验证与格式检查（deps_check、regression、classutils 测试已通过）


## 意外与发现


- 观察：`AutoRunner` 位于 `Manager/TurnManager/GUI/AutoRunner.lua`，而非原清单中的 `Manager/System/AutoRunner.lua`。
  证据：`rg -n "__index" Components Manager` 输出包含 `Manager\\TurnManager\\GUI\\AutoRunner.lua`。

- 观察：最初运行 `lua .github/tests/regression.lua` 与 `lua .github/tests/classutils_refactor_test.lua` 时挂起，定位到 `X.new()` 兼容包装覆盖了 `Class()` 的 `new` 导致递归。
  证据：中断测试时堆栈停在 `Components/Flow.lua:24` 的 `Flow.new` 递归调用。
  处理：改为保留 `__class_new`，并由 `X.new()` 转发调用。


## 决策日志


- 决策：使用 `require "Library.ClassUtils"` 引入全局 `Class()`，每个类文件显式依赖。
  理由：降低隐式依赖，便于读者理解类来源。
  日期/作者：2026-01-30 / Codex

- 决策：保留 `X.new()` 作为兼容入口，内部转发到 `X:new()`。
  理由：现有调用大量使用点号调用，不改变对外接口。
  日期/作者：2026-01-30 / Codex

- 决策：在 `CompositionRoot.assemble` 中使用 `GameClass.__class_new(GameClass)` 构造实例，再填充字段。
  理由：`Class()` 实例需要专用元表，且 `Game.new` 保留为装配入口时需显式调用原始构造器。
  日期/作者：2026-01-30 / Codex

- 决策：为兼容 `X.new()` 保留原始 `Class()` 构造器为 `__class_new`，由包装函数转发。
  理由：避免覆盖 `Class()` 自带的 `new` 导致递归，同时保持旧调用点可用。
  日期/作者：2026-01-30 / Codex


## 结果与复盘


已完成 ClassUtils 迁移与关键类 EmmyLua 注释，新增 classutils 兼容性测试脚本，并完成回归与新增测试验证。该里程碑目标已达成，未发现行为回归。


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

已按上述步骤完成类迁移与注释补全，并新增 `.github/tests/classutils_refactor_test.lua` 用于验证 `X.new()` 兼容入口。回归与新测试已运行并通过。


## 验证与验收


运行回归测试：
    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

新增一个最小测试（如 `.github/tests/classutils_refactor_test.lua`），验证 `X.new()` 兼容入口仍可创建实例并调用方法。预期输出包含 `ok`：
    lua .github/tests/classutils_refactor_test.lua
    ok - classutils refactor

若测试依赖引擎对象（如 `GameAPI`），测试应只覆盖不依赖引擎的类（如 `Flow`、`Store`、`Inventory`、`RNG`）。

已运行 `deps_check`、`regression` 与 `classutils_refactor_test`，均通过。


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
`.github/tests/classutils_refactor_test.lua`

测试输出示例：
    lua .github/tests/classutils_refactor_test.lua
    ok - classutils refactor

本次已新增 `.github/tests/classutils_refactor_test.lua`，其输出以实际运行结果为准；回归测试已通过。


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
改动记录：完成 ClassUtils 迁移、注释补全与测试脚本新增，更新进度与决策日志以反映真实实施情况。
改动记录：记录测试挂起的根因与修复方式，并更新验证状态为已通过。
改动记录：补充回归通过与结果复盘，确保里程碑完成状态可追溯。
改动记录：补充 `__class_new` 兼容策略与装配入口说明，保证后续维护者理解实例构造路径。
