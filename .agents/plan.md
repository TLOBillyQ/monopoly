# 计划：全研究项并行治理与计划重建

**Summary**
- 用这份计划完整替换 `.agents/plan.md:1`，并按 `.agents/harness/PLANS.md:1` 维护成活文档；新文档必须自带“进度 / 意外与发现 / 决策日志 / 结果与复盘”四章。
- 范围覆盖 `.agents/research.md:1` 的四类工作：CRAP 热点降险、重复代码收敛、仅限已证实零消费者的安全清理、架构边界整改。
- 默认策略是“先补行为护栏，再做小步重构，再做结构迁移”；不引入新依赖，不做跨任务混合重构，不在 `src/` 保留兼容 shim。
- 已确认的 repo 真相要先写回计划：`src/config/gameplay/vehicle_catalog.lua:1`、`src/infrastructure/runtime/global_aliases.lua:1`、`src/player/actions/state_ops/status_ops.lua:9` 仍有消费者，不进入首轮死代码删除。

**接口变化**
- `src.app.bootstrap` 从副作用入口改为显式 `init()`；最终宿主入口切到 `src/presentation/runtime/install.lua:1`，`main.lua:1` 只负责调用 presentation 入口。
- `src/config/gameplay/rules.lua:1` 在同一波迁移中拆分并删除；消费者直接改用 `src/config/gameplay/debug_flags.lua:1`、`src/config/gameplay/timing.lua:1`、`src/config/gameplay/board_geometry.lua:1`、`src/config/gameplay/target_pick.lua:1`、`src/config/gameplay/item_ids.lua:1`。
- `src/ui/runtime/landing_visual_hold.lua:1` 保留为 presentation 唯一可见 seam；`landing_visual_hold` 的真实状态只保留一个来源。

**任务与依赖**
- `T0` `[depends_on: []]` 基线与计划重写 —— `.agents/plan.md:1`、`.agents/research.md:1`、`tmp/crap_report.json`；重写计划骨架，记录 baseline 命令结果，并把 CRAP top 热点“函数名 + 分数 + 文件”原样抄入计划；验证：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check`、`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 全部入档。
- `T1` `[depends_on: [T0]]` 道具可用性热点 —— `src/rules/items/availability.lua:1`、`tests/suites/domain/item_availability_matrix.lua:1`；只治理 `_can_offer_rent_response` / `trigger_timing_allowed`，补 rent-response 分支与余额边界测试；验证：目标 suite、`lua tests/behavior.lua`，并记录这两个函数的新 CRAP 分数。
- `T2` `[depends_on: [T0]]` preconsume + item phase 热点 —— `src/core/choice/item_preconsume_policy.lua:1`、`src/rules/items/phase.lua:1`、`tests/suites/gameplay/gameplay_t2_characterization.lua:2033`；把 cancel 禁用、meta 初始化、resume args 构造拆成单职责 helper，不改选择流转语义；验证：相关 characterization、`tests/suites/domain/item.lua:1`、`tests/suites/gameplay/gameplay_items_startup.lua:1`。
- `T3` `[depends_on: [T0]]` runtime context 热点 —— `src/host/eggy/context.lua:1`、`tests/suites/runtime/misc.lua:330`、`tests/suites/runtime/runtime_ports_contract.lua:1`；隔离 provider roles、GameAPI fallback、`get_role` 容错，保持 release/noop helper 行为不变；验证：misc + runtime ports contract。
- `T4` `[depends_on: [T0]]` presentation 热点 —— `src/ui/render/anim_units.lua:1`、`src/ui/ctl/event_handlers.lua:1`、`src/ui/ctl/ui_runtime.lua:1`；分别治理 `play_mine_trigger`、`_resolve_tile_index`、turn label 匿名闭包命名化，先补护栏再提炼 helper；验证：`tests/suites/presentation/presentation_action_anim_effect_routes.lua:386`、`tests/suites/presentation/presentation_ui_event_handlers.lua:1`、相关 presentation suite。
- `T5` `[depends_on: [T0]]` validator + backward board 热点 —— `src/turn/actions/validator.lua:1`、`src/rules/board/init.lua:1`、`tests/suites/presentation/ui_runtime_state_contract.lua:85`、`tests/suites/domain/movement.lua:599`；把 item slot 校验链与 backward 选路链拆成中间结果函数；验证：对应 contract/domain suite。
- `T6` `[depends_on: [T0]]` AI 远程骰子热点 —— `src/computer/policies/core_agent.lua:1`、`tests/suites/domain/land.lua:135`；把 `_remote_priority` 拆成 tile-type / land 子规则，保证排序语义不变；验证：domain land suite 与 CRAP 分数下降。
- `T7` `[depends_on: [T0]]` ring map + test profile 热点 —— `src/config/content/maps/ring_map_builder.lua:1`、`src/config/testing/test_profiles.lua:1`、`tests/suites/gameplay/gameplay_t4_characterization.lua:1041`、`tests/suites/runtime/startup_profile.lua:159`；以补覆盖为主，只做最小意图拆分；验证：ring map characterization + startup profile suite。
- `T8` `[depends_on: [T2]]` choice 迭代 / cancel helper 合并 —— `src/core/choice/resolver.lua:1`、`src/core/choice/item_preconsume_policy.lua:1`；抽共享 `_each_option` 与 cancel 判定 helper，迁移 resolver 与 preconsume；验证：gameplay T2 characterization + choice 相关 contract。
- `T9` `[depends_on: [T1, T2]]` copy / normalize / contains helper 合并 —— `src/rules/bootstrap/choice_optional_effect_handler.lua:1`、`src/rules/items/choice_handlers.lua:1`、`src/rules/market/choice_handlers.lua:1`、`src/rules/items/phase.lua:1`、`src/rules/items/availability.lua:1`、`src/rules/market/choice/builder.lua:1`；只合并“同因变化”的表复制、整数归一化、包含判断；验证：受影响的 gameplay/domain suite 全绿。
- `T10` `[depends_on: [T0]]` 骰子倍率 helper 合并 —— `src/turn/phases/roll.lua:1`、`src/turn/phases/move.lua:1`；提取统一倍率逻辑到 `src/turn/phases/` 内共享模块；验证：相关 gameplay turn flow suite。
- `T11` `[depends_on: [T5]]` 方向表共享 —— `src/rules/board/init.lua:1`、`src/rules/items/post_effects.lua:285`；抽单一方向映射常量，保持 backward / post effects 语义不变；验证：movement + item/domain 回归。
- `T12` `[depends_on: [T0]]` `_with_client_role` 去重 —— `src/presentation/runtime/ports/debug.lua:1`、`src/ui/ctl/market.lua:1`、`src/ui/ctl/popup.lua:1`、`src/ui/wid/turn_effects.lua:1`；抽 presentation 共享 helper，不混入 turn wait；验证：presentation suites。
- `T13` `[depends_on: [T0]]` `_log_once` 去重 —— `src/turn/waits/ui_sync.lua:1`、`src/turn/waits/choice_timeout.lua:1`；抽 wait 层共享 helper；验证：wait 相关 behavior/contract suite。
- `T14` `[depends_on: [T0]]` 安全清理第一批 —— `src/config/content/skins.lua:1`、`src/config/gameplay/feature_toggles.lua:1`、`src/turn/output/state_adapter.lua:100`、`src/turn/loop/ports.lua:199`；只删零消费者或空实现；runtime refs 先审计后删，不先假定 orphan key 可删；验证：每删一波立即跑 `lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check`。
- `T15` `[depends_on: [T0]]` rules 层宿主解耦 —— `src/rules/land/effects/chance.lua:1`、`src/app/bootstrap/compose_game.lua:1`、`tests/suites/domain/chance.lua:1`、`tests/suites/runtime/runtime_ports_contract.lua:1`、`tests/suites/architecture/usecase_boundary_contract.lua:1`；把 `LuaAPI.rand()` 改成现有注入 RNG（优先 `ctx.game.rng:next_int(...)`），补确定性测试，禁止 rules 直读宿主全局；验证：chance/domain + runtime ports + usecase boundary。
- `T16` `[depends_on: [T0]]` game state 组装保护 —— `src/state/game_state.lua:1`；为 mixin 合并加 collision assert，并新增“重复 key 组装失败”负向测试；验证：现有 game assemble 正常、专门负测失败信息可读。
- `T17` `[depends_on: [T0]]` bootstrap 显式化兼容阶段 —— `src/app/bootstrap/init.lua:1`、`main.lua:1`、`tests/suites/runtime/startup_profile.lua:430`；先把 app bootstrap 改为显式 `init()`，确保 `require("src.app.bootstrap")` 不自动执行，同时保住当前启动路径；验证：startup profile suite 新增“显式 init 只执行一次 / require 不自启动”。
- `T18` `[depends_on: [T17]]` 入口反转切换 —— `src/presentation/runtime/install.lua:1`、`main.lua:1`、`tools/ops/deploy.ps1:416`；新建 presentation-owned 入口，main 改为 require 新入口，部署脚本和 repo 内启动引用一起切换；验证：main 启动、deploy 打包路径、runtime 启动测试全部通过。
- `T19` `[depends_on: [T1, T2, T4, T5, T6, T7, T12, T15, T16, T18]]` gameplay rules 拆分 —— `src/config/gameplay/rules.lua:1`；按五个模块一次性迁移所有消费者，删旧聚合文件，不留 shim；先用 `rg 'src.config.gameplay.rules' src tests` 生成迁移清单，再在同一波完成替换；验证：清单归零，`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check`、`lua tests/behavior.lua` 通过。
- `T20` `[depends_on: [T0]]` landing visual hold 原型门 —— `src/state/state_access/landing_visual_hold.lua:1`、`src/ui/runtime/landing_visual_hold.lua:1`；先盘点所有 caller：`src/turn/waits/await.lua:1`、`src/turn/loop/tick_flow.lua:1`、`src/turn/loop/tick_steps.lua:1`、`src/turn/phases/land.lua:1`、`src/turn/phases/move_followup.lua:1`、`src/presentation/runtime/event_bridge.lua:1`、`src/ui/ctl/event_handlers.lua:1`、`src/ui/runtime/landing_visual_hold.lua:1`，再用 characterization tests 固定“单一状态源”目标行为与 release 顺序；验证：`tests/suites/runtime/misc_landing_visual_hold.lua:23`、`:78`，以及相关 gameplay/presentation hold tests。
- `T21` `[depends_on: [T20]]` hold 单一状态源迁移 —— `src/state/state_access/landing_visual_hold.lua:1`、`src/state/state_access/runtime_state.lua:163`；把 hold/release 真相收敛到一个状态源，先完成底层读写迁移，不做 caller 清理；验证：新增“无双写漂移”测试 + 原有 misc_landing_visual_hold 顺序测试。
- `T22` `[depends_on: [T4, T18, T19, T21]]` hold caller 切换与清理 —— `src/turn/loop/tick_flow.lua:1`、`src/turn/loop/tick_steps.lua:1`、`src/turn/phases/land.lua:1`、`src/presentation/runtime/event_bridge.lua:1`、`src/ui/ctl/event_handlers.lua:1`；统一 callers 到新单源，再删旧双源同步逻辑；验证：runtime/presentation/gameplay 全部 hold 相关 suite。
- `T23` `[depends_on: [T3, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T18, T19, T22]]` 最终质量收口 —— `.agents/plan.md:1`、`tmp/crap_report.json`；重跑 baseline 五条命令，核对 T0 记录的 CRAP 热点分数逐项下降，arch/guard 不回退，并把证据、偏差、剩余风险写回计划文档。

**并行波次**
- **Wave 0**：`T0`
- **Wave 1**：`T1 T2 T3 T4 T5 T6 T7 T12 T13 T14 T15 T16 T17 T20`
- **Wave 2**：`T8 T9 T10 T11 T18 T21`
- **Wave 3**：`T19 T22`
- **Wave 4**：`T23`

**测试计划**
- 每个热点任务先跑对应目标 suite，再补 `lua tests/behavior.lua`；只有确认行为锁住后才继续共享 helper 合并。
- 每个删除 / 配置迁移 / 架构边界任务都必须至少跑 `lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check`；不要等到最后一波才发现越界。
- bootstrap 任务必须额外验证 `main.lua:1`、`tests/suites/runtime/startup_profile.lua:430`、`tools/ops/deploy.ps1:416`。
- landing visual hold 任务必须同时验证“无双源漂移”和“release callback 顺序不变”，以 `tests/suites/runtime/misc_landing_visual_hold.lua:78` 为硬护栏。
- 最终验收必须包含 baseline 五条命令重跑，并把 T0 的 CRAP 基线和 T23 的结果并排写进 `.agents/plan.md:1`。

**Assumptions**
- 不需要新三方库，也不需要额外外部文档；全部工作基于仓内 Lua 代码、现有 runtime ports、现有测试/质量工具完成。
- `vehicle_catalog.lua`、全局别名桥、`set_player_seat` 本轮默认保留；只有未来新增“迁移其消费者”的明确任务时才允许删除。
- `src/config/gameplay/rules.lua:1` 不能长期保留兼容层；拆分任务必须“一次迁完再删旧文件”。
- bootstrap 入口允许切换；最终以 presentation 入口为唯一宿主启动点。
