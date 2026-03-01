# Monopoly Clean Architecture 边界收敛执行计划（基于 research 评审版）


本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。
本文件必须遵循 `.agents/harness/PLANS.md` 维护，且以 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\.agents\research.md`（含 [R] 评审标注版）为唯一事实输入。

## 目的 / 全局视角


这项工作的目标是把当前“能跑、能测，但边界不够干净”的 Monopoly 代码库，收敛为“核心规则不再直接依赖 Eggy 全局 API，依赖方向可由测试守护”的状态。完成后，开发者可以在不启动真实 Eggy 运行时的情况下验证核心用例，并且能够用自动化规则阻止新的架构反向依赖进入主干。

用户可见结果不是新 UI 或新玩法，而是稳定性与可维护性的可观察提升：同样运行 `lua tests/regression.lua` 应继续通过（当前基线 187），同时新增的架构规则测试会明确报告哪些依赖方向被禁止，形成可执行的“完成定义”。

## 进度


- [x] (2026-03-01 06:40Z) 已重读 `.agents/harness/PLANS.md` 与带评审标注的 `.agents/research.md`，完成评审意见内化。
- [x] (2026-03-01 06:44Z) 已将计划重排为“守护测试前置”的执行顺序，并修正依赖计数与风险评估口径。
- [ ] M1：先落地架构守护测试（禁止 `game/core` 直连全局 API，禁止 `game/core -> game/flow`）。
- [ ] M2：引入运行时端口并替换 P0 直连点（`GameFactory` RNG、`Bankruptcy` lose、`TurnAnim` 定时器）。
- [ ] M3：将 `PhaseRegistry` 与 `TurnEngine` 从 `game/core/runtime` 语义外移，清除 7 条反向依赖。
- [ ] M4：收敛 `PresentationPorts` 职责，去除 adapter 对 use-case 细节的反向引用。
- [ ] M5：做 state 分片的低风险首切，建立字段归属并保持兼容镜像。
- [ ] M6：全量回归、文档回填、形成可复用的后续迭代基线。

## 意外与发现


评审指出了一个已被证实的数据误差：目录依赖统计里 `presentation -> game/systems` 实际是 2 条而不是 3 条，因此 `presentation -> game/*` 总数应为 5 条而不是 6 条。这个修正会直接影响后续“依赖减少”验收口径，必须作为固定基线。

评审还确认了 `GameplayLoopPorts` 的 clock 默认实现同时依赖 `GameAPI.get_timestamp` 与 `os.clock` 回退。两者时间语义不同，可能造成测试与生产行为偏差。这意味着后续改造不能只做“语法去依赖”，还要做“时钟语义去歧义”。

另一个关键发现是 state 分片影响面被低估。`state` 并不只在 `GameStartup.lua`、`GameplayLoop.lua`、`UIViewService.lua` 三处使用，而是被 `PresentationPorts`、动画、Board 渲染与交互链路广泛读写。因此该里程碑必须先做字段归属盘点，再做分批迁移。

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

## 结果与复盘


当前计划阶段尚未开始代码实施；本次完成的是“评审意见内化 + 计划重构”。与初稿相比，新的计划把顺序改为“先测试守护，再改实现边界”，并修正了所有已确认的口径问题。这样做的直接收益是后续每个里程碑都可以用同一套约束验证，减少返工概率。

后续复盘将重点对照两个目标：第一，回归基线 187 是否保持；第二，新增架构规则是否真的阻止了 P0/P1 类型的反向依赖回流。

## 背景与导读


本仓库入口是 `main.lua`，会加载 `src/app/init.lua`，再依次走 `RuntimeInstall`、`GameStartup`、`GameStartupEventBridge`、`UIBootstrap`、`GameRuntimeBootstrap`。其中 `game/core`、`game/flow`、`game/runtime_coroutine` 负责游戏规则与回合推进，`presentation/*` 负责 UI 渲染与交互。

Clean Architecture 在本计划中的含义是：内层规则不应直接依赖外层细节。这里的“外层细节”包括 Eggy 的 `GameAPI`、全局事件函数（如 `SetTimeOut`、`RegisterTriggerEvent`）和具体 UI 状态结构。当前已确认的关键违例点包括：`GameFactory` 直接读 `GameAPI.random_int`、`Bankruptcy` 直接触发 `role.lose()`、`TurnAnim` 直接调用 `SetTimeOut`，以及 `game/core/runtime` 直接依赖 `game/flow` 与 `runtime_coroutine`。

本计划中的“守护测试”指 `tests/internal/dep_rules.lua` 这类依赖规则扫描测试。它不是业务功能测试，而是架构边界测试，用于在 CI 中自动阻止依赖方向回退。

## 工作计划


第一阶段先扩展 `tests/internal/dep_rules.lua`，把“禁止 `src/game/core/**` 直接使用 `GameAPI/GlobalAPI/SetTimeOut/Register*`”与“禁止 `src/game/core/**` 依赖 `src.game.flow.*`”落成可执行规则。这里允许使用临时白名单机制承接迁移期存量违规，但白名单必须显式、可递减。

第二阶段在不改行为的前提下引入端口注入。`GameFactory` 只依赖 `rng_port.next_int`，`Bankruptcy` 通过 `platform_port.resolve_role` 与 `platform_port.mark_role_lose` 访问角色能力，`TurnAnim` 通过 `platform_port.schedule` 驱动延时动作。这样做可以把框架全局集中到 `RuntimeInstall` 一处装配。

第三阶段做目录语义收敛。`PhaseRegistry` 与 `TurnEngine` 移至 use-case 层（建议 `src/game/flow/runtime/` 或 `src/game/flow/turn/`），`Game.lua` 留在 core 仅管理状态与规则操作。为降低风险，可保留同名代理文件一段时间，让 `require` 路径兼容。

第四阶段收敛 `PresentationPorts`，把其中携带 use-case 逻辑的部分（尤其 `TickTimeout`、`TickUISync` 的反向耦合）改为由用例层端口契约驱动，adapter 只负责 UI 调用和事件桥接。

第五阶段处理 state 分片，但只做首切：先建立 `state` 字段归属文档，再把最稳定的一组字段迁到子对象并保留旧字段镜像，确保调用方平滑过渡。

## 具体步骤


以下命令均在工作目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先固定当前基线：

    lua tests/regression.lua

    预期关键输出：
    All regression checks passed (187)
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

## 验证与验收


验收必须同时满足行为与边界两类证据。行为证据是 `lua tests/regression.lua` 持续通过且基线不下降（当前为 187）。边界证据是新增依赖规则在 CI 中稳定执行，并且对 P0/P1 违例提供明确失败信息。

里程碑验收口径如下。M1 完成时，守护规则已生效并能检测到现存违例；M2 完成时，`GameFactory`、`Bankruptcy`、`TurnAnim` 不再直接触达框架全局；M3 完成时，`game/core/runtime` 不再直接依赖 `game/flow` 与 `runtime_coroutine`；M4 完成时，`PresentationPorts` 不再反向携带 use-case 细节；M5 完成时，state 首批分片上线且回归不变。

## 可重复性与恢复


本计划按增量里程碑设计，可重复执行。若某一步失败，先恢复到上一个“回归全绿 + 规则通过”的提交点，再局部重做当前里程碑，禁止跨里程碑混合修复。

守护规则引入后，如果一次性暴露违规过多，可通过白名单临时放行，但白名单条目必须带到期清理目标，并在后续提交中逐条删除。任何涉及文件搬迁的改动都应保留兼容代理文件一段时间，待检索确认无调用后再退役。

## 产物与备注


本计划执行后应至少产出三类工件：第一是更新后的 `tests/internal/dep_rules.lua`（含新增规则与必要白名单机制）；第二是运行时端口装配与调用替换相关改动；第三是更新后的 `.agents/research.md` 与本计划文档中的进度、发现、决策、复盘回填记录。

证据记录只保留关键片段，重点展示两件事：回归持续通过，以及新增边界规则在迁移前后的差异表现。

## 接口与依赖


M2 完成后，代码中必须存在可被替换的端口接口语义。`rng_port` 至少提供 `next_int(min, max)`。`platform_port` 至少提供 `schedule(delay, fn)`、`resolve_role(player_id)`、`mark_role_lose(role)`、`emit_event(name, payload)` 中本仓库实际需要的子集。端口定义可以是 Lua table 约定，不强制 class。

`RuntimeInstall` 负责把 Eggy 全局能力绑定到这些端口，并向用例层注入。`game/core` 与 `game/flow` 代码不得再新增对 `GameAPI/SetTimeOut/Register*` 的直接依赖。`tests/internal/dep_rules.lua` 中的规则文本必须与此约束保持一致，避免“规范说一套、测试查另一套”。

## 本次修订记录


- 修订：重写 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\.agents\plan.md`，将评审意见完整内化到执行顺序、基线口径、风险评估和接口拆分策略。
  原因：用户要求“整理内化评审意见，并按 PLANS 格式写入 plan.md”。
  日期/作者：2026-03-01 / Codex GPT-5。
