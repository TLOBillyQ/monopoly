# Eggy Lua 规则对齐重构计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .agent/PLANS.md 的全部要求。

## 目的 / 全局视角


本次重构的目标是让运行时 Lua 代码与 docs/eggy/eggy_lua_agent_memory.md 的硬性规则对齐，避免因浮点写法、UI 初始化时机、30 FPS 逻辑时间换算和单位可操作性导致的运行时坑。完成后可以观察到：所有用于时长/旋转/向量的字面量按 x.y 书写且通过自测审计，UI 仍只在 GAME_INIT 后创建，UI 提示有统一时长且不会因为未初始化而报错，且新增的规则审计脚本与现有回归测试能够稳定通过。本计划明确不修改 Library/ 下的文件。

## 进度


- [x] (2026-01-31 20:40Z) 已审阅 docs/eggy/eggy_lua_agent_memory.md 与主要运行路径（Entry/Layer/MoveAnim/Globals）。
- [x] (2026-01-31 01:41Z) 统一浮点字面量与 30 FPS 时间换算（仅修改 Manager/Globals）。
- [x] (2026-01-31 01:41Z) 增加 Eggy 规则审计测试并补足运行时提示（不扫描/修改 Library）。
- [ ] (2026-01-31 01:43Z) 完成脚本与手工验收（已完成：lua tests/eggy_memory_audit.lua、lua tests/acceptance.lua、lua tests/lua_env_audit.lua；剩余：Eggitor 手工验收与结果复盘）。

## 意外与发现


观察：少量 UI 提示时长仍是整数或未显式指定。  
证据：Manager/TurnManager/GUI/Layer.lua 中 show_tips(entry.text, 2)，UIEventRouter/UIState 中 GlobalAPI.show_tips 未传 duration。

观察：存在 Role 全局表的兜底调用，不符合“单位 API 必须先拿对象”。  
证据：Manager/TurnManager/GUI/Layer.lua 的 show_tips 兜底逻辑使用 Role.show_tips。

观察：逻辑时间换算仍混用 30 与 30.0，且 tick 间隔计算有 +1 的偏移。  
证据：Manager/TurnManager/GUI/Layer.lua 用 (tick_interval + 1) / 30.0。

观察：测试环境直接 require Globals/Macro.lua 会触发 math.Vector3 缺失报错。  
证据：tests/acceptance.lua 报错 “Globals/Macro.lua:1: field 'Vector3' is not callable (a nil value)”。

除以上记录外，本次执行未发现新的意外行为。

## 决策日志


决策：把“API 只能用 .”限定为 Eggy 引擎 API（LuaAPI/GameAPI/GlobalAPI）与单位对象方法，内部类方法（UIManager/自定义类）保留冒号语法。  
理由：引擎 API 不支持冒号；内部类以 self 调用为设计前提，强制改写会引入大量无意义改动。  
日期/作者：2026-01-31 / Codex

决策：不新增独立模块，优先在现有 Globals/Macro.lua 增补 FPS 常量，按 CodingDiscipline 减少新抽象。  
理由：已有全局常量入口，FPS 仅用于 Manager 的时间换算，不需要引入新模块。  
日期/作者：2026-01-31 / Codex

决策：本计划不修改 Library/ 下任何文件。  
理由：用户要求缩小范围，避免影响底层库。  
日期/作者：2026-02-01 / Codex

决策：show_tips 兜底从 Role 全局改为 GameAPI.get_role(1)。  
理由：遵循“单位 API 必须先拿对象”的规则，同时保持 UI 提示可用。  
日期/作者：2026-01-31 / Codex

决策：Layer.start_tick_loop 不再 require Globals/Macro.lua，改为使用 FPS 或 30.0 兜底。  
理由：测试环境缺少 math.Vector3，直接 require Macro 会导致测试中断。  
日期/作者：2026-01-31 / Codex

## 结果与复盘


已完成代码与脚本修改，并通过静态审计与自动测试；手工验收待执行。

## 背景与导读


仓库入口为 main.lua -> init.lua -> Manager/GameManager/Entry.lua，Entry.install 创建 EggyLayer 并注册 GAME_INIT 回调。UI 初始化与 UIManager.Builder 发生在 Manager/TurnManager/GUI/Layer.lua 的 GAME_INIT 触发器内。MoveAnim/UI 逻辑主要位于 Manager/BoardManager/GUI/ 与 Manager/TurnManager/GUI/，全局速度常量与后续新增 FPS 常量在 Globals/Macro.lua。本计划只修改 Manager/Globals/tests 及入口文件，不改动 Library/ 下代码。所有 Eggy API 依赖以 LuaAPI/GameAPI/GlobalAPI 形式调用。

## 工作计划


首先补齐规则审计脚本，作为“可观察结果”的基线。新增 tests/eggy_memory_audit.lua，扫描运行时代码目录（Components/Config/Manager/Globals）与 init.lua、main.lua，检查：LuaAPI/GameAPI/GlobalAPI 是否出现冒号调用、GlobalAPI.show_tips 与 LuaAPI.call_delay_time 是否存在整数时长字面量、math.Quaternion/Vector3 是否仍含明显整数字面量（只针对纯字面量参数）。若已有 tests/acceptance.lua 作为主入口，则把该审计加入 scripts 列表，否则保留独立执行指令。审计脚本仅做静态文本检查，保持轻量、可重复。

然后统一浮点字面量与时间换算。把 GlobalAPI.show_tips 的默认时长显式写为 2.0，并为 UIEventRouter 与 UIState 的提示补上统一 duration。把 math.Quaternion(0,0,0) / math.Vector3(0,1.5,0) 等字面量改为 0.0/1.0 形式（只改 Manager/Globals/Components/Config 运行路径，避免全仓库无谓改动）。在 Globals/Macro.lua 增加 FPS = 30.0，并在 Manager/TurnManager/GUI/Layer.lua 使用 FPS 进行换算，移除 tick_interval + 1 的偏移以保证 dt 与帧间隔一致。

最后补充“单位可操作性”的运行时提示。对 EggyLayer.install_game_init 中通过 LuaAPI.query_units/ GameAPI.get_role 获得的单位，新增轻量的 pcall 检测（例如尝试读取 get_position 或 LuaAPI.get_unit_id），失败时用 GlobalAPI.show_tips 提示“单位可能未关闭组件性能优化”。该提示只在初始化时触发一次，避免刷屏。

## 具体步骤


步骤一（已完成）：在仓库根目录收集待修复点与验证点，命令如下：

    rg "math\.Quaternion\(|math\.Vector3\(|show_tips\(|call_delay_time\(" Manager Globals Components Config init.lua main.lua

输出包含 Macro、UI、Board 等文件路径，为后续修改提供清单。

步骤二（已完成）：修复浮点与时间换算，把 show_tips 的时长显式写为 2.0，UIEventRouter 与 UIState 的提示补全 duration，Layer.start_tick_loop 改用 FPS 常量并修正 tick_seconds。顺带把运行时路径中的 math.Quaternion/Vector3 纯字面量改为 0.0/1.0，保持仅修改 Manager/Globals/Components/Config。

步骤三（已完成）：在 Manager/TurnManager/GUI/Layer.lua 的 GAME_INIT 回调内加入单位检查提示，确保仅初始化时触发一次。

步骤四（已完成）：新增 tests/eggy_memory_audit.lua，并将其加入 tests/acceptance.lua。

## 验证与验收


验收一：运行静态审计。

    lua tests/eggy_memory_audit.lua

已执行，输出包含 “ok - eggy memory audit”。若发现违规，应在输出中带文件与行号。

验收二：运行现有测试。

    lua tests/acceptance.lua
    lua tests/lua_env_audit.lua

已执行，输出包含 “ok - acceptance suite” 与 “[lua-env] ok”。

验收三（Eggitor 手工）：以 main.lua 为入口启动，观察 UI 在 GAME_INIT 后才出现；触发 UI 缺失提示时停留约 2 秒；如单位未关闭组件性能优化，初始化时应提示一次。

## 可重复性与恢复


所有修改为本地 Lua 代码与测试脚本调整，不涉及数据迁移。若出现问题，可通过逐文件回滚恢复。静态审计脚本可重复执行以验证回滚后是否恢复到原状态。

## 产物与备注


预期产物包括：更新后的 Globals/Macro.lua 与 UI 相关文件、tests/eggy_memory_audit.lua 以及可能更新的 tests/acceptance.lua。示例变更片段如下：

    -- Globals/Macro.lua
    FPS = 30.0

    -- Layer.lua
    local DEFAULT_TIP_DURATION = 2.0
    show_tips(entry.text, DEFAULT_TIP_DURATION)

测试输出片段如下：

    ok - eggy memory audit
    ok - acceptance suite
    [lua-env] ok: no violations in runtime paths

## 接口与依赖


依赖的 Eggy API 与内建类型保持不变，核心调用仍为 LuaAPI.global_register_trigger_event、LuaAPI.call_delay_time、LuaAPI.query_units、GameAPI.get_role、GlobalAPI.show_tips、math.Quaternion、math.Vector3。新增或更新的全局常量需在 Globals/Macro.lua 中定义并保持名称稳定（例如 FPS = 30.0）。若新增审计脚本，应仅使用 io/rg/dofile 方式读取文件，不引入新的第三方库。本计划不修改 Library/ 下文件。

本次更新：首次创建计划，基于 eggy_lua_agent_memory.md 的规则与当前代码审计结果制定重构步骤。
本次更新：取消弧度角度相关内容，新增“不修改 Library/”约束，并同步调整审计范围、步骤与验收，原因是用户要求缩小范围与避免触碰底层库。
本次更新：执行计划并完成代码修改与审计脚本接入，同步更新进度、步骤与复盘状态，原因是进入实施阶段。
本次更新：完成静态审计与自动测试，记录测试环境缺失 math.Vector3 的发现与兜底决策，原因是确保测试稳定通过。
