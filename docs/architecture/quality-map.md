---
kind: contract
status: stable
owner: architecture
last_verified: 2026-06-27
---
# 测试与静态分析地图

这份文档回答三个问题：

1. 现在仓库有哪些质量入口。
2. 每条入口在守什么，不守什么。
3. 本地该先跑哪条，通常要等多久。

> **按改动 glob 反查**：先看 [`.agents/README.md` § 按改动入口路由](../../.agents/README.md#按改动入口路由)。本文档是工具机制真源，路由是入口决策面。

> 基线日期：2026-03-16（Asia/Hong_Kong，本机实测）。耗时会随 case 数、日志量、冷启动状态变化。

## 七块质量面

| 入口 | 类型 | 主要回答的问题 | 当前本地耗时参考 |
|------|------|----------------|------------------|
| `busted --run behavior` | 行为回归 | 改动后真实玩法 / UI 行为有没有坏 | 串行约 `5s`，并行约 `2.5s` |
| `busted --run behavior-smoke` | 行为冒烟 | 核心回合流程 + 规则 + UI 行为有没有坏 | 约 `6s` |
| `lua spec/support/behavior_parallel.lua` | 行为回归（并行） | 同 behavior，3 worker LPT 调度 | 约 `2.5s` |
| `~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract` | 快速契约回归 | 端口、边界、读模型、快速架构契约有没有漂移 | 约 `10s` |
| `busted --run tooling` | 工具 smoke / 慢契约 | `mutate --index-suites`、`arch_view viewer/scan` 这类真实工具链是否还能跑通 | 串行约 `45s`，并行约 `30s` |
| `busted --run guards` | 文本护栏 | 有没有出现明确禁用写法、旧路径、越界依赖文本痕迹 | 约 `1.3s` |
| `lua tools/quality/arch.lua check` | 静态架构扫描 | `src/**/*.lua` 的模块依赖图是否违反边界、产生循环 | 约 `0.2s` |
| `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` | 风险热点分析 | 哪些函数复杂且覆盖不足，应该先补测或重构；`crap.lua summary` 输出 src/ 行覆盖率三层聚合（见 `crap_report.md#覆盖率聚合`） | 约 `9s-10s` |
| `lua tools/quality/mutate.lua src/foo.lua --scan` | 单文件变异测试 | 这个文件现有测试是否真能杀掉简单错误 | 目标文件和 lane 差异很大；默认先按 `behavior` 估算 |
| `lua tools/quality/verify_full.lua` | 管道编排 | 默认 slim：lint→encoding→behavior(全)→contract/guards/arch；`--full` 加 coverage + crap | 默认 slim 约 `5s`（实测待补），`--full` 约 `50s`，含 `--tooling` 再加 `~30s` |
| `busted --run e2e` | 真实编辑器 e2e | host 层胶水（场景实体、试玩生命周期、UI 射线、事件广播）在真实 Eggy 编辑器里有没有坏 | 取决于编辑器启动状态，单 spec 通常几秒；**仅 Windows + 编辑器在线时可跑** |

建议把它们分成两层理解：

- `spec/*` 负责确认“功能/契约还是不是对的”。
- `guard + arch_view + crap` 负责确认“结构/风险有没有继续变坏”。

## 当前规模

| 入口 | 当前规模 | 备注 |
|------|----------|------|
| `behavior` | `147` 个 suite，`2033` 个 case | 其中部分 case 在特定 mode 下禁用 |
| `behavior-smoke` | `159` 个 suite，`2249` 个 case | turn/foundation/host/state/rules/ui/scenarios |
| `contract` | `23` 个 suite，`150` 个 case | 默认高频快车道，含 tooling 调度纯逻辑契约 |
| `tooling` | `34` 个 spec 文件，`275` 个 case | 并行 3 worker 约 `30s`；`MONO_BEHAVIOR_WORKERS=1` 退回串行 |
| `guard` | `6` 个 script，`27` 个 case | `dep_rules`、`gameplay_loop_no_ui`、`forbidden_globals`、`arch_view_guard`、`fixed_type_guard`、`repo_hygiene` |
| `arch_view` | 扫描 `src/**/*.lua` | 不扫 `tests/`、`tools/`、`vendor/`、`.swarmforge/tools/` |
| `crap` | 当前 behavior lane 分析 `3050` 个函数 | 只给 `src/**/*.lua` 打分 |
| `mutate4lua` | 每次只盯 `1` 个 `src/**/*.lua` 文件 | 诊断工具，不进默认回归 |

## 每条入口具体看什么

### `behavior`

- 入口：`busted --run behavior`（串行）或 `lua spec/support/behavior_parallel.lua`（并行）
- 来源：`spec/behavior/*_spec.lua`
- 覆盖面：`rules / turn / state / host / foundation / ui / scenarios`
- 适用时机：改了玩法规则、UI 行为、回合推进、运行时胶水，先跑它
- 不适合：证明架构边界没漂移；那是 `contract / guard / arch_view` 的工作
- warn 判读：常见预期 warn 与慢测基线见 `docs/reports/behavior-warns.md`
- 并行执行：`MONO_BEHAVIOR_WORKERS` 环境变量控制 worker 数（默认 auto=3），`=1` 回退串行

### `behavior-smoke`

- 入口：`busted --run behavior-smoke`
- 来源：`spec/behavior/{turn,foundation,host,state,rules,ui,scenarios/turn_flow,scenarios/startup}/*_spec.lua`
- 覆盖面：回合推进、基础设施、宿主层、状态层、**规则层**、**UI 行为层**、核心场景流程
- 适用时机：开发迭代快反馈；`verify --smoke` 内含这条 lane，覆盖 src 全部七层 + foundation 行为 spec
- 不替代：完整 `behavior`（含 app/computer/config/player/scenarios 其余子目录）；提交前仍应跑 full behavior

### `contract`

- 入口：`~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract`
- 来源：`spec/contract/*_spec.lua`（13 个 BDD spec 文件）
- 关注点：读模型、架构护栏、窄 Port、UI gate、runtime ports、快速脚本工具契约
- 适用时机：改了跨层接口、装配、端口、架构脚本、展示契约，先跑它
- 特点：不是业务玩法回归，而是“接口和边界别偷偷变形”；默认不再包含重型工具 smoke

### `tooling`

- 入口：`busted --run tooling`
- 来源：`.busted` 的 `tooling` profile，当前覆盖工具源码旁的 owner-local `spec/` 目录；测试基础设施 spec 放在 `spec/support/<harness>/spec`
- 关注点：真实 `mutate --index-suites`、`arch_view scan`、`arch_view viewer --in-json` 这类工具链导出
- 适用时机：改了质量工具包装层、导出流程、viewer 产物或 suite indexing 逻辑，再显式跑它
- 特点：故意和 `contract` 分开，避免慢工具 smoke 拖垮高频契约回归；真实 `arch_view analyze(...)` 常驻覆盖留在 `guard` 的 `arch_view_guard`
- 运行方式：`busted --run tooling`（串行）或 `lua spec/support/behavior_parallel.lua --profile tooling`（并行）
- 并行执行：复用 `behavior_parallel.lua` 基础设施，3 worker LPT 调度，约 `30s`（串行约 `45s`）
- 调度策略：显式并发时按 `suite.module_name` 命中的固定 cost hint 做 weighted LPT；未注册的新 suite 回退到 `#tests`
- 当前拆分：
  - `tools/acceptance/<module>/spec`：feature_stamp、mutator、scenario_manifest、spec_hash、run_acceptance
  - `tools/quality/<tool>/spec`：arch、busted_lane、coverage、crap、dry、encoding、loc、mutate、verify_full
  - `tools/ops/<tool>/spec`：deploy、update_api
  - `tools/shared/<module>/spec`：bootstrap、busted_sharding、common、loc_history
  - `spec/support/<harness>/spec`：busted infra、behavior_parallel、log_warns_handler

### `guard`

- 入口：`busted --run guards`
- 当前子项：
  - `dep_rules`：文本级硬边界、禁用旧路径、禁用少量跨子系统依赖
  - `gameplay_loop_no_ui`：`gameplay loop` 在最小 runtime 下不直接依赖 UI 对象
  - `forbidden_globals`：禁用 `src/` 下的 `tonumber`、`type(...) == "number"`、`rawget` 等运行时禁用写法
  - `arch_view_guard`：把 `arch_view` 的检查结果接入 guard lane
- 适用时机：想快速知道有没有出现“明确不允许的写法”

### `arch_view`

- 入口：`lua tools/quality/arch.lua check`
- 文档：`docs/reports/arch-view.md`
- 工具代码：`swarmforge/tools.lock` 钉定的 `arch_view` 参考实现，按需缓存到 `.swarmforge/tools/arch_view@<sha>/`
- Monopoly 规则真源：`tools/quality/arch/config.json`
- Monopoly viewer bundle：本地或 CI 临时导出，不再提交到仓库
- 检查内容：
  - 模块级 `require` 依赖边界
  - 未分类模块
  - 模块级循环依赖
  - projection/view 级反馈环
- 与 `guard` 的分工：
  - `arch_view` 看结构化依赖图
  - `guard` 看文本级禁令和个别仓库硬规则

### `crap`

- 入口：`lua tools/quality/crap.lua report ...` / `lua tools/quality/crap.lua viewer ...`
- 文档：`docs/reports/crap.md`
- 性质：不是纯静态分析，而是“静态复杂度 + 动态覆盖率”混合
- 数据来源：
  - 复杂度：`luac -p -l`
  - 覆盖率：测试 lane 运行时 `debug.sethook(..., "l")`
- 适用时机：需要给“先补测还是先重构”排序
- 不适合：单独做合并 gate；它依赖测试 lane 质量

现在的 CLI 入口由 `tools/quality/crap.lua` 负责兼容，核心实现来自 `swarmforge/tools.lock` 钉定的 `crap4lua` 参考实现。Monopoly 先通过公开 Lua bridge 加载默认项目配置 `tools/quality/crap/config.lua` 并执行 `tools/quality/crap/adapter.lua` 收集 coverage，再由纯 Lua analyzer / viewer 完成 report / viewer：

- `report`：生成 JSON 报告
- `viewer`：导出静态页面
- 无参数：默认等价于 `viewer --out-dir tmp/crap_view --open`

### `e2e`

- 入口：`busted --run e2e`
- 来源：`spec/e2e/*/*_spec.lua`
- 边界契约：`docs/decisions/0013-e2e-host-integration-smoke.md`（必要/禁止条件、增长触发；"e2e" 在本仓库特指宿主集成 smoke，不是端到端业务流）
- Bridge：`tools/bridge/editor_cli/`（`client.lua` / `escape.lua` / `result_capture.lua`）
- 关注点：host 层胶水代码（`src/host/*`）在真实 Eggy 编辑器里是否还能跑通
  - 场景 CRUD：实体池、属性赋值、删除
  - 试玩生命周期：`run_game` / `stop_game` 状态机
  - 事件广播：自定义事件触发与副作用
  - Marker round-trip：`EditorAPI.log("__E2E_RESULT__:" .. json)` 结构化结果采集
- 前提条件：
  - **必须在 Windows 上跑**（macOS 端 fixture 会 `pending(...)` 整组跳过）
  - **Eggy 编辑器必须启动并可被 `editor-cli.exe` 探测到**（fixture 用 `--json status` 做 pre-flight）
- 适用时机：改了 `src/host/*` 胶水、`EditorAPI` / `GameAPI` 包装、试玩启动路径之后跑
- 不适合：业务规则回归（用 `behavior`）、跨层契约（用 `contract`）
- 工作流：Mac 写代码 → git push → Windows pull → 启动编辑器 → `busted --run e2e`
- 调参环境变量：
  - `EDITOR_CLI_BIN`：覆盖默认 `editor-cli.exe` 路径
  - `EDITOR_CLI_FORCE=1`：在非 Windows 平台也尝试执行（调试 bridge 本身用）
- 不进 `verify_full`：依赖外部状态、串行执行、与现有 hermetic 车道反馈速度差一个量级

### `mutate4lua`

- 入口：`lua tools/quality/mutate.lua <file.lua> ...`
- 文档：`docs/guides/mutation-testing.md`
- 性质：单文件变异测试；看“测试有没有真正卡住错误”，不是看“代码有没有被执行到”
- 数据来源：
  - 变异点：`swarmforge/tools.lock` 钉定的 `mutate4lua` Lua lexer / scanner
  - 覆盖率：常规 mutate 仍用 `tools/quality/mutate/driver.lua` 的 `debug.sethook(..., "l")`
  - suite index：`--index-suites` 改为单进程文件级触达映射，不再逐 suite 采行覆盖
- 适用时机：怀疑某个文件 assertion 太松、准备做高风险重构、想验证 characterization tests 是否够硬
- 不适合：日常全量 gate；它本来就是按文件诊断

现在的 CLI 入口由 `tools/quality/mutate.lua` 负责兼容，核心实现来自 `swarmforge/tools.lock` 钉定的 `mutate4lua` 参考实现，Monopoly 的默认 lane 适配在 `tools/quality/mutate/driver.lua`：

- 默认 lane：`behavior`
- 显式可选：`--lane contract`
- 上游原生参数继续透传，例如 `--scan`、`--mutate-all`、`--update-manifest`、`--lines N,N`（默认行为已是按 manifest 差分，跳过未修改 scope，无需显式 flag）
- `--max-workers N`：mutant 并行度，默认 CPU 核数的一半，`1` 退回串行；并行裁决与串行逐位一致，详见 `docs/decisions/0014-parallel-mutation-execution.md`。10 核机默认 5 worker 实测单文件 `--mutate-all` 约 3×（`identity.lua` 50s→16s）

## 裸调用行为（是否使用缓存）

| 工具 | 裸调用命令 | 行为 | 缓存策略 |
|------|-----------|------|---------|
| `loc` | `lua tools/quality/loc.lua` | 分析最近3天 Git 历史代码行数变化 | **实时** — 每次从 Git 重新计算 |
| `crap` | `lua tools/quality/crap.lua` | 等价于 `report` → `viewer --open` | **实时** — 重新运行测试收集覆盖率 |
| `mutate` | `lua tools/quality/mutate.lua` | ❌ 报错 — 必须指定 `<file.lua>` | N/A |
| `arch` | `lua tools/quality/arch.lua` | 打开 viewer（需先有分析结果） | **用缓存** — 读取已生成的 JSON |

**关键区别：**
- `crap` 裸调用会**实时跑测试**，耗时约 9-10s，结果始终反映当前代码状态
- `arch` 裸调用**不自动重新分析**，如需更新需配合其他命令生成新 JSON
- `mutate` **不支持裸调用**，必须指定目标文件

## 按问题选命令

| 你现在想回答的问题 | 先跑什么 |
|--------------------|----------|
| 功能有没有坏 | `busted --run behavior` |
| 跨层接口或读模型有没有漂移 | `~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract` |
| 有没有出现明确禁用写法 | `busted --run guards` |
| 依赖图有没有越界或成环 | `lua tools/quality/arch.lua check` |
| 哪些函数最值得先补测/重构 | `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` |
| 某个文件的测试是不是只是“跑到了”而不是“断严了” | `lua tools/quality/mutate.lua src/foo.lua --scan` 然后再决定是否真正跑 mutation |
| host 层在真实编辑器里还能跑通吗 | `busted --run e2e`（Windows + 编辑器在线） |

## 常用命令套餐

### 快速本地冒烟

```sh
lua tools/quality/arch.lua check
busted --run guards
busted --run behavior-smoke
```

适合高频本地回归，通常约 `8s`。Agent 路由用更全面的 `verify --smoke`（叠加 lint + encoding + contract，~8s）。

### 完整行为回归（并行）

```sh
lua spec/support/behavior_parallel.lua
```

适合提交前跑完整行为回归，约 `2.5s`（3 worker）。等价于 `busted --run behavior` 但并行执行。

### 架构/契约检查

```sh
~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract
lua tools/quality/arch.lua check
```

适合改 Port、边界、装配、读模型之后跑。目标是高频快回归。

### 工具链 smoke

```sh
lua spec/support/behavior_parallel.lua --profile tooling
```

适合改 `tools/quality/*`、`tools/acceptance/*`、`tools/shared/*`、`tools/ops/*` 包装层，或 lockfile 工具 bootstrap / `arch_view` / `mutate4lua` 对接逻辑之后跑。并行约 `30s`（串行 `busted --run tooling` 约 `45s`）。

### 热点分析

```sh
lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json
lua tools/quality/crap.lua viewer --in-json tmp/crap_report.json --out-dir tmp/crap_view
```

适合重构前排优先级。通常约 `10s`。

### 单文件变异诊断

```sh
lua tools/quality/mutate.lua src/foundation/identity.lua --scan
lua tools/quality/mutate.lua src/foundation/identity.lua
```

适合先看一个文件值不值得做 mutation，再决定是否跑完整变异回合。耗时主要取决于目标文件的变异点数量和所选 lane。

### 完整质量回归

```sh
lua tools/quality/verify_full.lua --full
```

管道编排器一条命令跑全套：默认 slim + coverage + crap。约 `50s`。

默认无 flag 只跑 slim 车道（lint → encoding → behavior(全) → contract/guards/arch），约 `5s`（实测待补）。

opt-in flag：

- `--coverage`：加 coverage 并行 lane。
- `--crap`：加 crap_collect → crap → crap_gate。
- `--full`：`--coverage --crap` 别名，恢复旧默认。
- `--no-coverage`：向后兼容静默 no-op。

`tooling` profile 下的工具模块单测（quality / acceptance / ops / shared / 测试基础设施）不在 verify 管线内：

```sh
busted --run tooling
```

### verify flag 与角色权限

| flag | 含义 | 允许角色 |
|---|---|---|
| `--smoke` | behavior-smoke 窄反馈 | 全部 |
| （无 flag） | slim 默认：behavior(全) + contract/guards/arch/lint/encoding | 全部 |
| `--coverage` | 加 coverage lane | refactorer, architect |
| `--crap` | 加 crap_collect → crap → crap_gate | refactorer, architect |
| `--full` | `--coverage --crap` 别名，恢复旧默认 | refactorer, architect |
| `--no-coverage` | 向后兼容静默 no-op | 全部 |
| `--tooling` | 加 tooling lane（与上述正交） | 改工具链时任何人 |

详见 ADR 0006 D6。

## 使用上的默认建议

- 改业务逻辑或 UI，开发迭代先跑 `verify --smoke`（含 behavior-smoke），提交前跑 `verify`（默认 slim：behavior 全跑 + contract/guards/arch/lint/encoding）。
- 需要 coverage 或 CRAP 报告时，refactorer/architect 显式跑 `verify --full`（或分别 `--coverage` / `--crap`）。coder/specifier 不直接使用这些 flag。
- 改端口、契约、装配、边界，默认先跑 `contract + arch_view`。
- 改 `tools/quality/*`、`tools/acceptance/*`、`tools/shared/*`、`tools/ops/*`、viewer 导出、mutation suite index，默认补跑 `busted --run tooling`。
- 改目录结构或依赖方向，默认先跑 `guard + arch_view`。
- 做 CRAP 清理时，默认先看 behavior lane；只有明确需要时再叠加 contract lane。
- 做 mutation 时，默认从单个 `src/*.lua` 文件开始，并优先用 `behavior` lane。
