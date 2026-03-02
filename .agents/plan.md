# R16 代码膨胀收敛执行计划（RuntimePorts 首轮拆分）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 维护，任何执行和范围调整都必须先更新本文件，再继续实施。

## 目的 / 全局视角

这轮工作的目标是把最近两天最突出的膨胀热点 `src/core/RuntimePorts.lua` 做一次可回归验证的收缩拆分，在不改变业务行为的前提下，把“策略管理”和“默认端口实现”从单文件拆开。用户可见结果是游戏行为和测试结果不变；维护者可见结果是热点文件体积下降、职责更聚焦、后续修改冲突减少。

本轮改完后，应该能观察到三个事实：一是 `RuntimePorts.lua` 行数下降；二是 `runtime_ports_contract` 与全量回归仍通过；三是研究文档补充了“已执行收缩动作 + 可量化结果”，而不是停留在建议。

## 进度

- [x] (2026-03-02 22:18 +08:00) 读取 `.agents/harness/PLANS.md` 与当前 `plan/research`，确认本轮范围与验收标准。
- [x] (2026-03-02 22:20 +08:00) 重写本计划为 R16 活文档，补齐必需章节并写入可执行命令。
- [x] (2026-03-02 22:24 +08:00) 拆分 `src/core/RuntimePorts.lua`：新增 `ContextPolicy.lua` 与 `DefaultPorts.lua`，保持对外接口签名不变。
- [x] (2026-03-02 22:25 +08:00) 运行契约测试、依赖规则与全量回归，记录输出证据。
- [x] (2026-03-02 22:27 +08:00) 更新 `.agents/research.md`：补充“执行后结果”和收缩效果。
- [x] (2026-03-02 22:28 +08:00) 回填本计划“结果与复盘”与文档更新记录。

## 意外与发现

- 观察：目前计划文件仍停留在 R15 的完成态，和用户当前“以降膨胀为目标并执行”需求不匹配。
  证据：`.agents/plan.md` 标题与进度均指向 R15，且条目已全完成。

- 观察：最近两天净增最高文件与高频碰撞文件重叠在 `RuntimePorts.lua`，优先拆它能用最小范围验证“降膨胀”策略。
  证据：`.agents/research.md` 的 Top 文件统计与触达频次统计均将其排在首位。

- 观察：`RuntimePorts.lua` 在拆分后从 299 行降到 119 行，单文件热区显著收缩。
  证据：`wc -l src/core/RuntimePorts.lua` 输出从 `299` 变为 `119`。

- 观察：拆分后契约测试与全量回归均通过，说明本轮收缩未改变可观察行为。
  证据：`runtime_ports_contract` 输出 `All regression checks passed (7)`；`lua tests/regression.lua` 输出 `All regression checks passed (213)`。

## 决策日志

- 决策：本轮只做一轮“热点单文件拆分”，不并行改多个模块。
  理由：用户要求“可执行并更新研究文档”，先交付一轮完整闭环（改动-验证-回填）比大范围改造更稳。
  日期/作者：2026-03-02 / Codex

- 决策：保持 `RuntimePorts` 对外函数签名完全不变，拆分仅发生在内部实现。
  理由：能显著降低回归风险，避免牵一发而动全身。
  日期/作者：2026-03-02 / Codex

- 决策：将默认实现函数集中到 `DefaultPorts.build(...)` 返回表，不在 `RuntimePorts` 里保留任何默认实现细节。
  理由：把热点文件定位为“端口入口层”，避免再次因默认实现增长而膨胀。
  日期/作者：2026-03-02 / Codex

## 结果与复盘

本轮已完成一次可验证的降膨胀收缩。具体做法是把 `RuntimePorts.lua` 的策略与默认行为拆到 `src/core/runtime_ports/ContextPolicy.lua` 和 `src/core/runtime_ports/DefaultPorts.lua`，主文件仅保留状态与端口路由。`RuntimePorts.lua` 行数从 299 降到 119，单文件阅读和碰撞面明显下降。

验证方面，`runtime_ports_contract`、`dep_rules`、`regression` 全部通过，说明拆分没有改变既有行为，也未破坏依赖规则。当前仍未处理的膨胀点是 `HostRuntimePort.lua` 与 `ViewCommandDispatcher.lua`，它们应作为下一轮压缩对象。

下一轮建议优先做 `HostRuntimePort` 的角色解析职责外提，再处理 `ViewCommandDispatcher` 中 intent 分发与角色解析耦合问题，继续保持“单热点、可回归”的节奏。

## 背景与导读

`RuntimePorts` 是运行时端口层，对项目多个模块提供调度、角色解析、事件发射和计时能力。这里的“端口”指跨边界调用时的稳定接口；“默认实现”指端口在未注入 mock 或替代实现时使用的具体执行逻辑；“上下文策略”指 strict/legacy 等兼容行为开关。

当前问题不是功能错误，而是单文件过度承载多类职责：一方面管理策略状态（例如 legacy fallback）；另一方面实现大量默认能力函数（例如 resolve_role、emit_event、clock）。这种混合会导致文件持续膨胀、改动碰撞集中、评审成本上升。

本轮涉及的核心文件如下：

`src/core/RuntimePorts.lua`：现有热点文件，需收缩。

`src/core/runtime_ports/ContextPolicy.lua`（新增）：负责策略合法性与 fallback 归一化。

`src/core/runtime_ports/DefaultPorts.lua`（新增）：负责默认端口函数集合。

`tests/suites/runtime_ports_contract.lua`：验证端口契约未回归。

`.agents/research.md`：补充执行后结果和量化指标。

## 工作计划

先拆分，再验证，再回写文档。拆分阶段把 `RuntimePorts.lua` 内与策略相关的纯函数迁移到 `ContextPolicy.lua`，把默认端口实现函数迁移到 `DefaultPorts.lua`，`RuntimePorts.lua` 仅保留状态、注入、路由与对外 API。迁移时保持所有对外函数名和参数不变，避免调用方改动。

随后运行三组验证：第一组是 `runtime_ports_contract`，确认端口行为一致；第二组是 `dep_rules`，确认依赖关系未破坏；第三组是 `regression`，确认整体行为不变。若失败，优先修正拆分引入的问题，不额外扩展范围。

最后更新研究文档，新增“R16 执行结果”段落，写清本轮实际减了什么、还剩什么膨胀风险，以及下一步压缩对象。

## 具体步骤

所有命令在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。

1. 记录改动前体量基线。

    wc -l src/core/RuntimePorts.lua

    预期：输出约 299 行（当前热点状态）。

2. 执行拆分改动（新增模块 + 收缩 RuntimePorts）。

    # 通过编辑器或补丁修改：
    # - 新增 src/core/runtime_ports/ContextPolicy.lua
    # - 新增 src/core/runtime_ports/DefaultPorts.lua
    # - 修改 src/core/RuntimePorts.lua

    预期：`RuntimePorts.lua` 体积明显下降，模块职责更清晰。

3. 运行契约与规则测试。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; local harness = require('TestHarness'); harness.run_all({ require('runtime_ports_contract') })"
    lua tests/internal/dep_rules.lua

    预期：均通过，无新增违规。

4. 运行全量回归。

    lua tests/regression.lua

    预期：全部通过（数量若变化需解释）。

5. 更新研究文档和计划回填。

    # 编辑 .agents/research.md 与 .agents/plan.md

    预期：研究文档包含“执行后结果”，计划四大活文档章节均为最新状态。

## 验证与验收

验收标准是“收缩可量化 + 行为可证明不变”。收缩可量化由 `wc -l` 对比证明；行为不变由 `runtime_ports_contract`、`dep_rules`、`regression` 三组测试共同证明。三项任一失败都视为本轮未完成。

## 可重复性与恢复

本计划步骤可重复执行。若拆分后测试失败，先保留现场并记录到“意外与发现”，再按最小修复原则处理。禁止用破坏性命令回滚工作树。若需要撤销本轮改动，使用新的反向提交而不是改写历史。

## 产物与备注

执行后在此补充关键证据片段：

    拆分后体量：
      - 改动前：299  src/core/RuntimePorts.lua
      - 改动后：119  src/core/RuntimePorts.lua

    runtime_ports_contract：
      .......
      All regression checks passed (7)

    dep_rules：
      dep_rules ok

    regression：
      .....................................................................................................................................................................................................................
      All regression checks passed (213)
      dep_rules ok
      tick ok
      forbidden_globals ok

## 接口与依赖

本轮不引入外部依赖。接口约束如下：

`src/core/RuntimePorts.lua` 对外公开函数名必须保持不变：`configure/install_context_policy/set_legacy_fallback_policy/context_policy/legacy_fallback_policy/rng_next_int/schedule/resolve_role/resolve_roles/mark_role_lose/resolve_vehicle_helper/resolve_camera_helper/emit_event/wall_now_seconds/wall_diff_seconds/cpu_now_seconds/cpu_diff_seconds/reset_for_tests`。

`ContextPolicy.lua` 只处理策略归一化与合法性判断，不依赖 `GameAPI`。

`DefaultPorts.lua` 只实现默认端口行为，通过注入函数读取策略状态，不直接持有策略全局状态。

## 文档更新记录

2026-03-02（本次）：将计划从 R15 切换到 R16，目标改为“执行一次可验证的降膨胀拆分”，并补齐本轮验收标准与步骤。改动原因是用户明确要求“制定可执行计划并执行后更新研究文档”。
2026-03-02（执行回填）：完成 `RuntimePorts` 首轮拆分与验证，新增 `src/core/runtime_ports/ContextPolicy.lua`、`src/core/runtime_ports/DefaultPorts.lua`，并将证据回填到计划。改动原因是把“建议”转成“已执行结果”，满足本轮交付目标。
