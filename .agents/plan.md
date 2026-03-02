# Monopoly R9 兼容债务清理可执行计划（M37-M39）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。任何人从零开始执行时，只依赖当前工作树与本文件，不依赖聊天历史。

## 目的 / 全局视角

R8 已完成边界纯化，R9 的目标是继续把运行时 legacy 兼容债务显式化并逐步退役。用户可见收益是：后续改动更可预测，回归失败定位更快，运行时上下文隔离能力更强。可观察结果是：核心回归持续全绿，且新增契约/规则可以证明“有上下文时不再回退全局读取，热点模块继续降复杂度”。

## 进度

- [x] (2026-03-02 10:24 +08:00) 已完成：根据 `.agents/research.md`（R8 执行后复盘）重写为 R9 可执行计划。
- [x] (2026-03-02 10:46 +08:00) 已完成：M37 `RuntimeCompat` 退役治理第一阶段（新增 `strict_context_first` 配置与 fallback 命中计数）。
- [x] (2026-03-02 10:46 +08:00) 已完成：M38 `GameplayLoopPorts` / `TickTimeout` 继续拆分策略与适配职责（新增 `GameplayLoopUISyncDefaults`、`TickChoiceTimeout`）。
- [x] (2026-03-02 10:46 +08:00) 已完成：M39 新增“兼容退役”契约测试与依赖规则，并接入回归聚合。

## 意外与发现

R8 执行后基线已经变化：`tests/regression.lua` 通过数为 `204`（高于 R7 时的 202）。R9 必须以 `>= 204` 作为最低通过线，而不是旧值。

    All regression checks passed (204)
    dep_rules ok
    tick ok
    forbidden_globals ok

`RuntimeCompat` 调用方分布在 9 个文件中（详见背景与导读），其中 `StatusOps.lua` 位于 game core 层，构成交叉依赖。这意味着 M37 收紧 compat 行为时必须保守——只加守护不改行为，否则可能反向破坏 game core 路径。

`GameplayLoopPorts.lua`（319 行）内部 `_fill_ui_sync_defaults` 占约 80 行，是独立的适配填充逻辑，可安全拆分。`TickTimeout.lua`（244 行）内部策略工厂（`default_policy` + `step_default_*`）占约 80 行，同样可独立。

R9 执行后回归通过数提升至 `206`（新增 `runtime_compat_contract` 套件），并保持 `dep_rules ok`。说明新增规则与契约与现状一致。

    All regression checks passed (206)
    dep_rules ok

## 决策日志

决策：R9 采用“先限制新增回退，再逐步移除旧回退”的双阶段策略，不做一次性硬切。理由：当前 `all_roles/camera_helper/vehicle_helper` 仍在多层模块被读取，直接硬切会造成高回归风险。日期/作者：2026-03-02 / Codex GPT-5。

决策：R9 里程碑只设 3 个（M37-M39），优先保证每步可独立验收。理由：当前主要风险是演进过程中的稳定性，而非缺少重构方向。日期/作者：2026-03-02 / Codex GPT-5。

决策：M37 只加守护（日志+契约+dep_rules），不改变 `RuntimeCompat` 的运行时回退行为。理由：M38 拆分热点时需要稳定的运行时语义；如果 M37 同时收紧 compat 行为（如 context 缺失时 panic），M38 的局部测试可能因为环境差异而产生误报。行为变更留到 R10。日期/作者：2026-03-02 / Review。

决策：`StatusOps.lua`（game core）对 `RuntimeCompat` 的依赖标记为已知过渡状态，不在 R9 强制迁移。理由：迁移需要 game core 获得显式 vehicle 端口注入能力，这超出 R9 的范围。在 dep_rules 中作为白名单注释记录退役条件。日期/作者：2026-03-02 / Review。

## 结果与复盘

当前状态更新为“R9 全部里程碑已完成”。M37 完成兼容回退可观测与 context-first 守护；M38 完成热点文件进一步职责拆分；M39 完成规则与契约接入。最终验证结果：`dep_rules ok`，`All regression checks passed (206)`。

与计划初稿的偏差：M37 原计划使用 `compat_context_first.lua` 命名，实际落地为 `runtime_compat_contract.lua`；M38 原计划文件名是 `GameplayLoopPortDefaults.lua` / `TickTimeoutPolicy.lua`，实际落地为 `GameplayLoopUISyncDefaults.lua` / `TickChoiceTimeout.lua`。偏差仅在命名与拆分边界，不影响目标达成与验收行为。

## 背景与导读

本仓库当前运行方式是：`RuntimeContext`（`src/core/RuntimeContext.lua`）保存运行时上下文并通过 `install_runtime_helper_globals()` 向 4 个全局符号写入（`all_roles`/`ALLROLES`/`vehicle_helper`/`camera_helper`）。`RuntimeCompat`（`src/core/RuntimeCompat.lua`）提供 3 个读取适配函数（`get_roles`/`get_vehicle_helper`/`get_camera_helper`），每个函数先尝试从 `RuntimeContext.current()` 读取，若不存在则回退读全局变量。UI/渲染/交互层已从直读全局迁移到 `RuntimeCompat`，但回退路径仍活跃。

`RuntimeCompat` 当前被 9 个文件调用（共 20+ 处）：

- `src/app/bootstrap/GameStartup.lua` — `get_roles`
- `src/presentation/render/status3d_service/scene.lua` — `get_roles`
- `src/presentation/render/MoveAnim.lua` — `get_vehicle_helper` ×5
- `src/presentation/render/board_runtime/player_units.lua` — `get_roles`
- `src/presentation/render/board_runtime/placement.lua` — `get_vehicle_helper`
- `src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua` — `get_roles`
- `src/presentation/api/UIRuntimePort.lua` — `get_roles`
- `src/presentation/api/presentation_ports/UISyncPorts.lua` — `get_camera_helper`
- `src/game/core/runtime/player_state/StatusOps.lua` — `get_vehicle_helper` ×2

其中 `StatusOps.lua` 位于 `src/game/core/runtime` 下，意味着 game core 层已经依赖 compat 桥。这是一个交叉依赖——如果 M37 收紧 compat 行为（如 context 缺失时 panic），会反向破坏 game core。计划必须在此处谨慎处理。

R9 的核心问题不是"功能正确性"，而是"可维护性与可替换性"：当上下文存在时，代码是否仍意外走全局回退；当继续拆分热点时，是否还能稳定通过回归。为避免语义漂移，R9 要同时推进代码收敛与自动化守护。

涉及关键文件包括上述 9 个调用方，以及：`src/core/RuntimeContext.lua`（全局写入源头）、`src/game/flow/turn/GameplayLoopPorts.lua`（319 行，port 解析与默认值填充）、`src/game/flow/turn/TickTimeout.lua`（244 行，超时策略与引擎）、`src/game/flow/turn/TurnDispatchValidator.lua`（166 行）、`tests/suites/usecase_boundary_contract.lua`、`tests/internal/dep_rules.lua`、`tests/regression.lua`。

## 工作计划

里程碑 M37 的目标是让"兼容回退点"从隐式行为变成显式清单，并用契约测试证明"有 context 时走 context、不回退全局"。完成后会新增一个测试文件 `tests/suites/compat_context_first.lua`，接入回归后基线至少 +3（每个 compat 函数一个断言）。M37 **只加守护，不改 `RuntimeCompat` 的运行时行为**——这确保 M38 热点拆分时不受 compat 语义变化影响。

M37 第一步：在 `src/core/RuntimeCompat.lua` 中为每个 fallback 分支添加一个可选的 warn 日志调用。具体做法是在 `runtime_compat.get_roles()`、`get_vehicle_helper()`、`get_camera_helper()` 三个函数中，当走到全局回退分支时，调用 `logger.warn("[RuntimeCompat]", "global fallback:", "<符号名>")` 发出信号（需在文件头 require `src.core.Logger`）。这不改变行为，只让回退路径可观察。

M37 第二步：新建契约测试文件 `tests/suites/compat_context_first.lua`。核心断言逻辑如下。先 `require("src.core.RuntimeContext")` 并构造一个 context，设置 `ctx.roles = { "from_context" }`；同时向全局写入 `all_roles = { "from_global" }`。然后设置 `runtime_context.set_current(ctx)` 使 context 生效，调用 `runtime_compat.get_roles()` 并断言返回值是 `ctx.roles`（即 `"from_context"`），而非全局值。`get_vehicle_helper` 和 `get_camera_helper` 同理：context 中有值时必须返回 context 版本。每个函数至少一个 "context beats global" 断言和一个 "fallback works when context is nil" 断言。

M37 第三步：将 `compat_context_first` 接入 `tests/regression.lua` 的 suites 列表中 ui_gate_contract 之后。运行全量回归验收。

M37 第四步（可选但推荐）：在 `tests/internal/dep_rules.lua` 的 rules 列表中新增一条规则，禁止 `src/presentation` 目录直接读取全局 `all_roles`/`ALLROLES`/`vehicle_helper`/`camera_helper`（不通过 `RuntimeCompat`），防止新增模块绕过兼容层。匹配模式草案：

    {
      root = "src/presentation",
      forbidden_patterns = {
        "%f[%w_]all_roles%f[^%w_]",
        "%f[%w_]ALLROLES%f[^%w_]",
        "%f[%w_]vehicle_helper%f[^%w_]",
        "%f[%w_]camera_helper%f[^%w_]",
      },
      description = "presentation must use RuntimeCompat instead of direct global reads",
    }

需注意排除 `require` 行中路径字符串内的误匹配——可以把模式限制为非 `require` 行，或用更精确的 boundary。

里程碑 M38 的目标是继续降低 `GameplayLoopPorts`（319 行）和 `TickTimeout`（244 行）的单文件认知负担，同时保持对外 API 不变、调用方零改动。完成后各自至少拆出 1 个职责模块，主文件行数目标下降 60+ 行。

M38 第一步：从 `GameplayLoopPorts.lua` 中拆出 `GameplayLoopPortDefaults.lua`。移动的内容是 `_fill_ui_sync_defaults`（约 80 行，L235-L313）和 `_fill_clock_defaults`（约 15 行，L315-L330）两个函数。新文件导出 `{ fill_ui_sync_defaults, fill_clock_defaults }`。原文件改为 `require` 新模块并调用。`_build_resolved_ports` 中的两行调用从 `_fill_ui_sync_defaults(...)` 改为 `port_defaults.fill_ui_sync_defaults(...)`。拆分后跑 `lua tests/suites/gameplay_loop.lua` + `lua tests/suites/gameplay_runtime.lua` 验证局部通过，再跑全量。

M38 第二步：从 `TickTimeout.lua` 中拆出 `TickTimeoutPolicy.lua`。移动的内容是 `default_policy` 表（L188-L215）、`_clone_policy`（L217-L231）、`step_default_choice`（L237-L250）、`step_default_modal`（L252-L264）。新文件依赖 `TickTimeout`（用于调用 `step_choice_timeout`/`step_modal_timeout` 引擎）和 `TickUIGate`/`TurnChoiceAutoPolicy`。原文件的 `tick_timeout.default_policy`/`step_default_choice`/`step_default_modal` 改为转发到新模块。拆分后同样先跑局部再跑全量。

里程碑 M39 的目标是闭合守护环——确保新增代码不能绕过 compat 层直读全局，且所有新测试接入回归聚合。完成后 `dep_rules` 新增至少 1 条全局读取守护规则，回归基线 `>= 204 + M37 新增条数 + M39 新增条数`。

M39 第一步：在 `dep_rules.lua` 中对 `src/game/core` 目录新增规则，禁止除 `RuntimeCompat.lua` 和 `RuntimeContext.lua` 自身外直接使用 `all_roles`/`ALLROLES`/`vehicle_helper`/`camera_helper` 全局符号。`StatusOps.lua` 当前通过 `RuntimeCompat` 间接访问是合规的，但如果未来有人在 game core 中直接写 `vehicle_helper.xxx()` 就会被拦截。

M39 第二步：为 `StatusOps` 的 compat 依赖添加专项说明——在 `dep_rules.lua` 的注释中标注：`StatusOps` 对 `RuntimeCompat` 的依赖是已知过渡状态，退役条件是"game core 获得显式 vehicle 端口注入后移除"。

M39 第三步：确认所有新增测试（`compat_context_first` 等）已接入 `tests/regression.lua`。运行全量回归，记录最终基线。

## 具体步骤

所有命令在仓库根目录 `c:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先建立 R9 前基线。

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

预期至少出现：

    dep_rules ok
    All regression checks passed (204)

M37 步骤 1：在 `src/core/RuntimeCompat.lua` 文件头添加 `local logger = require("src.core.Logger")`。在 `get_roles()` 的全局回退分支（`if type(all_roles) == "table"` 和 `if type(ALLROLES) == "table"`）前各加一行 `logger.warn("[RuntimeCompat]", "global fallback: all_roles")`。`get_vehicle_helper()` 和 `get_camera_helper()` 同理。改完后跑：

    lua tests/regression.lua

预期不变：`All regression checks passed (204)`。

M37 步骤 2：新建 `tests/suites/compat_context_first.lua`。文件结构如下（伪代码，需适配 TestHarness 格式）：

    local runtime_context = require("src.core.RuntimeContext")
    local runtime_compat = require("src.core.RuntimeCompat")
    -- test: get_roles prefers context over global
    --   set ctx.roles = {"ctx"}, global all_roles = {"global"}
    --   runtime_context.set_current(ctx)
    --   assert runtime_compat.get_roles() == ctx.roles
    -- test: get_roles falls back when context is nil
    --   runtime_context.set_current(nil)
    --   assert runtime_compat.get_roles() == global all_roles
    -- test: get_vehicle_helper prefers context over global
    -- test: get_camera_helper prefers context over global
    -- 每个测试结束后 cleanup: runtime_context.set_current(nil)

M37 步骤 3：在 `tests/regression.lua` 的 suites 列表中 `require("ui_gate_contract")` 之后添加 `require("compat_context_first")`。跑：

    lua tests/regression.lua

预期：`All regression checks passed (>= 206)`（原 204 + 新契约测试接入）。

M37 步骤 4（可选）：在 `tests/internal/dep_rules.lua` 的 `rules` 表中，在 turn flow state.ui 规则之后添加 presentation 全局读取守护规则。跑：

    lua tests/internal/dep_rules.lua

预期：`dep_rules ok`（当前 presentation 层不直读全局，规则应通过）。

M38 步骤 1：新建 `src/game/flow/turn/GameplayLoopPortDefaults.lua`。从 `GameplayLoopPorts.lua` 剪切 `_fill_ui_sync_defaults` 和 `_fill_clock_defaults` 函数到新文件。新文件导出 `{ fill_ui_sync_defaults = ..., fill_clock_defaults = ... }`。原文件在 `_build_resolved_ports` 中将调用改为 `port_defaults.fill_ui_sync_defaults(...)` / `port_defaults.fill_clock_defaults(...)`。跑：

    lua tests/suites/gameplay_loop.lua
    lua tests/suites/gameplay_runtime.lua
    lua tests/regression.lua

预期：全部通过，基线不低于 M37 后的值。

M38 步骤 2：新建 `src/game/flow/turn/TickTimeoutPolicy.lua`。从 `TickTimeout.lua` 剪切 `default_policy` 表、`_clone_policy`、`step_default_choice`、`step_default_modal`。原文件保留 `step_choice_timeout`/`step_modal_timeout` 引擎，并将 `tick_timeout.default_policy`/`step_default_choice`/`step_default_modal` 改为转发到新模块。跑：

    lua tests/suites/gameplay_loop.lua
    lua tests/suites/gameplay_runtime.lua
    lua tests/regression.lua

预期同上。

M39 步骤 1：在 `dep_rules.lua` 的 rules 表中新增"game core 禁止直读全局运行时符号"规则（排除 `RuntimeCompat.lua` 和 `RuntimeContext.lua`）。跑：

    lua tests/internal/dep_rules.lua

预期：`dep_rules ok`。

M39 步骤 2：在 `dep_rules.lua` 中添加注释标注 `StatusOps` 对 `RuntimeCompat` 的已知过渡依赖及退役条件。

M39 步骤 3：最终全量回归。

    lua tests/regression.lua

预期：`All regression checks passed (N)`，N >= 206。

## 验证与验收

M37 验收条件（全部满足方可推进 M38）：
1. `tests/suites/compat_context_first.lua` 存在且至少包含 3 个断言：get_roles/get_vehicle_helper/get_camera_helper 在 context 可用时优先返回 context 值。
2. 该测试文件已出现在 `tests/regression.lua` 的 suites 列表中。
3. 运行 `lua tests/regression.lua` 输出 `All regression checks passed (N)`，N >= 206。
4. `RuntimeCompat.lua` 的 fallback 分支新增了 logger.warn 可观察日志（可选但推荐）。
5. 运行 `lua tests/internal/dep_rules.lua` 输出 `dep_rules ok`。

M38 验收条件：
1. `src/game/flow/turn/GameplayLoopPortDefaults.lua` 存在，包含 `fill_ui_sync_defaults` 和 `fill_clock_defaults`。
2. `src/game/flow/turn/TickTimeoutPolicy.lua` 存在，包含 `default_policy`、`step_default_choice`、`step_default_modal`。
3. `GameplayLoopPorts.lua` 行数下降至 ~240（减少 ~80 行，容许 ±10 行）。
4. `TickTimeout.lua` 行数下降至 ~195（减少 ~50 行，容许 ±10 行）。
5. 所有调用方零改动——对外 API（`gameplay_loop_ports.resolve()`、`tick_timeout.step_choice_timeout/step_modal_timeout/default_policy/step_default_choice/step_default_modal`）签名不变。
6. 运行 `lua tests/regression.lua` 基线不低于 M37 后的值（当前为 206）。

M39 验收条件：
1. `dep_rules.lua` 新增至少 1 条规则，对 `src/presentation` 或 `src/game/core` 中直接读取全局运行时符号（`all_roles`/`ALLROLES`/`vehicle_helper`/`camera_helper`）形成守护。
2. `dep_rules.lua` 中有注释标注 `StatusOps` 的 compat 过渡依赖及退役条件。
3. 运行 `lua tests/internal/dep_rules.lua` 输出 `dep_rules ok`。
4. 运行 `lua tests/regression.lua` 输出 `All regression checks passed (N)`，N >= 206。

## 可重复性与恢复

本计划按里程碑增量执行，可重复。若某步失败，先定位到当前里程碑的文件集，优先做最小回滚与重试；不要跨里程碑混合回滚。保持每次失败后仍能执行回归命令，避免进入“不可验证状态”。

若发现外部运行时差异（例如 Eggy API 行为变化）导致预期不一致，先把证据写入“意外与发现”，再在“决策日志”明确是否调整里程碑范围。

## 产物与备注

实施中持续补充最小证据片段，至少包括：

    [evidence] dep_rules ok
    [evidence] All regression checks passed (N), N >= 206
    [evidence] compat contract: context-first passed (get_roles/get_vehicle_helper/get_camera_helper)

M37 新增文件：`tests/suites/compat_context_first.lua`。
M38 新增文件：`src/game/flow/turn/GameplayLoopPortDefaults.lua`、`src/game/flow/turn/TickTimeoutPolicy.lua`。
M39 修改文件：`tests/internal/dep_rules.lua`（新增规则 + StatusOps 白名单注释）。

## 接口与依赖

R9 期间 `RuntimeCompat` 仍作为统一读取入口存在，但要逐步收紧回退语义。M37 只加守护不改行为；行为变更（如 context 缺失时 panic）留到 R10。`UIGatePort`、`ClockPort` 的现有接口保持稳定，不在本轮破坏。所有验证继续使用现有 Lua 测试工具链，不引入新依赖。

M38 新增模块的导出接口：

`src/game/flow/turn/GameplayLoopPortDefaults.lua` 导出：

    {
      fill_ui_sync_defaults = function(ui_sync_ports, base_ui_sync_ports) end,
      fill_clock_defaults = function(clock_ports, base_clock_ports) end,
    }

`src/game/flow/turn/TickTimeoutPolicy.lua` 导出：

    {
      default_policy = function() -> table end,
      step_default_choice = function(game, state, dt) end,
      step_default_modal = function(game, state, dt) end,
    }

`StatusOps.lua` 对 `RuntimeCompat` 的已知过渡依赖——退役条件：game core 获得显式 vehicle 端口注入能力后，将 `StatusOps` 中的 `runtime_compat.get_vehicle_helper()` 调用替换为端口参数，然后移除 compat 依赖。

---

本次修订说明：基于 `research.md` 的 R9 建议，将 `plan.md` 从 R8 执行收尾文档切换为 R9 可执行计划。这样做的原因是 R8 里程碑已完成，当前主要工作已从“边界纯化”转为“兼容债务清理 + 热点持续瘦身”，需要新的可执行里程碑与验收口径。
修订 2（2026-03-02 Review）：根据评审意见补充以下内容：(1) 背景章节内联 `RuntimeCompat` 完整调用方清单（9 文件 20+ 处）及 `StatusOps` 交叉依赖说明；(2) M37 工作计划细化到文件/函数级，含契约测试设计（context vs global 断言逻辑）和 `dep_rules` 新规则模式草案；(3) M38 标注具体拆分边界（`_fill_ui_sync_defaults` → `GameplayLoopPortDefaults`、`default_policy` → `TickTimeoutPolicy`）及预期行数变化；(4) M39 补充 `StatusOps` 过渡白名单注释与退役条件；(5) 验收条件从描述性改为编号式可检查清单；(6) 决策日志新增 M37 行为冻结和 StatusOps 过渡两条决策；(7) 意外与发现补充热点内部结构分析。修订目的是将计划从"方向书"提升到 PLANS.md 要求的"可执行粒度"。
修订 3（2026-03-02 Execute）：完成 M37-M39 全量实施并回填状态。实际新增：`tests/suites/runtime_compat_contract.lua`、`src/game/flow/turn/GameplayLoopUISyncDefaults.lua`、`src/game/flow/turn/TickChoiceTimeout.lua`，并在 `dep_rules` 增加 app/game/presentation 禁止直接 legacy 全局读取规则。最终回归基线更新为 `206`。
