# R15 Legacy 收口与 RuntimePorts 拆分执行计划

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件遵循 `.agents/harness/PLANS.md` 维护，任何执行或范围调整都必须先同步更新本文件，再继续实施。


## 目的 / 全局视角

这轮工作的目标是把“阶段性兼容”继续压缩成“最小可控入口”，并把 `RuntimePorts` 从“多职责聚合点”拆回“清晰边界接口”。对用户可见的结果是：游戏行为不变、回归测试持续全绿，但内部调用路径更短、更稳定，后续退役 legacy 代码时不再需要大范围联动改动。

本轮完成后，应能通过检索看到 legacy 入口进一步减少，通过契约测试证明 `RuntimePorts` 仍满足现有调用方，通过全量回归证明功能无回归。也就是说，用户看不到行为变化，但维护者可以更快定位问题、更安全地删除兼容代码。

## 进度

- [x] (2026-03-02 10:45 +08:00) 重新建立本轮计划文档骨架，并对齐 `.agents/harness/PLANS.md` 必需章节。
- [x] (2026-03-02 21:02 +08:00) 盘点并分类 `context_policy`、`enable_legacy_helper_fallback`、`set_legacy_fallback_policy(` 的现存调用点，形成“保留/迁移/删除”清单（见“产物与备注”）。
- [x] (2026-03-02 21:04 +08:00) 在 `src/app/bootstrap/RuntimeInstall.lua` 收口 legacy 入口：改为单点 `runtime_ports.install_context_policy(...)` 安装策略。
- [x] (2026-03-02 21:05 +08:00) 在 `src/core/RuntimePorts.lua` 完成职责拆分：新增上下文策略安装入口并将策略解析从默认端口实现中抽离。
- [x] (2026-03-02 21:06 +08:00) 同步更新并补强 `tests/suites/runtime_ports_contract.lua`，新增策略安装入口契约覆盖。
- [x] (2026-03-02 21:07 +08:00) 复核 `tests/internal/dep_rules.lua` 治理效果：规则已覆盖 legacy 策略扩散场景，本轮无需新增规则。
- [x] (2026-03-02 21:09 +08:00) 执行回归与检索验收，记录证据到“产物与备注”。
- [x] (2026-03-02 21:13 +08:00) 提交代码并回填“结果与复盘”与文档更新记录。

## 意外与发现

- 观察：上一轮清理后，`forward_eca_event_*` 与全局 legacy 开关已清零，但 policy 型 legacy 入口仍集中在 Runtime 安装与端口层，说明“语义兼容”已从 API 层转移到策略层。
  证据：`rg "context_policy|enable_legacy_helper_fallback|set_legacy_fallback_policy\\(" src tests -n` 仍有命中。

- 观察：`.agents/plan.md` 在本次改写前处于缺失状态，属于流程风险点（执行无法继续追踪）。
  证据：`Test-Path .agents/plan.md` 返回 `False`。

- 观察：`runtime_ports_contract` 不能直接使用 `lua tests/suites/runtime_ports_contract.lua` 运行，需要先补充 `package.path` 并通过 `TestHarness` 加载 suite。
  证据：直接运行时报错 `module 'TestSupport' not found`，改用 `lua -e "package.path=...; require('TestHarness').run_all({require('runtime_ports_contract')})"` 后通过。

- 观察：全量回归通过数从“约 210”提升到 213，主要由近期 suite 增量导致；本轮新增 1 个 `runtime_ports_contract` 用例属于预期增长。
  证据：`lua tests/regression.lua` 输出 `All regression checks passed (213)`。

## 决策日志

- 决策：本轮先做“收口 + 拆分 + 防护折叠”的小步闭环，不直接一次性删除全部 legacy policy 分支。
  理由：当前回归面较大，先把入口集中和职责拆干净，再做最终退役，风险更低且更易验证。
  日期/作者：2026-03-02 / Codex

- 决策：把规则治理（`dep_rules`）与实现改动同批推进，而不是最后补。
  理由：治理规则晚于实现落地会出现短窗口回退风险；同批推进可把“禁止扩散”前置为默认行为。
  日期/作者：2026-03-02 / Codex

- 决策：在 `RuntimePorts` 新增 `install_context_policy`，并让 `RuntimeInstall` 只调用该入口，不再直接拼装 legacy fallback 表。
  理由：把“策略解析”与“端口默认实现”解耦后，后续退役 legacy 只需替换策略入口，避免安装层和端口层重复分支。
  日期/作者：2026-03-02 / Codex

## 结果与复盘

本轮改动已完成“收口 + 拆分 + 验证”闭环。`RuntimeInstall` 从“本地拼装 legacy policy”改为“单点安装上下文策略”，`RuntimePorts` 新增 `install_context_policy` 与 `context_policy` 可观测接口，把策略解析独立出来，默认端口函数继续保持签名不变。`runtime_ports_contract` 新增策略安装契约测试，`dep_rules` 与全量回归均通过。

全部计划项已完成并提交。风险变化方面，legacy 策略入口已从分散调用压缩为单点调用，回归通过说明行为未变；剩余风险是 `set_legacy_fallback_policy` 仍被测试支持代码使用，需在最终退役阶段评估是否收敛到测试专用 API。

## 背景与导读

本仓库是 Lua 项目，运行时入口与核心逻辑分层组织。这里的 “legacy” 指为了兼容历史调用保留的策略或路径；“收口”指把多个分散入口合并成单点入口，减少扩散；“RuntimePorts” 指运行时对外提供的端口接口层，理想状态只表达能力契约，不混入策略决策或历史兼容细节。

本轮主要关注以下文件：

`src/app/bootstrap/RuntimeInstall.lua` 负责运行时装配与策略注入，当前仍可能承接部分 legacy policy 决策。

`src/core/RuntimePorts.lua` 是端口层核心文件，当前职责可能混合“接口定义、默认实现选择、兼容兜底逻辑”。

`tests/suites/runtime_ports_contract.lua` 用于验证端口契约与关键行为，是拆分后的核心保护网。

`tests/internal/dep_rules.lua` 用于限制依赖方向与禁用路径扩散，是防止 legacy 回流的治理边界。

`.agents/research.md` 记录这两天清理结果与当前卡点，本计划直接落实其中“继续收口 legacy 入口，并推进 RuntimePorts 职责拆分，逐步把阶段性防护代码折叠掉”这一目标。

## 里程碑

里程碑 1 聚焦“看清现状并锁定边界”。完成标准是得到一份可执行的 legacy 调用清单，并明确哪些入口必须保留到下一阶段，哪些可以立即迁移。验证方式是检索命中可解释且无未知调用点。

里程碑 2 聚焦“RuntimeInstall 收口”。完成标准是 legacy policy 只有一个装配入口，调用方不再直接拼装 fallback 细节。验证方式是契约测试通过，且检索结果显示策略配置集中化。

里程碑 3 聚焦“RuntimePorts 拆分与防护折叠”。完成标准是 `RuntimePorts` 仅保留端口职责，兼容语义转移到适配层或显式策略模块，阶段性防护代码减少且仍可观测。验证方式是回归全绿、dep_rules 全绿、legacy 命中下降。

里程碑 4 聚焦“提交与复盘”。完成标准是提交包含代码、测试、文档更新，复盘明确下一次最终退役的前置条件与剩余阻塞。

## 工作计划

先做静态清点，再做最小改动闭环。第一步在 `src/` 与 `tests/` 内检索所有 legacy policy 相关符号，逐个归类为“短期保留（有业务依赖）”或“立即迁移（仅历史冗余）”。归类结果直接写入本计划“产物与备注”，避免执行中丢上下文。

第二步改 `RuntimeInstall.lua`。目标不是新增能力，而是把 legacy 策略注入统一到单一函数或单一配置对象，调用者只表达“是否允许兼容策略”，不直接触达兼容细节。这样可以把后续退役变为替换单点实现，而不是全仓搜索替换。

第三步改 `RuntimePorts.lua`。把“端口契约”和“策略/兼容选择”拆开：端口层保留稳定函数签名，策略分支迁移到独立策略模块或安装阶段装配逻辑。若存在阶段性防护分支，优先折叠重复判断，保留最小必要断言，并在注释中说明退役条件。

第四步补测试与规则。`runtime_ports_contract.lua` 需要覆盖 strict 与受控 legacy 两类路径，保证行为一致；`dep_rules.lua` 需要新增或收紧规则，防止新模块绕过集中入口直接引用 legacy 开关。

最后执行全量验证并提交。若任何验证失败，先在本计划“意外与发现”记录症状与证据，再决定是回滚单步还是补丁修复，确保计划始终可从当前状态重启。

## 具体步骤

所有命令在仓库根目录 `c:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

1. 建立 legacy 调用基线，保存命中结果。

    rg "context_policy|enable_legacy_helper_fallback|set_legacy_fallback_policy\\(" src tests -n

    预期：仍有少量命中，且主要集中在 Runtime 安装与端口相关模块。

2. 执行 RuntimeInstall 收口改动后，复查命中分布。

    rg "context_policy|enable_legacy_helper_fallback|set_legacy_fallback_policy\\(" src tests -n

    预期：命中总量不增加，分布更集中，新增调用点为 0。

3. 执行 RuntimePorts 拆分后，运行契约与规则测试。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; local harness = require('TestHarness'); harness.run_all({ require('runtime_ports_contract') })"
    lua tests/internal/dep_rules.lua

    预期：`runtime_ports_contract` 与 `dep_rules` 全部通过，无新增违规依赖。

4. 运行全量回归确认业务行为不变。

    lua tests/regression.lua

    预期：全量回归通过（当前基线约 210 项，若数量变化需在“意外与发现”解释原因）。

5. 提交并回填文档。

    git status --short
    git add -A
    git commit -m "refactor runtime legacy entry contraction and RuntimePorts split"

    预期：提交仅包含本轮计划内文件与必要测试更新。

## 验证与验收

验收以“行为不变 + 边界更清晰 + 扩散被阻断”为准。行为不变由 `lua tests/regression.lua` 证明；边界更清晰由 legacy 检索命中集中化和 `runtime_ports_contract` 通过共同证明；扩散被阻断由 `lua tests/internal/dep_rules.lua` 证明。

如果出现“测试通过但命中扩散”的情况，视为未验收，因为这说明治理目标失败。只有当三类证据同时成立，才允许进入下一轮最终退役计划。

## 可重复性与恢复

本计划采用增量小步策略，每一步都可独立重复执行。检索命令与测试命令可重复运行且不会污染仓库状态。

若改动后测试失败，先保留现场并记录到“意外与发现”，再按最小粒度修复。禁止跨模块大回滚；优先回滚最近单文件改动以恢复可测状态。若提交后发现问题，使用新提交修复，不改写历史，确保追踪链完整。

## 产物与备注

以下内容在执行后补充真实输出片段，作为“确实生效”的证据：

    legacy 调用分类清单（改动后）：
      - 保留：tests/suites/runtime_ports_contract.lua（显式 legacy 契约用例）
      - 保留：tests/TestSupport.lua（测试基座兼容开关）
      - 迁移：src/app/bootstrap/RuntimeInstall.lua（由 set_legacy_fallback_policy 迁移到 install_context_policy）
      - 保留：src/core/RuntimePorts.lua（提供集中策略入口 + 兼容查询 API）
      - 删除：本轮无可直接删除入口，待最终退役阶段处理测试基座兼容接口

    runtime_ports_contract 通过输出：
      .......
      All regression checks passed (7)

    dep_rules 通过输出：
      dep_rules ok

    regression 通过输出：
      All regression checks passed (213)
      dep_rules ok
      tick ok
      forbidden_globals ok

    最终提交哈希与变更摘要：
      - e422ca1 refactor runtime legacy entry contraction and RuntimePorts split
      - 涉及文件：.agents/plan.md、.agents/research.md、RuntimeInstall、RuntimePorts、runtime_ports_contract

## 接口与依赖

本轮不引入新外部依赖，继续使用 Lua 现有测试与检索工具链。关键接口约束如下：

`src/core/RuntimePorts.lua` 对外暴露的端口函数签名必须保持向后兼容，调用方不应因为本轮拆分而修改业务参数结构。

`src/app/bootstrap/RuntimeInstall.lua` 负责策略装配，legacy policy 只允许通过该层受控进入，其他模块不得新增直接开关调用。

`tests/suites/runtime_ports_contract.lua` 必须覆盖 strict 与受控 legacy 路径，确保同一输入下业务可观察结果一致。

`tests/internal/dep_rules.lua` 必须把 legacy 触达限制在白名单模块，作为最终退役前的强约束。

## 文档更新记录

2026-03-02（本次）：重建缺失的 `.agents/plan.md`，将研究结论中的下一步目标落成可执行计划，新增里程碑、验证命令、风险恢复与活文档章节，目的是让后续执行可以无外部上下文直接推进。
2026-03-02（执行回填）：完成 R15 代码实施与验证，更新进度为已执行状态，补充契约测试运行方式、回归证据、legacy 调用分类和决策日志，确保文档可从当前快照直接重启执行。
2026-03-02（提交回填）：记录最终提交哈希与变更摘要，并将进度与复盘状态更新为“全部完成”，避免执行状态与仓库实际状态不一致。
