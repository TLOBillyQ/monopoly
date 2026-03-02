# Monopoly legacy 策略使用面收口可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。执行者只依赖当前工作树与本文件即可复现实施与验收过程。

## 目的 / 全局视角


基于最新 `research.md` 结论，本轮目标不是再清理命名，而是收口 legacy 策略使用面，防止 `context_policy = "legacy"` 与 `enable_legacy_helper_fallback = true` 在代码库继续扩散。用户可见结果是：兼容能力仍可用，但被明确限制在契约测试白名单内；一旦新增扩散，`dep_rules` 会立即阻断。验收以规则扫描与全量回归通过为准。

## 进度


- [x] (2026-03-02T17:33:40+08:00) 完成上轮退役范围确认：旧兼容开关 API 仅在 `RuntimePorts` 与契约测试侧退役。
- [x] (2026-03-02T17:34:20+08:00) 删除 `RuntimePorts` 旧兼容开关函数实现并保持分项策略 API 在役。
- [x] (2026-03-02T17:34:50+08:00) 更新 `runtime_ports_contract`，移除旧开关断言。
- [x] (2026-03-02T18:03:00+08:00) 新增 `dep_rules` 收口规则：legacy 策略显式使用仅允许在 `tests/suites/runtime_ports_contract.lua`。
- [x] (2026-03-02T18:04:40+08:00) 运行 `lua tests/internal/dep_rules.lua` 验证新规则与白名单生效。
- [x] (2026-03-02T18:05:05+08:00) 运行 `lua tests/regression.lua` 完成全量回归验收。
- [x] (2026-03-02T18:05:29+08:00) 回填证据与复盘，进入提交阶段。

## 意外与发现


上轮退役后，旧兼容开关 API 已在 `src/tests` 检索清零，但 legacy 策略本体仍在役（`RuntimeInstall` 与契约测试）。这不是缺陷，而是阶段性设计：先移除死兼容入口，再通过规则约束防止新增调用扩散。

实施中遇到一次规则自命中：`dep_rules.lua` 自身包含目标字面量字符串，首次运行触发误报。修复方案是扫描器显式跳过 `tests/internal/dep_rules.lua` 自身，并将路径统一规整为仓库相对路径后再做白名单判断。

## 决策日志


决策一：本轮不退役 `context_policy = "legacy"` 本身，只做使用面治理。理由是该策略仍承担受控降级职责，直接删除会放大运行环境风险。日期/作者：2026-03-02 / Codex GPT-5。

决策二：治理手段采用 `dep_rules` 规则而非运行时硬失败。理由是静态规则成本更低、反馈更早，并且不会改变线上行为。日期/作者：2026-03-02 / Codex GPT-5。

决策三：legacy 治理白名单仅保留 `tests/suites/runtime_ports_contract.lua`，其余文件零容忍。理由是该文件是契约测试唯一合法样例，扩大白名单会削弱治理效果。日期/作者：2026-03-02 / Codex GPT-5。

## 结果与复盘


本轮已完成。`dep_rules` 新增了 legacy 使用面治理扫描器，明确限制 `context_policy = "legacy"` 与 `enable_legacy_helper_fallback = true` 的显式使用范围；规则已验证可运行且无误伤。回归与依赖规则全绿，运行时行为接口未变化，达到“收口但不破坏”的目标。

## 背景与导读


当前运行时策略入口在 `src/app/bootstrap/RuntimeInstall.lua`，其中 `context_policy` 决定 strict/legacy，`enable_legacy_helper_fallback` 决定是否放开 helper 全局回退。`src/core/RuntimePorts.lua` 提供分项策略 API（`set_legacy_fallback_policy` / `legacy_fallback_policy`）。`tests/suites/runtime_ports_contract.lua` 用来验证 strict/legacy 契约，是当前唯一允许显式 legacy 策略样例的测试文件。

问题在于：如果没有治理，后续开发可能把 legacy 配置扩散到更多模块。为防止回潮，本轮通过 `tests/internal/dep_rules.lua` 建立白名单规则，让新增扩散在 CI 阶段直接失败。

## 工作计划


首先确认旧兼容开关 API 已退役并保持检索清零。然后在 `dep_rules` 增加一个独立扫描器，检查两个模式：`context_policy = "legacy"` 与 `enable_legacy_helper_fallback = true`。扫描范围覆盖 `src` 与 `tests`，只对白名单文件 `tests/suites/runtime_ports_contract.lua` 放行。完成规则后，先跑 `dep_rules` 再跑全量回归。若全部通过，再回填计划并提交。

## 具体步骤


所有命令均在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先确认旧兼容开关退役状态：

    rg "set_legacy_global_fallback_enabled|legacy_global_fallback_enabled\(" src tests -n

验证新增治理规则：

    lua tests/internal/dep_rules.lua

执行全量回归：

    lua tests/regression.lua

核对 legacy 在役入口与规则白名单：

    rg "context_policy|enable_legacy_helper_fallback|set_legacy_fallback_policy\(" src tests -n

## 验证与验收


验收标准共有五条。第一，旧兼容开关 API 在 `src/tests` 检索清零。第二，`dep_rules` 新规则生效且当前白名单通过。第三，`lua tests/regression.lua` 全绿。第四，legacy 显式使用只出现在 `RuntimeInstall` 与 `runtime_ports_contract`。第五，无额外行为回归。

## 可重复性与恢复


本计划可重复执行。若规则误伤，优先调整规则白名单，不回滚业务实现。若回归失败，按文件粒度回退本轮改动并重跑两条测试命令。全程不使用破坏性 git 命令。

## 产物与备注


执行完成后在此保留关键证据：

    [evidence] rg "set_legacy_global_fallback_enabled|legacy_global_fallback_enabled\(" src tests -n -> No matches found
    [evidence] lua tests/internal/dep_rules.lua -> dep_rules ok
    [evidence] lua tests/regression.lua -> All regression checks passed (210), dep_rules ok, tick ok, forbidden_globals ok
    [evidence] rg "context_policy|enable_legacy_helper_fallback|set_legacy_fallback_policy\(" src tests -n -> 命中仅限 RuntimeInstall + runtime_ports_contract + RuntimePorts API

## 接口与依赖


本轮只改动 `tests/internal/dep_rules.lua` 与计划文档，保持 runtime 行为接口不变。runtime 侧有效策略接口仍是 `set_legacy_fallback_policy(policy)` 与 `legacy_fallback_policy()`；legacy 模式能力仍由 `RuntimeInstall` 管理。测试依赖仍使用 `lua tests/internal/dep_rules.lua` 与 `lua tests/regression.lua`。

本次修订说明（2026-03-02 18:03+08:00）：根据 `research.md` 的“继续收口 legacy 使用面”结论，重写 `plan.md` 为治理计划并启动执行。
本次修订说明（2026-03-02 18:05+08:00）：治理计划执行完成，补充了规则自命中修复记录、最终证据与完成态进度。
