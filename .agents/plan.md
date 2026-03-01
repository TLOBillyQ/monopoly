# Monopoly Clean Architecture 边界收敛执行计划（基于 research 评审版）


本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。
本文件必须遵循 `.agents/harness/PLANS.md` 维护，且以 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\.agents\research.md`（含 [R] 评审标注版）为唯一事实输入。

## 目的 / 全局视角


这项工作的目标是把当前“能跑、能测，但边界不够干净”的 Monopoly 代码库，收敛为“核心规则不再直接依赖 Eggy 全局 API，依赖方向可由测试守护，且不再依赖兼容代理转发文件”的状态。当前 M1-M9 已完成，下一阶段将继续收口 `research.md` 复评中剩余的两项缺口：state 跨边界 DTO 化与 `PresentationPorts` 纯适配化。完成后，开发者可以在不启动真实 Eggy 运行时的情况下验证核心用例，并且能够用自动化规则阻止新的架构反向依赖进入主干。

用户可见结果不是新 UI 或新玩法，而是稳定性与可维护性的可观察提升：同样运行 `lua tests/regression.lua` 应继续通过（当前基线 190），同时新增的架构规则测试会明确报告哪些依赖方向被禁止，形成可执行的“完成定义”。

## 进度


- [x] (2026-03-01 06:40Z) 已重读 `.agents/harness/PLANS.md` 与带评审标注的 `.agents/research.md`，完成评审意见内化。
- [x] (2026-03-01 06:44Z) 已将计划重排为“守护测试前置”的执行顺序，并修正依赖计数与风险评估口径。
- [x] (2026-03-01 07:06Z) M1：已扩展 `tests/internal/dep_rules.lua`，新增 `game/core` 全局 API 禁止规则与 `core -> flow` 禁止规则。
- [x] (2026-03-01 07:09Z) M2：已引入 `src/core/RuntimePorts.lua` 并替换 `GameFactory` RNG、`Bankruptcy` lose、`TurnAnim` 定时器直连点。
- [x] (2026-03-01 07:12Z) M3：已将 `PhaseRegistry`/`TurnEngine` 迁移到 `src/game/runtime/`，并调整 `CompositionRoot` 装配引用。
- [x] (2026-03-01 07:18Z) M4：已移除 `PresentationPorts` 对 `TickTimeout/TickUISync` 的反向依赖，恢复 `GameplayLoopPorts` 默认实现承载用例逻辑。
- [x] (2026-03-01 07:20Z) M5：已完成 state 分片首切，在 `GameStartup.build_state` 增加 `ui_runtime/board_runtime/anim_runtime/turn_runtime/debug_runtime` 兼容视图。
- [x] (2026-03-01 07:22Z) M6：已完成全量回归与边界检索验证，当前基线保持 `187` 全绿。
- [x] (2026-03-01 07:36Z) M7：已删除 `src/game/core/runtime/TurnEngine.lua` 与 `PhaseRegistry.lua` 代理，并将 tests 中旧 require 全量改为 `src/game/runtime/*`。
- [x] (2026-03-01 07:39Z) M8：已在 `tests/internal/dep_rules.lua` 新增“禁止代理路径引用 + 禁止代理文件存在”规则，锁定无代理状态。
- [x] (2026-03-01 07:41Z) M9：已完成回归、计划回填与研究文档同步，形成“无兼容代理”新基线。
- [x] (2026-03-01 08:16Z) M10：已将 `game.ui_port` 替换为最小 `ui_runtime_port` DTO（不再整包共享 `state`）。
- [x] (2026-03-01 08:18Z) M11：已将 turn camera follow 判定迁回 `GameplayLoopRuntime`，`PresentationPorts` 仅保留渲染与事件桥接。
- [x] (2026-03-01 08:21Z) M12：已拆分 clock 为 wall/cpu 显式端口并补齐契约测试，回归基线更新为 `190` 全绿。

## 意外与发现


评审指出了一个已被证实的数据误差：目录依赖统计里 `presentation -> game/systems` 实际是 2 条而不是 3 条，因此 `presentation -> game/*` 总数应为 5 条而不是 6 条。这个修正会直接影响后续“依赖减少”验收口径，必须作为固定基线。

评审还确认了 `GameplayLoopPorts` 的 clock 默认实现同时依赖 `GameAPI.get_timestamp` 与 `os.clock` 回退。两者时间语义不同，可能造成测试与生产行为偏差。这意味着后续改造不能只做“语法去依赖”，还要做“时钟语义去歧义”。

另一个关键发现是 state 分片影响面被低估。`state` 并不只在 `GameStartup.lua`、`GameplayLoop.lua`、`UIViewService.lua` 三处使用，而是被 `PresentationPorts`、动画、Board 渲染与交互链路广泛读写。因此该里程碑必须先做字段归属盘点，再做分批迁移。

实施新增发现 1：`TurnEngine`/`PhaseRegistry` 迁移后，`tests/suites/gameplay_coroutine.lua` 仍使用旧路径 require，导致回归首次失败。最终通过兼容代理文件（旧路径转发到新路径）解决，并保持依赖规则不回退。

实施新增发现 2：把 timeout/countdown 逻辑直接内联到 `GameplayLoop` 会破坏端口可覆盖契约，导致两条回归失败。最终改为将默认逻辑放回 `GameplayLoopPorts`，并使用惰性 require 避免 `TurnDispatch -> GameplayLoopPorts -> TickTimeout -> TurnDispatch` 循环依赖。

实施新增发现 3：`src/game/core/runtime/TurnEngine.lua` 与 `PhaseRegistry.lua` 目前是纯转发兼容代理，虽然短期保障了迁移稳定，但会持续制造“旧路径仍可用”的认知噪音，且阻碍 `core/runtime` 职责边界最终收敛。

实施新增发现 4（执行 M10-M12）：`game.ui_port` 在 gameplay 内实际只依赖少数字段与回调（`wait_*`、`pending_choice_elapsed`、`push_popup`、`on_tile_owner_changed`、`board_scene`），可通过代理 DTO 收口而无需共享整包 `state`。

实施新增发现 5（执行 M11）：camera follow 逻辑可拆为“用例层判定 + adapter 桥接触发”，这样 `refresh_from_dirty` 可保持纯渲染职责且不丢运行时行为。

## 决策日志


- 决策：将“扩展架构守护测试”前置为第一里程碑（M1）。
  理由：这是评审一致认为“价值最高、风险最低”的动作，且能为后续每一步提供自动化完成定义，避免边改边漂移。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：把 `presentation -> game/*` 依赖基线固定为 5 条（core 1 / flow 2 / systems 2）。
  理由：评审已复核并纠正原始统计误差，后续验收必须使用修正后的数字以避免虚假进展。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：将 state 分片里程碑风险等级上调为“中等偏高”，并强制加入“字段归属分析”前置任务。
  理由：真实触及面远大于初稿估计，若直接拆分会造成跨层回归噪声，需先做可观测边界映射。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：运行时端口拆分为 `rng_port` 与 `platform_port`，不使用单一大端口。
  理由：评审建议“避免端口过大”；拆分后职责更清晰，也便于独立替换与单测替身。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：保留 `src/game/core/runtime/TurnEngine.lua` 与 `PhaseRegistry.lua` 作为兼容代理（转发到 `src/game/runtime/*`）。
  理由：测试与潜在外部调用仍依赖旧路径；代理可在不违反新依赖规则的前提下平滑迁移。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：`TickTimeout/TickUISync` 默认行为归位到 `GameplayLoopPorts`，而非 `GameplayLoop` 直接调用。
  理由：必须保留端口覆盖能力（测试/自定义端口依赖该契约），否则会造成行为回归。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：将兼容代理转发从“长期兼容”升级为“本轮必须清理”的技术债，新增 M7-M9 专项里程碑。
  理由：代理层已完成过渡使命，继续保留会弱化目录语义并放任旧依赖路径复活。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：依据 `research.md` 最新 `[R2]` 复评，新增 M10-M12 作为第二轮收口里程碑，不将 M9 视为最终终点。
  理由：当前仍有“state 整包跨边界共享”与“adapter 职责过重”两项结构性缺口，若不处理将继续放大后续变更扩散风险。
  日期/作者：2026-03-01 / Codex GPT-5。

## 结果与复盘


M1-M9 已执行完成，且“兼容代理转发彻底清理”已落地：旧路径引用清零、代理文件已删除、并由 dep_rules 永久守护。行为层面保持稳定，`lua tests/regression.lua` 继续通过 187 项且附带 `dep_rules ok / tick ok / forbidden_globals ok`。

第二轮收口 M10-M12 已全部完成：`game.ui_port = state` 清零、`PresentationPorts` 收敛为纯渲染/桥接、clock 端口拆分为 wall/cpu 并通过契约测试。当前行为基线为 `All regression checks passed (190)` 且 `dep_rules ok / tick ok / forbidden_globals ok`。本计划状态更新为“全部完成”。

## 背景与导读


本仓库入口是 `main.lua`，会加载 `src/app/init.lua`，再依次走 `RuntimeInstall`、`GameStartup`、`GameStartupEventBridge`、`UIBootstrap`、`GameRuntimeBootstrap`。其中 `game/core`、`game/flow`、`game/runtime_coroutine` 负责游戏规则与回合推进，`presentation/*` 负责 UI 渲染与交互。

Clean Architecture 在本计划中的含义是：内层规则不应直接依赖外层细节。这里的“外层细节”包括 Eggy 的 `GameAPI`、全局事件函数（如 `SetTimeOut`、`RegisterTriggerEvent`）和具体 UI 状态结构。当前已确认的关键违例点包括：`GameFactory` 直接读 `GameAPI.random_int`、`Bankruptcy` 直接触发 `role.lose()`、`TurnAnim` 直接调用 `SetTimeOut`，以及 `game/core/runtime` 直接依赖 `game/flow` 与 `runtime_coroutine`。

本计划中的“守护测试”指 `tests/internal/dep_rules.lua` 这类依赖规则扫描测试。它不是业务功能测试，而是架构边界测试，用于在 CI 中自动阻止依赖方向回退。

## 工作计划


第一阶段先扩展 `tests/internal/dep_rules.lua`，把“禁止 `src/game/core/**` 直接使用 `GameAPI/GlobalAPI/SetTimeOut/Register*`”与“禁止 `src/game/core/**` 依赖 `src.game.flow.*`”落成可执行规则。这里允许使用临时白名单机制承接迁移期存量违规，但白名单必须显式、可递减。

第二阶段在不改行为的前提下引入端口注入。`GameFactory` 只依赖 `rng_port.next_int`，`Bankruptcy` 通过 `platform_port.resolve_role` 与 `platform_port.mark_role_lose` 访问角色能力，`TurnAnim` 通过 `platform_port.schedule` 驱动延时动作。这样做可以把框架全局集中到 `RuntimeInstall` 一处装配。

第三阶段做目录语义收敛。`PhaseRegistry` 与 `TurnEngine` 已移至 `src/game/runtime/`，`Game.lua` 留在 core 管理状态与规则操作。下一步（M7）不再保留同名代理文件，改为一次性收口旧路径并修正所有调用点。

第四阶段收敛 `PresentationPorts`，把其中携带 use-case 逻辑的部分（尤其 `TickTimeout`、`TickUISync` 的反向耦合）改为由用例层端口契约驱动，adapter 只负责 UI 调用和事件桥接。

第五阶段处理 state 分片，但只做首切：先建立 `state` 字段归属文档，再把最稳定的一组字段迁到子对象并保留旧字段镜像，确保调用方平滑过渡。

第六阶段（M7-M9）专门清理迁移遗留：删除 `src/game/core/runtime/TurnEngine.lua`、`src/game/core/runtime/PhaseRegistry.lua` 两个转发代理，修复 tests 与任何运行时调用的旧 require 路径，并在 dep_rules/检索脚本中新增“禁止代理路径回流”的守护约束。

第七阶段（M10-M12）按复评意见继续收口：先把 `GameplayLoop` 与 `GameStartup` 之间的跨边界状态改为最小 DTO 端口，再把 `PresentationPorts.ui_sync.refresh_from_dirty` 中的流程性判断下沉回 use-case 层，最后拆分并显式化 clock 语义（wall-clock 与 cpu-clock 不再混用 fallback）。

## 具体步骤


以下命令均在工作目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先固定当前基线：

    lua tests/regression.lua

    预期关键输出：
    All regression checks passed (190)
    dep_rules ok
    tick ok
    forbidden_globals ok

执行 M1（守护测试前置）：

    lua tests/internal/dep_rules.lua

    预期关键输出：
    在规则新增前应为 dep_rules ok；新增规则后会先暴露当前违例点，这是预期现象。

执行 M2-M5 每个里程碑后都运行：

    lua tests/regression.lua

并用检索确认目标依赖是否下降：

    (PowerShell) Get-ChildItem -Path src -Recurse -File -Filter '*.lua' | Select-String -Pattern 'GameAPI|SetTimeOut|RegisterTriggerEvent|RegisterCustomEvent'

    (PowerShell) Get-ChildItem -Path src/game/core -Recurse -File -Filter '*.lua' | Select-String -Pattern 'src\.game\.flow\.'

在目录外移阶段补做语法验证：

    lua -e "assert(loadfile('src/game/core/runtime/Game.lua'))"
    lua -e "assert(loadfile('src/game/flow/turn/GameplayLoop.lua'))"

执行 M7（代理彻底清理）：

    (PowerShell) Get-ChildItem -Path src -Recurse -File -Filter '*.lua' | Select-String -Pattern 'src\\.game\\.core\\.runtime\\.(TurnEngine|PhaseRegistry)'

    预期关键输出：
    先命中旧引用；修改后命中为 0。

    lua tests/regression.lua

执行 M8（规则锁定）：

    lua tests/internal/dep_rules.lua

    (PowerShell) Get-ChildItem -Path src -Recurse -File -Filter '*.lua' | Select-String -Pattern 'return require\\(\"src\\.game\\.runtime\\.(TurnEngine|PhaseRegistry)\"\\)'

    预期关键输出：
    dep_rules ok，且代理转发模式命中为 0。

执行 M10（state DTO 收口）：

    (PowerShell) Get-ChildItem -Path src/game/flow/turn -Recurse -File -Filter '*.lua' | Select-String -Pattern 'game\\.ui_port\\s*=\\s*state'

    预期关键输出：
    命中应从 1 下降到 0；改为明确的 `ui_runtime_port`（或同语义）最小接口注入。

    lua tests/regression.lua

执行 M11（PresentationPorts 纯适配化）：

    (PowerShell) Get-ChildItem -Path src/presentation/api -Recurse -File -Filter '*.lua' | Select-String -Pattern 'refresh_from_dirty'

    预期关键输出：
    `PresentationPorts` 仅保留渲染/桥接调用，不再承载复杂流程判断分支。

    lua tests/regression.lua

执行 M12（clock 语义收口）：

    (PowerShell) Get-ChildItem -Path src/game/flow/turn -Recurse -File -Filter '*.lua' | Select-String -Pattern 'os\\.clock|GameAPI\\.get_timestamp_diff|GameAPI\\.get_timestamp'

    预期关键输出：
    wall-clock 与 cpu-clock 接口分离，默认路径不再混用语义不同的 fallback。

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

## 验证与验收


验收必须同时满足行为与边界两类证据。行为证据是 `lua tests/regression.lua` 持续通过且基线不下降（当前为 190）。边界证据是新增依赖规则在 CI 中稳定执行，并且对 P0/P1 违例提供明确失败信息。

里程碑验收口径如下。M1 完成时，守护规则已生效并能检测到现存违例；M2 完成时，`GameFactory`、`Bankruptcy`、`TurnAnim` 不再直接触达框架全局；M3 完成时，`game/core/runtime` 不再直接依赖 `game/flow` 与 `runtime_coroutine`；M4 完成时，`PresentationPorts` 不再反向携带 use-case 细节；M5 完成时，state 首批分片上线且回归不变；M7 完成时，兼容代理文件被删除且旧 require 路径清零；M8 完成时，规则锁定并可防止代理回流；M9 完成时，回归保持 187 全绿并完成文档回填；M10 完成时，`game.ui_port = state` 整包共享清零并由最小 DTO 端口替代；M11 完成时，`PresentationPorts` 收敛为纯 adapter；M12 完成时，clock 语义分离并通过契约/回归验证（当前基线 190）。

## 可重复性与恢复


本计划按增量里程碑设计，可重复执行。若某一步失败，先恢复到上一个“回归全绿 + 规则通过”的提交点，再局部重做当前里程碑，禁止跨里程碑混合修复。

守护规则引入后，如果一次性暴露违规过多，可通过白名单临时放行，但白名单条目必须带到期清理目标，并在后续提交中逐条删除。任何涉及文件搬迁的改动都应保留兼容代理文件一段时间，待检索确认无调用后再退役。

针对 M7：若删除代理后出现加载失败，优先修复调用点而不是恢复代理文件。只有在“无法定位调用来源且阻断主流程”的情况下，才允许短暂回滚代理，并必须在同一次修订中记录阻断原因与下一次移除日期。

## 产物与备注


本计划执行后应至少产出三类工件：第一是更新后的 `tests/internal/dep_rules.lua`（含新增规则与必要白名单机制）；第二是运行时端口装配与调用替换相关改动；第三是更新后的 `.agents/research.md` 与本计划文档中的进度、发现、决策、复盘回填记录。

证据记录只保留关键片段，重点展示两件事：回归持续通过，以及新增边界规则在迁移前后的差异表现。

新增产物要求：M7-M9 结束时必须包含“代理清理证据”，至少包括一次旧路径检索清零输出与一次 dep_rules + regression 双通过输出。

新增产物要求（M10-M12）：必须新增“边界收口证据”，至少包括一次 `game.ui_port = state` 清零检索输出、一次 `PresentationPorts` 纯 adapter 说明片段、以及一次 clock 语义分离后的契约测试结果。

## 接口与依赖


M2 完成后，代码中必须存在可被替换的端口接口语义。`rng_port` 至少提供 `next_int(min, max)`。`platform_port` 至少提供 `schedule(delay, fn)`、`resolve_role(player_id)`、`mark_role_lose(role)`、`emit_event(name, payload)` 中本仓库实际需要的子集。端口定义可以是 Lua table 约定，不强制 class。

`RuntimeInstall` 负责把 Eggy 全局能力绑定到这些端口，并向用例层注入。`game/core` 与 `game/flow` 代码不得再新增对 `GameAPI/SetTimeOut/Register*` 的直接依赖。`tests/internal/dep_rules.lua` 中的规则文本必须与此约束保持一致，避免“规范说一套、测试查另一套”。

M7 之后，`src/game/core/runtime/TurnEngine.lua` 与 `src/game/core/runtime/PhaseRegistry.lua` 不应再存在。所有调用方应直接依赖 `src/game/runtime/TurnEngine.lua` 与 `src/game/runtime/PhaseRegistry.lua`。

M10 之后，`game` 与 `presentation` 之间应通过最小端口 DTO 交互，不应继续共享整个 `state` 表作为 `ui_port`。

## 本次修订记录


- 修订：重写 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\.agents\plan.md`，将评审意见完整内化到执行顺序、基线口径、风险评估和接口拆分策略。
  原因：用户要求“整理内化评审意见，并按 PLANS 格式写入 plan.md”。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：回填 M1-M6 实际执行结果，补充实施过程中的失败样例与修复决策，并将计划状态更新为完成。
  原因：用户要求“执行计划到结束，不要停下来”；计划需作为活文档反映最终真实状态。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：新增 M7-M9，明确“兼容代理转发临时处理彻底重构”的执行路径、验收标准与恢复策略。
  原因：用户要求“更新计划，将执行过程中的兼容代理转发临时处理彻底重构”。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：回填 M7-M9 实施结果（删除代理、规则锁定、双重验证通过），并将计划状态更新为全部完成。
  原因：用户要求“执行到底，不要停下来”；计划需反映最终交付状态。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：根据 `research.md` 最新 `[R2]` 复评追加 M10-M12 新阶段，覆盖 state DTO 收口、adapter 纯化与 clock 语义分离。
  原因：用户要求“根据最新的 research.md，追加新阶段到 plan.md 中”。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：回填 M10-M12 实施结果（ui_runtime DTO、camera follow 判定迁回 use-case、clock wall/cpu 端口分离与契约测试），并将计划状态更新为全部完成。
  原因：用户要求“执行所有计划”。
  日期/作者：2026-03-01 / Codex GPT-5。
