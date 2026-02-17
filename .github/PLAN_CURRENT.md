# 测试体系收口计划（去桥接、去遗留依赖）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.github/PLANS.md` 维护。

## 目的 / 全局视角

这轮工作的目标不是“再能跑一次回归”，而是把当前测试体系从“可运行”收口到“可长期维护”。现在 `lua tests/regression.lua` 已经稳定通过，但仍存在迁移桥接和遗留依赖（例如 `tests/specs/regression/suite_src/*` 对 `TestSupport` 的强依赖）。本计划完成后，团队将得到一个职责清晰、依赖方向稳定、可持续扩展的测试系统：新增测试不需要触碰中心执行器，运行过滤和内部门禁语义清晰，回归失败可直接定位到分层与领域。

可见效果是：默认回归命令保持不变，输出仍为可读摘要；新增或迁移测试时，开发者只改对应层目录与清单，不再改 `runner` 的硬编码细节。

## 进度

- [x] (2026-02-17 09:10) 新入口与新 runner 已上线，`tests/suites/` 目录已移除，suite 源迁入 `tests/specs/regression/legacy_src/`。
- [x] (2026-02-17 09:20) 统一单路径执行，legacy 开关和适配器已删除。
- [x] (2026-02-17 09:30) 新增 contract/unit/integration/regression 首批用例，并补 timeout 核心场景。
- [x] (2026-02-17 10:05) 拆分 `tests/runner/init.lua` 职责（收集、过滤、执行、后置检查分离）。
- [x] (2026-02-17 10:08) 将 `suites_migrated_spec.lua` 的模块硬编码迁移为 manifest 驱动。
- [ ] (2026-02-17 09:40) 分批将回归模块从 `TestSupport` 迁移到 `tests/support/*` 窄接口（已完成首批：`misc`、`movement`、`market`）。
- [x] (2026-02-17 11:05) 完成剩余 8 个回归模块的直接依赖切换：`chance/land/landing/item/paid_currency/modal_choice_timeout/gameplay/presentation_ui` 不再直接 `require("TestSupport")`。
- [x] (2026-02-17 11:08) 抽离 `tests/support/patch.lua` 并让 `tests/support/time_stub.lua` 改用新 patch 支撑。
- [x] (2026-02-17 11:12) 修复 `gameplay` 域过滤执行下的 2 个顺序依赖用例（case_20 / case_22），确保 domain filter 与全量回归一致通过。
- [x] (2026-02-17 10:12) 将 `tests/internal/*` 逐步 spec 化，减少 `dofile` 直跑模式。
- [x] (2026-02-17 10:15) 完成文档与命名收口（`legacy_src` 重命名为 `suite_src`）。
- [x] (2026-02-17 10:28) 完成“全迁移执行链”：删除 `suites_migrated_spec.lua`/`manifest.lua`，11 个回归模块直接以标准 spec 形式接入 runner。

## 意外与发现

- 观察：执行器职责已拆分，`init.lua` 由“细节实现”收口为“编排入口”，结构风险显著降低。
  证据：新增 `tests/runner/spec_loader.lua`、`tests/runner/filter.lua`、`tests/runner/post_checks.lua`，`init.lua` 仅负责编排与汇总。

- 观察：桥接清单已外置到 manifest，新增 source 的漏挂风险下降。
  证据：`tests/specs/regression/manifest.lua` 提供模块清单，`suites_migrated_spec.lua` 改为 `require("regression.manifest")`。

- 观察：执行链已经不再依赖桥接文件，回归模块直接为标准 spec；当前主要技术债仅剩 `TestSupport` 依赖收口。
  证据：`tests/runner/spec_loader.lua` 直接 `require("regression.<module>")`；`tests/specs/regression/suites_migrated_spec.lua` 与 `manifest.lua` 已删除。

- 观察：`misc`、`movement`、`market` 三个模块已完成去 `TestSupport`，且回归通过，说明可以按专题滚动迁移。
  证据：`tests/specs/regression/misc.lua`、`movement.lua`、`market.lua` 不再 `require("TestSupport")`；`lua tests/regression.lua` -> `All regression checks passed (151)`。

## 决策日志

- 决策：继续保留“默认回归 + internal 脚本门禁”这一行为，不在本轮改变命令语义。
  理由：先保证行为稳定，再做执行器职责拆分，避免一次改动叠加太多变量。
  日期/作者：2026-02-17 / Copilot

- 决策：把旧 suite 源搬到 `tests/specs/regression/legacy_src/`，而不是立即逐文件重写。
  理由：先完成目录与入口统一，确保回归连续可运行；随后按专题逐步去 `TestSupport`。
  日期/作者：2026-02-17 / Copilot

- 决策：下一阶段优先做架构收口（runner 拆分 + manifest），再批量改测试内容。
  理由：先处理“改一处牵全局”的结构风险，可降低后续迁移成本。
  日期/作者：2026-02-17 / Copilot

- 决策：internal 检查改为 integration specs 执行，不再在 runner 中直接 `dofile`。
  理由：执行链统一后，过滤、报告和失败定位都走同一通道，减少特殊分支。
  日期/作者：2026-02-17 / Copilot

## 结果与复盘

当前阶段已经达成“单入口、单路径、可运行”，并完成了 runner 职责拆分、manifest 化（并最终下线桥接）、internal spec 化。当前最大的剩余风险是回归模块对 `TestSupport` 的重耦合。下一阶段重点是按专题迁移场景到 `tests/support/*` 窄接口。

## 背景与导读

本仓库测试系统的入口在 `tests/regression.lua`。该入口设置 `package.path` 后调用 `tests/runner/init.lua`。`runner` 负责收集 specs、执行并汇总失败。当前 specs 分四层：

- `tests/specs/contract/`：协议与边界。
- `tests/specs/unit/`：纯逻辑。
- `tests/specs/integration/`：跨模块流程。
- `tests/specs/regression/`：主链路回归与桥接用例。

回归模块位于 `tests/specs/regression/*.lua`，均直接返回统一 spec 结构参与执行。`tests/internal/dep_rules.lua` 与 `tests/internal/gameplay_loop_no_ui.lua` 已通过 integration specs 纳入统一执行管道。

关键术语说明：

- “spec” 是单个测试模块返回的数据结构，包含 `layer`、`domain`、`cases`。
- “bridge/桥接” 是把旧 suite 形式转成 spec 形式的过渡代码。
- “manifest” 是模块清单文件，专门维护“要执行哪些 spec 模块”。

## 工作计划

第一步先拆执行器职责。将 `tests/runner/init.lua` 中“收集 spec、过滤参数解析、执行循环、后置检查”四块拆到独立模块，使 `init.lua` 只做编排。拆分后，回归行为必须与当前完全一致。

第二步（已完成并收口）曾把硬编码模块列表抽离到 manifest，随后在全迁移阶段删除桥接层，改为 `spec_loader` 直接加载标准 spec 模块。

第三步按专题减少 `legacy_src` 对 `TestSupport` 的依赖。优先迁移 timeout、input lock、dispatch 相关场景到 `tests/support/context_builder.lua`、`tests/support/time_stub.lua`、`tests/support/assertions.lua` 的窄接口。每轮迁移必须保持回归全绿。

第四步已经完成：`tests/internal/*` 检查通过 integration specs 执行，后续仅做必要用例细化。

## 具体步骤

以下命令都在仓库根目录执行：`/Users/billyq/Dev/Github/Lua/monopoly`。

1) 先确认基线与当前状态。

    git status --short
    lua tests/regression.lua

预期看到回归通过，总数约为 151（随着新增用例会变化）。

2) 拆分 runner 职责并保持行为一致。

    # 新增
    tests/runner/spec_loader.lua
    tests/runner/filter.lua
    tests/runner/post_checks.lua

    # 修改
    tests/runner/init.lua

3) 引入 manifest，替换桥接文件硬编码列表。

    # 新增
    tests/specs/regression/manifest.lua

    # 修改
    tests/specs/regression/suites_migrated_spec.lua

4) 批量迁移一簇回归模块用例到 `tests/support/*` 窄接口（每轮至少 3 个场景）。

    # 修改/新增
    tests/specs/regression/*.lua
    tests/specs/integration/*.lua
    tests/specs/unit/*.lua

5) 每轮迁移后验证并提交。

    lua tests/regression.lua
    TEST_LAYERS=contract,unit lua tests/regression.lua
    git add -A && git commit -m "test: migrate <topic> specs and reduce TestSupport coupling"

## 验证与验收

验收以可观察行为为准：

1. 运行 `lua tests/regression.lua`，应通过且输出包含：

    All regression checks passed (N)

2. 运行 `TEST_LAYERS=contract,unit lua tests/regression.lua`，应仅执行对应层并通过。

3. 迁移完成标准：

- `tests/runner/init.lua` 只做编排，不再直接包含具体后置脚本路径。（已达成）
- 桥接层（`suites_migrated_spec.lua` / `manifest.lua`）已删除，回归模块直接由 `spec_loader` 加载。（已达成）
- 回归模块中 `require("TestSupport")` 数量持续下降，最终为 0。（已达成：`tests/specs/regression/*.lua` 直接引用为 0）
- internal 检查通过 spec 管道执行，不再 `dofile` 直跑。（已达成）

## 可重复性与恢复

本计划按增量推进，所有步骤可重复执行。若某轮迁移失败，使用 `git restore -SW .` 回退工作区，再按“单簇迁移 + 验证 + 提交”的节奏重试。严禁一次性重写全部 `legacy_src`，以避免失控。

## 产物与备注

以下是本阶段已验证的关键输出样式（示例）：

    .........dep_rules ok
    .tick ok
    ................................................................................
    .............................................................

    All regression checks passed (151)

当前关键文件定位：

- 入口：`tests/regression.lua`
- 执行器：`tests/runner/init.lua`、`tests/runner/report.lua`
- 回归模块：`tests/specs/regression/*.lua`（直接 spec 返回）
- 支撑层：`tests/support/*.lua`

首批去耦完成模块：

- `tests/specs/regression/misc.lua`
- `tests/specs/regression/movement.lua`
- `tests/specs/regression/market.lua`

## 接口与依赖

本计划要求并维持以下接口约定：

- 每个 spec 模块返回：

    {
      layer = "unit|contract|integration|regression",
      domain = "...",
      cases = {
        { id = "...", desc = "...", run = function() ... end }
      }
    }

- runner 过滤参数来源：

    TEST_LAYERS=contract,unit
    TEST_DOMAINS=ports,runtime

- 支撑依赖优先级：

    tests/support/assertions.lua
    tests/support/context_builder.lua
    tests/support/time_stub.lua
    tests/support/ports_stub.lua

  `TestSupport.lua` 仅作为迁移过渡依赖，逐步淘汰。

---

本次更新说明：在“全迁移执行链”基础上继续推进去耦，完成剩余 8 个回归模块的直接 `TestSupport` 依赖切换，并新增 `support.patch` 统一补丁能力；已验证 `lua tests/regression.lua`（151 通过）及 `TEST_LAYERS=regression TEST_DOMAINS=chance,land,landing,item,paid_currency,timeout_modal_choice,gameplay,presentation_ui`（124 通过）。

