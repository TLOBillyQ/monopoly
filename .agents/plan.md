# 修复 AFK 托管实机不生效

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。讨论、实施、暂停和重启都只依赖这份计划本身，不依赖聊天历史。

## 目的 / 全局视角

本次修复解决的是“AFK 托管逻辑代码存在，但实机长时间不操作仍然不会进入托管”的问题。用户真正关心的不是仓库里多了几个字段或测试，而是同一真人玩家连续多轮都不操作时，15 秒自动推进仍然可以保留，但累计约 90 秒后必须自动切到托管，并且托管按钮状态、后续 auto runner 行为与逻辑状态一致。

这次改动完成后，可观察结果是这样的：默认回归会实际覆盖 AFK 用例；普通可操作等待阶段不再只靠 `start` 或手工设的 `wait_choice` 才累计 AFK；系统 15 秒超时推进不会把 AFK 当成“玩家有输入”而清零；同一玩家跨回合连续无操作时，累计 90 秒后会被切到托管。自动化已经证明这一点，最终证据是 AFK 定向 suite 通过和全量 `lua tests/regression.lua` 通过。

## 进度

- [x] (2026-03-06 19:08+08:00) 已确认问题根因：AFK 专项测试未纳入默认回归；AFK 只跟踪 `start` / 部分 `wait_choice`；15 秒自动推进会把 90 秒 AFK 计时打断。
- [x] (2026-03-06 19:18+08:00) 已完成运行时修复：AFK 可累计状态改为复用共享等待判定，新增 `action.input_source` 区分玩家输入与系统 timeout。
- [x] (2026-03-06 19:26+08:00) 已完成 AFK 跨回合累计修复：同一玩家的 AFK 秒数改为按角色缓存，玩家切换时不继承他人时间，但会保留自己的累计值。
- [x] (2026-03-06 19:31+08:00) 已补测试与默认回归接线：新增 `tests/suites/gameplay_afk.lua`、补 3 条 AFK 缺失测试、补 1 条 runtime bootstrap 小 `dt` 测试，并接入 `tests/regression.lua`。
- [x] (2026-03-06 19:34+08:00) 已完成验证：`gameplay_afk + runtime_bootstrap` 通过 `All regression checks passed (17)`；`gameplay_loop` 通过 `All regression checks passed (26)`；全量 `lua tests/regression.lua` 通过 `All regression checks passed (357)`，并附带 `dep_rules ok`、`tick ok`、`forbidden_globals ok`。

## 意外与发现

2026-03-06 19:10+08:00：如果保留现有“玩家切换即清零”的 AFK 逻辑，那么在默认 `action_timeout_seconds = 15` 的前提下，真人玩家几乎不可能在普通回合路径累计到 `afk_auto_host_seconds = 90`。证据是当前 `next` 会直接推进回合，而回合推进后 `current_player_index` 改变；若还按旧逻辑清零，90 秒永远积不起来。

2026-03-06 19:14+08:00：单纯让 timeout `next` 不重置 AFK 仍然不够，必须把 AFK 秒数从“当前玩家单值”升级成“按角色缓存的累计值”，否则跨回合后仍会丢失。证据是定向复现里，玩家 1 每次等待 15 秒后就轮到玩家 2；只有把玩家 1 的累计值保存在 `turn_runtime.afk_elapsed_seconds_by_role` 里，下一轮玩家 1 回来时才可能继续从 15、30、45 秒往上累。

2026-03-06 19:18+08:00：`turn_runtime.afk_elapsed_seconds` 仍然被 UI 和测试当作“当前观察窗口”的镜像值使用，所以在引入按角色缓存后，不能只更新 map，不更新镜像字段。证据是第一次定向回归中，角色缓存已正确累加，但 `_test_afk_auto_host_enters_auto_after_timeout_in_start_phase` 仍然因镜像值保持 0 而失败；补同步后恢复通过。

2026-03-06 19:34+08:00：全量回归继续出现大量 `market paid goods mapping missing`、`ui_button blocked by actor check`、`board_feedback skip play_*` 等既有告警，但这批告警未引入新的失败。证据是 `lua tests/regression.lua` 最终输出 `All regression checks passed (357)`、`dep_rules ok`、`tick ok`、`forbidden_globals ok`。

## 决策日志

- 决策：不再让 AFK 只依赖 `GameplayLoop` 内部硬编码的 phase 判断，而是把“动作按钮等待态”抽到 `src/game/flow/turn/TurnTimerPolicy.lua` 暴露共享谓词。
  理由：action timeout 和 AFK 都是在判定“当前是不是玩家可操作但没输入的等待态”；复用一份谓词可以避免后续某一边修了，另一边继续漂移。
  日期/作者：2026-03-06 / Codex

- 决策：新增内部 action 元数据 `input_source = "user" | "timeout"`，并在 `TurnDispatch` 中把缺省值归一为 `"user"`。
  理由：AFK 需要区分“用户真的点了按钮”与“系统替用户点了 next”；这个区分只属于用例流内部协议，不需要改 UI 语义。
  日期/作者：2026-03-06 / Codex

- 决策：AFK 秒数采用 `turn_runtime.afk_elapsed_seconds_by_role` 按角色保存，同时保留 `afk_actor_role_id`、`afk_elapsed_seconds`、`afk_tracking_active` 作为当前观察视图。
  理由：需要让同一玩家跨回合继续累计，又不能让当前 UI / 旧测试失去“当前玩家 AFK 进度”的简单读取口。
  日期/作者：2026-03-06 / Codex

- 决策：AFK 默认回归采用新 suite `tests/suites/gameplay_afk.lua` 接入，而不是扩张 `gameplay.loop` 的 slice 范围。
  理由：现有 `gameplay.loop` 只覆盖 14-39 号测试，直接扩 slice 会把一串非 AFK 的后续测试也带进默认回归；新 suite 只引入 40-50 号 AFK 用例，影响面最小。
  日期/作者：2026-03-06 / Codex

## 结果与复盘

这次修复已经完成。仓库现在具备四层保障。第一层是行为修复：AFK 的“可累计状态”已经覆盖普通动作等待和选择等待，不再只认旧的 `start` / 局部 `wait_choice`。第二层是来源修复：系统 `timeout next` 会显式打上 `input_source = "timeout"`，因此不会再被误判为“玩家有输入”。第三层是状态修复：同一玩家的 AFK 秒数会跨回合保留，直到该玩家发生真实用户输入或已经被切到托管。第四层是守卫修复：AFK 测试现在已经进了默认回归，不再是仓库里“写了但默认不跑”的孤立用例。

自动化验证已经覆盖了这次改动最关键的场景。`gameplay_afk` 新增并通过了普通动作等待态累计、timeout `next` 不清零、跨回合累计到 90 秒切托管三类用例；`runtime_bootstrap` 新增了多次小 `dt` 的 wall clock diff 用例，避免时间链验证只靠一次大 `dt` 灌值；全量 `lua tests/regression.lua` 通过说明这次改动没有破坏既有玩法、UI、事件桥和表现层。

这次工作的经验教训很直接。第一，超时逻辑和 AFK 逻辑只要依赖的是同一种“等待态”，就应该共用谓词，不能各写一套。第二，默认回归不覆盖的测试，等于没有真正守住线上行为。第三，只在单轮当前玩家上记录 AFK，是一个在纯逻辑测试里容易通过、但在真实回合制产品里很容易失真的建模方式；只要 timeout 会推进回合，AFK 就必须按玩家维度累计。

## 背景与导读

这次修复只动了三块主链路。第一块是回合主循环，入口在 `src/game/flow/turn/GameplayLoop.lua`。这里每帧会先判 AFK，再跑 auto runner，再跑 choice timeout、popup timeout、action timeout 和 UI 刷新。第二块是超时策略，位于 `src/game/flow/turn/TurnTimerPolicy.lua`。这里定义了动作按钮 15 秒自动推进的等待条件，以及 timeout 到期时如何派发内部 `next`。第三块是 action 派发，位于 `src/game/flow/turn/TurnDispatch.lua`。这里决定按钮点击、choice 选择、黑市翻页等输入如何真正落到 game runtime 上，同时也是 AFK 是否清零的唯一可信位置。

AFK 原先失效的关键不是“没写超时托管”，而是这三块之间对“等待”和“输入”的定义不一致。`GameplayLoop` 过去只在 `start` 或带 UI 标志的 `wait_choice` 累计 AFK；`TurnTimerPolicy` 却会在更宽的普通等待阶段自动派发 `next`；`TurnDispatch` 又把这个 `next` 当成普通输入处理，直接把 AFK 计时清零。最终结果就是：纯逻辑单测能通过，但实机里普通玩家的 AFK 永远达不到 90 秒。

测试侧也有一个关键背景。`tests/suites/gameplay.lua` 里本来已经有 8 条 AFK 用例，但默认回归的 `tests/regression.lua` 只引用了 `tests/suites/gameplay_loop.lua`，它对应的是 `gameplay_registry.slice("gameplay.loop", 14, 39)`，没有覆盖 AFK 段。换句话说，仓库里原本确实“有 AFK 测试”，但默认入口根本没跑到。

## 工作计划

本次实施顺序是先改行为，再补守卫。先在 `TurnTimerPolicy` 中公开动作按钮等待态谓词，并新增 AFK 专用共享谓词，让 AFK 与 action timeout 对“玩家可等待”的理解收口到一处。再在 `TurnDispatch` 与 `GameplayLoopTickSteps` 之间引入 `input_source`，把系统派发的 timeout `next` 显式标记出来。之后在 `GameplayLoop` 中把 AFK 秒数升级为按角色缓存，同时保留当前观察视图，确保 UI 与旧测试仍能读到当前 AFK 状态。

行为改完后，再处理测试和默认回归。`tests/suites/gameplay.lua` 需要补三类新场景：普通动作等待态累计 AFK、timeout `next` 不清零、跨回合累计到托管。`tests/suites/runtime_bootstrap.lua` 需要补小 `dt` 连续 wall clock diff 用例。然后新建 `tests/suites/gameplay_afk.lua`，只切出 AFK 段，最后把它接到 `tests/regression.lua` 的默认 suites 列表里。

## 具体步骤

先跑 AFK 与时间链的定向回归，确保新的共享谓词、按角色累计和小 `dt` 测试都通过。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('gameplay_afk'), require('runtime_bootstrap') })"

预期输出是：

    All regression checks passed (17)

再跑 gameplay loop 相关 suite，确认新增的 `input_source` 和 AFK map 没破坏旧循环行为。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('gameplay_loop') })"

预期输出是：

    All regression checks passed (26)

最后跑默认回归入口，确认 `gameplay_afk` 已经被正式纳入。

    lua tests/regression.lua

预期输出是：

    All regression checks passed (357)
    dep_rules ok
    tick ok
    forbidden_globals ok

## 验证与验收

这次改动的验收标准不是“AFK 相关文件改了”，而是下面这些行为成立。第一，普通可操作等待阶段，例如 `roll` 这种没有弹窗、没有 choice、没有动画阻塞的阶段，必须能累计 AFK。第二，`wait_choice` 且 UI 确实处于 choice 或 market 激活时，仍然能累计 AFK。第三，玩家手动点击 `next`、手动选择选项、手动切换黑市 tab 时，AFK 必须清零。第四，15 秒 timeout 自动派发 `next` 时，AFK 不得清零。第五，同一玩家跨多轮都不操作时，累计值必须继续叠加，达到 90 秒后进入托管。第六，这些行为必须进入默认回归，而不是只在手工命令里才能跑到。

自动化已经证明上述标准成立。定向 `gameplay_afk` 覆盖了普通等待态、timeout `next`、跨回合累计；`runtime_bootstrap` 覆盖了多次小 `dt` 的时间链；全量回归则证明接线本身没有破坏旧模块。

## 可重复性与恢复

这次修复是可重复执行的。新增的 `input_source` 是内部兼容扩展，老的 action 不传该字段时会在 `TurnDispatch` 中自动归一为 `"user"`，因此不会因为旧测试、旧 UI intent 或旧 helper 没有同步更新而崩掉。AFK 的新角色缓存也保留了旧镜像字段，所以读取 `turn_runtime.afk_elapsed_seconds` 的代码不会失效。

如果后续需要回退，只要撤回本次对 `GameplayLoop.lua`、`TurnTimerPolicy.lua`、`TurnDispatch.lua`、`GameplayLoopTickSteps.lua`、`RuntimeState.lua` 的改动，并同步移除 `tests/suites/gameplay_afk.lua` 与 `tests/regression.lua` 中的 suite 注册即可。最重要的是不要只回退逻辑、不回退测试，否则默认回归会留下不一致状态。

## 产物与备注

本次产物集中在三类文件。第一类是运行时逻辑：`src/game/flow/turn/GameplayLoop.lua`、`src/game/flow/turn/TurnTimerPolicy.lua`、`src/game/flow/turn/TurnDispatch.lua`、`src/game/flow/turn/GameplayLoopTickSteps.lua`、`src/core/RuntimeState.lua`。第二类是测试与注册：`tests/suites/gameplay.lua`、`tests/suites/runtime_bootstrap.lua`、`tests/suites/gameplay_registry.lua`、`tests/suites/gameplay_afk.lua`、`tests/regression.lua`。第三类是兼容补点：`src/game/flow/turn/TurnDispatchValidator.lua` 用来在 item slot 转换 action 时保留 `input_source`。

关键终端证据如下。

    All regression checks passed (17)

以及：

    All regression checks passed (26)

以及：

    All regression checks passed (357)
    dep_rules ok
    tick ok
    forbidden_globals ok

## 接口与依赖

这次改动引入了两个内部约定。第一，`turn_runtime.afk_elapsed_seconds_by_role` 现在必须存在，并按角色保存 AFK 累计秒数。第二，内部 action 可以携带 `input_source`，当前只允许 `"user"` 与 `"timeout"` 两个值；缺省值会在 `TurnDispatch` 中按 `"user"` 处理。

实现结束后，以下接口已经存在并被使用。

在 `src/game/flow/turn/TurnTimerPolicy.lua` 中：

    turn_timer_policy.is_action_button_wait_active(game, state, ports) -> boolean
    turn_timer_policy.is_afk_trackable_wait(game, state, ports) -> boolean

在 `src/game/flow/turn/TurnDispatch.lua` 中：

    turn_dispatch.dispatch_action(game, state, action, opts)

其中 `action` 现在支持可选字段：

    input_source = "user" | "timeout"

在 `src/core/RuntimeState.lua` 的 `ensure_turn_runtime(state)` 中，返回的 `turn_runtime` 现在保证包含：

    afk_actor_role_id
    afk_elapsed_seconds
    afk_tracking_active
    afk_elapsed_seconds_by_role

2026-03-06 / Codex：本次更新完全重写了 `.agents/plan.md`，把上一项音效特效任务的计划替换为当前 AFK 托管修复的实施与结果记录。这样做是为了让仓库里的唯一执行计划始终对应当前任务，避免后续执行者读到与代码状态不一致的旧文档。
