# 回合流协程化（一次切换）可执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件遵循 `.agents/PLANS.md` 维护。


## 目的 / 全局视角


当前回合系统依赖显式状态跳转与 waiting/resume_state/resume_args 协议，阅读和扩展成本高。本计划目标是在不改变玩家可见行为的前提下，把回合主链路改成 Lua 协程顺序编排，逻辑代码可以按“先做 A，再等事件，再做 B”的自然顺序书写。改完后玩家仍看到相同的 wait_choice / wait_move_anim / wait_action_anim 阶段，动画与选择交互保持一致。可观察结果是回归脚本仍通过，且手工流程中的回合推进与改造前一致。


## 进度


- [x] (2026-02-09 13:40+08:00) 完成代码勘察，确认当前等待协议分布与入口。
- [x] (2026-02-09 13:45+08:00) 明确改造决策：范围“回合流先改”、兼容“一次切换”、节奏“两阶段里程碑”。
- [x] (2026-02-09 13:49+08:00) 跑通基线回归：regression.lua 通过 35 项。
- [ ] 实施里程碑 1：落地协程 Runner 骨架与动画等待闭环。
- [ ] 实施里程碑 2：完成回合主链路切换并移除旧等待协议。


## 意外与发现


观察：仓库当前没有业务层 coroutine 用法，等待语义主要靠状态机返回值和 SetTimeOut 回调驱动。证据：rg -n "coroutine|yield|resume" src vendor 仅命中文档和第三方片段，业务主链路未使用。

观察：现有回归已覆盖动画等待恢复关键路径，可作为协程改造最小护栏。证据：regression.lua 中 _test_move_anim_callback_and_delay、_test_move_anim_wait_and_resume 已存在且当前通过。


## 决策日志


决策：本轮仅改“回合主链路”，不改第三方 UIManager。理由：降低风险，聚焦收益最大的复杂流程。日期/作者：2026-02-09 / Codex。

决策：采用“一次切换”而非双轨兼容。理由：减少长期维护负担，避免两套协议并存。日期/作者：2026-02-09 / Codex。

决策：采用“两阶段里程碑”推进。理由：先用动画等待链路验证 Runner，再切全链路，降低一次性回归风险。日期/作者：2026-02-09 / Codex。


## 结果与复盘


当前处于计划完成、尚未实施阶段。已完成上下文确认、风险识别、验收护栏定义。待实施后补充：完成项、遗留项、性能与可维护性收益、是否达到“行为一致 + 代码更直观”的初始目标。


## 背景与导读


回合推进入口在 `src/game/Game.lua` 的 advance_turn() 与 dispatch_action(action)。核心状态机位于 `src/game/turn/TurnFlow.lua`，其内部通过 `src/game/flow/Flow.lua` 做状态切换。等待态来源分散在 `src/game/turn/TurnStart.lua`、`src/game/turn/TurnRoll.lua`、`src/game/turn/TurnMove.lua`、`src/game/turn/TurnLand.lua`、`src/game/turn/ItemPhase.lua`、`src/game/turn/EffectPipeline.lua`，共同通过 waiting/resume_state/resume_args 协议返回。动画完成信号由 `src/game/turn/TurnAnim.lua` 触发 move_anim_done/action_anim_done，再回流到回合推进。Tick 驱动在 `src/init.lua` 的 SetFrameOut，主循环在 `src/game/GameplayLoop.lua`。

术语说明：waiting/resume_state/resume_args 是当前回合流等待协议，含义是“函数返回等待描述，由外层保存并在事件到来时恢复继续”。协程 Runner 指新增的回合协程执行器，它用 coroutine.yield 产出等待描述，并在事件匹配时 coroutine.resume 恢复执行。等待原语指统一封装等待选择与动画的函数集合。


## 工作计划


先新增协程执行器与等待原语模块，不动 UI 事件结构与动作类型。协程执行器负责创建/恢复回合协程，并在等待点产出统一描述。接着把 TurnRoll 与 TurnMove 的等待点迁入协程原语，验证动画链路，保持动作事件名不变。最后迁移 TurnStart、TurnLand、ItemPhase、EffectPipeline 的等待逻辑，彻底移除旧 waiting/resume_* 协议在回合主链路的使用，并清理 TurnFlow 对 Flow 的运行时依赖。全过程不做与协程改造无关的顺手优化。


## 具体步骤


先清理并写入以下新增模块。

    在仓库根目录创建 `src/game/turn/TurnCoroutineRunner.lua`，定义回合协程执行与恢复逻辑。
    在仓库根目录创建 `src/game/turn/TurnAwait.lua`，定义 await_choice / await_move_anim / await_action_anim。

然后把 CompositionRoot 中回合注入从 turn_flow 切到协程 Runner，保持 Game 对外方法签名不变。

    修改 `src/game/CompositionRoot.lua` 中回合构建与注入逻辑。
    保持 `src/game/Game.lua` 中 advance_turn() 与 dispatch_action(action) 签名不变，仅改内部绑定。

里程碑 1 只改动画等待链路，先验证协程 Runner 可用。

    重写 `src/game/turn/TurnRoll.lua` 与 `src/game/turn/TurnMove.lua` 的等待动画路径为 await 调用。
    保持动作事件名不变：move_anim_done、action_anim_done。

执行回归并确认通过。

    在仓库根目录运行：lua .agents/tests/regression.lua
    预期输出片段：All regression checks passed (35)

里程碑 2 切换完整主链路并清理旧协议。

    迁移 `src/game/turn/TurnStart.lua`、`src/game/turn/TurnLand.lua`、`src/game/turn/ItemPhase.lua`、`src/game/turn/EffectPipeline.lua` 的等待逻辑。
    删除回合主链路里的 waiting/resume_state/resume_args 返回协议。
    清理 `src/game/turn/TurnFlow.lua` 与 `src/game/flow/Flow.lua` 的运行时耦合。

再次运行回归并做手工流程验证。

    在仓库根目录运行：lua .agents/tests/regression.lua


## 验证与验收


回归验证：在仓库根目录运行 lua .agents/tests/regression.lua，预期输出 All regression checks passed (35)。

新增与重点验收场景包括：动画 seq 匹配才恢复，旧 seq 事件被忽略；选择 choice_id 不匹配时不恢复协程；自动托管开启时等待态不出现重入或重复推进；steal_interrupt、market_interrupt、landing_optional_effect 链路行为与改造前一致；协程内部异常可被记录并安全重置，不会卡死回合。


## 可重复性与恢复


该改造可分里程碑重复执行。每个里程碑结束必须跑回归。若中途失败，优先回退注入点，恢复旧 TurnFlow 绑定以保证主流程可运行，再逐步重做对应里程碑。所有步骤保持增量、可回滚，不做与协程改造无关的优化。


## 产物与备注


新增文件：`src/game/turn/TurnCoroutineRunner.lua`、`src/game/turn/TurnAwait.lua`。修改文件：`src/game/CompositionRoot.lua`、`src/game/Game.lua`、`src/game/turn/TurnStart.lua`、`src/game/turn/TurnRoll.lua`、`src/game/turn/TurnMove.lua`、`src/game/turn/TurnLand.lua`、`src/game/turn/ItemPhase.lua`、`src/game/turn/EffectPipeline.lua`。必要时清理：`src/game/turn/TurnFlow.lua` 与其调用关系。关键验收证据保留为短日志片段与测试通过输出。


## 接口与依赖


对外接口保持不变：`src/game/Game.lua` 的 advance_turn() 与 dispatch_action(action)。内部接口新增并固定：TurnCoroutineRunner:run_turn()、TurnCoroutineRunner:dispatch(action)、TurnCoroutineRunner:resume_if_match(action)、TurnAwait.await_choice(...)、TurnAwait.await_move_anim(...)、TurnAwait.await_action_anim(...)。内部协议变更为协程 yield(await_desc) 并由 Runner 恢复。动作事件 schema 与名称不变（确保 UI/事件层无感）。依赖不新增外部库，仅使用 Lua 协程与现有 SetTimeOut/事件分发机制。


修改说明：本次整理排版，按 `.agents/PLANS.md` 统一结构与格式，补足标题间距、段落组织与术语解释，确保计划可独立执行与可验证。
