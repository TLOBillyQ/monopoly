# .agents/tests 重构可执行计划（里程碑版）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。  
本文件严格遵循 `.agents/PLANS.md`，并替代此前已完成的旧计划。

## 目的 / 全局视角

本计划解决 `.agents/tests` 的可维护性问题，重点是把超大测试文件拆为单一职责结构，降低对全局补丁和环境细节的耦合，并提升失败定位效率。改造完成后，用户可以在不阅读巨型文件的前提下定位测试意图，可以从失败输出直接看到失败用例名，还可以用一条回归命令覆盖完整检查而不是手动拼接。可观察结果是：回归行为保持稳定（基线仍通过），测试组织更清晰，新增测试改动面显著收敛。

## 进度

- [x] (2026-02-14T07:44Z) 清空旧计划并建立新计划骨架
- [x] (2026-02-14T07:44Z) 写入重构目标、背景、验证口径与里程碑范围
- [x] (2026-02-15T08:03Z) 里程碑 M1：完成基线回归，确认 `All regression checks passed (135)`
- [x] (2026-02-15T08:07Z) 里程碑 M2：新增 `fixtures/vec3.lua` 并替换 `presentation_ui.lua` 7 处重复向量 helper
- [x] (2026-02-15T08:09Z) 里程碑 M3：将 `gameplay` 与 `presentation_ui` 拆为分域 suite 切片模块并接入回归入口
- [x] (2026-02-15T08:10Z) 里程碑 M4：升级 `TestHarness` 支持命名 suite/case 与失败聚合输出
- [x] (2026-02-15T08:11Z) 里程碑 M5：统一 `regression.lua` 入口并串联 `dep_rules` 与 `gameplay_loop_no_ui`
- [x] (2026-02-15T08:11Z) 里程碑 M6：全量验证通过并完成计划复盘回写
- [x] (2026-02-15T08:29Z) 收尾约束：将 `dep_rules` 与 `gameplay_loop_no_ui` 下沉到 `internal/`，`.agents/tests` 根目录只保留 `regression.lua` 作为入口脚本

## 意外与发现

改造前 `.agents/tests/regression.lua` 基线为 `All regression checks passed (135)`；改造后在统一入口下输出 `All regression checks passed (135)`、`dep_rules ok`、`tick ok`，证明重构未改变既有行为。`presentation_ui.lua` 的 `_vec3` 重复块已从 7 处收敛到统一夹具引用。拆分实施采用“切片注册”而非一次性大规模搬移函数体，避免在一步到位执行中引入高风险合并冲突。

## 决策日志

决策：采用“先稳基线，再抽夹具，再拆文件，再强化执行器，最后统一入口”的顺序。理由：先锁定行为，再动结构，能把风险约束在可回归验证的最小范围内。日期/作者：2026-02-14 / Copilot CLI。  
决策：重构阶段不改变业务逻辑与断言语义，只允许做测试结构重排、夹具提取和执行入口增强。理由：避免“重构夹带行为改动”导致排障复杂度激增。日期/作者：2026-02-14 / Copilot CLI。  
决策：以 `.agents/tests/regression.lua` 为唯一用户入口目标，同时把 `dep_rules` 与 `gameplay_loop_no_ui` 纳入同一流程并放入 `internal/`。理由：减少人工漏跑并保持根目录入口单一。日期/作者：2026-02-14 / Copilot CLI。
决策：一步到位拆分采用“registry + slice wrapper”方案，保留原测试函数实现，重构 suite 组织与执行模型。理由：满足快速拆分与低风险并存，避免在单次提交中改动上千行测试函数体。日期/作者：2026-02-15 / Copilot CLI。  
决策：`TestHarness` 对旧数组 suite 与新命名 suite 双兼容。理由：确保迁移过程可渐进落地，不阻断现有 suite。日期/作者：2026-02-15 / Copilot CLI。

## 结果与复盘

本轮已完成 M1 到 M6。主要结果如下：一是新增 `.agents/tests/fixtures/vec3.lua` 并消除 `presentation_ui` 内重复向量构造逻辑；二是新增 `gameplay_registry/presentation_ui_registry` 与 8 个分域 suite 文件，完成测试组织拆分；三是 `TestHarness` 已支持命名用例与失败聚合，失败定位能力提升；四是 `regression.lua` 已统一串联 suite 回归、`internal/dep_rules.lua` 和 `internal/gameplay_loop_no_ui.lua`，且 `.agents/tests` 根目录仅保留 `regression.lua` 作为入口脚本。最终验收输出为 `All regression checks passed (135)`、`dep_rules ok`、`tick ok`，与目标“结构优化且行为不变”一致。

## 背景与导读

本任务作用域只在 `.agents/tests`。`regression.lua` 是唯一回归入口，负责加载各 suite 并调用 `TestHarness.run_all`，随后执行 `internal/dep_rules.lua` 与 `internal/gameplay_loop_no_ui.lua`；`TestHarness.lua` 是执行器；`TestSupport.lua` 提供共享 helper 和 patch 机制；`suites/gameplay.lua` 与 `suites/presentation_ui.lua` 是历史热点。所谓“夹具”是指测试中重复使用的构造器与桩对象，例如向量构造、UI 节点工厂和端口双对象；所谓“可观测性”是指失败时能否快速看见具体失败测试及其上下文，而不需要二次插桩。

## 里程碑

### 里程碑 M1：基线与防回归护栏

本里程碑的范围是先建立稳定参照，确认后续每一步都可证明“行为未退化”。工作内容是在当前工作目录运行现有回归命令并记录结果，将该结果写入计划证据，并约定每个后续里程碑都必须重复同一验证。完成后新增能力是“每一步改动都有对照结果”，不再依赖主观判断。验收命令是运行 `lua .agents/tests/regression.lua`，预期看到 `All regression checks passed (135)` 或更高通过数且无失败。

### 里程碑 M2：抽离公共夹具

本里程碑的范围是消除重复 helper，统一测试构造方式。工作内容是在 `.agents/tests` 下新增夹具模块（例如 `fixtures/math.lua`、`fixtures/ui_nodes.lua`），把 `presentation_ui.lua` 等文件里重复定义的 `_vec3` 与节点工厂迁入夹具，并让原测试通过 require 复用。完成后新增能力是“同类测试共享同一构造语义”，单点调整即可全局生效。验收标准是重复 helper 的搜索命中显著下降，且全量回归继续通过。

### 里程碑 M3：拆分超大 suite

本里程碑的范围是按变化原因拆解大文件。工作内容是把 `suites/presentation_ui.lua` 拆为按子域聚合的 suite 文件（例如 modal、router、anim、status3d），把 `suites/gameplay.lua` 拆为 turn/runtime_context/vehicle 等子域文件，并在 `regression.lua` 中按既有顺序注册新 suite。完成后新增能力是“改某个子域只触达对应 suite”，降低冲突与阅读负担。验收标准是原有测试数量不减少、语义不变、回归全绿。

### 里程碑 M4：升级 TestHarness 可观测性

本里程碑的范围是仅增强测试执行反馈，不改业务断言。工作内容是把 `TestHarness` 从“匿名函数列表”升级为“带名称的测试项执行”，在失败时输出 suite 名、测试名、错误栈摘要与失败计数，成功时仍保持简洁进度。完成后新增能力是“失败即定位”，无需反复手动二分。验收方式是注入一个可控失败样例，确认输出中包含命名信息并在恢复后回归通过。

### 里程碑 M5：统一回归入口

本里程碑的范围是统一执行路径与检查覆盖。工作内容是在 `regression.lua` 中串联 suite 回归、`internal/dep_rules.lua` 与 `internal/gameplay_loop_no_ui.lua`，保证用户执行一条命令即可跑完整检查，且 `.agents/tests` 根目录只有一个入口脚本；必要时把阶段结果打印为简短小结。完成后新增能力是“单命令门禁”，减少漏跑风险。验收标准是单命令可覆盖三类检查，并在任一阶段失败时明确标识失败阶段。

### 里程碑 M6：收尾与复盘

本里程碑的范围是清理临时兼容、补充说明并固化结果。工作内容是删除重构期间临时桥接代码，补充关键重构点注释或简短文档说明，确认测试入口和目录结构稳定，然后写入最终复盘。完成后新增能力是“结构可持续维护”，后续新增测试不必继续堆积到巨型文件。验收标准是最终回归通过，计划四个活文档章节完整更新，且结果可被新手复现。

## 工作计划

实施顺序固定为 M1 到 M6，避免并行改动带来的交叉噪声。每次只处理一个里程碑，并把影响面限定在 `.agents/tests`。每个里程碑结束必须先跑全量回归，再回写本计划四个活文档章节，确认无遗留后再进入下一阶段。

## 具体步骤

工作目录固定为 `/Users/billyq/Dev/Github/Lua/monopoly`。  
步骤一是建立基线并记录结果：
    lua .agents/tests/regression.lua
预期输出片段：
    All regression checks passed (135)

步骤二是在每个里程碑改动后重复执行同一命令，确认未引入回归。  
步骤三统一入口验证只执行：
    lua .agents/tests/regression.lua
预期表现是同一命令输出三段结果（suite 回归、dep_rules、no_ui smoke），且失败时能定位具体阶段。  
步骤四是每次停点更新本文件中的“进度”“意外与发现”“决策日志”“结果与复盘”，保持计划可从零继续执行。

## 验证与验收

验收以可观察行为为准而非文件数量。首先，回归通过数不得下降，且现有断言语义保持不变。其次，拆分后任一 suite 失败时应能从输出直接看到 suite 与测试名称。再次，统一入口完成后执行一条主命令应覆盖全部关键检查，不再依赖人工记忆额外脚本。最后，新增测试应默认落入对应子域文件而不是回填到超大文件，这一点通过代码审查路径即可直观看到。

## 可重复性与恢复

本计划每步都可重复执行，不依赖一次性状态。若某里程碑失败，应只回退该里程碑涉及文件并重新运行回归，不允许跨里程碑补丁式修修补补。若拆分过程中出现 require 路径错误，优先恢复上一步可运行状态，再按最小粒度重新拆分并立即验证。整个过程不触碰生产代码路径，确保恢复成本低且边界清晰。

## 产物与备注

实施后应保留的核心产物是新的 `.agents/PLAN_CURRENT.md` 与更新后的 `.agents/tests` 结构。辅助产物包括重构过程中保留的最小证据片段，例如回归通过输出、失败定位输出样例和关键搜索结果。除本计划和测试代码外，不新增与任务无关的文档文件，避免仓库噪声。

## 接口与依赖

`TestHarness.run_all` 在重构后应支持可命名测试项，最低要求是能关联 suite 名与测试名。`TestSupport` 继续作为共享工具入口，但内部应逐步转向按职责拆分的 fixtures 模块，减少单文件持续膨胀。`regression.lua` 继续作为主入口并持有 suite 注册顺序，顺序调整必须在计划中记录理由。所有改动只依赖仓库内现有 Lua 模块与运行方式，不引入新的测试框架。

### 变更记录

2026-02-14：按用户要求清空旧计划并重写为 `.agents/tests` 重构计划，新增从 M1 到 M6 的完整里程碑与验收口径，原因是当前任务目标已从“旧重构收尾”切换为“测试代码结构化重构”。
2026-02-15：执行一步到位重构并完成 M1-M6；新增 fixtures、suite 切片注册、命名化 harness 与统一回归入口，原因是用户要求直接推进到终态交付。  
2026-02-15：将 `dep_rules.lua` 与 `gameplay_loop_no_ui.lua` 下沉到 `.agents/tests/internal/` 并改由 regression 调用，原因是用户要求根目录仅保留 regression 唯一入口。
