# 修订 `.agents/swarm_plan.md`：测试目录重组与回归装配收口

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。它替换当前偏摘要式的 `.agents/swarm_plan.md`，作为后续并行实施的唯一真源。

## 目的 / 全局视角

这项工作要把 `tests/` 从“runner、共享脚手架、guard 脚本、契约 suite、行为 suite 混装且依赖隐式入口”的状态，收口为一个可发现、可分 lane、可并行迁移、失败时可低噪声定位的测试系统。改完后，开发者仍然执行 `lua tests/regression.lua`，但也可以单独执行 `behavior`、`contract`、`guard` 三条车道；默认通过路径不再被大量重复 warning 淹没。

可观察结果必须是具体可见的。当前基线是：`tests/` 共有 56 个文件；`tests/suites/manifest.lua` 平铺装载 471 个 suite case；`MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua` 通过并输出 `All regression checks passed (469)`，随后 5 个 guard 脚本各自报告成功。计划完成后，`tests/catalog.lua` 成为唯一真源，两个当前未接入 manifest 的孤儿 contract suite 也会被纳入正式回归，所以总 case 基线更新为 480，`release_trimmed` 基线更新为 478，同时 guard 仍保持 5 个脚本检查。

## 进度

- [x] (2026-03-09 18:30+08:00) 已核对 `.agents/harness/PLANS.md`、现有 `.agents/swarm_plan.md`、架构边界文档、`lua_env.md` 与测试目录现状。
- [x] (2026-03-09 18:30+08:00) 已确认当前测试基线：`tests/` 56 个文件，manifest 原始装载 471 个 case，`release_trimmed` 实际通过数为 469。
- [x] (2026-03-09 18:30+08:00) 已确认当前大文件与装配热点：`tests/TestSupport.lua`、`tests/TestHarness.lua`、`tests/internal/guard_support.lua`、`tests/suites/gameplay/gameplay.lua`、`presentation_ui_action_status_part1/2/3.lua`、`presentation_ui_popup_market.lua`、`presentation_ui_action_anim.lua`。
- [x] (2026-03-09 18:30+08:00) 已确认当前孤儿 suite：`tests/suites/architecture/intent_output_contract.lua` 与 `tests/suites/runtime/narrow_runtime_ports_contract.lua` 未接入 manifest，本计划默认把它们纳入正式 contract lane。
- [x] (2026-03-09 19:04+08:00) 已新增 `.agents/test_reorg_inventory.md`，固定当前 `471/469/5` 基线、孤儿 contract suite 和旧入口引用清单，作为迁移真源。
- [x] (2026-03-09 19:04+08:00) 已引入 `tests/bootstrap.lua`、`tests/catalog.lua`、`tests/suites/manifest.lua` 转发 shim 与 `tests/support/test_env.lua`，并保持 `lua tests/regression.lua` 入口可用。
- [x] (2026-03-09 19:04+08:00) 已完成 `release_trimmed` metadata 迁移、`behavior`/`contract`/`guard` runner、guard shim、孤儿 contract suite 纳管与共享日志捕获；当前 `MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua` 通过 `416`，`lua tests/contract.lua` 通过 `62`，`lua tests/guard.lua` 通过 `5`。
- [ ] 再完成 gameplay / presentation 巨型 suite 拆分，并退役 wrapper-only suite。
- [ ] 替换 `TestSupport` 的 logger/test-mode 钩子后，清理旧入口、更新文档与命令示例，跑完整验证。

## 意外与发现

- 观察：当前 `.agents/swarm_plan.md` 的数字已经过期，不能直接沿用。
  证据：现树 `manifest` 原始装载 471 个 case，而 `release_trimmed` 实际通过数是 469，不是旧计划中的 468/466。

- 观察：`tests/regression.lua` 的 `release_trimmed` 过滤真源已经漂移，不能直接机械搬到 case metadata。
  证据：现有 hardcoded 列表里 `chance`、`config_sanity` 的若干目标名已经不存在，真正命中的只剩少数 case。

- 观察：`tests/TestHarness.lua` 的稳定性依赖“每个 case 执行前都 `math.randomseed(1)`”，不是进程启动时只设一次。
  证据：当前 harness 在 case 循环内部重置随机种子；如果改成 bootstrap 级别，会把 case 顺序变成语义的一部分。

- 观察：`tests/TestSupport.lua` 不只是 helper 汇总，它还在加载时补全全局 API、刷新 runtime context、配置 logger，并立刻执行环境刷新；`logger.lua` 还把 `package.loaded["TestSupport"]` 当作测试模式信号。
  证据：`tests/TestSupport.lua` 内存在 `_refresh_runtime_context_for_tests()` 与加载期副作用，`src/core/utils/logger.lua` 存在 `TestSupport` 特判。

- 观察：噪声并不只来自 harness；大量输出来自 `logger` 直接 `print(...)`，guard 脚本也运行在 harness 之外。
  证据：当前全量回归的大部分 warning 来自 `market paid goods mapping missing`、`board_feedback skip ...` 等 `logger` 输出。

- 观察：guard 迁移不能直接改路径，否则 contract suite、`regression.lua` 和文档会一起断。
  证据：当前 `guard_scripts_contract.lua`、`tests/regression.lua` 和若干文档仍把 `tests/internal/*` 当作入口。

- 观察：如果先拆 `gameplay.loop` 和 `presentation_ui.action_status` wrapper，再迁移 `release_trimmed` metadata，过滤会悄悄失效。
  证据：当前 `release_trimmed` 是按旧 suite 名和 case 名硬编码过滤，依赖 `registry.lua` 和 `presentation_ui_action_status.lua` 产出的旧命名。

## 决策日志

- 决策：先做 inventory，再做 catalog / metadata 迁移。
  理由：当前 `release_trimmed` 过滤名单已漂移，必须先得到真实命中表，否则会把错误禁用项永久写进 catalog。
  日期/作者：2026-03-09 / Codex

- 决策：`bootstrap` 只统一 `package.path`、环境装配与 runner 入口，不接管每个 case 的随机种子重置。
  理由：必须保持现有 case 级确定性，避免引入顺序相关回归。
  日期/作者：2026-03-09 / Codex

- 决策：`TestSupport` 先拆出显式 `tests/support/test_env.lua` 与 `tests/support/log_capture.lua`，再拆 assertions / factories / helpers；删除 facade 前必须先替换 `logger.lua` 的 `package.loaded["TestSupport"]` 测试钩子。
  理由：先把加载期副作用与测试模式判断显式化，才能安全做 helper 粒度拆分。
  日期/作者：2026-03-09 / Codex

- 决策：两个孤儿 contract suite 不放到最后清理阶段，而是在 catalog / runner 切换时一并纳入正式 contract lane。
  理由：否则新 contract lane 会出现“假绿”。
  日期/作者：2026-03-09 / Codex

- 决策：guard 迁移采用“先 shim、后切换、再删除”的三段式，不允许一步到位改路径。
  理由：当前真实调用面包括 suite、脚本入口和文档，直接迁移会造成多入口同时失效。
  日期/作者：2026-03-09 / Codex

- 决策：catalog metadata 与 runner 切换必须先于大 suite 拆分。
  理由：只有先把 `release_trimmed` 从旧命名切到 case metadata，后续删 wrapper 才不会改变回归语义。
  日期/作者：2026-03-09 / Codex

## 结果与复盘

当前已完成 `T0-T3`。测试入口、catalog、lane runner、guard shim 与日志捕获已经落地，且新的整体验证已经通过：`MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua` 当前输出为 `All regression checks passed (416)`、`All regression checks passed (62)`、以及 5 个 guard `ok`。剩余工作集中在 `T4-T7`：拆掉 gameplay / presentation 巨型 suite、退役 wrapper-only suite、替换剩余旧入口引用并更新文档。

## 背景与导读

当前测试入口由 `tests/regression.lua` 驱动。它手工拼 `package.path`，从 `tests/suites/manifest.lua` 装载 suite，运行 `tests/TestHarness.lua`，然后再用 `dofile(...)` 顺序执行 `tests/internal/dep_rules.lua`、`legacy_path_guard.lua`、`gameplay_loop_no_ui.lua`、`forbidden_globals.lua`、`arch_view_guard.lua`。同时，`release_trimmed` 过滤被硬编码在这个 runner 里，且依赖旧 suite 命名 `gameplay.loop` 与 `presentation_ui.action_status`。

当前共享脚手架主要集中在 `tests/TestSupport.lua` 与 `tests/internal/guard_support.lua`。前者承担断言、patch、建模、UI 夹具、runtime context 刷新和 logger 装配等多种职责，并在模块加载时执行副作用；后者承担文本级 guard 的文件枚举与行级扫描。当前大文件热点集中在 `tests/suites/gameplay/gameplay.lua`、`tests/suites/presentation/presentation_ui_action_status_part1.lua`、`presentation_ui_action_status_part2.lua`、`presentation_ui_action_status_part3.lua`、`presentation_ui_popup_market.lua` 与 `presentation_ui_action_anim.lua`。同时，`tests/suites/gameplay/registry.lua` 与 `gameplay_core.lua` / `gameplay_runtime.lua` / `gameplay_loop.lua` 仍在用索引切片；`presentation_ui_action_status.lua` 仍只是 part1/2/3 聚合壳；`tests/suites/architecture/intent_output_contract.lua` 与 `tests/suites/runtime/narrow_runtime_ports_contract.lua` 目前未接入 manifest。

## 工作计划

先建立一个不会改变现有测试语义的 inventory。这个 inventory 记录 manifest 当前 471 个 case、`release_trimmed` 实际命中的 case、5 个 guard 脚本入口、两个孤儿 contract suite、以及所有 repo 内对 `TestHarness`、`TestSupport`、`tests/internal/*`、旧 `package.path` 配方的引用。只有拿到这份 inventory，后面的 catalog 与 metadata 才不会把过期信息固化下来。

然后引入新装配骨架，但先保留兼容面。新增 `tests/bootstrap.lua` 负责路径安装和 test bootstrap；新增 `tests/catalog.lua` 作为唯一注册真源，结构固定为 `behavior_suites`、`contract_suites`、`guard_scripts` 三组；保留 `tests/suites/manifest.lua` 作为转发 shim；保留 `tests/TestHarness.lua`、`tests/TestSupport.lua` 与 `tests/internal/*` 作为兼容 facade。这个阶段不删旧入口，只让新旧入口同时可用，并保证 `lua tests/regression.lua` 继续工作。

接着先做 catalog metadata、guard shim 和 runner 切换，再做大 suite 拆分。`release_trimmed` 过滤要先从 `regression.lua` 硬编码迁到 case metadata，格式固定为 `{ name, run, disabled_in = { release_trimmed = true }, tags = {...} }`；suite 格式固定为 `{ name, layer, kind, tests = {...} }`。guard lane 真实脚本迁到 `tests/guards/`，但必须同时提供脚本级 shim 和模块级 shim，确保 `tests/regression.lua`、`guard_scripts_contract.lua`、以及仍然 `require("internal.*")` 的 guard 文件在迁移期都不被打断。两个孤儿 contract suite 也在这一刀里纳入 `contract` lane，不放到最后补录。

在 runner 稳定后，再把 `TestSupport` 的加载期副作用拆显式。先抽出 `tests/support/test_env.lua` 负责 LuaAPI / GameAPI / runtime context / logger 的测试环境安装，再抽出 `tests/support/log_capture.lua` 负责 logger 与 stdout 捕获，最后才把 assertions、patches、`game_factory.lua`、`ui_factory.lua`、`runtime_helpers.lua`、`scenario_helpers.lua` 拆出去。只有当 `logger.lua` 的测试模式判断不再依赖 `package.loaded["TestSupport"]` 后，`tests/TestSupport.lua` 才能从“必须加载的测试模式开关”退化为纯 facade。

大 suite 拆分分三块并行推进。`tests/suites/gameplay/gameplay.lua` 拆成 6 个真实 suite：`gameplay_bankruptcy_and_tile_owner.lua`、`gameplay_intent_dispatch_and_event_feed.lua`、`gameplay_runtime_context_and_camera_sync.lua`、`gameplay_turn_flow_and_interrupts.lua`、`gameplay_timeout_and_auto_runner.lua`、`gameplay_visual_feedback_and_prompts.lua`；已有 `gameplay_afk.lua`、`gameplay_coroutine.lua`、`gameplay_items_startup.lua` 保留，`registry.lua` 与 `gameplay_core.lua` / `gameplay_runtime.lua` / `gameplay_loop.lua` 删除。`presentation_ui_action_status` 系列拆成 9 个真实 suite：`presentation_choice_routes.lua`、`presentation_target_pick.lua`、`presentation_action_log_and_role_context.lua`、`presentation_market_panel.lua`、`presentation_item_slots.lua`、`presentation_action_anim_queue_and_turn_lock.lua`、`presentation_status3d_and_turn_effects.lua`、`presentation_popup_and_modal_renderers.lua`、`presentation_player_panels.lua`；`presentation_ui_action_status.lua` 与 part1/2/3 删除。`presentation_ui_popup_market.lua` 拆成 `presentation_ui_role_slots.lua`、`presentation_ui_touch_policy.lua`、`presentation_market_confirm_flow.lua`、`presentation_popup_visibility.lua`；`presentation_ui_action_anim.lua` 拆成 `presentation_action_anim_core.lua`、`presentation_overlay_compute.lua`、`presentation_board_feedback.lua`。

最后才收口删除旧入口。只有当 repo 内对 `require("TestSupport")`、`require("TestHarness")`、`tests/internal/*` 旧入口、旧 `package.path` 配方和 wrapper-only suite 的引用经 `rg` 清零，且文档命令全部更新后，才允许删除 facade 与 shim。

## 任务与依赖

### T0: 建立 inventory 与真实基线

depends_on: []  
location: `tests/regression.lua`、`tests/suites/manifest.lua`、`tests/internal/`、`docs/architecture/`  
description: 产出迁移真源，记录 471 原始 case、469 release_trimmed case、5 个 guard 脚本、2 个孤儿 contract suite、以及所有旧入口引用与实际命中过滤项。  
validation: inventory 能解释当前 `manifest`、`release_trimmed` 与 guard 执行面的全部数字来源。

### T1: 建立 bootstrap、catalog 与兼容 shim

depends_on: [T0]  
location: `tests/bootstrap.lua`、`tests/catalog.lua`、`tests/suites/manifest.lua`、`tests/regression.lua`  
description: 建立统一入口与 catalog 分组，保留 `manifest` 转发 shim 和 `lua tests/regression.lua` 兼容；`bootstrap` 不接管 case 级 `math.randomseed(1)`。  
validation: 在不改 suite 内容的前提下，`lua tests/regression.lua` 仍输出当前基线，`manifest` 与 `catalog` 装载结果一致。

### T2: 抽离显式 test_env 与可替换测试模式钩子

depends_on: [T1]  
location: `tests/TestSupport.lua`、`tests/support/test_env.lua`、`tests/support/log_capture.lua`、`src/core/utils/logger.lua`  
description: 先把 `TestSupport` 的环境副作用显式化，再为 `logger` 增加不依赖 `package.loaded["TestSupport"]` 的测试模式入口；此阶段保留 `tests/TestSupport.lua` facade。  
validation: 现有 suite 继续通过，`logger` 与 runtime context 相关测试不因模块拆分改变行为，且测试模式不再依赖 `TestSupport` 是否已加载。

### T3: 先完成 metadata、guard shim、runner 与 contract lane 切换

depends_on: [T0, T1, T2]  
location: `tests/behavior.lua`、`tests/contract.lua`、`tests/guard.lua`、`tests/regression.lua`、`tests/TestHarness.lua`、`tests/guards/`、`tests/internal/`  
description: 把 suite 分成 behavior / contract / guard 三条车道；把 `release_trimmed` 迁到 case metadata；为 `tests/internal/*` 与 `internal.*` require 提供兼容 shim；把 `intent_output_contract` 与 `narrow_runtime_ports_contract` 一并纳入 contract lane；引入共享日志捕获，让通过路径只输出进度点与摘要，失败路径回放失败 case 日志。  
validation: `MONO_TEST_VERBOSE=1` 可恢复全量日志；默认通过路径不再回放重复 warning；guard lane 也走统一捕获；`release_trimmed` 在 wrapper 仍存在和 wrapper 删除后都命中同一批 case。

### T4: 拆 gameplay 巨型 suite 并退役索引切片

depends_on: [T3]  
location: `tests/suites/gameplay/`  
description: 按行为边界拆掉 `gameplay.lua`，移除 `registry.lua` 与 wrapper-only slice suite，把 catalog 直接指向真实 suite。  
validation: gameplay 相关 case 总数与命名可从旧文件一一映射，新 catalog 不再依赖索引区间，`release_trimmed` 仍保持相同禁用结果。

### T5: 拆 `presentation_ui_action_status` 系列

depends_on: [T3]  
location: `tests/suites/presentation/`  
description: 用 9 个真实 suite 替代 `presentation_ui_action_status.lua` 与 part1/2/3 聚合结构，catalog 直接登记新 suite。  
validation: 当前 82 个 case 全部有归宿，status3d 相关禁用项来自真实 case metadata，不再靠旧 suite 名硬编码。

### T6: 拆 `presentation_ui_popup_market` 与 `presentation_ui_action_anim`

depends_on: [T3]  
location: `tests/suites/presentation/`  
description: 分别把 popup_market 拆成 4 个 suite，把 action_anim 拆成 3 个 suite；保留现有 smaller suite 不动。  
validation: 相关 case 全部映射完成，catalog 不再引用聚合壳文件。

### T7: 清理旧入口、更新文档并完成对账

depends_on: [T4, T5, T6]  
location: `tests/catalog.lua`、`tests/suites/`、`tests/internal/`、`docs/architecture/`  
description: 删除已无引用的 wrapper-only suite、facade 与旧路径文档，更新命令示例，并完成最终基线对账。  
validation: `rg` 对 `require("TestSupport")`、`require("TestHarness")`、`tests/internal/` 旧入口引用归零或只剩兼容层本身；文档命令与实际 runner 一致。

## 依赖图

    T0 ──> T1 ──> T2 ──> T3 ──┬── T4 ──┐
                              ├── T5 ──┤── T7
                              └── T6 ──┘

并行波次固定为三轮。第一轮先做 `T0-T2`。第二轮先完成 `T3`，也就是 catalog metadata、孤儿 contract suite 纳管、guard shim、runner 与日志捕获。第三轮并行执行 `T4-T6`，最后执行 `T7` 收口删除旧入口。

## 具体步骤

在仓库根目录先校准现基线：

    lua - <<'LUA'
    package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua;./?/init.lua'
    local manifest = require('suites.manifest')
    local total = 0
    for _, mod in ipairs(manifest) do
      local suite = require(mod)
      total = total + #(suite.tests or suite)
    end
    print(total)
    LUA

预期输出 `471`。

然后确认当前 release_trimmed 基线：

    MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua

预期看到：

    All regression checks passed (469)
    dep_rules ok
    legacy_path_guard ok
    tick ok
    forbidden_globals ok
    arch_view_guard ok

实施完成后，用新 runner 验收：

    MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua
    lua tests/contract.lua
    lua tests/guard.lua
    MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua

预期结果分别为：behavior lane `416` 通过，contract lane `62` 通过，guard lane `5` 个脚本全部成功，整体验收输出 `All regression checks passed (478)` 且仍保留 5 条 guard 成功行。

## 验证与验收

验收必须同时满足七条。第一，`tests/catalog.lua` 成为 suite 真源，`tests/suites/manifest.lua` 只剩兼容转发或已在最终清理阶段删除。第二，原始 suite case 总数从当前 471 增长到 480，增长的 9 个 case 仅来自 `intent_output_contract` 与 `narrow_runtime_ports_contract` 正式纳管。第三，`release_trimmed` 总数为 478，且禁用项全部来自 case metadata，不再存在 `regression.lua` 内部硬编码过滤表。第四，在 wrapper 仍存在的中间阶段和 wrapper 删除后的最终阶段，`release_trimmed` 命中集合必须一致。第五，不再存在 `registry.lua`、`presentation_ui_action_status.lua`、part1/2/3 这类 wrapper-only suite。第六，默认通过路径不再逐行回放重复 `market paid goods mapping missing` 和同类 warning，但失败 case 仍能回放完整缓冲日志，`MONO_TEST_VERBOSE=1` 仍可输出全量日志。第七，repo 内文档与命令示例全部切换到新 runner，不再引用旧 `tests/internal/*` 路径或旧 `.agents/tests/...` 说明。

## 可重复性与恢复

本计划必须按“先增量、后删减”执行。每一轮都先新增新入口与 shim，再切 catalog，再删旧入口。任何一步失败时，都回到上一轮仍保持兼容的状态，不允许通过直接删除 facade 来“逼着” suite 迁移。所有新增文件与新 suite 命名使用 `snake_case`，测试辅助代码继续遵守 `lua_env` 与 `forbidden_globals` 约束，不引入 `tonumber` 或 `type(x) == "number"` 之类违规写法。

## 产物与备注

本轮最终应留下的关键产物是 `tests/bootstrap.lua`、`tests/catalog.lua`、`tests/behavior.lua`、`tests/contract.lua`、`tests/guard.lua`、`tests/support/test_env.lua`、`tests/support/log_capture.lua` 与拆分后的真实 suite 文件。最终应删除的旧装配壳包括 `tests/suites/gameplay/registry.lua`、`tests/suites/gameplay/gameplay.lua`、`tests/suites/gameplay/gameplay_core.lua`、`tests/suites/gameplay/gameplay_runtime.lua`、`tests/suites/gameplay/gameplay_loop.lua`、`tests/suites/presentation/presentation_ui_action_status.lua`、`tests/suites/presentation/presentation_ui_action_status_part1.lua`、`tests/suites/presentation/presentation_ui_action_status_part2.lua`、`tests/suites/presentation/presentation_ui_action_status_part3.lua`，以及在引用清零后的兼容 facade。

## 接口与依赖

新测试装配接口固定如下。`tests/catalog.lua` 导出 `behavior_suites`、`contract_suites`、`guard_scripts`。suite 表统一为 `{ name, layer, kind, tests = {...} }`；case 表统一为 `{ name, run, disabled_in = { release_trimmed = true }, tags = {...} }`。`tests/TestHarness.lua` 升级后必须支持 `run_all(suites, opts)`，其中 `opts` 至少包含 `filter`、`reporter`、`capture_logs`、`mode`，但必须继续兼容现有单参数调用。`tests/support/test_env.lua` 是唯一允许安装测试运行时副作用的入口；`tests/support/log_capture.lua` 是 behavior、contract、guard 三条 lane 共用的日志缓冲层。guard 迁移后真实脚本位于 `tests/guards/`，但在删除 shim 之前，旧 `tests/internal/*` 路径与 `internal.*` 模块名仍需可执行。`src/core/utils/logger.lua` 必须提供显式测试模式开关或等价注入点，替代 `package.loaded["TestSupport"]` 特判。

本文件于 2026-03-09 19:04+08:00 更新：完成 `T0-T3` 实施，新增 inventory 文档、bootstrap/catalog/test_env/log_capture、behavior/contract/guard runner、guard shim 与孤儿 contract suite 纳管，并记录新的 `416 + 62 + 5` 验证结果。
