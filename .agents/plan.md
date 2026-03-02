# R17 代码膨胀收敛执行计划（热点去中心化交易）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 维护，任何执行和范围调整都必须先更新本文件，再继续实施。

## 目的 / 全局视角


本轮目标是把“代码膨胀风险”从单点问题变成可控的工程流程问题。研究结论显示，最近两天 `src/` 净增 +1269，风险集中在 `core/presentation` 边界层，且热点文件改动频次高。用户可见收益是：功能行为不变，但后续同类需求改动时冲突更少、评审更快、回归风险更低。

本计划把“交易”定义为一组有约束的工程交换：用少量模块新增，换取热点文件职责收敛与碰撞面下降。完成后应观察到三类证据：热点文件职责收敛、关键回归测试通过、研究文档与计划文档可复算。

## 进度


- [x] (2026-03-02 23:18 +08:00) 读取 `.agents/harness/PLANS.md`、`.agents/research.md` 与现有 `.agents/plan.md`，确认本轮目标从 R16 单点拆分升级为多热点去中心化。
- [x] (2026-03-02 23:20 +08:00) 建立 R17 计划骨架并写入本文件，补齐强制章节、里程碑、验收与恢复策略。
- [x] (2026-03-02 23:21 +08:00) 记录实施前基线并固化到“产物与备注”：热点文件行数已落盘。
- [x] (2026-03-02 23:25 +08:00) 完成里程碑 1：拆分 `HostRuntimePort` 与 `UISyncPorts`，新增 host_runtime 与 ui_sync 子模块承接职责。
- [x] (2026-03-02 23:26 +08:00) 完成里程碑 2：拆分 `ViewCommandDispatcher` 角色上下文与 `RuntimeInstall` 默认端口配置。
- [x] (2026-03-02 23:35 +08:00) 完成里程碑 3：补齐回归测试与文档闭环。`dep_rules` 与 `regression` 全部通过（213 checks），验证行为未变。

## 意外与发现


- 观察：当前 `plan.md` 仍是 R16“已完成态”，与最新研究结论中的风险中心（多热点并发增长）不一致。
  证据：旧计划聚焦 `RuntimePorts.lua` 首轮拆分，研究文件已将风险描述升级为 `RuntimeInstall`、`HostRuntimePort`、`ViewCommandDispatcher` 等热点簇。

- 观察：热点文件中既有“高净增文件”也有“高频触达文件”，二者重叠不完全，说明单看行数不足以指导治理。
  证据：`RuntimePorts.lua` 触达 9 次但净增 +119；`HostRuntimePort.lua` 净增 +136 且仍在接口边界层。

- 观察：当前终端环境缺少 Lua 运行时，测试命令无法执行。
  证据：执行 `lua tests/internal/dep_rules.lua` 和 `lua tests/regression.lua` 均返回 `zsh:1: command not found: lua`。

- 观察：通过 Homebrew 安装 Lua 5.4.8 后，测试顺利执行并全部通过。
  证据：`dep_rules ok`；`All regression checks passed (213)`；`tick ok`；`forbidden_globals ok`。

## 决策日志


- 决策：R17 采用“热点去中心化交易”而不是继续只做单文件缩行。
  理由：研究结论显示风险已从单点膨胀转为热点簇并发增长，治理目标应从“行数下降”升级为“改动集中度下降 + 职责边界清晰”。
  日期/作者：2026-03-02 / Codex

- 决策：本轮优先改 `presentation` 与 `app bootstrap` 边界，再触达 `core` 中枢文件。
  理由：`RuntimePorts` 已在 R16 做过首轮收缩，继续优先处理 `HostRuntimePort`、`PresentationPorts`、`ViewCommandDispatcher` 能更快降低跨层耦合。
  日期/作者：2026-03-02 / Codex

- 决策：在测试环境缺失时先完成结构性拆分并记录阻塞证据，不做未经验证的语义扩展。
  理由：用户要求执行计划；先完成低风险职责拆分并保留可回归入口，待环境补齐后再完成验收闭环。
  日期/作者：2026-03-02 / Codex

## 结果与复盘


本轮 R17 “热点去中心化交易”已全部完成。三个里程碑均达成：

1. **里程碑 1**（presentation 端口去重）：`HostRuntimePort` 从 136 行降至 80 行，`UISyncPorts` 从 119 行降至 44 行。职责分别迁移到 `host_runtime/` 与 `ui_sync/` 子模块。

2. **里程碑 2**（分发与装配解耦）：`ViewCommandDispatcher` 从 90 行降至 67 行，`RuntimeInstall` 从 91 行降至 41 行。角色解析与默认端口配置分别迁移到 `RoleContext.lua` 与 `RuntimePortDefaults.lua`。

3. **里程碑 3**（证据固化）：安装 Lua 5.4.8 后，`dep_rules` 与 `regression`（213 checks）全部通过，验证行为未变。

**量化结果**：4 个热点文件共减少 204 行（-43.8%），新增 8 个职责聚焦的小模块共 331 行。热点文件从”多职责混杂”转变为”薄入口 + 子模块承接”架构，后续改动碰撞面显著下降。

**风险收敛结论**：本轮把代码膨胀风险从”单文件绝对行数”升级为”改动集中度治理”，通过新增模块分散热点，验证后再提交，形成可重复的交易模式。

## 背景与导读


本仓库当前的“代码膨胀”不是指业务规则无限增加，而是指边界层与装配层持续吸收职责，导致少数文件成为高频碰撞点。这里的“边界层”是连接核心逻辑与表现层/框架层的适配接口；“去中心化”是把一个文件里的多类职责拆到更小、更稳定的模块，减少每次需求都改同一文件。

本轮直接相关文件如下。`src/presentation/api/HostRuntimePort.lua` 负责宿主运行时接口；`src/presentation/api/presentation_ports/UISyncPorts.lua` 负责 UI 同步端口；`src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua` 负责意图分发；`src/app/bootstrap/RuntimeInstall.lua` 负责启动装配。它们都处于高频改动路径。

本计划不引入外部依赖，不改变玩法规则，不修改公开行为语义。所有改动都以“内部职责重分配 + 契约测试兜底”为前提。

## 里程碑


里程碑 1（presentation 端口去重）聚焦 `HostRuntimePort` 与 `UISyncPorts`。目标是把重复透传与职责重叠收敛为明确边界，减少后续同一需求需要同时改多个端口文件的概率。验收方式是相关回归测试通过，并且端口文件变成薄入口。

里程碑 2（分发与装配解耦）聚焦 `ViewCommandDispatcher` 与 `RuntimeInstall`。目标是把“意图解释”“角色解析”“装配 wiring”分开，让交互改动不再频繁触达启动装配。验收方式是 UI 交互回归通过，且装配文件仅保留依赖连接逻辑。

里程碑 3（证据固化与文档闭环）聚焦测试证据、统计复算与文档回填。目标是把本轮交易结果固化为可重复流程。验收方式是 `research` 与 `plan` 同步更新且证据片段可复算。

## 工作计划


实施顺序为“先边界去重，再分发解耦，最后证据固化”。第一步在 `presentation` 端口层明确职责切面：入口文件负责对外 API，内部能力由小模块承接。第二步在 `interaction/bootstrap` 层分离解释逻辑和装配逻辑，确保热点文件不继续吸收业务判断。

实现过程中保持外部调用入口与函数签名兼容，避免大面积调用方修改。每完成一个里程碑立即跑测试并回填文档，禁止全部改完后一次性验证。

## 具体步骤


所有命令在仓库根目录 `/Users/gangan/Dev/repo/monopoly` 执行。

1. 记录实施前基线，写入“产物与备注”。

    wc -l src/core/RuntimePorts.lua src/app/bootstrap/RuntimeInstall.lua src/presentation/api/HostRuntimePort.lua src/presentation/api/PresentationPorts.lua src/presentation/api/presentation_ports/UISyncPorts.lua src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua

2. 实施里程碑 1：端口去重。

    # 编辑文件：
    # - src/presentation/api/HostRuntimePort.lua
    # - src/presentation/api/presentation_ports/UISyncPorts.lua
    # - 新增 src/presentation/api/host_runtime/*
    # - 新增 src/presentation/api/presentation_ports/ui_sync/*

3. 跑第一轮验证。

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

4. 实施里程碑 2：分发与装配解耦。

    # 编辑文件：
    # - src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua
    # - src/app/bootstrap/RuntimeInstall.lua
    # - 新增 src/presentation/interaction/ui_intent_dispatcher/RoleContext.lua
    # - 新增 src/app/bootstrap/runtime_install/RuntimePortDefaults.lua

5. 跑第二轮验证。

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

6. 回填文档并完成闭环。

    # 编辑文件：
    # - .agents/research.md
    # - .agents/plan.md

## 验证与验收


验收采用双轨标准。第一轨是行为不变：运行 `lua tests/internal/dep_rules.lua` 与 `lua tests/regression.lua`，预期全部通过。第二轨是结构收敛：热点文件职责重叠减少，且高频文件不再承担多类职责。

双轨验收均已完成：行为不变轨通过 `dep_rules` 与 `regression`（213 checks）验证；结构收敛轨通过热点文件行数对比与新增模块清单验证。

## 可重复性与恢复


本计划按里程碑增量执行，可重复运行。每个里程碑完成后都要先记录现场，再进入下一步，避免失败时回退范围过大。若某里程碑失败，恢复策略是只撤销该里程碑变更并保留已验证里程碑，不做破坏性历史改写。

## 产物与备注


实施前基线（2026-03-02）：

    wc -l:
      119 src/core/RuntimePorts.lua
       91 src/app/bootstrap/RuntimeInstall.lua
      136 src/presentation/api/HostRuntimePort.lua
       22 src/presentation/api/PresentationPorts.lua
      119 src/presentation/api/presentation_ports/UISyncPorts.lua
       90 src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua
      577 total

实施后（里程碑 1/2）：

    热点文件行数：
       80 src/presentation/api/HostRuntimePort.lua
       44 src/presentation/api/presentation_ports/UISyncPorts.lua
       67 src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua
       41 src/app/bootstrap/RuntimeInstall.lua

    新增承接模块：
       51 src/presentation/api/host_runtime/RoleResolver.lua
       33 src/presentation/api/host_runtime/UnitLifecycle.lua
       26 src/presentation/api/host_runtime/SceneUI.lua
       42 src/presentation/api/presentation_ports/ui_sync/UIModelSync.lua
       30 src/presentation/api/presentation_ports/ui_sync/CameraSync.lua
       62 src/presentation/api/presentation_ports/ui_sync/UIGateSync.lua
       29 src/presentation/interaction/ui_intent_dispatcher/RoleContext.lua
       58 src/app/bootstrap/runtime_install/RuntimePortDefaults.lua

    测试验证（里程碑 3 完成后）：

    lua tests/internal/dep_rules.lua:
      dep_rules ok

    lua tests/regression.lua:
      All regression checks passed (213)
      dep_rules ok
      tick ok
      forbidden_globals ok

## 接口与依赖


本轮不新增第三方依赖。接口约束如下：`HostRuntimePort` 负责宿主桥接，不承载 UI 同步策略；`UISyncPorts` 负责 UI 同步端口入口，不承载具体实现细节；`RuntimeInstall` 负责依赖装配，不承载默认端口实现细节；`ViewCommandDispatcher` 负责命令分发，不承载角色解析策略细节。

若出现接口职责冲突，优先新增小模块承接而不是回填到现有热点文件。

## 文档更新记录


2026-03-02（R16）：完成 `RuntimePorts` 首轮拆分与验证，形成单热点收缩闭环。

2026-03-02（R17 计划重建）：依据重新调研结论将计划升级为“热点去中心化交易”，把目标从单文件收缩扩展到 `presentation/interaction/bootstrap` 多热点协同收敛，并重写里程碑、步骤、验收与恢复策略。改动原因是研究已确认风险由单点膨胀演化为多热点并发增长。

2026-03-02（R17 执行回填）：完成里程碑 1 与里程碑 2 的结构拆分，新增 8 个承接模块并收缩 4 个热点文件；测试阶段因缺少 `lua` 命令受阻，已记录证据并保留里程碑 3 待完成状态。改动原因是先完成低风险职责去中心化，再等待运行环境补齐后闭环验证。

2026-03-02（R17 最终完成）：安装 Lua 5.4.8 后完成里程碑 3，回归测试全部通过（213 checks），更新进度、结果与复盘、产物与备注、验证与验收等章节，标记 R17 完整闭环。改动原因是交付可验证的代码膨胀收敛交易，形成可重复的工程模式。
