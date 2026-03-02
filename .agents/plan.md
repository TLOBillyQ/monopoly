# Monopoly R10 兼容退役最小闭环可执行计划（M40-M42）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。任何人从零开始执行时，只依赖当前工作树与本文件，不依赖聊天历史。

## 目的 / 全局视角

R9 已经把兼容层做成“可观测 + 有守护”，R10 的目标是把这套兼容债务继续收敛成可退役状态：先去掉 game core 对 `RuntimeCompat` 的反向依赖，再把 legacy globals 写入改为显式开关默认关闭，最后继续削减 turn 主编排热点复杂度。用户可见收益是：回归失败定位更快，行为更可预测，后续改动不需要在 “context/global 双路径” 上反复防守。可观察结果是：`dep_rules` 和回归持续全绿，且 `StatusOps` 不再依赖 `RuntimeCompat`、常规启动路径不再默认写 `all_roles/vehicle_helper` 等全局。

## 进度

- [x] (2026-03-02 11:26 +08:00) 已完成：将 R10 建议落地为本可执行计划，重写 `.agents/plan.md` 为 R10 主线。
- [x] (2026-03-02 11:54 +08:00) M40 完成：`StatusOps` 移除 `RuntimeCompat` 依赖，改为 `RuntimePorts.resolve_vehicle_helper()`；`RuntimeInstall` 注入 vehicle helper 端口；`dep_rules` 新增 game core 禁止依赖 `RuntimeCompat`。
- [x] (2026-03-02 11:56 +08:00) M41 完成：`install_runtime_helpers` 默认 `install_globals=false`；`RuntimeInstall.install(opts)` 增加显式 `install_globals` 开关（默认关闭）；同步更新 gameplay/runtime compat 契约测试。
- [x] (2026-03-02 12:00 +08:00) M42 完成：新增 `GameplayLoopTickFlow.lua`，迁移 tick phase sync / dirty refresh / timeout 编排逻辑；`GameplayLoop.lua` 保持对外 API 不变。
- [x] (2026-03-02 12:03 +08:00) 最终验收通过：`dep_rules ok` + `All regression checks passed (207)`，`N=207 >= 206`。
- [ ] (R11 规划) M43：完成 roles 端口化替换，清理 `runtime_compat.get_roles()` 的 6 个调用点（`UIRuntimePort` / `UIBootstrap` / `GameStartup` / `player_units` / `scene` / `ViewCommandDispatcher`）。
- [ ] (R11 规划) M44：完成 vehicle/camera 端口化替换，清理 `runtime_compat.get_vehicle_helper()` 与 `runtime_compat.get_camera_helper()` 的 7 个调用点（`MoveAnim` / `placement` / `UISyncPorts`）。
- [ ] (R11 规划) M45：升级守护与退役收口（`dep_rules` 禁止 app/presentation 依赖 `RuntimeCompat`，默认 strict context-first，`RuntimeCompat` 标记 deprecated 并达到零消费者）。
- [ ] (R11 规划) 最终验收：`lua tests/internal/dep_rules.lua` 与 `lua tests/regression.lua` 全绿，且 turn 复杂度拆分任务顺延到 R12。

## 意外与发现

`StatusOps` 已切换为 `RuntimePorts.resolve_vehicle_helper()`，game core 到 compat 的反向依赖已消除；新增 dep rule 会阻止回退。

`RuntimeContext.install_runtime_helpers` 默认值改为 `install_globals=false` 后，`install_globals(ctx)` 仍保持显式导出语义（内部强制 `install_globals=true`），避免破坏分阶段安装测试语义。

`GameplayLoop` tick 编排已迁移到 `GameplayLoopTickFlow.lua`，主文件职责收敛为 API 与装配；回归计数从 206 提升到 207（新增契约覆盖）。

局部套件直接运行存在入口差异：`lua tests/suites/gameplay_core.lua` 依赖 `tests/regression.lua` 提供的 package.path 配置，单独执行会报 `module 'gameplay_registry' not found`。因此最终验收统一以 `tests/regression.lua` + `tests/internal/dep_rules.lua` 为准。

## 决策日志

决策：M40 采用“game core 依赖 `RuntimePorts` 抽象端口”而不是继续依赖 `RuntimeCompat`。理由：`RuntimeCompat` 是外层兼容桥，core 直接依赖会违反依赖方向；`RuntimePorts` 已在 core 层用于 RNG/调度等能力，扩展一个 vehicle 端口成本最小。日期/作者：2026-03-02 / Codex GPT-5。

决策：M41 保留“可选兼容模式”，但默认关闭 legacy globals 写入。理由：要先把默认行为改成 context-first，同时保留显式开关作为受控回退，避免一次性硬切导致场景脚本不可恢复。日期/作者：2026-03-02 / Codex GPT-5。

决策：M42 只做职责迁移和文件瘦身，不改 `gameplay_loop` 对外 API 与行为时序。理由：R10 的目标是架构收敛，不是功能重写；行为变更会扩大回归面并干扰兼容退役验证。日期/作者：2026-03-02 / Codex GPT-5。

## 结果与复盘

R10 M40-M42 已全部落地并通过最终验收，输出达到“兼容退役最小闭环”目标：内层不再依赖 compat、legacy globals 默认关闭、turn 主编排继续瘦身且 API 不变。

最终证据：

    [evidence] dep_rules ok
    [evidence] All regression checks passed (207)
    [evidence] tick ok
    [evidence] forbidden_globals ok

## 背景与导读

本仓库运行时分三层：`src/app` 负责启动装配，`src/core` 提供上下文与端口抽象，`src/game/core` 实现游戏核心状态与规则。这里的“compat”指 `src/core/RuntimeCompat.lua`：它会先读 `RuntimeContext.current()`，读不到时再回退 legacy 全局（`all_roles` / `vehicle_helper` / `camera_helper`）。这里的“port”指抽象函数入口（如 `RuntimePorts`），让内层只依赖能力接口，不依赖外层适配细节。

R10 相关关键文件：

- `src/game/core/runtime/player_state/StatusOps.lua`：R10 后已改为依赖 `RuntimePorts.resolve_vehicle_helper()`，不再直接依赖 `RuntimeCompat`。
- `src/core/RuntimePorts.lua`：core 已使用的端口聚合点（rng/schedule/resolve_role 等），M40 在此扩展 vehicle 能力。
- `src/app/bootstrap/RuntimeInstall.lua`：运行时安装入口，负责配置 ports 与 runtime context。
- `src/core/RuntimeContext.lua`：`install_runtime_helpers` 默认不写 legacy globals，仅显式兼容模式才开启。
- `tests/suites/runtime_compat_contract.lua`：compat 契约测试，M41 需要补充“context 命中时 fallback 计数为 0”的稳定性断言。
- `src/game/flow/turn/GameplayLoop.lua` 与 `src/game/flow/turn/GameplayLoopRuntime.lua`：M42 的主拆分对象。
- `tests/suites/gameplay_loop.lua`、`tests/suites/gameplay_runtime.lua`、`tests/regression.lua`、`tests/internal/dep_rules.lua`：里程碑验收入口。

当前基线按 R9 记录为 `All regression checks passed (206)`，R10 必须保持不回退。

## 工作计划

M40 的范围是“清除反向依赖，不改用户行为”。先在 `RuntimePorts` 新增 `resolve_vehicle_helper()` 端口（默认返回 `nil`），再在 `RuntimeInstall.install()` 的 `runtime_ports.configure({...})` 中注入实现，使其返回当前 runtime context 的 vehicle helper。随后修改 `StatusOps.lua`：移除 `RuntimeCompat` require，改为 `RuntimePorts.resolve_vehicle_helper()` 读取；其余逻辑保持原样。最后在 `dep_rules` 增加针对 game core 的规则，禁止再次直接依赖 `src.core.RuntimeCompat`（必要时对白名单注释更新为“已退役”）。

M41 的范围是“收紧默认行为并保留显式兼容开关”。在 `RuntimeContext.install_runtime_helpers()` 中将默认 `install_globals` 从 `true` 改为 `false`；在 `RuntimeInstall` 显式传入 `install_globals`（默认 `false`，兼容模式才设 `true`）。兼容模式的开关实现可落在 `RuntimeInstall.install(opts)` 参数上，或单独的常量配置，但必须满足“常规路径不写全局，兼容路径显式开启”。随后更新 `tests/suites/gameplay.lua` 中旧默认行为断言，并在 `runtime_compat_contract` 中新增或细化断言：当 context 可用时，fallback hits 维持 0。

M42 的范围是“继续瘦身编排热点，保持 API 不变”。优先拆分 `GameplayLoop.lua` 中纯编排段（例如 `_sync_tick_phase` / `_refresh_tick_from_dirty` / auto-runner gating 相关逻辑）到新模块；`GameplayLoopRuntime.lua` 保持为行为工具层。拆分后 `gameplay_loop.tick()`、`set_game()`、`new_game()` 的调用签名不变，调用方零改动。M42 结束后，`GameplayLoop.lua` 行数应继续下降，且 `gameplay_loop` / `gameplay_runtime` / 全量回归全绿。

## 具体步骤

所有命令在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先建立 R10 前基线：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

预期至少出现：

    dep_rules ok
    All regression checks passed (206)

执行 M40（StatusOps 依赖收敛）：

    1) 修改 src/core/RuntimePorts.lua：
       - 新增 _default_resolve_vehicle_helper()。
       - 新增 runtime_ports.resolve_vehicle_helper() 公共函数。
       - 支持 configure 注入 resolve_vehicle_helper 端口。
    2) 修改 src/app/bootstrap/RuntimeInstall.lua：
       - 在 runtime_ports.configure({...}) 中注入 resolve_vehicle_helper，返回 runtime_ctx.vehicle_helper（或 current ctx 对应 helper）。
    3) 修改 src/game/core/runtime/player_state/StatusOps.lua：
       - 删除 RuntimeCompat 依赖。
       - 将两处 get_vehicle_helper() 替换为 runtime_ports.resolve_vehicle_helper()。
    4) 修改 tests/internal/dep_rules.lua：
       - 新增规则：src/game/core 不允许 require("src.core.RuntimeCompat")。
       - 更新 StatusOps 过渡注释状态（从“过渡中”改为“已退役”）。

M40 局部验证：

    lua tests/internal/dep_rules.lua
    lua tests/suites/gameplay_core.lua
    lua tests/suites/gameplay_runtime.lua

执行 M41（legacy globals 默认关闭）：

    1) 修改 src/core/RuntimeContext.lua：
       - install_runtime_helpers 默认 install_globals=false。
    2) 修改 src/app/bootstrap/RuntimeInstall.lua：
       - install_runtime_helpers 显式传参 install_globals（常规 false；兼容模式 true）。
    3) 修改 tests/suites/gameplay.lua：
       - 调整“默认会导出全局 helper”的旧断言，改为“默认不导出；显式开启才导出”。
    4) 修改 tests/suites/runtime_compat_contract.lua：
       - 增加/细化 context 可用时 fallback hits 为 0 的断言。

M41 局部验证：

    lua tests/suites/gameplay.lua
    lua tests/suites/runtime_compat_contract.lua

执行 M42（GameplayLoop 热点拆分）：

    1) 新建 src/game/flow/turn/GameplayLoopTickFlow.lua（命名可微调）：
       - 收纳 GameplayLoop 中纯编排段（phase sync / dirty refresh / auto gating 至少一组）。
    2) 修改 src/game/flow/turn/GameplayLoop.lua：
       - 通过 require 调用新模块，保留对外函数签名不变。
    3) 仅在必要时微调 src/game/flow/turn/GameplayLoopRuntime.lua 的辅助函数暴露，不改行为语义。

M42 局部验证：

    lua tests/suites/gameplay_loop.lua
    lua tests/suites/gameplay_runtime.lua

最终全量验证：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

## 验证与验收

M40 验收条件：
1. `src/game/core/runtime/player_state/StatusOps.lua` 不再 `require("src.core.RuntimeCompat")`。
2. `RuntimePorts` 存在 `resolve_vehicle_helper()` 端口，且 `RuntimeInstall` 已注入实现。
3. `dep_rules` 对 game core 新增“禁止直接依赖 RuntimeCompat”守护并通过。
4. 相关局部测试与回归通过。

M41 验收条件：
1. `RuntimeContext.install_runtime_helpers()` 默认不写 legacy globals。
2. 常规 bootstrap 路径显式使用 `install_globals = false`；兼容模式才显式开启。
3. `runtime_compat_contract` 覆盖 context 命中场景且 fallback hits 为 0。
4. `lua tests/regression.lua` 通过，`N >= 206`。

M42 验收条件：
1. `GameplayLoop.lua` 继续瘦身，至少一组纯编排段完成迁移。
2. `gameplay_loop` / `gameplay_runtime` 套件均通过。
3. `gameplay_loop.tick()`、`set_game()`、`new_game()` 对外签名不变，调用方零改动。
4. 最终回归保持全绿（`N >= 206`）。

## 可重复性与恢复

本计划按 M40 -> M41 -> M42 增量执行，每个里程碑都可单独回滚。若某步失败，先只回退该里程碑触及文件，再重跑该里程碑的局部验证；禁止跨里程碑混合回滚，避免把失败原因掩盖。

若 M41 改默认值后发现线上环境仍依赖 legacy globals，可临时通过 `RuntimeInstall.install(opts)` 的兼容开关恢复 `install_globals=true`，同时记录触发场景并补测试；不得直接恢复“默认 true”。

## 产物与备注

本计划实施期的最小证据建议保留以下片段：

    [evidence] dep_rules ok
    [evidence] runtime_compat_contract: context-hit fallback count remains zero
    [evidence] All regression checks passed (N), N >= 206

计划期预期改动文件（实施后回填实际清单）：

- `src/core/RuntimePorts.lua`
- `src/app/bootstrap/RuntimeInstall.lua`
- `src/game/core/runtime/player_state/StatusOps.lua`
- `src/core/RuntimeContext.lua`
- `src/game/flow/turn/GameplayLoop.lua`
- `tests/suites/gameplay.lua`
- `tests/suites/runtime_compat_contract.lua`
- `tests/internal/dep_rules.lua`
- （可选新增）`src/game/flow/turn/GameplayLoopTickFlow.lua`

## 接口与依赖

R10 完成时必须存在并可用的接口如下：

`src/core/RuntimePorts.lua` 新增：

    runtime_ports.resolve_vehicle_helper() -> table|nil

`src/app/bootstrap/RuntimeInstall.lua` 保持入口：

    M.install(opts?)

并在内部显式决定：

    runtime_context.install_runtime_helpers(runtime_ctx, { install_globals = <bool> })

`src/game/core/runtime/player_state/StatusOps.lua` 对外函数签名保持不变：

    set_player_seat(self, player, seat_id)
    stop_all_players_movement(self)

但其 vehicle helper 来源改为端口注入，不再依赖 compat 读取。

`src/game/flow/turn/GameplayLoop.lua` 对外 API 保持不变：

    gameplay_loop.set_game(state, game)
    gameplay_loop.new_game(state)
    gameplay_loop.tick(game, state, dt)

---

本次修订说明：按用户要求，将 `.agents/research.md` 的 R10 建议（M40-M42）正式落地为新的 `.agents/plan.md` 可执行计划，并替换原 R9 完成态文档。这样做的原因是 R9 已结束，当前工作目标已切换为“兼容债务退役 + 主编排热点继续瘦身”，需要一份可直接执行和验收的 R10 计划作为单一事实来源。
修订 2（2026-03-02 Execute）：执行并验收 M40-M42，更新进度与结果证据；补充“局部套件需经 regression 入口执行”的执行发现，避免复现实操误判。
