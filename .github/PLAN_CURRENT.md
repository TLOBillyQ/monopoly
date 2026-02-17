# tests 层级治理与测试架构重构（全阶段可执行计划）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.github/PLANS.md` 维护规范，且面向“仅有当前工作树、无历史上下文”的新手执行者编写。

## 目的 / 全局视角

这项工作的目标是把 `tests/` 从“可运行但层级混杂”的状态，重构为“层级语义一致、扩展不改核心、职责边界清晰”的状态。完成后，新增测试文件不需要修改核心 loader，回归测试目录命名统一，复杂回归场景不再塞在单个巨型 Lua 文件里，维护成本与误改风险显著下降。

用户可见的成功信号有三点：第一，运行 `lua tests/regression.lua` 仍能执行完整测试；第二，新增一个符合约定的 `tests/specs/<layer>/<name>_spec.lua` 文件后，无需改 `tests/runner/spec_loader.lua` 也会被执行；第三，目录结构和命名规则在 `tests/README.md` 中有清晰可执行说明，并由测试规则守卫。

## 进度

- [x] (2026-02-17 03:04Z) 阶段 0：建立基线，确认现有 `tests/` 结构、执行链路与通过状态（已完成：列出文件与执行回归；剩余：无）
- [x] (2026-02-17 03:56Z) 阶段 1：统一 `tests/specs/**` 命名与层级语义（已完成：回归层统一为 `*_spec.lua` 并清理命名；剩余：无）
- [x] (2026-02-17 05:13Z) 阶段 2：将 `tests/specs/regression/gameplay_spec.lua` 拆分为薄 spec + support 场景构建模块（已完成：提取 runtime_context 相关辅助到 `tests/support/regression/runtime_context_helpers.lua`，抽离 loop_state 构建到 `tests/support/regression/loop_state_builder.lua`，并迁出 runtime_context 用例到 `tests/support/regression/runtime_context_cases.lua`，新增 autorunner 用例模块 `tests/support/regression/gameplay_autorunner_cases.lua` 与 loop/timeout 用例模块 `tests/support/regression/gameplay_loop_cases.lua`；剩余：无）
- [x] (2026-02-17 03:27Z) 阶段 3：将 `tests/runner/spec_loader.lua` 从硬编码清单改为约定驱动加载（已完成：实现按 `tests/specs/**/*_spec.lua` 自动发现；回归通过；剩余：文档跟进）
- [x] (2026-02-17 05:34Z) 阶段 4：补充层级守卫（依赖边界与 spec 元数据约束）（已完成：integration/internal 校验已通过；剩余：无）
- [x] (2026-02-17 05:34Z) 阶段 5：文档收敛与全链路验收（README + 回归命令 +过滤器验证）（已完成：README 命名约定同步；过滤器与全量回归通过；剩余：无）

## 意外与发现

- 观察：`tests/specs/regression/` 已完成命名统一，全部为 `*_spec.lua`。
  证据：`find tests/specs/regression -type f -name '*_spec.lua' | sort`。

- 观察：阶段 2 拆分后回归仍通过，未引入新增失败。
  证据：`lua tests/regression.lua` 输出 `All regression checks passed (130)`。

- 观察：过滤器与 internal/integration 校验通过。
  证据：`TEST_LAYERS=integration lua tests/regression.lua` 输出 `All regression checks passed (4)`；`TEST_LAYERS=contract,unit lua tests/regression.lua` 输出 `All regression checks passed (7)`；`TEST_DOMAINS=ports,runtime lua tests/regression.lua` 输出 `All regression checks passed (5)`。

- 观察：已新增 `tests/support/regression/runtime_context_helpers.lua`、`tests/support/regression/loop_state_builder.lua`、`tests/support/regression/runtime_context_cases.lua`、`tests/support/regression/gameplay_autorunner_cases.lua` 与 `tests/support/regression/gameplay_loop_cases.lua`，`gameplay_spec` 中 runtime_context/loop/autorunner 相关逻辑已迁出。
  证据：`tests/specs/regression/gameplay_spec.lua` 顶部引用 `support.regression.runtime_context_helpers`。

- 观察：`tests/runner/spec_loader.lua` 使用硬编码 `require(...)` 列表收集 spec。
  证据：文件内 `_base_specs()` 显式列举 `contract/unit/integration/regression` 每个模块。

- 观察：`tests/specs/regression/gameplay_spec.lua` 已明显收敛，多个辅助与用例已迁出到 `tests/support/regression/`。
  证据：`tests/specs/regression/gameplay_spec.lua` 现改为引用 `support.regression.*_cases` 与 `support.regression.*_helpers`。

- 观察：`tests/runner/spec_loader.lua` 现可基于文件系统自动发现 spec，而不再需要硬编码清单。
  证据：`tests/runner/spec_loader.lua` 改为扫描 `tests/specs/**/*_spec.lua` 并映射模块名。

## 决策日志

- 决策：按“双轨目标”实施，即“架构层级治理 + 文件树层级治理”同时推进，而非仅做命名整理。
  理由：仅改命名不能降低新增测试改核心 loader 的系统性风险，也不能解决巨型回归文件职责过载。
  日期/作者：2026-02-17 / Codex

- 决策：保留入口命令 `lua tests/regression.lua` 作为兼容约束。
  理由：避免影响现有团队习惯与 CI 集成；重构应在内部实现层完成，不破坏外部调用。
  日期/作者：2026-02-17 / Codex

- 决策：采用“阶段化渐进迁移”，每阶段都可独立验证。
  理由：测试基础设施改动范围大，拆阶段可降低回归风险并便于回滚。
  日期/作者：2026-02-17 / Codex

- 决策：spec loader 通过 `find tests/specs -name '*_spec.lua'` 自动发现 spec，并按 `tests/specs/<layer>/<name>_spec.lua` 映射 `require("<layer>.<name>_spec")`。
  理由：阶段 1 已完成命名统一，可收敛为严格约定驱动。
  日期/作者：2026-02-17 / Codex

- 决策：将 `gameplay_spec` 中 loop/timeout/autorunner 相关用例迁出为 `tests/support/regression/gameplay_autorunner_cases.lua` 与 `tests/support/regression/gameplay_loop_cases.lua`。
  理由：降低单文件体积并提高复用性，便于后续继续拆分场景。
  日期/作者：2026-02-17 / Codex

## 结果与复盘

阶段 0-5 已完成：基线回归与过滤器校验通过，回归层命名统一，spec loader 约定驱动化，`gameplay_spec` 已拆分为多个 support 模块。后续需对照“目的/全局视角”补足完整复盘。

## 背景与导读

本仓库测试执行入口是 `tests/regression.lua`，它设置 `package.path` 并调用 `tests/runner/init.lua` 的 `runner.run(...)`。`runner` 负责收集 spec、按过滤条件执行 case、并输出报告。`tests/specs/` 按层分为 `unit`、`contract`、`integration`、`regression`，理论上应表达从小到大的测试粒度。

当前主要问题是“层级语义与职责边界偏移”。所谓“层级语义”，是指目录名和文件名让读者一眼知道测试粒度与用途；“职责边界”，是指每个模块只做一件事，例如 spec 文件聚焦行为断言，support 文件负责构建测试上下文。实际现状里，`tests/specs/regression/gameplay_spec.lua` 同时承担大量 support 职责，`tests/runner/spec_loader.lua` 作为核心编排却硬编码每个 spec，导致扩展时必须修改核心。

关键文件导读如下（均为仓库相对路径）：

- `tests/regression.lua`：测试入口。
- `tests/runner/init.lua`：执行器，负责跑 case 与汇总结果。
- `tests/runner/spec_loader.lua`：收集 spec（当前为静态清单）。
- `tests/specs/regression/gameplay_spec.lua`：主要的巨型回归文件（重点拆分对象）。
- `tests/support/*.lua`：当前通用测试支持模块。
- `tests/internal/*.lua` 与 `tests/specs/integration/internal_*_spec.lua`：内部规则和行为验证。
- `tests/README.md`：测试分层、运行方式、约束说明。

## 工作计划

本计划按六个阶段推进，每阶段都要求“先改最小可验证单元，再跑对应验证命令”。阶段 0 先冻结基线，记录当前测试通过情况和文件列表，作为后续对照。阶段 1 处理“可见层级问题”：统一 `tests/specs/**` 命名规则，把回归目录中的非 `_spec.lua` 文件改名到一致规范，并同步 `require` 路径。阶段 2 处理“职责边界问题”：从 `tests/specs/regression/gameplay_spec.lua` 中提取环境装配与桩函数到 `tests/support/regression/` 子模块，使 spec 文件只保留场景描述与断言。

阶段 3 处理“扩展性问题”：重写 `tests/runner/spec_loader.lua`，由静态清单改为约定驱动加载（扫描 `tests/specs/**/*_spec.lua` 并映射模块名），保证新增 spec 默认可发现，减少对核心编排的修改。阶段 4 增加守卫机制，在 internal/integration 检查中加入层级依赖规则与 spec 元数据校验，防止未来回退到混杂结构。阶段 5 汇总文档与验收，更新 `tests/README.md`，给出新增 spec 标准流程，并执行全链路命令验证行为不变、结构更清晰。

每一阶段都必须更新“进度、意外与发现、决策日志、结果与复盘”四个活文档章节，并在文末追加“本次更新说明”。

## 具体步骤

以下命令默认在仓库根目录执行：`/Users/billyq/Dev/Github/Lua/monopoly`。

1) 阶段 0：基线采集

    pwd
    find tests -type f | sort
    lua tests/regression.lua

预期：成功列出当前测试文件；回归命令可运行（若已有失败，需记录失败明细作为基线，不在本计划外顺手修其他问题）。

2) 阶段 1：命名与层级语义统一

    # 识别非 *_spec.lua 的 specs 文件
    find tests/specs -type f -name '*.lua' | rg -v '_spec\.lua$'

    # 按重构决策逐个重命名（示例，具体名单以执行时为准）
    # mv tests/specs/regression/gameplay.lua tests/specs/regression/gameplay_spec.lua

    # 更新 require 引用后运行
    lua tests/regression.lua

预期：`tests/specs/**` 下测试文件命名统一；运行结果与基线一致或更清晰。

3) 阶段 2：拆分 `gameplay` 巨型文件

    # 新增 support 子模块（示例目录）
    # tests/support/regression/runtime_context_helpers.lua
    # tests/support/regression/loop_state_builder.lua
    # tests/support/regression/runtime_context_cases.lua
    # tests/support/regression/gameplay_autorunner_cases.lua
    # tests/support/regression/gameplay_loop_cases.lua

    # 将 gameplay spec 收敛为薄 orchestration
    lua tests/regression.lua

预期：`gameplay` spec 文件显著变薄；support 逻辑可复用；行为不变。

4) 阶段 3：loader 约定驱动化

    # 修改 tests/runner/spec_loader.lua 后执行
    lua tests/regression.lua

    # 新增一个最小 smoke spec（临时）验证自动发现
    # lua tests/regression.lua
    # 回滚临时文件

预期：新增符合命名约定（`*_spec.lua`）的 spec 无需改 loader 即可被执行。

5) 阶段 4：层级守卫与元数据校验

    # 运行 internal/integration 相关检查
    TEST_LAYERS=integration lua tests/regression.lua

    # 运行全量回归确认未破坏
    lua tests/regression.lua

预期：越层依赖与不合规 spec 能被明确报错；正常 spec 不受影响。

6) 阶段 5：文档与最终验收

    # 校验层过滤
    TEST_LAYERS=contract,unit lua tests/regression.lua

    # 校验域过滤
    TEST_DOMAINS=ports,runtime lua tests/regression.lua

    # 全量
    lua tests/regression.lua

预期：README 与实际行为一致；过滤器可稳定工作；重构目标达成。

## 验证与验收

验收以“行为可观察”为准，不以“代码看起来更整洁”为准。必须满足以下条件：

第一，默认命令 `lua tests/regression.lua` 可运行并输出完整报告。第二，新增一个符合约定的 `tests/specs/<layer>/<name>_spec.lua` 文件后，无需修改 `tests/runner/spec_loader.lua` 也可被执行。第三，`TEST_LAYERS` 与 `TEST_DOMAINS` 过滤行为与 README 描述一致。第四，巨型回归文件拆分后，原有关键回归场景结果保持一致（可通过对比 case id 通过数确认）。

建议在每阶段结束时记录一段最小证据输出（通过数、失败数、过滤结果），写入“产物与备注”。

## 可重复性与恢复

本计划采用增量、可回滚策略。每阶段应为独立提交（即使本地不立即 commit，也要保持可独立回退的改动边界）。若某阶段失败，回滚该阶段改动并恢复到上阶段通过状态，再重新执行。严禁跨阶段混合重构，以免难以定位回归来源。

命名迁移阶段需特别注意 `require` 路径同步；若出现模块找不到，先通过 `rg "require\(" tests` 定位引用并修正，再继续执行回归命令。对于自动发现 loader，若平台不支持目录扫描能力，应采用“自动生成清单文件”的过渡方案，并在决策日志说明。

## 产物与备注

以下是应在实施过程中持续补充的短证据模板（含本次基线输出）：

    $ lua tests/regression.lua
    ...dep_rules ok
    .tick ok
    ..............................................................................................................................
    All regression checks passed (130)

    $ TEST_LAYERS=contract,unit lua tests/regression.lua
    .......
    All regression checks passed (7)

    $ TEST_DOMAINS=ports,runtime lua tests/regression.lua
    .....
    All regression checks passed (5)

如果某阶段出现失败，记录最短必要证据：失败 case id、错误栈首行、对应修复动作。不要粘贴冗长日志。

## 接口与依赖

本重构不改变外部入口接口，保持：

- `tests/regression.lua` 仍作为默认执行入口。
- `tests/runner/init.lua` 的对外调用形式保持 `runner.run(opts)`。

本重构会收敛内部约定接口：

- spec 文件约定统一为 `tests/specs/<layer>/*_spec.lua`。
- spec 返回结构必须包含：`layer`、`domain`、`cases`。
- `cases` 元素至少包含 `id` 与 `run`（或 `arrange/act/assert` 组合）。

若实施目录扫描 loader，需在 `tests/runner/spec_loader.lua` 明确并固定模块名映射规则（例如从路径 `tests/specs/regression/foo_spec.lua` 映射到 `require("regression.foo_spec")`），并在 README 写明，避免隐式规则导致维护困难。

---

更新说明（2026-02-17 / Codex）：
已完成阶段 2-5：完成 gameplay 拆分、internal/integration 校验、过滤器验证与全量回归，补充最新证据输出。
