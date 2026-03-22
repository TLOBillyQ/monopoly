# Plan: 新事件系统硬切 + 全仓兼容/遗留代码清理

## Summary
- 目标是**直接切到新系统**：只保留 `game_event` / `notice_intent` / `log_entry` / `diagnostic_entry` 这套正交模型，不保留任何兼容入口、旧命名、旧桥接、旧开关。
- 范围覆盖**产品运行时、UI、宿主桥接、bootstrap、tests、guards、tools/ops、对外帮助文案与 contract**。
- 明确不清理两类内容：一是**正常鲁棒性 fallback**（如时钟、寻路、数值默认值）；二是宿主 seam `src/infrastructure/runtime/global_aliases.lua` 这种**非业务兼容层**。

## Public API / Contract Changes
- 删除 `logger.event`、`logger.event_no_tips`、`logger.show_tip`、`logger.has_pending_tips`、`logger.set_event_collection_enabled_provider`。
- 删除 `game_event_port.publish_legacy_text`、`legacy.log`、`legacy.notice`。
- 删除 `show_tips` 作为**业务反馈入口**；toast 只经 `notice_dispatcher` / `feedback_policy`。
- 删除 `monopoly_event.*` / `monopoly_events.*` 作为玩家日志或玩家反馈语义层。
- 删除 runtime / deploy / tooling 中所有 `legacy` 运行模式、历史别名、兼容输入；只保留 canonical 命名与严格接口。

## Tasks

### T1a: 冻结新事件契约
- **depends_on**: `[]`
- **location**: `src/core/events/*`, `src/core/utils/logger.lua`
- **description**: 先锁定 canonical `game_event` taxonomy、payload、audience、importance、projector/policy 边界；迁移阶段禁止再新增任何 text-first 或 shim 式接口。
- **validation**: 后续任务全部只面向结构化事件契约，不再引入新的过渡 API。

### T2: 迁移 gameplay / use case 发射点
- **depends_on**: `[T1a]`
- **location**: `src/player/**`, `src/rules/**`, `src/turn/**`, `src/rules/endgame/**`
- **description**: 把所有 `publish_legacy_text` 和规则层拼文案替换成结构化 `game_event_port.publish(...)`；规则层只发事实，不产 toast 文案、日志文案。
- **validation**: gameplay/rules/turn 层不再直接拼玩家展示文本；旧文本事件调用为 0。

### T3a: 切换 UI / runtime 反馈链路
- **depends_on**: `[T1a]`
- **location**: `src/ui/ctl/event_handlers.lua`, `src/ui/ctl/event_bindings.lua`, `src/ui/ctl/canvas_event_router.lua`, `src/ui/input/dispatch_item_phase_ask.lua`, `src/ui/runtime/host_bridge.lua`, `src/ui/render/action_anim.lua`, `src/host/eggy/init.lua`
- **description**: 去掉 `show_tips` / `monopoly_event.*` 驱动的业务流；UI 只消费 `notice_dispatcher` 和 action-log 投影结果；本地异常只走 `diagnostic_entry`。
- **validation**: UI/runtime 不再依赖旧自定义事件名或 `GlobalAPI.show_tips` 作为业务主通道。

### T3b: 切换组装层 / bootstrap / 注入点
- **depends_on**: `[T1a]`
- **location**: `src/app/bootstrap/init.lua`, `src/app/bootstrap/compose_game.lua`, `src/app/bootstrap/runtime_install.lua`, `src/presentation/runtime/ports/debug.lua`, `src/turn/output/intent_dispatcher.lua`
- **description**: 清理旧 logger/debug/event-collection wiring；把组装层改成只注入新 notice/log/diagnostic 链路，不再暴露 legacy flag 或兼容配置。
- **validation**: bootstrap/runtime install 不再出现 `enable_legacy_helper_fallback`、event collection provider、旧 logger 兼容注入。

### T1b: 删除 core shim 与兼容分支
- **depends_on**: `[T2, T3a, T3b]`
- **location**: `src/core/utils/logger.lua`, `src/core/events/game_event_port.lua`, `src/core/events/event_types.lua`, `src/core/events/feedback_policy.lua`, `src/core/events/action_log_projector.lua`, `src/core/events/monopoly_events.lua`
- **description**: 在上下游都切完后，再硬删 core 里的兼容 API、legacy event types、projector/policy special-case、旧 bridge 分支。
- **validation**: core 事件链只接受新模型；不存在 legacy symbol、legacy branch、legacy event type。

### T4a: 清理产品 runtime / host 的 legacy 命名与桥接
- **depends_on**: `[T3a, T3b]`
- **location**: `src/state/state_access/vehicle_runtime_source.lua`, `src/host/eggy/vehicle_runtime_legacy.lua`, 相关 runtime 注入路径
- **description**: 移除 `vehicle_runtime_legacy` 路径与 `legacy` 语义，改成 canonical host runtime 模块名；同步清理相关注释、启动注入与路径常量。
- **validation**: 运行时不再存在 `vehicle_runtime_legacy` 路径名或 legacy 模式选择。

### T4b: 清理 tools / ops / 历史别名
- **depends_on**: `[]`
- **location**: `tools/ops/deploy.ps1`, `tools/shared/package_path_helper.lua`, `tools/quality/scrap/config.lua`, 相关 tool contract / help text
- **description**: 删除 deploy 的 `legacy` 选项与文案，删除 package-path compatibility patterns，删除质量工具 historical alias 扩展与对外说明。
- **validation**: 工具链不再接受 legacy 输入，也不再声明历史别名或兼容路径。
- **status**: completed
- **work_log**: 删除了 `package_path_helper` 里的 `vendor/arch_view` 兼容注入，改由 `tests/bootstrap.lua` 和 `tools/shared/bootstrap.lua` 显式加回所需路径；清空 `tools/quality/scrap/config.lua` 的历史搜索别名；更新 `docs/architecture/scrap4lua.md` 与相关契约测试，确认 `deploy.ps1` 不再暴露 `vehicle-runtime` 入口。
- **files_changed**: `tools/shared/package_path_helper.lua`, `tools/shared/bootstrap.lua`, `tests/bootstrap.lua`, `tools/quality/crap.lua`, `tools/quality/scrap/config.lua`, `docs/architecture/scrap4lua.md`, `tests/suites/architecture/crap_contract.lua`, `tests/suites/architecture/scrap4lua_contract.lua`, `tests/suites/architecture/script_tools_contract.lua`
- **gotchas**: `arch_view` 运行时代码仍需要 `vendor/arch_view` 的 Lua 路径，所以兼容注入不能直接删到运行入口；必须先从 helper 移走，再在 bootstrap 入口显式补回。

### T5: 重写 tests / guards / support contract
- **depends_on**: `[T1b, T4a, T4b]`
- **location**: `tests/support/shared_support.lua`, `tests/support/test_env.lua`, `tests/guards/dep_rules.lua`, `tests/suites/runtime/**`, `tests/suites/presentation/**`, `tests/suites/gameplay/**`, `tests/suites/architecture/**`
- **description**: 去掉对旧 logger、旧 bridge、`show_tips`、legacy deploy/tooling 行为的断言；新增 guards 禁止已退休 symbol/path 重新出现。
- **validation**: guards 明确禁用 `logger.event*`、`logger.show_tip`、`publish_legacy_text`、`legacy.log`、`legacy.notice`、业务 `show_tips` 入口、`vehicle_runtime_legacy` 路径。

### T6: 分波验证与零引用扫描
- **depends_on**: `[T5]`
- **location**: `src`, `tests`, `tools`
- **description**: 先跑 targeted runtime/presentation/gameplay/tooling/architecture suites，再跑完整行为回归；最后做 `rg` 级 zero-reference 扫描，确认 retired symbol/path/help text 全部清零。
- **validation**: targeted suites 通过、完整行为回归通过、`src tests tools` 中 retired symbol/path 引用为 0。

## Parallel Execution Groups
| Wave | Tasks | Can Start When |
|---|---|---|
| 1 | `T1a`, `T4b` | 立即 |
| 2 | `T2`, `T3a`, `T3b` | `T1a` 完成 |
| 3 | `T1b`, `T4a` | `T2/T3a/T3b` 完成后分别满足依赖 |
| 4 | `T5` | `T1b`, `T4a`, `T4b` 完成 |
| 5 | `T6` | `T5` 完成 |

## Test Plan
- 规则层 / 用例层只发布结构化事件，不再拼 toast/log 文案。
- `game_event` 是否出 toast 只由 `feedback_policy` 决定；event log 不再隐式带提示。
- UI / 宿主本地错误只进 `diagnostic_entry`，不会污染 action log 或玩家 toast。
- 重大事件仍可同时产生 `log_entry` + 定向 `notice_intent`，且 `audience` 正确。
- debug panel 关闭时 action log 仍持续记录；UI 打开后可从投影状态恢复。
- `show_tips`、`monopoly_event.*`、`publish_legacy_text`、`legacy.*`、`vehicle_runtime_legacy`、deploy `legacy` 模式、historical alias 扩展全部为 0 引用。
- 工具 contract 更新后，帮助文案、错误文案、搜索别名说明不再对外暴露 legacy 入口。

## Assumptions
- 直接基于当前已存在的新事件 primitives 继续硬切，不回滚到旧系统，也不保留双写期。
- “清理所有兼容/遗留代码”包含**工具/运维历史项**，不只限于 gameplay 事件链路。
- 只删除“为兼容旧接口/旧命名/旧路径而存在”的 fallback / alias / shim；不删除正常业务容错。
- `src/infrastructure/runtime/global_aliases.lua` 保留为宿主 seam，不视为业务兼容层。
