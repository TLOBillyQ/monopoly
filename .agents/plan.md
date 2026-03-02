# Monopoly R11 RuntimeCompat 退役收口可执行计划（M43-M45）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。任何人从零开始执行时，只依赖当前工作树与本文件，不依赖聊天历史。

## 目的 / 全局视角

R10 已完成 game core 侧收口（M40-M42），R11 的目标是把兼容桥 `src/core/RuntimeCompat.lua` 从 app/presentation 侧继续退役到“可删除前状态”。用户可见收益是：运行时行为更稳定（默认 context-first，不再隐式依赖 legacy globals），故障定位更快（端口注入路径单一），后续重构不会在 compat/global 双路径来回补丁。可观察结果是：`runtime_compat.get_roles/get_vehicle_helper/get_camera_helper` 在业务代码零消费者，`dep_rules` 把 app/presentation 对 RuntimeCompat 的依赖直接拦截，回归持续全绿。

## 进度

- [x] (2026-03-02 12:03 +08:00) R10 完成：M40-M42 已验收通过，基线为 `All regression checks passed (207)`。
- [x] (2026-03-02 12:30 +08:00) 计划重写：将 `plan.md` 切换为 R11 专用执行文档，R10 仅作为背景基线，不再作为本轮执行范围。
- [x] (2026-03-02 13:18 +08:00) R11/M43 完成：新增 `RuntimePorts.resolve_roles()` 并注入；`UIRuntimePort`、`UIBootstrap`、`GameStartup`、`player_units`、`scene`、`ViewCommandDispatcher` 全部移除 `RuntimeCompat` 依赖。
- [x] (2026-03-02 13:19 +08:00) R11/M44 完成：新增 `RuntimePorts.resolve_camera_helper()`；`MoveAnim`、`placement`、`UISyncPorts` 改为走 ports，保留空 helper 回退语义。
- [x] (2026-03-02 13:23 +08:00) R11/M45 完成：`dep_rules` 新增 app/presentation 禁止 RuntimeCompat 依赖及 tests 最小白名单守护；`RuntimeCompat` 增加 deprecated 说明并默认 strict context-first；`runtime_compat_contract` 新增默认 strict 断言。
- [x] (2026-03-02 13:24 +08:00) R11 最终验收通过：`dep_rules ok` + `All regression checks passed (208)`，`N=208 >= 207`。

## 意外与发现

R10 的“局部 suite 直跑”存在入口差异：多个 `tests/suites/*.lua` 依赖 `tests/regression.lua` 注入 `package.path`，直接执行会出现 `module 'gameplay_registry' not found` 或 `module 'TestSupport' not found`。R11 验收应以 `tests/regression.lua` 与 `tests/internal/dep_rules.lua` 为统一入口。

当前仓库中 RuntimeCompat 业务调用分布已可确认：

- roles 调用点在 `UIRuntimePort`、`UIBootstrap`、`GameStartup`、`player_units`、`scene`、`ViewCommandDispatcher`。
- vehicle/camera 调用点在 `MoveAnim`、`placement`、`UISyncPorts`。

该分布与 R10 文档中的 R11 规划范围一致，可直接按里程碑推进。

M43 首轮替换后触发 `presentation_ui` 两个回归失败（role slot 与 auto button），根因是 `RuntimePorts.resolve_roles()` 初版未保留 `all_roles/ALLROLES` fallback；补回 fallback 后回归恢复全绿。

M45 首轮把 `strict_context_first` 配置放在 `RuntimeInstall` 时触发 dep_rules（app 不得依赖 RuntimeCompat）；最终改为 `RuntimeCompat` 默认 strict，避免 app 层直接依赖 compat。

## 决策日志

决策：R11 按“先 roles、再 vehicle/camera、最后守护收口（M43 -> M44 -> M45）”顺序推进。
理由：roles 是最多调用点的共享入口，先完成可降低后续模块改动冲突；vehicle/camera 属于渲染与 UI 同步细节，依赖于 roles 路径稳定后再收口风险更低。
日期/作者：2026-03-02 / Codex GPT-5。

决策：R11 不在本轮计划中删除 `src/core/RuntimeCompat.lua` 文件本体，仅实现零业务消费者与 deprecated 标记。
理由：保留契约测试和应急回退窗口，先达成“可删”状态，再在后续独立里程碑执行物理删除，可降低一次性改动面。
日期/作者：2026-03-02 / Codex GPT-5。

决策：`RuntimePorts.resolve_roles()` 保留 `all_roles/ALLROLES` fallback。
理由：presentation 侧仍有测试场景通过 legacy globals 注入角色数据；完全移除 fallback 会造成行为回归，且不影响“业务代码不依赖 RuntimeCompat”目标。
日期/作者：2026-03-02 / Codex GPT-5。

决策：`strict_context_first` 通过 `RuntimeCompat` 默认值实现，不在 `RuntimeInstall` 显式 configure。
理由：M45 新 dep rule 禁止 app 层依赖 RuntimeCompat；把 strict 默认放在 compat 内部可满足默认行为收紧，同时保持依赖方向正确。
日期/作者：2026-03-02 / Codex GPT-5。

## 结果与复盘

R11 M43-M45 已全部执行并通过验收。当前状态达到“RuntimeCompat 可删除前”目标：app/presentation 业务代码已零依赖 compat，roles/vehicle/camera 读取统一走 `RuntimePorts`，并由 dep_rules 阻止回退。

最终证据：

    [evidence] dep_rules ok
    [evidence] All regression checks passed (208)
    [evidence] tick ok
    [evidence] forbidden_globals ok

## 背景与导读

本仓库运行时主链路由三层组成：

- `src/app`：启动与装配层，负责 runtime context/ports 安装。
- `src/core`：上下文、端口、兼容桥等基础设施。
- `src/presentation`：UI 与渲染行为。

`RuntimeCompat` 是兼容桥：优先读取 `RuntimeContext.current()`，读不到时回退 legacy globals（`all_roles`、`vehicle_helper`、`camera_helper`）。R10 已把 game core 从 compat 解耦，R11 的主任务是把 app/presentation 对 compat 的读取改成显式端口或 context 读取。

R11 相关关键文件：

- `src/core/RuntimePorts.lua`：当前已有 `resolve_role`、`resolve_vehicle_helper` 等端口；R11 需补齐 roles/camera 侧可复用入口。
- `src/app/bootstrap/RuntimeInstall.lua`：端口注入中心，R11 需要注入新增 resolver。
- `src/core/RuntimeContext.lua`：context-first 的真实数据来源（roles/vehicle_helper/camera_helper）。
- `src/presentation/api/UIRuntimePort.lua`：UI 侧 runtime 访问聚合入口，M43 应优先在此切换 roles 来源。
- `src/presentation/api/presentation_ports/UISyncPorts.lua`、`src/presentation/render/MoveAnim.lua`、`src/presentation/render/board_runtime/placement.lua`：M44 的 vehicle/camera 主要消费者。
- `tests/internal/dep_rules.lua`：M45 守护升级入口。
- `tests/suites/runtime_compat_contract.lua`：compat 契约与 strict context-first 行为验证入口。

## 工作计划

M43 的范围是“roles 读取去 compat 化，不改变业务语义”。先在 `RuntimePorts` 提供稳定的 roles 解析入口（例如新增 `resolve_roles()`，默认从 `RuntimeContext.current().roles` 读取，必要时可回退 `GameAPI.get_all_valid_roles` 作为防御）。然后在 `RuntimeInstall` 中注入对应实现，确保 app 启动后所有调用点走同一端口。之后按调用链从聚合入口到边缘模块替换 `runtime_compat.get_roles()`：优先改 `UIRuntimePort`，再改 `UIBootstrap`、`GameStartup`、`player_units`、`scene`、`ViewCommandDispatcher`。目标是业务模块不再 require `src.core.RuntimeCompat`。

M44 的范围是“vehicle/camera 读取去 compat 化，保持动画与镜头语义不变”。在 `RuntimePorts` 补齐 camera resolver（如 `resolve_camera_helper()`），并确认 `resolve_vehicle_helper()` 仍由 runtime context 注入。随后替换 `MoveAnim`、`placement`、`UISyncPorts` 中的 compat 调用；其中 `MoveAnim` 与 `placement` 对“空 helper 时回退到非载具路径”的行为必须保持不变，`UISyncPorts.follow_camera` 对 camera helper 为空时返回 `false` 的语义不变。

M45 的范围是“守护与退役收口”。更新 `dep_rules`：新增 app/presentation 禁止 require `src.core.RuntimeCompat` 的规则，并保留最小白名单（仅 `tests/suites/runtime_compat_contract.lua`）。同步把 `RuntimeCompat.lua` 顶部标记为 deprecated（注释 + 使用说明），并将 `strict_context_first` 默认值收紧为开启状态；仅显式兼容场景才允许关闭 strict。最后补齐测试以证明 context-hit 不走 fallback。

## 具体步骤

所有命令在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先确认 R11 开始前基线：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

预期输出至少包含：

    dep_rules ok
    All regression checks passed (207)

执行 M43（roles 去 compat）：

    1) 修改 src/core/RuntimePorts.lua：
       - 新增 _default_resolve_roles() 与 runtime_ports.resolve_roles()。
       - configure 支持注入 resolve_roles 端口。
    2) 修改 src/app/bootstrap/RuntimeInstall.lua：
       - 在 runtime_ports.configure({...}) 注入 resolve_roles，实现从 runtime_ctx.roles 读取。
    3) 修改 roles 调用点并去除 RuntimeCompat require：
       - src/presentation/api/UIRuntimePort.lua
       - src/app/bootstrap/UIBootstrap.lua
       - src/app/bootstrap/GameStartup.lua
       - src/presentation/render/board_runtime/player_units.lua
       - src/presentation/render/status3d_service/scene.lua
       - src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua

M43 局部验证建议：

    lua tests/suites/runtime_compat_contract.lua
    lua tests/suites/gameplay.lua

若局部命令受入口影响失败，改以回归入口验证：

    lua tests/regression.lua

执行 M44（vehicle/camera 去 compat）：

    1) 修改 src/core/RuntimePorts.lua：
       - 新增 _default_resolve_camera_helper() 与 runtime_ports.resolve_camera_helper()。
       - configure 支持注入 resolve_camera_helper。
    2) 修改 src/app/bootstrap/RuntimeInstall.lua：
       - 注入 resolve_camera_helper，实现从 runtime_ctx.camera_helper 读取。
    3) 修改 vehicle/camera 调用点并去除 RuntimeCompat require：
       - src/presentation/render/MoveAnim.lua
       - src/presentation/render/board_runtime/placement.lua
       - src/presentation/api/presentation_ports/UISyncPorts.lua

M44 局部验证建议：

    lua tests/suites/gameplay_runtime.lua
    lua tests/suites/gameplay_loop.lua

若局部命令受入口影响失败，改以回归入口验证：

    lua tests/regression.lua

执行 M45（守护与退役收口）：

    1) 修改 tests/internal/dep_rules.lua：
       - 新增规则：src/app 与 src/presentation 不允许 require("src.core.RuntimeCompat")。
       - 添加最小白名单，仅允许 tests/suites/runtime_compat_contract.lua 使用 RuntimeCompat。
    2) 修改 src/core/RuntimeCompat.lua：
       - 增加 deprecated 注释，声明仅用于契约测试与紧急兼容。
    3) 修改 RuntimeCompat 默认行为：
       - `strict_context_first` 默认开启。
       - 兼容模式如需回退，必须显式关闭 strict 并记录场景。
    4) 修改/补充 tests/suites/runtime_compat_contract.lua：
       - 覆盖 strict_context_first 默认开启后的 context-hit 行为与 fallback 计数。

M45 局部验证：

    lua tests/internal/dep_rules.lua
    lua tests/suites/runtime_compat_contract.lua

最终全量验证：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

## 验证与验收

M43 验收条件：

1. app/presentation 侧原 roles 调用点不再 require `src.core.RuntimeCompat`。
2. `RuntimePorts` 提供并可调用 `resolve_roles()`，且由 `RuntimeInstall` 注入实现。
3. 回归通过，行为不回退（`N >= 207`）。

M44 验收条件：

1. `MoveAnim`、`placement`、`UISyncPorts` 不再依赖 `RuntimeCompat`。
2. `RuntimePorts` 提供 `resolve_camera_helper()`；`resolve_vehicle_helper()` 持续可用。
3. 载具移动/落位与相机跟随语义保持不变，回归通过（`N >= 207`）。

M45 验收条件：

1. `dep_rules` 能阻止 app/presentation 重新依赖 `RuntimeCompat`。
2. 常规路径 strict context-first 默认开启，compat fallback 只在显式兼容模式可用。
3. `RuntimeCompat` 在业务代码零消费者，仅契约测试保留。
4. `lua tests/internal/dep_rules.lua` 与 `lua tests/regression.lua` 全绿。

## 可重复性与恢复

本计划按 M43 -> M44 -> M45 增量推进，每个里程碑都可独立回滚。若某里程碑失败，仅回退该里程碑触及文件并重跑对应验证；禁止跨里程碑混合回滚。

若 M45 上 strict_context_first 默认开启后发现环境仍依赖 fallback，可临时通过启动兼容开关恢复，但必须记录触发模块、追加回归测试，并在下一次提交中移除该回退。

## 产物与备注

R11 执行期应保留以下最小证据片段：

    [evidence] dep_rules ok
    [evidence] All regression checks passed (N)
    [evidence] runtime_compat_contract: context-hit fallback count remains zero

计划期预期改动文件（实施后回填实际清单）：

- `src/core/RuntimePorts.lua`
- `src/app/bootstrap/RuntimeInstall.lua`
- `src/core/RuntimeCompat.lua`
- `src/presentation/api/UIRuntimePort.lua`
- `src/app/bootstrap/UIBootstrap.lua`
- `src/app/bootstrap/GameStartup.lua`
- `src/presentation/render/board_runtime/player_units.lua`
- `src/presentation/render/status3d_service/scene.lua`
- `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua`
- `src/presentation/render/MoveAnim.lua`
- `src/presentation/render/board_runtime/placement.lua`
- `src/presentation/api/presentation_ports/UISyncPorts.lua`
- `tests/internal/dep_rules.lua`
- `tests/suites/runtime_compat_contract.lua`

## 接口与依赖

R11 结束时必须存在并可用以下接口：

`src/core/RuntimePorts.lua`：

    runtime_ports.resolve_roles() -> table
    runtime_ports.resolve_vehicle_helper() -> table|nil
    runtime_ports.resolve_camera_helper() -> table|nil

`src/app/bootstrap/RuntimeInstall.lua` 保持入口：

    M.install(opts?)

并在内部明确注入：

    runtime_ports.configure({
      resolve_roles = <fn>,
      resolve_vehicle_helper = <fn>,
      resolve_camera_helper = <fn>,
      ...
    })

`src/core/RuntimeCompat.lua` 保留但仅用于契约与应急：

    runtime_compat.get_roles()
    runtime_compat.get_vehicle_helper()
    runtime_compat.get_camera_helper()

以上接口不得再被 app/presentation 业务模块直接依赖。

---

本次修订说明（2026-03-02）：按用户要求将 `.agents/plan.md` 重写为“R11 规划专用可执行计划”。本次修订移除了“R10 执行叙事 + R11 附带待办”的混合结构，改为“R10 仅作为已完成基线，R11（M43-M45）作为唯一执行主线”。这样做的原因是避免范围误解，确保后续执行者按单一目标推进并验收。
