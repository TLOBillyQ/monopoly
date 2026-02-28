# 架构收敛（薄封装与 Port 减重）可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。

本文件严格遵循 `.agents/harness/PLANS.md`。后续实施者在编码前必须先重读该规范，并按本文档的里程碑顺序推进。

## 目的 / 全局视角


这项工作的目标是把当前“能跑但间接层较多”的结构收敛成“同等行为、但更少中间层”的结构。对玩家和策划来说，改造后应该看不到玩法回归：游戏启动流程、回合推进、UI 交互、弹窗与动画都保持原有行为；对维护者来说，新增需求时需要跨越的文件和抽象层显著减少。

可观察的成功标准是：第一，`lua tests/regression.lua` 全量回归仍然通过（当前基线 182 条）；第二，被判定为可删除的薄封装文件在仓库中消失且无残留引用；第三，`GameplayLoop` 与 UI 端口接线简化后，仍能通过同一套回归证明“行为不变”。

## 进度


- [x] (2026-02-28 14:25Z) 已重读 `.agents/harness/PLANS.md`，确认本计划结构与活文档要求。
- [x] (2026-02-28 14:26Z) 已完成当前基线验证：`lua tests/regression.lua` 通过，结果为 `All regression checks passed (182)`。
- [x] (2026-02-28 14:27Z) 已核对关键引用事实：`GameplayLoopPortsAdapter` 在 `tests/suites/presentation_ui.lua` 仍被引用；`CanvasCoordinator` 当前无引用。
- [ ] 里程碑 M0：固化证据与回归护栏。
- [ ] 里程碑 M1：删除死代码与“仅测试依赖”适配层迁移。
- [ ] 里程碑 M2：内联单消费者薄封装并删除对应文件。
- [ ] 里程碑 M2b：合并 Agent + AgentTargeting 紧耦合文件。
- [ ] 里程碑 M3：塌缩 `GameStateOps` 链路，保持 `Game` 公共方法不变。
- [ ] 里程碑 M4：Port 基础设施收敛到“声明 + 实现聚合”双文件结构。
- [ ] 里程碑 M5a：拆分 state bag 为子对象并增量迁移消费者。
- [ ] 里程碑 M5b：去重路由/auto context、拆除循环依赖触发点。

## 意外与发现


- 观察：`src/presentation/api/GameplayLoopPortsAdapter.lua` 不是生产消费者，但仍被测试依赖，不能直接当“死代码”删除。
  证据：`tests/suites/presentation_ui.lua:1742,1770,1949,3256,3378` 存在 `require("src.presentation.api.GameplayLoopPortsAdapter")`。

- 观察：`src/presentation/canvas_runtime/CanvasCoordinator.lua` 是纯转发文件，当前没有调用点。
  证据：`rg "require\\(\"src\\.presentation\\.canvas_runtime\\.CanvasCoordinator\"\\)"` 返回 0 命中。

- 观察：`TurnEngine` 目前通过 `CompatBridge.sync_to_legacy_turn` 仅同步 `game.turn.phase`，逻辑体很小，适合就地内联。
  证据：`src/game/core/runtime/TurnEngine.lua:68-71`，`src/game/runtime_coroutine/CompatBridge.lua:3-17`。

- 观察：`UIViewService` 在多个函数体内延迟 `require("src.presentation.api.UIRuntimePort")`，体现了依赖环风险。
  证据：`src/presentation/api/UIViewService.lua:30,40,53,57,61`。

- 观察：choice 路由规则在 game 与 presentation 各维护一份，存在重复与漂移风险。
  证据：`src/game/flow/intent/IntentDispatcher.lua:13-68` 与 `src/presentation/interaction/UIChoiceRoutePolicy.lua:33-73`。

- 观察：`UIEventRouter` 不是纯单消费者——除 `UIBootstrap` 外，`tests/suites/presentation_ui.lua:21` 也 require 了它。内联前需先迁移测试引用。
  证据：`src/app/bootstrap/UIBootstrap.lua:3` 与 `tests/suites/presentation_ui.lua:21`。

- 观察：`AgentTargeting`（193 行）包含落点模拟、优先级排序、道具策略等真实业务逻辑，不属于"薄封装"。Agent.lua 中 4 个纯转发函数（L11-24）才是薄封装部分。合并方向应为"将 AgentTargeting 内容搬入 Agent.lua 并消除转发"，而非简单内联。
  证据：`src/game/core/runtime/AgentTargeting.lua:1-193`，`src/game/core/runtime/Agent.lua:11-24`。

## 决策日志


- 决策：按“先低风险删除/内联，再做结构塌缩”的顺序执行，先做 M1/M2，再做 M3-M5。
  理由：M1/M2 改动局部且可快速回归，能先降低文件数量与认知负担，再进入高耦合改造。
  日期/作者：2026-02-28 / Copilot GPT-5.3-Codex。

- 决策：`GameplayLoopPortsAdapter` 先迁移测试调用点，再删除文件；`CanvasCoordinator` 可直接删除。
  理由：两者都薄封装，但 adapter 仍有测试引用，直接删会先破坏基线。
  日期/作者：2026-02-28 / Copilot GPT-5.3-Codex。

- 决策：`GameStateOps` 删除后不改变 `Game` 对外方法名，缺失的方法直接在 `Game.lua` 补齐或由 `GameStatePlayers/Tiles/Turn` 提供。
  理由：外部系统已依赖 `game:rebuild()`/`game:current_player()` 等方法，先保证兼容签名，再收敛内部层级。
  日期/作者：2026-02-28 / Copilot GPT-5.3-Codex。

- 决策：Port 收敛阶段强制保留 fallback/no-op 契约并补测试，不以“删文件”替代“行为证明”。
  理由：`GameplayLoopPorts.resolve` 当前承担默认值语义，若无契约测试，后续回归定位成本高。
  日期/作者：2026-02-28 / Copilot GPT-5.3-Codex。

- 决策：state bag 拆分采用“先并存别名，再逐步去别名”的增量策略，不做一次性大迁移。
  理由：该改动横跨 `GameStartup`、`GameplayLoop`、UI 同步和 timeout，分批可控且便于回滚。
  日期/作者：2026-02-28 / Copilot GPT-5.3-Codex。

- 决策：`AgentTargeting`（193 行真实逻辑）从 M2"薄封装内联"中独立为 M2b，作为"紧耦合文件合并"单独执行。
  理由：AgentTargeting 不是薄封装，合并后产出 ~300 行文件，风险显著高于其他 M2 操作（UIEventRouter 20 行、CompatBridge 17 行等）。独立里程碑可单独回滚。
  日期/作者：2026-02-28 / Copilot Claude-Opus-4.6。

- 决策：`UIEventRouter` 内联前需先迁移 `tests/suites/presentation_ui.lua:21` 的测试引用，与 M1 处理 adapter 的模式一致。
  理由：UIEventRouter 有 2 个消费者（UIBootstrap + 测试），直接删除会破坏基线。
  日期/作者：2026-02-28 / Copilot Claude-Opus-4.6。

- 决策：`GameStateOps` 中非纯转发方法的归属明确为：`rebuild()`（重建 occupants 表）→ 内联到 `Game.lua`；`_mark_players`/`_mark_board` dirty 标记 → 搬入 `Game.lua`。
  理由：`rebuild` 直接操作 `game.occupants` 和 `game.players`，属于 Game 自身职责；dirty 标记同理，不适合下沉到子模块。
  日期/作者：2026-02-28 / Copilot Claude-Opus-4.6。

- 决策：原 M5 拆分为 M5a（state bag 拆分）和 M5b（逻辑去重 + 循环 require 清理），两者无前置依赖可独立推进。
  理由：四个独立维度打包在一个里程碑中，任一出问题都会阻塞整个 M5。拆分后可单独回滚、单独验收。
  日期/作者：2026-02-28 / Copilot Claude-Opus-4.6。

- 决策：M4 收敛时，`clock` port 的多级 fallback（`GameAPI.get_timestamp` → `os.clock` → 0）必须保留在声明侧 `GameplayLoopPorts.lua`，不可移到 `PresentationPorts.lua`。
  理由：clock fallback 含平台检测逻辑，属于 gameplay 层契约而非 presentation 实现；移走会导致无 presentation 时时钟失效。
  日期/作者：2026-02-28 / Copilot Claude-Opus-4.6。

## 结果与复盘


当前处于“计划已重写、尚未实施代码改造”阶段。阶段性成果是：目标边界、改造顺序、验证口径、回滚策略已经固定，且已修正“adapter 为 0 消费者”的事实偏差。后续复盘将在每个里程碑完成后更新，重点记录行为一致性和风险消解情况。

## 背景与导读


仓库入口是 `main.lua -> src/app/init.lua`，启动链路依次经过 `RuntimeInstall`、`GameStartup`、`UIBootstrap` 和运行时绑定。游戏核心在 `src/game/core/runtime/`，回合推进已统一由 `TurnEngine` 协程路径执行。presentation 层分为 canvas 运行时（`src/presentation/canvas_runtime/`）、交互层（`src/presentation/interaction/`）和 UI/API 适配层（`src/presentation/api/`）。

本计划聚焦的“薄封装/中间层”包括：`UIEventRouter`、`TurnActionPort`、`CompatBridge`、`Signals`、`CanvasCoordinator`、`GameplayLoopPortsAdapter`、`GameStateOps`，以及 `GameplayLoopPorts + ports/*.lua + GameplayLoopPortTypes` 形成的 Port 组合基础设施。另外，`Agent` 与 `AgentTargeting` 虽非薄封装，但存在紧耦合的转发关系（Agent.lua 4 个函数纯转发 AgentTargeting），适合合并为单文件。上述模块的共同问题不是“功能错误”，而是“路径过长、重复逻辑多、改动面被放大”。

术语说明：本文中的“Port”是 Lua table 形式的函数集合，用于把 gameplay loop 与 presentation 细节解耦；“fallback/no-op”是指某个端口未提供实现时使用空函数或默认返回，保证流程不崩溃；“state bag”是 `GameStartup.build_state()` 创建的大型状态表，当前包含 UI、动画、回合、棋盘、计时器、锁等多类字段。

## 工作计划


里程碑 M0 的范围是“先证明现状，再改代码”。这一阶段不做功能改动，只固定基线和证据：记录回归通过数、关键文件引用关系、将要删除文件的消费者清单。完成后得到一份可复核的“改造前快照”，防止后续争议。

里程碑 M1 的范围是“删除无消费者文件 + 迁移测试对 adapter 的依赖”。先在 `tests/suites/presentation_ui.lua` 把 `GameplayLoopPortsAdapter.build(state)` 替换为直接构建 grouped ports（与生产代码一致），然后删除 `src/presentation/api/GameplayLoopPortsAdapter.lua`。`src/presentation/canvas_runtime/CanvasCoordinator.lua` 因无消费者可直接删除。完成后，文件数减少且行为不变。

里程碑 M2 的范围是"内联单消费者薄封装"。先迁移 `tests/suites/presentation_ui.lua:21` 对 `UIEventRouter` 的 require（改为直接 require `CanvasEventRouter`），再把 `UIEventRouter` 内联到 `UIBootstrap`；把 `TurnActionPort.resolve` 内联到 `UIIntentDispatcher`；把 `CompatBridge` 内联到 `TurnEngine`；把 `Signals` 常量与判定函数内联到 `Scheduler/ActionRouter`。完成后要求：删除对应文件，且调用方无行为变化。

里程碑 M2b 的范围是"合并 Agent + AgentTargeting 紧耦合文件"。将 `AgentTargeting.lua`（193 行真实业务逻辑：落点模拟、优先级排序、道具策略）的内容搬入 `Agent.lua`，消除 Agent 中 4 个纯转发函数（L11-24），同时更新 `RuntimeInstall.lua` 的 preload 引用。合并后产出 ~300 行文件，风险高于 M2 其他操作，因此独立执行和回滚。完成后要求：`AgentTargeting.lua` 删除，Agent 对外行为不变，全量回归通过。

里程碑 M3 的范围是"塌缩 `GameStateOps`"。`Game.lua` 改为直接 mixin `GameStatePlayers`、`GameStateTiles`、`GameStateTurn`；`GameStateOps.lua` 删除前，先处理其非纯转发方法的归属：`rebuild()`（L153-166，重建 `game.occupants` 表的循环逻辑）内联到 `Game.lua`；`_mark_players`/`_mark_board` dirty 标记函数（L7-15）搬入 `Game.lua`，对应的 `mark_players_dirty`/`mark_board_dirty` 公开方法一并迁移。确保 `CompositionRoot` 仍可调用 `game:rebuild()`。完成后要求：`GameStateOps` 不再被引用，公开方法签名保持兼容。

里程碑 M4 的范围是"Port 基础设施收敛"。将 `src/presentation/api/ports/*.lua` 的 concrete 构建逻辑聚合到一个 `src/presentation/api/PresentationPorts.lua`，并在 `src/game/flow/turn/GameplayLoopPorts.lua` 内保留接口声明和 fallback 规则。注意：`clock` port 的多级 fallback（`GameAPI.get_timestamp` → `os.clock` → 0）含平台检测逻辑，必须保留在声明侧 `GameplayLoopPorts.lua`，不可移到 `PresentationPorts.lua`。`GameplayLoopPortTypes.lua` 与中间 resolve 层并入后删除。完成后要求：`GameplayLoop` 仍只依赖 grouped ports，fallback 行为有测试覆盖。

里程碑 M5a 的范围是"state bag 拆分"。在 `GameStartup.build_state()` 建立 `state.ui/state.anim/state.turn/state.board/state.timers/state.locks` 子对象并保留旧字段别名，再分批迁移 `GameplayLoop`、tick/timeout、UI 同步代码。每一批迁移后先保留别名并回归，再进入下一批。

里程碑 M5b 的范围是"逻辑去重 + 循环 require 清理"。把 `IntentDispatcher` 的 choice 路由推断委托给 `UIChoiceRoutePolicy`（消除两侧重复 if-chain）；提取 `AutoContext` 构建函数统一 `GameplayLoop` 中 `_build_auto_context()` 与 `_build_tick_auto_context()` 两段近似逻辑；把 `UIViewService` 对 `UIRuntimePort` 的延迟 `require` 改为显式依赖注入或顶层依赖，拆除依赖环触发点。M5a 与 M5b 无前置依赖，可独立推进和回滚。

## 具体步骤


所有命令在仓库根目录执行：`C:\Users\Lzx_8\Desktop\dev\monopoly`。

先执行 M0。运行回归并记录基线，然后运行引用检查命令，输出保存到“产物与备注”。

    lua tests/regression.lua
    rg -n "require\\(\"src\\.presentation\\.api\\.GameplayLoopPortsAdapter\"\\)" tests/suites/presentation_ui.lua
    rg -n "require\\(\"src\\.presentation\\.canvas_runtime\\.CanvasCoordinator\"\\)" src tests

再执行 M1。先改测试，再删文件，再跑全量回归；若回归通过，提交一个独立变更。测试中 grouped ports 的构建方式必须与生产逻辑一致，不要新造临时协议。

    lua tests/regression.lua
    rg -n "GameplayLoopPortsAdapter|CanvasCoordinator" src tests

再执行 M2。先迁移 `tests/suites/presentation_ui.lua:21` 对 `UIEventRouter` 的 require（改为直接 require `CanvasEventRouter`），再按“UI -> runtime”顺序内联并逐步删除封装文件，每删除一个文件都运行一次回归，避免累积故障。`TurnActionPort` 内联时保留“默认 reject + should_block_action=false”的原语义。

    lua tests/regression.lua
    rg -n "UIEventRouter|TurnActionPort|CompatBridge|Signals" src tests

再执行 M2b。将 `AgentTargeting.lua` 全部内容搬入 `Agent.lua`，消除 4 个纯转发函数，更新 `RuntimeInstall.lua` preload。此步产出 ~300 行合并文件，独立回归验证。

    lua tests/regression.lua
    rg -n "AgentTargeting" src tests

再执行 M3。先改 `Game.lua` mixin 与缺失方法归属，再删除 `GameStateOps.lua`，然后验证 `CompositionRoot` 初始化路径。这里必须额外检查 `game:rebuild()` 在建局时仍执行一次。

    lua tests/regression.lua
    rg -n "GameStateOps" src tests

再执行 M4。先引入 `PresentationPorts.build()` 并切换调用点，再把旧 `ports/*.lua` 与 `GameplayLoopPortTypes.lua` 收敛删除。若某 fallback 行为变更，先补测试再继续删除。

    lua tests/regression.lua
    rg -n "src\\.presentation\\.api\\.ports\\.|GameplayLoopPortTypes" src tests

再执行 M5a。state bag 拆分必须分批推进：每一批迁移后先保留别名并回归，再进入下一批。

    lua tests/regression.lua
    rg -n "pending_choice_elapsed|ui_modal_elapsed|wait_move_anim|wait_action_anim|move_anim_seq|action_anim_seq" src tests

最后执行 M5b。choice 路由与 auto context 去重、循环 require 清理。M5b 与 M5a 无前置依赖，可独立推进。

    lua tests/regression.lua
    rg -n "_resolve_choice_route|_build_tick_auto_context|_build_auto_context" src
    rg -n "require.*UIRuntimePort" src/presentation/api/UIViewService.lua

## 验证与验收


M0 验收标准：回归命令输出 `All regression checks passed (182)`，并能复现 adapter/CanvasCoordinator 的引用结论。

M1 验收标准：`GameplayLoopPortsAdapter` 与 `canvas_runtime/CanvasCoordinator` 文件已删除；`rg` 在 `src` 与 `tests` 下无残留 require；全量回归通过。

M2 验收标准：`UIEventRouter`、`TurnActionPort`、`CompatBridge`、`Signals` 文件删除；`tests/suites/presentation_ui.lua` 中 UIEventRouter 引用已迁移；调用方改为直接依赖目标模块；全量回归通过。

M2b 验收标准：`AgentTargeting.lua` 删除且无引用；`Agent.lua` 包含全部 targeting 逻辑（~300 行）；`RuntimeInstall.lua` preload 已更新；全量回归通过。

M3 验收标准：`GameStateOps.lua` 删除且无引用；`CompositionRoot` 初始化后 `game:rebuild()` 仍有效；全量回归通过。

M4 验收标准：Port 结构收敛为 `GameplayLoopPorts.lua + PresentationPorts.lua` 两个核心文件；旧 `ports/*.lua` 与 `GameplayLoopPortTypes.lua` 删除；fallback/no-op 行为有测试证明；全量回归通过。

M5a 验收标准：state 子对象成为主读写入口，旧字段仅剩短期兼容别名或已清理；全量回归通过。

M5b 验收标准：choice route 与 auto context 重复逻辑合并为单一入口；`UIViewService` 不再在函数体内延迟 require `UIRuntimePort`；全量回归通过。

## 可重复性与恢复


每个里程碑单独提交，且都以“回归全绿”作为提交门槛。若某里程碑失败，优先回滚该里程碑涉及文件，不跨里程碑混合修复。涉及删除文件时，先确认 `rg` 无引用再删除；若误删，使用版本控制恢复并重新执行该里程碑。

state bag 迁移期间保留别名层，保证步骤可重复。若发现行为回归，先恢复别名写回路径，再定位具体消费者，不做“静默兜底”。

## 产物与备注


以下是已获取的当前基线证据（实施前）：

    [baseline] lua tests/regression.lua
    All regression checks passed (182)
    dep_rules ok
    tick ok

    [evidence] tests/suites/presentation_ui.lua
    require("src.presentation.api.GameplayLoopPortsAdapter") at lines 1742,1770,1949,3256,3378

    [evidence] UIEventRouter consumers
    src/app/bootstrap/UIBootstrap.lua:3
    tests/suites/presentation_ui.lua:21

    [evidence] canvas_runtime/CanvasCoordinator
    require count = 0

后续每个里程碑完成后，在本节追加最小证据：一段回归结果 + 一段关键 `rg` 命中变化。

## 接口与依赖


本计划不引入外部第三方依赖，只在现有 Lua 模块内重组接口。

M4 完成时，`src/presentation/api/PresentationPorts.lua` 需要提供稳定接口（注意：`clock` 不在此处，其多级 fallback 含平台检测逻辑，保留在声明侧 `GameplayLoopPorts.lua`）：

    local presentation_ports = {}
    function presentation_ports.build(state)
      return {
        modal = {...},
        anim = {...},
        ui_sync = {...},
        debug = {...},
        state = {...},
      }
    end
    return presentation_ports

M5b 完成时，建议新增（或等价内联）统一 auto context 接口，供 `GameplayLoop.step_auto_runner` 与 tick 逻辑共用：

    local auto_context = {}
    function auto_context.build(game, context) ... end
    function auto_context.build_tick(game) ... end
    return auto_context

`UIIntentDispatcher` 内联 `TurnActionPort` 后，必须保持以下行为契约不变：缺失端口时 `dispatch_action` 返回 `{ status = "rejected" }`，`should_block_action` 返回 `false`。

## 本次修订记录


- 修订 1：将旧的"协程切流"历史计划整体替换为"架构收敛（薄封装与 Port 减重）"新计划，原因是当前需求已转为落实 `.agents/research.md` 的收敛方案。新版本补齐了可执行顺序、验收口径、回滚策略，并修正了 `GameplayLoopPortsAdapter` 仍被测试依赖这一事实。
  日期/作者：2026-02-28 / Copilot GPT-5.3-Codex。

- 修订 2（审查修正）：基于代码验证，修正以下 7 项问题：
  1. 回归基线从 181 更正为 182（实测结果）。
  2. `GameplayLoopPortsAdapter` 测试引用从 4 处更正为 5 处（补充 line 3378）。
  3. `UIEventRouter` 消费者从"仅 UIBootstrap"更正为"UIBootstrap + tests/suites/presentation_ui.lua:21"，M2 增加测试迁移步骤。
  4. `AgentTargeting`（193 行真实逻辑）从 M2"薄封装内联"中独立为 M2b"紧耦合文件合并"，降低风险耦合。
  5. M3 中 `GameStateOps` 非纯转发方法（`rebuild`/`_mark_*`）的归属方案明确写入：均内联到 `Game.lua`。
  6. 原 M5 拆分为 M5a（state bag 拆分）和 M5b（逻辑去重 + 循环 require 清理），两者无前置依赖可独立回滚。
  7. M4 标注 `clock` port 多级 fallback 必须保留在声明侧 `GameplayLoopPorts.lua`，接口示例中移除 clock。
  日期/作者：2026-02-28 / Copilot Claude-Opus-4.6。
