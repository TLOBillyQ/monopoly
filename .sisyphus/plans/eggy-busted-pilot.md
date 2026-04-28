# 落地：monopoly contract lane busted 试点

## TL;DR

> **目标**：将 monopoly 项目 contract lane（13 suites / ~68 cases）从自写 `TestHarness` 迁移到 busted BDD runner，同时把项目 Lua 版本对齐到 5.4。
>
> **交付物**：
> - `spec/helper.lua` + `spec/env_runtime.lua` + `spec/log_warns_handler.lua`（Eggy 宿主伪造 + runtime 重装 + warn 体检）
> - `spec/contract/*_spec.lua` × 13（contract suite BDD 迁移，含 `scrap4lua_contract`）
> - `tools/quality/mutate/busted_adapter.lua` + `tools/quality/crap/busted_adapter.lua`（覆盖率适配器）
> - `tools/quality/mutate.lua` CLI 扩展（支持 `--runner busted --dry-run`）
> - `tools/quality/crap.lua` + `tools/quality/crap/config.lua` 扩展（支持 `--runner busted` 路由）
> - `docs/architecture/behavior_warns_data.lua`（warn 白名单 Lua 模块）
> - 更新后的 `docs/architecture/quality_map.md`、`mutate4lua.md`、`crap_report.md`、`health_signals.md`、`arch_view.md`
>
> **估算**：中等（Medium）
> **并行执行**：YES，4 个 wave
> **关键路径**：Baseline → Phase 0 gate → Wave 1 infra → Wave 2 (12 并行) → Wave 2.6 cleanup → Wave 3 adapters → Wave 2.5 mutate suite → 终验

---

## Context

### 原始请求
用户要求落地 `.sisyphus/archive/plan.md` 中的 busted 可行性研究，仅覆盖阶段 0（版本对齐）+ 阶段 1（contract lane 试点）+ 阶段 2（mutate/crap 适配器）。阶段 3–5 不在本次范围。

### 访谈要点
- **Lua 版本**：对齐到 **5.4**（与 Eggy 生产一致）
- **迁移范围**：仅 **contract lane**（13 suites / ~68 cases）
- **其他 lane 不动**：behavior / guard / tooling 继续走旧 `TestHarness`
- **granularity**：13 个 contract suite 迁移拆为 13 个并行任务
- **新测试 infra 的测试**：通过现有 `tests/tooling.lua` 跑 meta-test
- **Phase 0 策略**：硬关卡 — 若 5.4 下任何 lane 出现回归，立即 halt，不再继续
- **`tests/contract.lua` 处理**：硬切换 — 删除 + 更新 5 篇文档
- **spec 命名**：扁平化 `spec/contract/<name>_spec.lua`，无 subsystem 子目录
- **warn 白名单**：新建 `docs/architecture/behavior_warns_data.lua` 作为单源真值

### 研究补充
- 当前项目 Lua 5.5；Eggy 生产 5.4
- 13 个 contract suites（`tests/catalog.lua:160-174`）：
  `read_model_contract`, `architecture_guard_contract`, `script_tools_contract`, `guard_scripts_contract`, `usecase_boundary_contract`, `cross_module_contract`, `intent_output_contract`, `ui_gate_contract`, `narrow_runtime_ports_contract`, `runtime_ports_contract`, `ui_runtime_state_contract`, `tooling_parallel_contract`, `scrap4lua_contract`
- `.luacheckrc` 已是 `std = "lua54"`，Phase 0 只需改 `.luarc.json` + 装 5.4

---

## Work Objectives

### 核心目标
在 monopoly 项目中完成 contract lane 的 busted BDD runner 试点，并保持 behavior / guard / tooling lane 零回归。

### 具体交付物
1. Lua 5.4 运行时与项目配置对齐
2. `spec/` 测试基础设施（helper / env_runtime / log_warns_handler / .busted / smoke spec）
3. 13 个 `spec/contract/*_spec.lua` 文件
4. 2 个覆盖率适配器（mutate / crap）
5. 5 篇文档更新（`quality_map.md`、`mutate4lua.md`、`crap_report.md`、`health_signals.md`、`arch_view.md`）

### 完成定义
- `busted --run=contract` 68 case 全绿
- `lua tests/behavior.lua` + `lua tests/guard.lua` + `lua tests/tooling.lua` 仍全绿（零回归）
- `lua tools/quality/mutate.lua --lane contract --runner busted` 跑通
- `lua tools/quality/crap.lua --lane contract --runner busted` 跑通
- 旧 contract lane 入口 `tests/contract.lua` 已删除

### 必须有
- Lua 5.4 版本对齐
- busted + luassert 安装
- `spec/helper.lua` Eggy 宿主伪造完整
- 13 个 contract suite 迁移
- mutate / crap busted_adapter 至少 dry-run 通过

### 必须不做（Guardrails）
- 不修改 `tests/behavior.lua`、`tests/guard.lua`、`tests/tooling.lua`
- 不修改 `tests/TestHarness.lua`
- 不修改 `tests/support/tooling_parallel.lua`、`tests/support/tooling_worker.lua`
- 不修改 `tools/quality/mutate/driver.lua`（现有），只新增 `busted_adapter.lua`；允许修改 `tools/quality/mutate.lua` 的 CLI 路由部分
- 不修改 `tools/quality/crap/adapter.lua`（现有），只新增 `busted_adapter.lua`；允许修改 `tools/quality/crap.lua` 的 CLI 路由部分和 `tools/quality/crap/config.lua`
- 不动 behavior/guard lane 的 suite 文件
- 不动 `tests/fixtures/*`
- 不在 shared_support.lua 上搞"顺手重构"
- 不在适配器代码里用 `os.execute` / `io.popen`（走 `tools/shared/lib/common.lua`）
- 不引入超出 `test_env.lua` 现有 Eggy 伪造的全局变量
- 不在一个 lane 里混跑两套 runner
- 阶段 3–5 不在本次范围

---

## Verification Strategy

> **零人工干预** — 所有验收都交给 agent 直接执行。绝不允许出现“请用户手动验证”字样的验收标准。

### 测试决策
- **已有测试基础设施**：YES（自写 harness）
- **本次新增自动化测试**：YES — meta-test 通过现有 `tests/tooling.lua`
- **框架**：busted 2.3.0 + luassert
- **TDD 否**：否 — 这是迁移重构，不是从零实现。采用"迁移后绿灯验收"。

### QA 政策
每个任务必须附带 agent 可执行的 QA Scenarios。证据保存到 `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`。
- **CLI / API**：`Bash`（`lua` / `busted` 命令 + 退出码 + stdout 断言）
- **覆盖率适配器**：`Bash`（跑 adapter 命令 + 断言 dry-run 输出包含 spec 文件列表）
- **回归检查**：`Bash`（跑旧 lane + 断言零失败）

---

## Execution Strategy

### 并行执行 Wave

```
Pre-Wave（基线快照，前置）:
├── T0: 捕获 Lua 5.5 下 4 lane case 数 + warn 行数 → baseline

Wave 1（Phase 0 + Phase 1 基础设施，并行）:
├── T1: 安装 Lua 5.4 + luarocks + busted + luassert
├── T2: 改 .luarc.json → Lua 5.4；跑 4 lane 回归检查
├── T3: 写 .busted 配置
├── T4: 写 spec/helper.lua（Eggy 伪造 + path 装配 + 全局 hook）
├── T5: 写 spec/env_runtime.lua（runtime ports 重装）
├── T6: 写 docs/architecture/behavior_warns_data.lua（warn 白名单）
├── T7: 写 spec/log_warns_handler.lua（自定义 output handler）
└── T8: 写 smoke spec + meta-test via tests/tooling.lua

Wave 2（13 个 contract suite 并行迁移）:
├── T9:  read_model_contract → spec/contract/read_model_spec.lua
├── T10: architecture_guard_contract → spec/contract/architecture_guard_spec.lua
├── T11: script_tools_contract → spec/contract/script_tools_spec.lua
├── T12: guard_scripts_contract → spec/contract/guard_scripts_spec.lua
├── T13: usecase_boundary_contract → spec/contract/usecase_boundary_spec.lua
├── T14: cross_module_contract → spec/contract/cross_module_spec.lua
├── T15: intent_output_contract → spec/contract/intent_output_spec.lua
├── T16: ui_gate_contract → spec/contract/ui_gate_spec.lua
├── T17: narrow_runtime_ports_contract → spec/contract/narrow_runtime_ports_spec.lua
├── T18: runtime_ports_contract → spec/contract/runtime_ports_spec.lua
├── T19: ui_runtime_state_contract → spec/contract/ui_runtime_state_spec.lua
├── T20: tooling_parallel_contract → spec/contract/tooling_parallel_spec.lua
└── T20b: scrap4lua_contract → spec/contract/scrap4lua_spec.lua

Wave 2.6（清理与文档更新，顺序）:
├── T21: 删除 13 个旧 suite 文件 + 更新 tests/catalog.lua
├── T22: 更新 5 篇文档（quality_map.md, mutate4lua.md, crap_report.md, health_signals.md, arch_view.md）
└── T23: 删除 tests/contract.lua；验证 busted --run=contract 全绿

Wave 3（Phase 2 适配器 + CLI 入口扩展，并行）:
├── T24: 写 mutate busted_adapter + 扩展 mutate.lua CLI（含 30-min spike）
└── T25: 写 crap busted_adapter + 扩展 crap.lua/config.lua（含 30-min spike）

Wave FINAL（终验，4 并行审查）:
├── F1: Plan compliance audit（oracle）
├── F2: Code quality review（unspecified-high）
├── F3: Real manual QA（unspecified-high）
└── F4: Scope fidelity check（deep）
-> 汇报 -> 等用户明确 okay
```

### 依赖矩阵

| 任务 | 依赖 | 阻塞 |
|---|---|---|
| T0 | - | T1, T2 |
| T1 | T0 | T2 |
| T2 | T0, T1 | T3–T8, Wave 2, F1–F4 |
| T3 | T2 | - |
| T4 | T2 | - |
| T5 | T2 | - |
| T6 | T2 | T7 |
| T7 | T6 | T8 |
| T8 | T7 | - |
| T9–T20b | T3–T8 | T21 |
| T21 | T9–T20b | T22–T23 |
| T22 | T21 | T23 |
| T23 | T21, T22 | F1–F4 |
| T24 | T23 | - |
| T25 | T23 | - |
| F1–F4 | T23, T24, T25 | - |

### Agent 调度汇总

- **Wave 1**: quick / unspecified-high（8 个任务并行）
- **Wave 2**: quick（13 个任务并行，每个迁移 1 个 suite）
- **Wave 2.6**: quick / unspecified-high（3 个顺序任务）
- **Wave 3**: deep（2 个并行，含 spike）
- **Wave 2.5**: unspecified-high（1 个顺序）
- **Final**: oracle / unspecified-high / deep（4 个并行）

---

## TODOs

- [x] T0. **捕获迁移前基线**

  **做什么**：
  - 在 Lua 5.5 下依次跑 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tests/tooling.lua`
  - 记录每条 lane 的：总 case 数、失败数、warn 行数（grep `^\[warn\]`）
  - 把基线写入 `.sisyphus/baseline-pre-migration.txt`

  **必须不做**：
  - 不动任何代码文件

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: NO（顺序前置）
  - **阻塞**: T1, T2

  **参考**：
  - `tests/behavior.lua`、`tests/contract.lua`、`tests/guard.lua`、`tests/tooling.lua` — 直接跑这些入口

  **验收标准**：
  - [ ] `.sisyphus/baseline-pre-migration.txt` 已创建，含 4 lane 的 case 数 + warn 数
  - [ ] 文件 diff 为空（0 个文件被改）

  **QA Scenarios**：
  ```
  Scenario: 基线文件存在
    Tool: Bash
    Steps:
      1. test -f .sisyphus/baseline-pre-migration.txt && echo OK
    Expected: 输出 OK
    Evidence: .sisyphus/evidence/t0-baseline.txt
  ```

  **Commit**: NO（不提交纯基线数据）

---

- [x] T1. **安装 Lua 5.4 + busted + luassert**

  **做什么**：
  - macOS: `brew install lua@5.4`（或等效），确保 `lua -v` 输出 `Lua 5.4.x`
  - 装 luarocks（随 Lua 5.4）
  - `luarocks install busted 2.3.0-1 luassert`
  - `busted --version` 验证通过
  - 记录 Windows 安装步骤到 `.sisyphus/notes/busted-install-windows.md`

  **必须不做**：
  - 不修改 .luarc.json（T2 做）
  - 不在项目代码里加 install 脚本

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（与 T2 中部分步骤可先后，但 T2 需等 T1 完成）
  - **阻塞**: T2 验证步骤

  **验收标准**：
  - [ ] `lua -v 2>&1 | grep -q "Lua 5.4"` → 通过
  - [ ] `which lua` 输出已捕获
  - [ ] `busted --version` → 退出码 0，含 `2.3.0`

  **QA Scenarios**：
  ```
  Scenario: busted 可用
    Tool: Bash
    Steps:
      1. busted --version
    Expected: stdout 含 "2.3.0"，exit 0
    Evidence: .sisyphus/evidence/t1-busted-version.txt

  Scenario: lua 5.4
    Tool: Bash
    Steps:
      1. lua -v
    Expected: stdout 含 "Lua 5.4"
    Evidence: .sisyphus/evidence/t1-lua-version.txt
  ```

  **Commit**: NO

---

- [x] T2. **Lua 5.4 版本对齐 + 回归关卡**

  **做什么**：
  - 改 `.luarc.json`：`runtime.version` → `"Lua 5.4"`
  - 依次跑 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tests/tooling.lua`
  - 每条 lane 的 case 数 + warn 行数与 T0 基线对比，**必须完全一致**（允许 ±0）
  - `lua tools/quality/lint.lua` → 无新违例
  - 若任何 lane 出现差异 → **halt**，标记计划为阻塞，汇报用户

  **必须不做**：
  - 不改任何 src/ 或 tests/ 逻辑代码（只改 .luarc.json）

  **推荐 Agent Profile**：
  - **Category**: `unspecified-high`（需严格断言回归）

  **并行化**：
  - **可并行**: NO（依赖 T0, T1）
  - **阻塞**: 全部后续 wave（硬关卡）

  **参考**：
  - `.luarc.json` — 改 runtime.version
  - `.sisyphus/archive/plan.md` §4 Phase 0

  **验收标准**：
  - [ ] `.luarc.json` 含 `"Lua 5.4"`
  - [ ] 4 lane 全部 exit 0
  - [ ] 每条 lane case 数与基线完全一致
  - [ ] `lua tools/quality/lint.lua` exit 0

  **QA Scenarios**：
  ```
  Scenario: 4 lane 回归通过
    Tool: Bash
    Steps:
      1. lua tests/behavior.lua > /tmp/behavior.txt 2>&1; echo $?
      2. lua tests/contract.lua > /tmp/contract.txt 2>&1; echo $?
      3. lua tests/guard.lua > /tmp/guard.txt 2>&1; echo $?
      4. lua tests/tooling.lua > /tmp/tooling.txt 2>&1; echo $?
    Expected: 4 个退出码均为 0；case 数与基线一致
    Evidence: .sisyphus/evidence/t2-regression.txt
  ```

  **Commit**: YES
  - Message: `chore(config): align project to Lua 5.4`
  - Files: `.luarc.json`

---

- [x] T3. **写 `.busted` 配置文件**

  **做什么**：
  - 在 repo root 写 `.busted`：
    - default: helper=spec/helper.lua, output=spec/log_warns_handler.lua, pattern="_spec"
    - contract: ROOT={"spec/contract"}, output="TAP"
    - ci: output="junit", Xoutput="junit-output.xml"
  - 验证 `.busted` 能被 busted 识别：`busted --run=contract --list`（或等效 dry-run）

  **必须不做**：
  - 不把 `.busted` 放到 spec/ 子目录

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（Wave 1 内与 T4–T8 并行）
  - **阻塞**: -（只被后续 wave 消费）

  **参考**：
  - `.sisyphus/archive/plan.md` §3.2 `.busted` 配置
  - busted 官方文档：配置 discovery 默认在 repo root

  **验收标准**：
  - [ ] `.busted` 存在且语法有效
  - [ ] `busted --run=contract --list`（或跑空目录）exit 0

  **QA Scenarios**：
  ```
  Scenario: .busted 可解析
    Tool: Bash
    Steps:
      1. busted --run=contract -p "__nonexistent__" 2>&1
    Expected: exit 0，stdout 含 "0 successes" 或等效空结果
    Evidence: .sisyphus/evidence/t3-busted-config.txt
  ```

  **Commit**: YES（与 T4–T8 合组）

---

- [x] T4. **写 `spec/helper.lua`（Eggy 宿主伪造 + path 装配 + 全局 hook）**

  **做什么**：
  - 1）path 装配：搬 `tests/bootstrap.lua` 内容 → `spec/helper.lua` 的 `install_paths()`
  - 2）Eggy 宿主伪造：搬 `tests/support/test_env.lua:install_defaults` → 全局 stub/mock（GameAPI, UIManager, LuaAPI, Enums, math.tofixed/Vector3/Quaternion, SetTimeOut 等）
  - 3）注册 busted 全局 hook：`busted.subscribe({"test", "start"}, function() math.randomseed(1); env_runtime.refresh() end)`
  - 4）`require("spec.env_runtime")`
  - 5）验证 helper 加载不报错：`busted --helper=spec/helper.lua -p "__nonexistent__"`

  **必须不做**：
  - 不新增超出 test_env.lua 现有 Eggy 伪造的全局变量
  - 不改 `tests/support/test_env.lua` 原文件

  **推荐 Agent Profile**：
  - **Category**: `unspecified-high`

  **并行化**：
  - **可并行**: YES（Wave 1 内与 T3, T5–T8 并行）
  - **阻塞**: T8 smoke spec

  **参考**：
  - `tests/bootstrap.lua` — path 装配逻辑
  - `tests/support/test_env.lua:install_defaults` — Eggy 伪造清单
  - `.sisyphus/archive/plan.md` §3.3 `spec/helper.lua` 骨架

  **验收标准**：
  - [ ] `busted --helper=spec/helper.lua -p "__nonexistent__"` → exit 0
  - [ ] 全局 GameAPI / UIManager / LuaAPI 存在（`lua -e 'require("spec.helper"); print(GameAPI ~= nil)'`）

  **QA Scenarios**：
  ```
  Scenario: helper 加载无报错
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua -p "__nonexistent__"
    Expected: exit 0
    Evidence: .sisyphus/evidence/t4-helper-load.txt

  Scenario: Eggy 伪造存在
    Tool: Bash
    Steps:
      1. lua -e "require('spec.helper'); print(type(GameAPI), type(UIManager), type(LuaAPI))"
    Expected: stdout 含 "table table table"
    Evidence: .sisyphus/evidence/t4-eggy-fakes.txt
  ```

  **Commit**: YES（与 T3, T5–T8 合组）

---

- [x] T5. **写 `spec/env_runtime.lua`（runtime ports 重装）**

  **做什么**：
  - 从 `tests/support/shared_support.lua` 提取 `_refresh_runtime_context_for_tests`（或等效函数）
  - 暴露为模块：`return { refresh = function() ... end }`
  - 被 `spec/helper.lua` 的 `before_each` hook 调用
  - 替代现有的 `with_patches` 机制（显式在每个 test start 重置）

  **必须不做**：
  - 不提取 `shared_support.lua` 的其他函数（assert_eq、fixture builders 等）
  - 不改 `tests/support/shared_support.lua` 原文件

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（Wave 1 内与 T3, T4, T6–T8 并行）
  - **阻塞**: T4（T4 会 `require("spec.env_runtime")`）

  **参考**：
  - `tests/support/shared_support.lua` — 找 `refresh` / `reset` / `with_patches` 相关逻辑
  - `.sisyphus/archive/plan.md` §3.3 骨架

  **验收标准**：
  - [ ] `lua -e "require('spec.env_runtime').refresh()"` → exit 0，不抛错
  - [ ] `spec/helper.lua` 加载后 `env_runtime` 表存在

  **QA Scenarios**：
  ```
  Scenario: env_runtime.refresh 可调用
    Tool: Bash
    Steps:
      1. lua -e "local e = require('spec.env_runtime'); e.refresh(); print('OK')"
    Expected: stdout 含 "OK"
    Evidence: .sisyphus/evidence/t5-env-runtime.txt
  ```

  **Commit**: YES（与 T3–T4, T6–T8 合组）

---

- [x] T6. **写 `docs/architecture/behavior_warns_data.lua`（warn 白名单 Lua 模块）**

  **做什么**：
  - 把 `docs/architecture/behavior_warns.md` 中的白名单条目提取为结构化 Lua 表
  - 格式：`return { whitelist = { ["warn message pattern"] = true, ... } }`
  - 保留 `behavior_warns.md` 作为文档，但从 `behavior_warns_data.lua` 生成或手动同步
  - 被 `spec/log_warns_handler.lua` 引用

  **必须不做**：
  - 不删除 behavior_warns.md
  - 不改白名单语义（只改存储格式）

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（Wave 1 内与 T3–T5, T7–T8 并行）
  - **阻塞**: T7（handler 需要引用它）

  **参考**：
  - `docs/architecture/behavior_warns.md` — 提取白名单条目
  - `tests/support/log_capture.lua` — 了解 warn 聚合逻辑

  **验收标准**：
  - [ ] `lua -e "local d = require('docs.architecture.behavior_warns_data'); print(type(d.whitelist))"` → "table"
  - [ ] 白名单条目数与 behavior_warns.md 一致

  **QA Scenarios**：
  ```
  Scenario: 白名单模块可加载
    Tool: Bash
    Steps:
      1. lua -e "local d = require('docs.architecture.behavior_warns_data'); print(type(d.whitelist))"
    Expected: stdout 含 "table"
    Evidence: .sisyphus/evidence/t6-warn-data.txt
  ```

  **Commit**: YES（与 T3–T5, T7–T8 合组）

---

- [x] T7. **写 `spec/log_warns_handler.lua`（自定义 output handler）**

  **做什么**：
  - 实现一个 busted output handler：
    - 构造：`local handler = require("busted.outputHandlers.base")(options)`
    - 订阅 `testStart`：启动 `log_capture.capture()` 创建 case buffer
    - 订阅 `testEnd`：调用 `log_capture.collect_summary(buffer)`，按白名单过滤，非白名单 warn 视为失败/pending
    - 订阅 `suiteEnd`：打印聚合 `[warn] suppressed xN <line>`
    - **委托模式**：handler 内部再套一个基础 handler（utfTerminal / TAP / junit），把格式输出委托给它。这样 `output = spec/log_warns_handler.lua` 仍然能产出 TAP/junit
  - 引用 `tests/support/log_capture.lua`（复用现有聚合逻辑）
  - 引用 `docs/architecture/behavior_warns_data.lua`（白名单）

  **必须不做**：
  - 不重新发明 warn 聚合算法（复用 log_capture）

  **推荐 Agent Profile**：
  - **Category**: `unspecified-high`

  **并行化**：
  - **可并行**: YES（Wave 1 内与 T3–T6, T8 并行）
  - **阻塞**: T8（smoke spec 跑 handler）

  **参考**：
  - `tests/support/log_capture.lua` — 复用 capture / collect_summary API
  - `docs/architecture/behavior_warns.md` — warn 白名单语义
  - busted 文档：自定义 output handler 事件订阅 + 委托模式
  - `.sisyphus/archive/plan.md` §3.4 handler 骨架

  **验收标准**：
  - [ ] `busted --helper=spec/helper.lua --run=contract -o spec/log_warns_handler.lua -p "smoke"` → exit 0
  - [ ] handler 能正确委托 TAP 格式：`busted --run=contract -o spec/log_warns_handler.lua` 输出含 TAP 前缀

  **QA Scenarios**：
  ```
  Scenario: handler 加载无报错
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua -o spec/log_warns_handler.lua -p "__nonexistent__"
    Expected: exit 0
    Evidence: .sisyphus/evidence/t7-handler-load.txt

  Scenario: handler 委托 TAP
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -o spec/log_warns_handler.lua spec/contract/_smoke_spec.lua
    Expected: stdout 含 "ok "（TAP ok 行）
    Evidence: .sisyphus/evidence/t7-handler-tap.txt
  ```

  **Commit**: YES（与 T3–T6, T8 合组）

---

- [x] T8. **写 smoke spec + meta-test**

  **做什么**：
  - 写 `spec/contract/_smoke_spec.lua`：
    - 1 个 `describe` + 1 个 `it`：验证 GameAPI 全局存在 + env_runtime.refresh() 可调用
    - 1 个 `it`：故意触发 warn，验证 handler 白名单过滤不报错
  - 跑 `busted --run=contract` 验证 smoke spec 绿
  - 在 `tests/tooling.lua` 中新增一个 meta-test 子任务（或新 suite），验证：
    - `spec/helper.lua` 可加载
    - `spec/env_runtime.lua` 可加载
    - `spec/log_warns_handler.lua` 语法有效
    - `docs/architecture/behavior_warns_data.lua` 条目数 > 0
  - 跑 `lua tests/tooling.lua` 验证 meta-test 通过

  **必须不做**：
  - 不写超过 3 个 case 的 smoke spec（这只是 infra 验证）

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: NO（依赖 T3–T7）
  - **阻塞**: Wave 2 全部

  **验收标准**：
  - [ ] `busted --run=contract` → exit 0，至少 2 success
  - [ ] `lua tests/tooling.lua` → exit 0（meta-test 通过）
  - [ ] `git diff --stat tests/behavior.lua tests/guard.lua tests/tooling.lua tests/TestHarness.lua` → 0 行改动（meta-test 只能新增 suite 文件或 tooling 子任务，不能改入口）

  **QA Scenarios**：
  ```
  Scenario: smoke spec 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract
    Expected: exit 0，stdout 含 "2 successes"（或等效）
    Evidence: .sisyphus/evidence/t8-smoke-green.txt

  Scenario: meta-test 通过
    Tool: Bash
    Steps:
      1. lua tests/tooling.lua
    Expected: exit 0
    Evidence: .sisyphus/evidence/t8-meta-test.txt
  ```

  **Commit**: YES（与 T3–T7 合组）
  - Message: `test(infra): add busted helper, env_runtime, handler, smoke spec`
  - Files: `spec/`, `.busted`, `docs/architecture/behavior_warns_data.lua`

---

- [x] T9. **迁移 `read_model_contract` → `spec/contract/read_model_spec.lua`**

  **做什么**：
  - 读 `tests/suites/presentation/read_model_contract.lua`
  - 改写为 `describe/it` 形式；用 luassert 替代 assert_eq；复用 `spec/env_runtime.lua` 和现有 fixtures
  - 保留原有的 warn 触发断言（如果有）
  - 跑 `busted --run=contract -p read_model` 绿
  - 对比基线：case 数与旧 suite 一致；warn 行数与基线一致

  **必须不做**：
  - 不新增 fixture / helper 函数
  - 不改旧 suite 文件（T21 统一删）

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（Wave 2 内与 T10–T20 并行）
  - **阻塞**: T21

  **参考**：
  - `tests/suites/presentation/read_model_contract.lua`
  - `tests/support/shared_support.lua` — 看该 suite 用了哪些辅助函数
  - `.sisyphus/archive/plan.md` §3.5 spec 形态示例

  **验收标准**：
  - [ ] `busted --run=contract -p read_model` → exit 0
  - [ ] case 数与基线一致
  - [ ] warn 行数与基线一致

  **QA Scenarios**：
  ```
  Scenario: 迁移后单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p read_model
    Expected: exit 0，stdout 含 "0 failures"
    Evidence: .sisyphus/evidence/t9-read-model.txt
  ```

  **Commit**: NO（Wave 2 结束统一提交）

---

- [x] T10. **迁移 `architecture_guard_contract` → `spec/contract/architecture_guard_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/architecture_guard_contract.lua`
  - 改写为 `describe/it`；跑 `busted --run=contract -p architecture_guard` 绿
  - case + warn 数与基线一致

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（Wave 2 内与 T9, T11–T20 并行）
  - **阻塞**: T21

  **参考**：
  - `tests/suites/architecture/architecture_guard_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p architecture_guard` → exit 0，0 failures
  - [ ] case/warn 数与基线一致

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p architecture_guard
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t10-arch-guard.txt
  ```

  **Commit**: NO

---

- [x] T11. **迁移 `script_tools_contract` → `spec/contract/script_tools_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/script_tools_contract.lua`
  - 改写；跑 `busted --run=contract -p script_tools` 绿
  - case + warn 数与基线一致

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES
  - **阻塞**: T21

  **参考**：
  - `tests/suites/architecture/script_tools_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p script_tools` → exit 0

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p script_tools
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t11-script-tools.txt
  ```

  **Commit**: NO

---

- [x] T12. **迁移 `guard_scripts_contract` → `spec/contract/guard_scripts_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/guard_scripts_contract.lua`
  - 改写；跑 `busted --run=contract -p guard_scripts` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/architecture/guard_scripts_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p guard_scripts` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p guard_scripts
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t12-guard-scripts.txt
  ```

  **Commit**: NO

---

- [x] T13. **迁移 `usecase_boundary_contract` → `spec/contract/usecase_boundary_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/usecase_boundary_contract.lua`
  - 改写；跑 `busted --run=contract -p usecase_boundary` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/architecture/usecase_boundary_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p usecase_boundary` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p usecase_boundary
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t13-usecase-boundary.txt
  ```

  **Commit**: NO

---

- [x] T14. **迁移 `cross_module_contract` → `spec/contract/cross_module_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/cross_module_contract.lua`
  - 改写；跑 `busted --run=contract -p cross_module` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/architecture/cross_module_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p cross_module` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p cross_module
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t14-cross-module.txt
  ```

  **Commit**: NO

---

- [x] T15. **迁移 `intent_output_contract` → `spec/contract/intent_output_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/intent_output_contract.lua`
  - 改写；跑 `busted --run=contract -p intent_output` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/architecture/intent_output_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p intent_output` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p intent_output
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t15-intent-output.txt
  ```

  **Commit**: NO

---

- [x] T16. **迁移 `ui_gate_contract` → `spec/contract/ui_gate_spec.lua`**

  **做什么**：
  - 读 `tests/suites/presentation/ui_gate_contract.lua`
  - 改写；跑 `busted --run=contract -p ui_gate` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/presentation/ui_gate_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p ui_gate` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p ui_gate
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t16-ui-gate.txt
  ```

  **Commit**: NO

---

- [x] T17. **迁移 `narrow_runtime_ports_contract` → `spec/contract/narrow_runtime_ports_spec.lua`**

  **做什么**：
  - 读 `tests/suites/runtime/narrow_runtime_ports_contract.lua`
  - 改写；跑 `busted --run=contract -p narrow_runtime_ports` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/runtime/narrow_runtime_ports_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p narrow_runtime_ports` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p narrow_runtime_ports
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t17-narrow-runtime.txt
  ```

  **Commit**: NO

---

- [x] T18. **迁移 `runtime_ports_contract` → `spec/contract/runtime_ports_spec.lua`**

  **做什么**：
  - 读 `tests/suites/runtime/runtime_ports_contract.lua`
  - 改写；跑 `busted --run=contract -p runtime_ports` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/runtime/runtime_ports_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p runtime_ports` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p runtime_ports
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t18-runtime-ports.txt
  ```

  **Commit**: NO

---

- [x] T19. **迁移 `ui_runtime_state_contract` → `spec/contract/ui_runtime_state_spec.lua`**

  **做什么**：
  - 读 `tests/suites/presentation/ui_runtime_state_contract.lua`
  - 改写；跑 `busted --run=contract -p ui_runtime_state` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/presentation/ui_runtime_state_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p ui_runtime_state` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p ui_runtime_state
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t19-ui-runtime-state.txt
  ```

  **Commit**: NO

---

- [x] T20. **迁移 `tooling_parallel_contract` → `spec/contract/tooling_parallel_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/tooling_parallel_contract.lua`
  - 改写；跑 `busted --run=contract -p tooling_parallel` 绿

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES

  **参考**：
  - `tests/suites/architecture/tooling_parallel_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p tooling_parallel` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p tooling_parallel
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t20-tooling-parallel.txt
  ```

  **Commit**: NO

---

- [x] T20b. **迁移 `scrap4lua_contract` → `spec/contract/scrap4lua_spec.lua`**

  **做什么**：
  - 读 `tests/suites/architecture/scrap4lua_contract.lua`
  - 改写为 `describe/it`；跑 `busted --run=contract -p scrap4lua` 绿
  - case + warn 数与基线一致

  **推荐 Agent Profile**：
  - **Category**: `quick`

  **并行化**：
  - **可并行**: YES（Wave 2 内与 T9–T20 并行）
  - **阻塞**: T21

  **参考**：
  - `tests/suites/architecture/scrap4lua_contract.lua`

  **验收标准**：
  - [ ] `busted --run=contract -p scrap4lua` → exit 0，0 failures

  **QA Scenarios**：
  ```
  Scenario: 单 suite 绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -p scrap4lua
    Expected: exit 0，0 failures
    Evidence: .sisyphus/evidence/t20b-scrap4lua.txt
  ```

  **Commit**: NO

---

- [x] T21. **清理旧 suite 文件 + 更新 `tests/catalog.lua`**

  **做什么**：
  - 删除 13 个旧 contract suite 文件（`tests/suites/presentation/read_model_contract.lua` 等）
  - 更新 `tests/catalog.lua`：从 `contract_modules` 列表移除这 13 个条目，使 `contract_modules` 为空列表 `{}`
  - 跑 `lua tests/behavior.lua` + `lua tests/guard.lua` + `lua tests/tooling.lua` 确认旧 lane 仍绿

  **必须不做**：
  - 不删 behavior / guard / tooling lane 的 suite 文件（含 `mutate4lua_tooling_contract.lua`）
  - 不改 `tests/TestHarness.lua`

  **推荐 Agent Profile**：
  - **Category**: `unspecified-high`

  **并行化**：
  - **可并行**: NO（顺序，依赖 T9–T20b）
  - **阻塞**: T22–T23

  **参考**：
  - `tests/catalog.lua:167-181` — 确认 contract_modules 列表

  **验收标准**：
  - [ ] 13 个旧 suite 文件已不存在
  - [ ] `tests/catalog.lua` 中 `contract_modules` 为空列表 `{}`
  - [ ] `lua tests/behavior.lua` → exit 0
  - [ ] `lua tests/guard.lua` → exit 0
  - [ ] `lua tests/tooling.lua` → exit 0
  - [ ] `git diff --stat tests/TestHarness.lua` → 0

  **QA Scenarios**：
  ```
  Scenario: 旧 lane 零回归
    Tool: Bash
    Steps:
      1. lua tests/behavior.lua && lua tests/guard.lua && lua tests/tooling.lua
    Expected: 全部 exit 0
    Evidence: .sisyphus/evidence/t21-old-lanes.txt
  ```

  **Commit**: YES（Wave 2.6 合组）
  - Message: `refactor(test): remove migrated contract suites from tests/suites`

---

- [x] T22. **更新 5 篇文档**

  **做什么**：
  - 更新以下文档中所有 `lua tests/contract.lua` 引用 → `busted --run=contract`：
    1. `docs/architecture/quality_map.md`
    2. `docs/architecture/mutate4lua.md`
    3. `docs/architecture/crap_report.md`
    4. `docs/architecture/health_signals.md`
    5. `docs/architecture/arch_view.md`
  - 更新 `docs/architecture/behavior_warns.md`：添加对 `behavior_warns_data.lua` 的说明
  - 若某篇文档提到的命令不只 contract lane，只改 contract 部分，不动 behavior/guard/tooling 部分

  **必须不做**：
  - 不改 behavior/guard/tooling 的命令引用

  **推荐 Agent Profile**：
  - **Category**: `writing`

  **并行化**：
  - **可并行**: NO（顺序，与 T21 同 wave）
  - **阻塞**: T23

  **参考**：
  - 5 篇 docs 中 grep `tests/contract.lua` 的结果

  **验收标准**：
  - [ ] 5 篇文档中已无 `lua tests/contract.lua` 字符串
  - [ ] `grep -r "lua tests/contract.lua" docs/` → 空

  **QA Scenarios**：
  ```
  Scenario: 文档已更新
    Tool: Bash
    Steps:
      1. grep -r "lua tests/contract.lua" docs/architecture/
    Expected: 空输出
    Evidence: .sisyphus/evidence/t22-docs-updated.txt
  ```

  **Commit**: YES（Wave 2.6 合组）

---

- [x] T23. **删除 `tests/contract.lua` + 验证 busted contract lane 全绿**

  **做什么**：
  - 删除 `tests/contract.lua`
  - 修改 `tests/regression.lua`：
    - 把 `local contract = require("tests.contract")` 移除
    - 把 `_run_lane("contract", contract.run, timings)` 改为用 `common.run_command({"busted", "--run=contract"})` 替代
    - 保持 behavior / guard 部分不变
  - 跑 `busted --run=contract`：
    - 总 case 数 = 68（或 T0 基线值）
    - 0 failures，0 errors
  - 跑 `busted --run=contract -o TAP`：验证输出含 `ok` 行数 = case 数
  - 跑 `busted --run=contract -o junit -Xoutput=/tmp/contract-junit.xml && xmllint --noout /tmp/contract-junit.xml`（如无 xmllint，则仅验证文件非空 + 含 `<testsuites>`）
  - 跑 `busted --run=contract --filter="rejects"`：验证 filter 机制有效
  - 跑 `lua tests/behavior.lua` + `lua tests/guard.lua` + `lua tests/tooling.lua`：零回归
  - 跑 `lua tests/regression.lua`：验证仍能通过（contract 部分走 busted，behavior/guard 部分不变）
  - 跑 `lua tools/quality/arch.lua check`：无新边界违例
  - 跑 `lua tools/quality/lint.lua`：无新违例

  **必须不做**：
  - 不删 tests/contract.lua 以外的入口文件
  - 不改 tests/behavior.lua、tests/guard.lua 的调用逻辑

  **推荐 Agent Profile**：
  - **Category**: `unspecified-high`

  **并行化**：
  - **可并行**: NO（顺序，依赖 T21–T22）
  - **阻塞**: Wave 3, F1–F4

  **验收标准**：
  - [ ] `tests/contract.lua` 已不存在
  - [ ] `busted --run=contract` → exit 0，case 数 = 基线，0 failures
  - [ ] `busted --run=contract -o TAP` → 有效 TAP 输出
  - [ ] 旧 lane 仍全绿
  - [ ] `lua tests/regression.lua` → exit 0
  - [ ] `lua tools/quality/arch.lua check` → exit 0

  **QA Scenarios**：
  ```
  Scenario: contract lane 全绿
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract
    Expected: exit 0，stdout 含 "0 failures"
    Evidence: .sisyphus/evidence/t23-contract-full.txt

  Scenario: TAP 输出有效
    Tool: Bash
    Steps:
      1. busted --helper=spec/helper.lua --run=contract -o TAP | grep -c "^ok"
    Expected: 输出 >= 68
    Evidence: .sisyphus/evidence/t23-tap.txt

  Scenario: 旧 lane 回归
    Tool: Bash
    Steps:
      1. lua tests/behavior.lua && lua tests/guard.lua && lua tests/tooling.lua
    Expected: 全部 exit 0
    Evidence: .sisyphus/evidence/t23-old-lanes.txt

  Scenario: regression.lua 仍可用
    Tool: Bash
    Steps:
      1. lua tests/regression.lua
    Expected: exit 0
    Evidence: .sisyphus/evidence/t23-regression.txt
  ```

  **Commit**: YES（Wave 2.6 合组）
  - Message: `refactor(test): remove tests/contract.lua, cut to busted runner`

---

- [x] T24. **写 `tools/quality/mutate/busted_adapter.lua` + 扩展 `mutate.lua` CLI**

  **做什么**：
  - **30-min spike**：先写最小证明：
    - glob `spec/contract/*_spec.lua`
    - 用 busted `standalone_loader` 加载 1 个 spec 文件并构建 suite tree
    - 验证能获取 suite 名和 case 名列表
  - spike 通过后再写完整适配器：
    - `discover_specs(lane)` → 返回 spec 文件列表
    - `run_with_coverage(spec_files, on_test)` → 用 busted runner 程序化调用，挂 `debug.sethook("l")` 收行覆盖，emit 覆盖数据给 `vendor/mutate4lua`
  - 扩展 `tools/quality/mutate.lua` CLI：
    - `_parse_args` 加入 `--runner` 选项（值为 `harness` 或 `busted`，默认 `harness`）
    - 当 `--runner busted` 时，`M.build_core_command` 把 `--driver-script` 指向 `tools/quality/mutate/busted_adapter.lua` 而非 `driver.lua`
    - 加入 `--dry-run` 支持：只调用 `busted_adapter.discover_specs()` 列出文件，不启动 engine
  - 走 `tools/shared/lib/common.lua` 做路径 / 进程操作
  - 验证 `lua tools/quality/mutate.lua --lane contract --runner busted --dry-run` → 列出 13 个 spec 文件

  **必须不做**：
  - 不改 `tools/quality/mutate/driver.lua` 原文件
  - 不用 `os.execute` / `io.popen`

  **推荐 Agent Profile**：
  - **Category**: `deep`（需要理解 busted 内部 API + CLI 路由）

  **并行化**：
  - **可并行**: YES（与 T25 并行）
  - **阻塞**: -

  **参考**：
  - `.sisyphus/archive/plan.md` §3.6 mutate4lua 适配器设计
  - busted `standalone_loader` / `busted.runner` 文档
  - `tools/quality/mutate/driver.lua` — 现有适配接口
  - `tools/quality/mutate.lua` — CLI 入口与 `_parse_args` / `build_core_command`
  - `tools/shared/lib/common.lua` — 路径/进程规范

  **验收标准**：
  - [ ] spike 产出：能列出 spec 文件名和 case 名
  - [ ] `lua tools/quality/mutate.lua --lane contract --runner busted --dry-run` → exit 0，stdout 含 13 个 spec 文件路径
  - [ ] `lua tools/quality/mutate.lua --lane contract --runner harness --dry-run` → 仍走旧 driver（回归验证）

  **QA Scenarios**：
  ```
  Scenario: dry-run 列出 spec
    Tool: Bash
    Steps:
      1. lua tools/quality/mutate.lua --lane contract --runner busted --dry-run
    Expected: stdout 含 13 个 spec/contract/*_spec.lua 路径
    Evidence: .sisyphus/evidence/t24-mutate-dryrun.txt

  Scenario: 旧 runner 仍可用
    Tool: Bash
    Steps:
      1. lua tools/quality/mutate.lua --lane behavior --runner harness --dry-run
    Expected: exit 0，stdout 含 behavior suite 文件路径
    Evidence: .sisyphus/evidence/t24-mutate-harness-regression.txt
  ```

  **Commit**: YES（Wave 3 合组）

---

- [x] T25. **写 `tools/quality/crap/busted_adapter.lua` + 扩展 `crap.lua` / `config.lua`**

  **做什么**：
  - **30-min spike**：先证明能从 busted 获取 suite tree + 跑 case + 收行覆盖
  - 写完整适配器：接口同 T24，但输出格式匹配 `vendor/crap4lua` 期望
  - 扩展 `tools/quality/crap/config.lua`：
    - `coverage` 配置改为支持多 lane / 多 adapter，如：
      ```lua
      coverage = {
        lanes = { behavior = "adapter.lua", contract = "busted_adapter.lua" }
      }
      ```
    - 保持向后兼容：不指定 lane 时默认仍走 `adapter.lua`
  - 扩展 `tools/quality/crap.lua` CLI：
    - 新增 `dry-run` 子命令：只调用 adapter 的 `discover_specs()` 列出 spec 文件并打印，不启动 engine / 不实际跑 coverage
    - `collect` / `report` 子命令加入 `--runner` 选项（或从 `--lane` 映射到 config 中的 adapter）
    - 当 `lane == "contract"` 时加载 `busted_adapter.lua` 替代 `adapter.lua`
  - 走 `tools/shared/lib/common.lua`
  - 验证 `lua tools/quality/crap.lua dry-run --lane contract --runner busted` → 列出 13 个 spec 文件
  - 验证 `lua tools/quality/crap.lua collect --lane contract --out /tmp/crap-contract.json` 能产出 coverage JSON

  **必须不做**：
  - 不改 `tools/quality/crap/adapter.lua` 原文件
  - 不用 `os.execute` / `io.popen`

  **推荐 Agent Profile**：
  - **Category**: `deep`

  **并行化**：
  - **可并行**: YES（与 T24 并行）
  - **阻塞**: -

  **参考**：
  - `.sisyphus/archive/plan.md` §3.6
  - `tools/quality/crap/adapter.lua` — 现有适配接口
  - `tools/quality/crap.lua` — CLI 入口
  - `tools/quality/crap/config.lua` — adapter 配置

  **验收标准**：
  - [ ] spike 通过
  - [ ] `lua tools/quality/crap.lua dry-run --lane contract --runner busted` → exit 0，stdout 含 13 个 spec 文件路径
  - [ ] `lua tools/quality/crap.lua collect --lane contract --out /tmp/crap-contract.json` → exit 0，/tmp/crap-contract.json 非空且含覆盖率数据
  - [ ] `lua tools/quality/crap.lua report --lane behavior` → 仍走旧 adapter（回归验证）

  **QA Scenarios**：
  ```
  Scenario: dry-run 列出 spec
    Tool: Bash
    Steps:
      1. lua tools/quality/crap.lua dry-run --lane contract --runner busted
    Expected: exit 0，stdout 含 13 个 spec/contract/*_spec.lua 路径
    Evidence: .sisyphus/evidence/t25-crap-dryrun.txt

  Scenario: collect contract lane coverage
    Tool: Bash
    Steps:
      1. lua tools/quality/crap.lua collect --lane contract --out /tmp/crap-contract.json
    Expected: exit 0，/tmp/crap-contract.json 存在且 size > 0
    Evidence: .sisyphus/evidence/t25-crap-collect.txt

  Scenario: behavior lane 回归
    Tool: Bash
    Steps:
      1. lua tools/quality/crap.lua report --lane behavior --out /tmp/crap-behavior.json
    Expected: exit 0
    Evidence: .sisyphus/evidence/t25-crap-behavior-regression.txt
  ```

  **Commit**: YES（Wave 3 合组）

---

## Final Verification Wave

> 4 个 review agent 并行执行。全部通过才汇报给用户，等用户明确 "okay" 再收工。
> 不要自动 proceed。

- [x] F1. **Plan Compliance Audit** — `oracle`
  通读计划全文。对每个 "Must Have"：用 read / bash 验证实现存在。对每个 "Must NOT Have"：搜代码库找禁用的模式，若发现 → 拒掉并给出 file:line。检查 `.sisyphus/evidence/` 下证据文件存在。对比交付物与计划。
  输出格式：`Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  跑 `lua tools/quality/lint.lua` + `lua tools/quality/arch.lua check`。审阅所有改动文件：
  - 有无 `tonumber` / `type == "number"` 违例（src/ 禁用）
  - 有无 `os.execute` / `io.popen`（tools/ 禁用）
  - 有无硬编码反斜杠路径
  - AI slop 检查：过度注释、过度抽象、通用命名（data/result/item/temp）
  输出格式：`Lint [PASS/FAIL] | Arch [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [x] F3. **Real Manual QA** — `unspecified-high`
  从干净状态执行每个任务的 QA Scenario：
  - 跑 `busted --run=contract`（完整 68 case）
  - 跑 `busted --run=contract -o TAP` 并验证格式
  - 跑 `busted --run=contract -o junit` 并验证 XML
  - 跑 `lua tests/behavior.lua` + `lua tests/guard.lua` + `lua tests/tooling.lua`
  - 跑 `lua tools/quality/mutate.lua --lane contract --runner busted --dry-run`
  - 跑 `lua tools/quality/crap.lua dry-run --lane contract --runner busted`
  - 测边缘：空 filter、无效 filter、rapid invoke
  证据保存到 `.sisyphus/evidence/final-qa/`。
  输出格式：`Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  对每个任务：读 "What to do"，看实际 git diff。验证 1:1 — spec 里写的都做了，没多写。检查 "Must NOT do" 合规。检查跨任务污染（Task N 改了 Task M 的文件）。标记未说明的改动。
  输出格式：`Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **T2**: `chore(config): align project to Lua 5.4` — `.luarc.json`
- **T3–T8 合组**: `test(infra): add busted helper, env_runtime, handler, smoke spec` — `spec/`, `.busted`, `docs/architecture/behavior_warns_data.lua`
- **T9–T20b 合组**: `test(contract): migrate 13 contract suites to busted` — `spec/contract/*_spec.lua`
- **T21–T23 合组**: `refactor(test): remove old contract suites and cut to busted runner` — 删除 `tests/suites/*_contract.lua`, `tests/contract.lua`, 更新 `tests/catalog.lua`, docs
- **T24–T25 合组**: `feat(tools): add mutate and crap busted adapters with CLI routing` — `tools/quality/mutate/busted_adapter.lua`, `tools/quality/mutate.lua`, `tools/quality/crap/busted_adapter.lua`, `tools/quality/crap.lua`, `tools/quality/crap/config.lua`

---

## Success Criteria

### 验证命令
```bash
# Phase 0
lua -v                           # Expected: Lua 5.4.x
lua tests/behavior.lua           # Expected: exit 0, case 数 = 基线
lua tests/contract.lua           # Expected: exit 0, case 数 = 基线
lua tests/guard.lua              # Expected: exit 0
lua tests/tooling.lua            # Expected: exit 0
lua tools/quality/lint.lua       # Expected: exit 0

# Phase 1
busted --run=contract            # Expected: 68 case 全绿
busted --run=contract -o TAP     # Expected: 有效 TAP 输出
busted --run=contract -o junit   # Expected: 有效 JUnit XML

# Phase 2
lua tools/quality/mutate.lua --lane contract --runner busted --dry-run   # Expected: 列出 13 spec 文件
lua tools/quality/crap.lua dry-run --lane contract --runner busted      # Expected: 列出 13 spec 文件

# 零回归
lua tests/behavior.lua && lua tests/guard.lua && lua tests/tooling.lua   # Expected: 全部 exit 0
lua tools/quality/arch.lua check                                         # Expected: exit 0
```

### 最终检查清单
- [ ] Lua 5.4 对齐完成
- [ ] busted + luassert 安装验证通过
- [ ] 13 个 `spec/contract/*_spec.lua` 全绿
- [ ] `busted --run=contract` 68 case 0 failure
- [ ] TAP / JUnit 输出有效
- [ ] 旧 `tests/contract.lua` 已删除
- [ ] `tests/catalog.lua` 中 `contract_modules` 为空
- [ ] 5 篇文档已更新
- [ ] mutate / crap busted_adapter dry-run 通过
- [ ] `lua tests/behavior.lua` + `lua tests/guard.lua` + `lua tests/tooling.lua` 零回归
- [ ] `lua tools/quality/arch.lua check` 零新违例
- [ ] `lua tools/quality/lint.lua` 零新违例
- [ ] `.sisyphus/evidence/` 下所有证据文件存在
- [ ] F1–F4 终验全部 APPROVE
- [ ] 用户明确 "okay"