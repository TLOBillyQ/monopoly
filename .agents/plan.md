│ src/ 下兼容层、转发壳清理计划                                                                                          │
│                                                                                                                        │
│ Context                                                                                                                │
│                                                                                                                        │
│ 这次要做的不是继续大范围迁移目录，而是收掉迁移后残留在 src/ 里的兼容层与转发壳，让仓库进一步回到 new-only 模块路径。   │
│                                                                                                                        │
│ 结合现有代码与最近提交，仓库已经完成了大部分模块重命名与 shim 清理，当前剩下的主要是两类内容：                         │
│                                                                                                                        │
│ 1. 纯路径兼容壳：文件本体只有 return require("...")，或等价的一层转发。                                                │
│ 2. 行为兼容适配：虽然也在“兼容层”目录里，但仍保留代理、全局注入、回调形态兼容、命名映射等行为。                        │
│                                                                                                                        │
│ 本次建议只处理第 1 类，明确不碰第 2 类。这样可以复用仓库已有的“先切调用点，再删桥，再补                                │
│ guard”的模式，避免把路径清理和行为变更绑在一起。                                                                       │
│                                                                                                                        │
│ Recommended Scope                                                                                                      │
│                                                                                                                        │
│ 本次纳入                                                                                                               │
│                                                                                                                        │
│ - src/turn/output/* 中的纯转发壳                                                                                       │
│ - src/rules/choices/* -> src/player/choices/*                                                                          │
│ - src/state/player_state_ops/* -> src/player/actions/state_ops/*                                                       │
│ - src/state/support/* -> src/core/utils/*                                                                              │
│ - src/core/state_access/* -> src/state/state_access/*                                                                  │
│ - src/host/eggy/support/* 中的纯转发壳                                                                                 │
│ - 单文件别名：                                                                                                         │
│   - src/state/compose_game.lua -> src/entry/compose_game                                                               │
│   - src/state/game_victory.lua -> src/rules/endgame/game_victory                                                       │
│   - src/computer/policies/agent.lua -> src/computer/policies/core_agent                                                │
│                                                                                                                        │
│ 本次明确排除                                                                                                           │
│                                                                                                                        │
│ 以下文件虽然属于“兼容层/支持层”，但不是纯路径壳，先不在这轮删除：                                                      │
│                                                                                                                        │
│ - src/host/eggy/support/market_context.lua（metatable 代理）                                                           │
│ - src/entry/runtime_globals.lua（运行时全局注入）                                                                      │
│ - src/ui/render/support/ui_aliases.lua（英文 ID -> 中文 UI 名映射）                                                    │
│ - src/turn/phases/land.lua 中的 backward-compatible callable 行为                                                      │
│                                                                                                                        │
│ Existing Code To Reuse                                                                                                 │
│                                                                                                                        │
│ - src/player/choices/*：rules/choices/* 的 canonical 实现                                                              │
│ - src/player/actions/state_ops/*：state/player_state_ops/* 的 canonical 实现                                           │
│ - src/state/state_access/*：core/state_access/* 的 canonical 实现                                                      │
│ - src/core/utils/logger.lua、src/core/utils/number_utils.lua：state/support/* 的 canonical 实现                        │
│ - tests/guards/dep_rules.lua：已有大量“退休路径禁止再被引用”的 guard 模式，可直接照现有 pattern 扩充                   │
│ - scripts/quality/arch/config.json：用于确认改直连后没有引入新的跨层依赖                                               │
│ - tests/catalog.lua、docs/architecture/quality_map.md：用于确认测试车道与质量入口说明是否仍准确                        │
│                                                                                                                        │
│ Critical Files                                                                                                         │
│                                                                                                                        │
│ Phase 1: 改源码调用点                                                                                                  │
│                                                                                                                        │
│ - src/rules/bootstrap/registries.lua                                                                                   ││ - src/state/player_state.lua                                                                                           │
│ - src/state/game_state.lua                                                                                             ││ - src/host/eggy/context.lua                                                                                            │
│ - src/host/eggy/synthetic_actor_registry.lua                                                                           ││ - src/host/eggy/sound.lua                                                                                              │
│ - src/turn/output/auto_play_port_adapter.lua                                                                           ││                                                                                                                        │
│ Phase 2: 改测试调用点                                                                                                  ││                                                                                                                        │
│ - tests/suites/gameplay/gameplay_coroutine.lua                                                                         ││ - tests/suites/gameplay/gameplay_cases.lua                                                                             ││ - 以及 repo 内其余仍引用上述 shim 模块族的 tests/**                                                                    ││                                                                                                                        │
│ Phase 3: 删纯转发壳                                                                                                    │
│                                                                                                                        │
│ - src/rules/choices/**                                                                                                 │
│ - src/state/player_state_ops/**                                                                                        │
│ - src/state/support/**                                                                                                 │
│ - src/core/state_access/**                                                                                             │
│ - src/host/eggy/support/** 中的纯转发文件                                                                              │
│ - src/turn/output/** 中的纯转发文件                                                                                    │
│ - src/state/compose_game.lua                                                                                           │
│ - src/state/game_victory.lua                                                                                           │
│ - src/computer/policies/agent.lua                                                                                      │
│                                                                                                                        │
│ Phase 4: 补护栏与收尾                                                                                                  │
│                                                                                                                        │
│ - tests/guards/dep_rules.lua                                                                                           │
│ - scripts/quality/arch/config.json（仅当桥接分类规则需要收窄时修改）                                                   │
│ - docs/architecture/quality_map.md（仅当文档仍提到本轮已退休 shim 时修改）                                             │
│                                                                                                                        │
│ Task Plan                                                                                                              │
│                                                                                                                        │
│ T1: 盘点并确认纯转发壳名单                                                                                             │
│                                                                                                                        │
│ - depends_on: []                                                                                                       │
│ - 逐个复核候选文件，确认文件本体只有路径转发，不含行为适配。                                                           │
│ - 特别对 src/host/eggy/support/** 做逐文件筛选，不整目录粗暴删除。                                                     │
│ - 产出“shim -> canonical 模块”的最终清单，作为后续机械替换依据。                                                       │
│                                                                                                                        │
│ T2: 切掉源码中的 shim 调用                                                                                             │
│                                                                                                                        │
│ - depends_on: [T1]                                                                                                     │
│ - 将已知仍使用旧路径的核心源码全部改到 canonical 模块：                                                                │
│   - src/rules/bootstrap/registries.lua -> src.player.choices.*                                                         │
│   - src/state/player_state.lua -> src.player.actions.state_ops.*                                                       │
│   - src/state/game_state.lua -> src.entry.compose_game、src.rules.endgame.game_victory                                 │
│   - src/host/eggy/context.lua / synthetic_actor_registry.lua / sound.lua ->                                            │
│ src.config.*、src.state.state_access.*、src.rules.*                                                                    │
│   - src/turn/output/auto_play_port_adapter.lua -> src.computer.policies.core_agent                                     │
│ - 目标是先让 src/** 内不再依赖这批 shim。                                                                              │
│                                                                                                                        │
│ T3: 切掉测试中的 shim 调用                                                                                             │
│                                                                                                                        │
│ - depends_on: [T2]                                                                                                     │
│ - 将 tests/** 中仍引用旧 shim 模块的用例全部改到 canonical 模块。                                                      │
│ - 已知重点：tests/suites/gameplay/gameplay_coroutine.lua、tests/suites/gameplay/gameplay_cases.lua。                   │
│ - 需要做一次 repo 级搜索，确保不是只改已知文件。                                                                       │
│                                                                                                                        │
│ T4: 分批删除纯转发壳                                                                                                   │
│                                                                                                                        │
│ - depends_on: [T3]                                                                                                     │
│ - 按低风险到高风险顺序删桥，避免一次性大删后难以定位：                                                                 │
│   a. src/rules/choices/**                                                                                              │
│   b. src/state/player_state_ops/**                                                                                     │
│   c. src/state/compose_game.lua、src/state/game_victory.lua、src/computer/policies/agent.lua                           │
│   d. src/core/state_access/**                                                                                          │
│   e. src/state/support/**                                                                                              │
│   f. src/host/eggy/support/** 中确认无行为的文件                                                                       │
│   g. src/turn/output/** 中纯转发文件                                                                                   │
│ - 每删完一批就做快速验证，确保问题定位清晰。                                                                           │
│                                                                                                                        │
│ T5: 补 retired-path guard，锁死回归口                                                                                  │
│                                                                                                                        │
│ - depends_on: [T4]                                                                                                     │
│ - 在 tests/guards/dep_rules.lua 中新增对已退休 shim 模块族的 require(...) 禁令。                                       │
│ - 对明确不应再出现的稳定路径，按需加入 forbidden_files。                                                               │
│ - 若 scripts/quality/arch/config.json 里仍保留只为桥接存在的特殊分类，再同步收窄。                                     │
│                                                                                                                        │
│ T6: 文档与最终验收                                                                                                     │
│                                                                                                                        │
│ - depends_on: [T5]                                                                                                     │
│ - 检查 docs/architecture/quality_map.md、tests/catalog.lua 是否仍残留本轮已删桥接的描述；仅在确有过期内容时更新。      │
│ - 做 repo 级旧路径检索，确认 src/、tests/、scripts/ 中不再引用这些 shim 模块族。                                       │
│                                                                                                                        │
│ Parallel Execution Groups                                                                                              │
│                                                                                                                        │
│ ┌──────┬───────┬────────────────┐                                                                                      │
│ │ Wave │ Tasks │ Can Start When │                                                                                      │
│ ├──────┼───────┼────────────────┤                                                                                      │
│ │ 1    │ T1    │ Immediately    │                                                                                      │
│ ├──────┼───────┼────────────────┤                                                                                      │
│ │ 2    │ T2    │ T1 complete    │                                                                                      │
│ ├──────┼───────┼────────────────┤                                                                                      │
│ │ 3    │ T3    │ T2 complete    │                                                                                      │
│ ├──────┼───────┼────────────────┤                                                                                      │
│ │ 4    │ T4    │ T3 complete    │                                                                                      │
│ ├──────┼───────┼────────────────┤                                                                                      │
│ │ 5    │ T5    │ T4 complete    │                                                                                      │
│ ├──────┼───────┼────────────────┤                                                                                      │
│ │ 6    │ T6    │ T5 complete    │                                                                                      │
│ └──────┴───────┴────────────────┘                                                                                      │
│                                                                                                                        │
│ Risks And Mitigations                                                                                                  │
│                                                                                                                        │
│ - src/host/eggy/support/** 混有真实适配逻辑，风险最高；必须逐文件确认，不能目录级删除。                                │
│ - src/turn/output/** 现在更多是测试侧在用；必须先改测试，再删文件，否则只会得到一堆缺模块错误，掩盖真实问题。          │
│ - src/state/game_state.lua 与 src/state/player_state.lua 是装配枢纽，改错会放大影响；优先在这两处完成 canonical        │
│ 切换，再做删除。                                                                                                       │
│ - src/core/state_access/** 看起来近乎死亡，但仍需对 tests/**、scripts/** 额外搜一次，避免遗漏仓库边缘调用点。          │
│ - Guard 不要提前加；顺序应是“改调用点 -> 删 bridge -> 加 retired-path 禁令”，否则中途会被新护栏阻塞。                  │
│ - 本轮不混入行为兼容层清理，避免出现“路径变更失败”与“行为变化失败”难以区分的问题。                                     │
│                                                                                                                        │
│ Verification                                                                                                           │
│                                                                                                                        │
│ 分批快速验证                                                                                                           │
│                                                                                                                        │
│ 每完成一批调用点切换或删桥，先跑：                                                                                     │
│                                                                                                                        │
│ - lua tests/guard.lua                                                                                                  │
│ - lua scripts/quality/arch.lua check                                                                                   │
│                                                                                                                        │
│ 完整功能验证                                                                                                           │
│                                                                                                                        │
│ 全部删除完成后跑：                                                                                                     │
│                                                                                                                        │
│ - lua tests/contract.lua                                                                                               │
│ - lua tests/behavior.lua                                                                                               │
│ - lua tests/regression.lua                                                                                             │
│                                                                                                                        │
│ 额外检查                                                                                                               │
│                                                                                                                        │
│ - 对本轮退休模块族做 repo 级搜索，确认 src/**、tests/**、scripts/** 不再有 require(old_module)。                       │
│ - 若本轮修改碰到质量工具或 viewer 说明，再补看 lua tests/tooling.lua --workers 1。                                     │
│                                                                                                                        │
│ Done Criteria                                                                                                          │
│                                                                                                                        │
│ - 本轮纳入的纯路径 shim 在 src/ 中全部删除。                                                                           │
│ - src/** 与 tests/** 均已改用 canonical 模块路径。                                                                     │
│ - tests/guards/dep_rules.lua 已禁止这些退休 shim 路径重新出现。                                                        │
│ - lua tests/guard.lua、lua scripts/quality/arch.lua check、lua tests/contract.lua、lua tests/behavior.lua、lua         │
│ tests/regression.lua 全绿。                                                                                            │
│ - 行为兼容层仍保持不动，并作为后续独立任务处理。
│                                                                                                                        │
│ Execution Log                                                                                                          │
│                                                                                                                        │
│ - [x] 2026-03-17 22:01 +0800 T1 完成：逐文件复核候选 shim，确认可删除纯转发壳共 32 个。                               │
│   - rules/choices 4 个；state/player_state_ops 5 个；state/support 2 个；core/state_access 4 个。                    │
│   - host/eggy/support 仅 runtime_constants/runtime_editor_exports/runtime_refs/vehicle 可删；                           │
│     market_context 保留，因为它通过 metatable 代理读写，不是纯路径壳。                                                 │
│   - turn/output 仅 decision/logger/loop_runtime/ports/scheduler_runtime/session_script/tick_flow/tick_steps 可删；     │
│     其余 output 文件是适配器或真实逻辑，不纳入本轮。                                                                   │
│   - 单文件别名 compose_game/game_victory/agent 均为纯转发。                                                            │
│   - 关键残留调用点已确认：src/rules/bootstrap/registries.lua、src/state/player_state.lua、                            │
│     src/state/game_state.lua、src/state/state_access/*、src/host/eggy/*、                                             │
│     src/turn/output/auto_play_port_adapter.lua、tests/suites/gameplay/*、tests/suites/domain/land.lua。               │
