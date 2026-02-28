# 协程切流验证与旧路径退役可执行计划

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件严格遵循 `.agents/harness/PLANS.md` 的维护规范。任何后续实施者必须先阅读该文件，再执行本计划。

## 目的 / 全局视角

前一轮工作完成了协程运行时骨架（`src/game/runtime_coroutine/` 的 7 个模块）和 Canvas 运行时结构（`CanvasStore`、`CanvasRenderPipeline`、canvas intents 路由），但系统仍处于"混合态"：旧 `TurnFlow` 是默认主路径，协程路径仅有 2 个基础测试，`resume_state/resume_args` 仍在 8 个生产文件中传播，`shared/UINodes` 仍被 14 个生产文件引用。

本计划的用户价值是：把协程路径从"实验性骨架"提升为"可信赖的默认路径"，然后安全退役旧状态机和旧 UI 兼容层。改完后，用户能观察到三个结果：第一，新增等待点只需写一行 `await` 调用而非维护 `resume_state/resume_args` 传递链；第二，回合逻辑在协程路径下行为与旧路径完全一致（测试证明）；第三，UI 节点引用统一收口到 canvas 模块，不再散落在 `shared/UINodes`。

## 进度

- [x] (2026-02-28 12:42:00 +08:00) 前置：协程运行时骨架与 CanvasStore/CanvasRenderPipeline 落地（前一轮计划里程碑 0-5）。
- [x] (2026-02-28 13:15:00 +08:00) 里程碑 A：补全协程路径测试覆盖，建立行为一致性验证。新增 5 个测试（wait_move_anim / wait_action_anim / detained_wait / full_turn_lifecycle / legacy_parity），总测试 168 条，8 条预存失败不变。dep_rules 新增 canvas_runtime 不得引用 intent_builders 规则。
- [x] (2026-02-28 14:30:00 +08:00) 里程碑 B：默认开启协程路径，迁移测试中的 turn_flow 直接替换。`experimental_coroutine_turn` 默认值改为 `true`。4 处直接 `turn_flow` 引用迁移至 `turn_engine` 接口（presentation_ui 2 处改用 TurnEngine 构造 + run_turn/dispatch，gameplay 2 处改用 turn_engine.phases/turn_mgr/next_player）。全量回归 168 条（8 条预存失败不变），legacy 回退验证通过。
- [x] (2026-02-28 16:00:34 +08:00) 里程碑 C：消除 phase 业务中的 `resume_state/resume_args` 传播。`TurnStart/TurnRoll/TurnMove/TurnLand`、`ItemPhase`、`EffectPipeline`、`PhaseRegistry` 已统一改为 `next_state/next_args` 协议；`Await.lua` 删除 `_resume()` 并改为读取 `next_*`。验收搜索：`src/game/flow/turn` 与 `src/game/systems` 下 `resume_state/resume_args` 命中为 0。全量回归 168 条，8 条预存失败不变。
- [x] (2026-02-28 16:07:05 +08:00) 里程碑 S（稳定性）：清零 8 条预存失败。根因是 `GameplayRules.test_profile=ui_quick_all` 导致 `Config.Map` 指向 10 格快速环图，历史测试中的硬编码 tile id 与路径假设失效。修复方式：`tests/suites/chance.lua`、`land.lua`、`item.lua`、`movement.lua` 显式使用 `Config.Maps.DefaultMap`；`tests/TestSupport.lua` 支持 `new_game(opts)` 传入 map/ui_port 覆盖。验收：全量回归通过，失败 0。
- [x] (2026-02-28 16:33:00 +08:00) 里程碑 T（测试重构）：修复 presentation_ui_registry（66→75 名称）和 gameplay_registry（35→38 名称）的名称/切片对齐，恢复 13 条被静默丢弃的测试并修复其 3 条夹具过期失败。10 个独立 suite 全部转为 name+tests 格式消除匿名输出。regression.lua 按 core/runtime/presentation/integration 四域分组。验收：全量回归 181 条（168+13），失败 0。
- [x] (2026-02-28 16:37:00 +08:00) 里程碑 D：退役 shared/UINodes 兼容层与 intent_builders 目录。14 个 src/ 文件迁移至直接引用 canvas/*/nodes.lua，required_click_nodes 移入 UIBootstrap，测试引用迁移至 canvas.base.item_slot_intents。删除 UINodes.lua 和 intent_builders/（5 文件）。dep_rules 扩展为全 src/presentation 范围守护。验收：全量回归 180 条，失败 0。
- [x] (2026-02-28 16:37:00 +08:00) 里程碑 E：退役旧 TurnFlow 主路径。TurnEngine 移除 legacy 分支和 get_legacy_flow()，Game._resolve_turn_runtime() 简化为直接返回 turn_engine，CompositionRoot 不再创建 game.turn_flow。删除 TurnFlow.lua/TurnChoiceHandler.lua/TurnWaits.lua/Flow.lua。Session.from_turn_flow() 移除。experimental_coroutine_turn 配置项移除。dep_rules 新增 runtime 不得引用 TurnFlow 规则。验收：全量回归 180 条（-1 legacy parity），失败 0。

## 意外与发现

- 观察：前一轮计划标记里程碑 0-5 全部完成，但第二轮审计发现实际是"骨架落地 + 混合态"，而非真正的切流完成。旧 `TurnFlow` 仍是默认路径，`experimental_coroutine_turn` 默认为 `false`。
  证据：`Config/RuntimeConstants.lua:38` 中 `experimental_coroutine_turn = false`；`Game._resolve_turn_runtime()` 在 `game.turn_flow` 被外部替换时优先走旧实例。

- 观察：`Await` 模块是"双模"设计——在旧路径中被当作同步轮询函数调用（每帧调用返回 `{wait=true}` 或 `{next_state, next_args}`），在协程路径中由 `TurnScript` 包裹 `yield` 实现真正挂起。这个设计是有意的，允许渐进切流。
  证据：`TurnWaits.lua` 和 `TurnChoiceHandler.lua` 同步调用 `await.*` 并检查返回值；`TurnScript.lua:43` 调用同一个 `await.*` 后根据 `wait_res.wait` 决定是否 `coroutine.yield`。

- 观察：`CanvasRegistry` 已完成从 `intent_builders` 到 `canvas/*/intents.lua` 的迁移，但 `intent_builders/` 目录仍存在，且 `tests/suites/presentation_ui.lua:2414` 仍引用 `ItemSlotIntents`。
  证据：`CanvasRegistry.lua` 顶部 8 个 require 全部指向 `canvas.*` 模块；`intent_builders/` 目录含 5 个文件仍在文件系统中。

- 观察：测试中 3 个文件直接替换 `game.turn_flow` 字段，这会绕过 `TurnEngine`，阻碍协程路径成为默认。
  证据：`tests/suites/presentation_ui.lua:369,2571`、`tests/suites/gameplay.lua:454,1383`。

- 观察：协程路径测试仅有 2 个（`gameplay_coroutine.lua`），只覆盖 `wait_choice` 的 `choice_cancel` 解决。未覆盖 `wait_move_anim`、`wait_action_anim`、`detained_wait`、`await.seconds`、完整回合串联、错误恢复。
  证据：`tests/suites/gameplay_coroutine.lua` 全文 71 行，2 个 `it()` 块。

## 决策日志

- 决策：保留前一轮计划的所有决策（兼容桥策略、切流顺序、运行时开关、Game 层兼容分支、CanvasRegistry 迁移方向），不做推翻。
  理由：前一轮决策经过验证是可行的，骨架已落地且回归通过。
  日期/作者：2026-02-28 / Claude Opus 4。

- 决策：新计划以"测试先行"为核心策略——先补足协程路径测试（里程碑 A），测试全绿后才改默认值（里程碑 B），然后才做 phase 改造和旧路径退役。
  理由：当前协程路径测试覆盖极低（2 个测试），直接切流风险过高。测试是切流的前置门控。
  日期/作者：2026-02-28 / Claude Opus 4。

- 决策：`resume_state/resume_args` 的消除（里程碑 C）排在默认切流（里程碑 B）之后，而非之前。
  理由：`resume_state/resume_args` 目前被 `Await._resume()` 兼容函数消化，不影响协程路径正确性。先切流再清理，避免同时改变两个维度增加回归风险。
  日期/作者：2026-02-28 / Claude Opus 4。

- 决策：UINodes 退役（里程碑 D）与逻辑层切流（里程碑 B/C）解耦，可并行推进。
  理由：UI 层和逻辑层的遗留依赖互相独立，一方的迁移不依赖另一方完成。
  日期/作者：2026-02-28 / Claude Opus 4。

- 决策：在 D/E 前插入“测试重构里程碑 T”，先统一测试结构和夹具契约，再继续删除旧路径/兼容层。
  理由：D/E 将带来大规模文件迁移和删除，若测试仍按历史文件散落组织，回归失败定位成本高；先重构测试可显著降低后续改造风险。
  日期/作者：2026-02-28 / Codex GPT-5。

## 结果与复盘

前一轮工作的成果已在前一版 plan.md 中记录，此处总结：协程运行时 7 个模块已落地，`TurnEngine` 双模切换可用，`CanvasStore/CanvasRenderPipeline/CanvasRegistry` 已实现，全量回归 163 条通过。残留问题是测试覆盖不足、默认路径未切换、`resume_state/resume_args` 和 `UINodes` 遗留依赖未清理。

本轮计划的目标是把这些残留问题逐一解决，实现真正的切流完成。

## 背景与导读

本仓库是一个 Lua 实现的大富翁游戏，运行在 Eggy 游戏平台上。入口是 `main.lua`，它只做 `require "src.app.init"`。启动链路在 `src/app/init.lua`：安装运行时、创建状态对象、绑定事件桥、安装 UI、启动 tick。

游戏回合内核有两套实现并存。旧内核在 `src/game/flow/turn/TurnFlow.lua`，通过 `src/core/Flow.lua` 做字符串状态推进（"start" -> "roll" -> "move" -> "land" -> "end_turn"），遇到 `wait_choice`、`wait_action_anim`、`wait_move_anim` 时停下等外部 action。新内核在 `src/game/runtime_coroutine/` 下，用 Lua coroutine 实现真正的 yield/resume 语义。`src/game/core/runtime/TurnEngine.lua` 根据 `experimental_coroutine_turn` 开关选择走哪条路径。`src/game/core/runtime/Game.lua` 的 `_resolve_turn_runtime()` 是入口分发器。

UI 层采用 Canvas-First 架构。`src/presentation/canvas/` 下 13 个子模块各有 `nodes.lua`（节点定义）、`contract.lua`（画布契约）、`intents.lua`（意图构建）。`src/presentation/canvas_runtime/` 下的 `CanvasRegistry`、`CanvasStore`、`CanvasRenderPipeline`、`CanvasEventRouter` 提供运行时编排。遗留兼容层包括 `src/presentation/shared/UINodes.lua`（节点字符串集中定义，14 个文件引用）和 `src/presentation/interaction/intent_builders/`（旧意图构建，CanvasRegistry 已不引用但目录未删除）。

关键术语：`Await` 是 `src/game/runtime_coroutine/Await.lua`，提供 `choice/move_anim/action_anim/detained/seconds` 五个等待原语。`Session` 是 `src/game/runtime_coroutine/Session.lua`，是协程执行上下文，也能从旧 `TurnFlow` 创建兼容包装。`resume_state/resume_args` 是旧内核的 continuation 传递机制，每个 phase 函数返回 `(wait_state, {resume_state=X, resume_args=Y})` 告知 Flow 回来后跳到哪、带什么参数。

测试入口是 `lua tests/regression.lua`，聚合 20 个 suite（30 个文件），当前 163 条通过。协程专项测试在 `tests/suites/gameplay_coroutine.lua`（2 条）。依赖规则在 `tests/internal/dep_rules.lua`（2 条规则）。

## 工作计划

里程碑 A 的目标是让协程路径达到"可信赖"级别，方法是补足测试覆盖。当前只有 2 个测试验证协程路径，需要扩展到覆盖所有 4 种等待态（`wait_choice`、`wait_action_anim`、`wait_move_anim`、`detained_wait`）、完整回合串联、以及新旧路径行为一致性。所有新测试写入 `tests/suites/gameplay_coroutine.lua`。同时在 `tests/internal/dep_rules.lua` 新增规则：`src/presentation/canvas_runtime` 不得引用 `intent_builders`。完成后全量回归必须通过。

里程碑 B 的目标是把协程路径设为默认。修改 `Config/RuntimeConstants.lua` 中 `experimental_coroutine_turn` 的默认值为 `true`。然后逐个迁移测试中直接替换 `game.turn_flow` 的写法（`tests/suites/presentation_ui.lua` 的 2 处、`tests/suites/gameplay.lua` 的 2 处），改为通过 `TurnEngine` 接口或传入协程配置。`Game._resolve_turn_runtime()` 的兼容分支暂保留，但旧 `TurnFlow` 不再是默认。全量回归通过后提交。

里程碑 C 的目标是消除 `resume_state/resume_args` 在 phase 文件中的传播。具体做法是改造 `TurnStart.lua`、`TurnRoll.lua`、`TurnMove.lua`、`TurnLand.lua` 中的 phase 函数，使其在协程路径下不再返回 `(wait_state, {resume_state, resume_args})`，而是由协程栈帧自然保存上下文。`ItemPhase.lua` 和 `EffectPipeline.lua` 中的 resume 逻辑同步改造。`Await.lua` 中的 `_resume()` 兼容函数在全部 phase 改造完成后移除。这一步改动影响面最大（8 个生产文件、~60 个引用点），需要逐文件改造并频繁跑回归。

里程碑 S（稳定性）的目标是清零历史失败用例并恢复回归门禁可信度。具体做法是将受影响的核心逻辑测试（chance/land/item/movement）与 UI 快速测试档位解耦，显式使用 `Config.Maps.DefaultMap` 构造 game；同时给 `tests/TestSupport.lua` 增加 `new_game(opts)` 入参，避免后续再出现“全局 profile 变更导致核心测试漂移”的问题。

里程碑 T（测试重构）的目标是整理当前所有测试并对齐当前代码重构方案。具体做法是：第一，按能力域重组测试入口（`core`、`runtime_coroutine`、`presentation`、`integration`），将“遗留命名/历史模块命名”逐步替换为“行为语义命名”；第二，为每个 suite 显式声明运行时档位（default map / quick map / coroutine flag / legacy fallback）并统一通过 `TestSupport.new_game(opts)` 构造；第三，补充测试模板与约束文档，要求新增测试必须声明依赖的 map/profile/runtime，不得隐式依赖 `GameplayRules.test_profile` 全局值。

里程碑 D 的目标是退役 `shared/UINodes.lua` 和 `interaction/intent_builders/` 目录。逐文件迁移 14 个引用 `UINodes` 的生产文件，改为直接引用对应 `canvas/*/nodes.lua` 或 `canvas/*/contract.lua` 导出的节点。迁移 `tests/suites/presentation_ui.lua:2414` 对 `ItemSlotIntents` 的引用到 `canvas/base/item_slot_intents.lua`。全部迁移后删除 `shared/UINodes.lua` 和 `interaction/intent_builders/` 目录，更新 dep_rules。

里程碑 E 的目标是退役旧 `TurnFlow` 主路径。`TurnEngine.lua` 移除 legacy 模式分支和 `get_legacy_flow()` 方法。`Game._resolve_turn_runtime()` 简化为只返回 `turn_engine`，移除 `turn_flow` 兼容检测。`CompositionRoot.lua` 不再创建 `game.turn_flow`。如果 `TurnFlow.lua` 和 `Flow.lua` 无其他使用者，直接删除；否则降级为独立工具模块。更新文档。

## 具体步骤

所有命令均在工作目录 `c:\Users\Lzx_8\Desktop\dev\monopoly` 执行。

里程碑 A 的步骤如下。

第一步，锁定当前基线。执行：

    lua tests/regression.lua

预期输出：

    All regression checks passed (163)

第二步，在 `tests/suites/gameplay_coroutine.lua` 中新增以下测试（保留现有 2 个不变）：

- `coroutine_mode_resolves_wait_move_anim`：构造进入 `wait_move_anim` 的 phase，在协程模式下 dispatch `move_anim_done` action（含正确 seq），断言状态前进。再 dispatch 错误 seq，断言保持等待。
- `coroutine_mode_resolves_wait_action_anim`：构造进入 `wait_action_anim` 的 phase，在协程模式下 dispatch `action_anim_done`，断言 seq 校验和状态前进。
- `coroutine_mode_resolves_detained_wait`：构造 `detained_wait` 状态，dispatch 解除 action，断言状态前进。
- `coroutine_mode_full_turn_lifecycle`：构造完整回合 phase 链（start -> roll -> move -> land -> end_turn），在协程模式下驱动至完成，断言最终 phase 为 nil 或 done。
- `coroutine_and_legacy_produce_same_result`：同一局面分别用 `experimental_coroutine_turn=false` 和 `true` 驱动一个完整回合，断言最终游戏状态（玩家位置、余额、pending_choice）一致。

第三步，在 `tests/internal/dep_rules.lua` 新增规则：

    {
      root = "src/presentation/canvas_runtime",
      forbidden = { "intent_builders" },
      description = "canvas_runtime must not depend on legacy intent_builders",
    }

第四步，执行回归验证：

    lua tests/regression.lua

预期输出包含新增测试全部通过且总数增长。

里程碑 B 的步骤如下。

第一步，修改 `Config/RuntimeConstants.lua` 第 38 行，将 `experimental_coroutine_turn = false` 改为 `experimental_coroutine_turn = true`。

第二步，逐个修复因默认路径改变而失败的测试。主要涉及 `tests/suites/presentation_ui.lua` 中直接 `g.turn_flow = turn_flow:new(g, phases)` 的两处和 `tests/suites/gameplay.lua` 中直接访问 `g.turn_flow.phases` 和 `g.turn_flow:next_player()` 的两处。改为通过 `g.turn_engine` 或 `g:advance_turn()`/`g:dispatch_action()` 接口操作。

第三步，全量回归通过后提交。

后续里程碑 T/D/E 的步骤将在前置里程碑完成后细化。

里程碑 T 的步骤如下。

第一步，建立测试清单并按能力域标注。对 `tests/suites/*.lua` 逐文件标记域、依赖 map/profile、依赖 runtime（coroutine/legacy）、是否 UI 相关，产出清单写入 `plan.md` 的“产物与备注”。

第二步，重构聚合入口。将 `tests/regression.lua` 的 suites 装配改为按能力域聚合（core/runtime/presentation/integration），保留兼容别名 1 个版本周期，避免一次性改动影响定位。

第三步，统一夹具入口。所有 suite 改为只通过 `TestSupport.new_game(opts)` 创建 game，禁止各 suite 直接拼装 map/profile；对现有特殊档位（`ui_quick_*`）改为显式 opts。

第四步，命名与断言规范化。把 `suite_x.case_y` 不可读命名替换为稳定语义名，断言失败信息统一包含“能力域 + 场景 + 期望/实际”，并为 flaky 场景加 deterministic 种子说明。

第五步，门禁分层。新增最小执行矩阵：`core` 每次必跑，`runtime+presentation` PR 必跑，`integration` 夜间跑；输出命令别名并在 README/计划中记录。

## 验证与验收

里程碑 A 的验收：运行 `lua tests/regression.lua`，总测试数从 163 增加到至少 168（新增 5 个协程路径测试），全部通过。新增测试在 `experimental_coroutine_turn = false` 时不执行或跳过，在测试内部设为 `true` 时执行并通过。

里程碑 B 的验收：运行 `lua tests/regression.lua`，全量通过且默认走协程路径。可通过在测试前临时设 `experimental_coroutine_turn = false` 验证旧路径仍可用。

里程碑 C 的验收：在 `src/game/flow/turn/` 和 `src/game/systems/` 下搜索 `resume_state` 和 `resume_args`，命中数为 0（`Await.lua` 中的 `_resume` 函数也已移除）。全量回归通过。

里程碑 T 的验收：`tests/suites` 全文件完成能力域标注；`tests/regression.lua` 已按能力域聚合；新增测试模板生效且 `new_game(opts)` 成为唯一建局入口；回归输出不再出现 `suite_x.case_y` 匿名失败；全量回归通过。

里程碑 D 的验收：搜索 `shared.UINodes` 和 `shared/UINodes`，在 `src/` 下命中数为 0。`intent_builders/` 目录不存在。全量回归通过。

里程碑 E 的验收：`TurnFlow.lua` 和 `Flow.lua` 不被 `src/game/core/runtime/` 下任何文件引用。`Game._resolve_turn_runtime()` 中不存在 `turn_flow` 兼容分支。全量回归通过。

## 可重复性与恢复

每个里程碑可独立提交，且提交后可重复跑 `lua tests/regression.lua`。若里程碑 B 切流后回归失败，优先将 `experimental_coroutine_turn` 改回 `false` 回退到旧路径，确认回归恢复后再排查。里程碑 C 的 phase 改造逐文件进行，每改一个跑一次回归，失败则 revert 该文件改动。里程碑 D/E 是删除操作，如有失败用 `git checkout` 恢复被删文件。

## 产物与备注

    [前置] 回归结果：All regression checks passed (163)
    [前置] 行为验证：协程骨架可用，旧路径为默认，CanvasRegistry 已切到 canvas intents。
    [前置] 文件：src/game/runtime_coroutine/*, src/presentation/canvas_runtime/*, Config/RuntimeConstants.lua

后续里程碑的产物将在完成后补充到此处。

## 接口与依赖

本计划不引入新的外部依赖。协程内核只用 Lua 标准 `coroutine` 库。

里程碑 A 新增测试依赖现有 `tests/TestSupport.lua` 提供的 `support.make_game()` 和 `support.turn_flow` 工具函数。如果需要创建协程模式的 game 实例，通过 `support.make_game({experimental_coroutine_turn = true})` 或在测试中直接构造 `TurnEngine`（参考现有 `gameplay_coroutine.lua` 第 20-30 行的模式）。

里程碑 C 改造后，`Await.lua` 的接口将简化：`choice(session, spec)` 不再需要 `args` 参数中的 `resume_state/resume_args`，返回值直接是 choice 结果而非 `{next_state, next_args}`。具体签名在里程碑 B 完成后确定。

里程碑 D 迁移后，节点引用统一从 `src/presentation/canvas/<key>/nodes.lua` 导出。每个 canvas 模块的 `nodes.lua` 应导出该画布所需的全部节点常量。

## 本次修订记录

本次修订基于第二轮深度代码审计，重新评估了前一轮计划中标记为"完成"的里程碑 0-5 的实际落地状态。发现系统处于"混合态"而非"切流完成"，因此制定了新的里程碑 A-E，聚焦于测试补全、默认切流、遗留清理和旧路径退役。前一轮计划的决策和骨架代码全部保留并继续使用。这样做的原因是：前一轮建立了正确的架构骨架，本轮的目标是把骨架变为可信赖的生产路径。
