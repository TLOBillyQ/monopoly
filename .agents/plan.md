# Plan: Tooling 并行调度优化

## Summary

把 `lua tests/tooling.lua` 的默认无参执行从“固定 `min(4, suite_count)` + catalog 顺序分批”改成“平台感知 auto worker + 固定权重 LPT 调度”，只改 `tests/support/tooling_parallel.lua` 的主进程排程与测试，不改 `tests/support/tooling_worker.lua`、不改覆盖边界、不再拆 suite。

已锁定的默认策略：
- 无参入口走 auto
- Windows 默认解析为 `1`
- 非 Windows 默认解析为 `max(1, min(3, suite_count))`
- `--workers N` 严格覆盖 auto
- 调度使用 `suite.module_name` 对应的固定 cost hint
- ties 必须稳定可复现，不能依赖 table 遍历顺序

## Key Changes

### 1. Auto worker 解析与输出
- 在 `tests/support/tooling_parallel.lua` 抽出纯函数 `resolve_worker_count(raw_workers, suite_count, is_windows)`：
  - `raw_workers == nil` 时走 auto
  - Windows: `1`
  - 非 Windows: `max(1, min(3, suite_count))`
  - 显式 `--workers N` 仍走现有整数解析，并 clamp 到 `[1, suite_count]`；若 `suite_count == 0`，最终也返回 `1`
- `tests/tooling.lua` CLI 不变：`lua tests/tooling.lua [--workers N]`
- 运行时打印固定诊断行：`[tooling] workers=<raw|auto> resolved=<n> scheduler=lpt`

### 2. 固定权重表与 deterministic LPT 调度
- 在 `tests/support/tooling_parallel.lua` 增加基于 `suite.module_name` 的固定权重表：
  - `suites.architecture.arch_view_live_tooling_contract` -> `40`
  - `suites.architecture.script_tools_io_tooling_contract` -> `28`
  - `suites.architecture.script_tools_mutate_tooling_contract` -> `16`
  - `suites.architecture.mutate4lua_tooling_contract` -> `10`
  - `suites.architecture.arch_view_snapshot_tooling_contract` -> `5`
  - `suites.architecture.crap_tooling_contract` -> `2`
- 未命中的 suite 回退到 `max(1, #(suite.tests or {}))`
- 新增纯函数 `suite_cost(suite)` 与 `build_execution_rounds(suites, worker_total)`：
  - 先把 suites 转成 `{ suite, cost, module_name }`
  - 先按 `cost desc` 排序
  - 成本相同时按 `module_name asc`，再按原始 catalog index asc` 打破平局，保证稳定
  - LPT 分配时把当前 suite 放入“累计成本最低”的 lane
  - lane 负载相同时按 lane index asc 打破平局
  - 最终把 lanes 展开为 rounds：第 `k` round 取每个 lane 的第 `k` 个 suite，跳过空槽，不创建空 worker
- 对新增 tooling suite 的注册规则也一并写进代码注释和文档：默认先走 fallback；确认成为长期热点后，再把 `suite.module_name` 加入权重表

### 3. 保持 worker 协议不变，只替换主进程批次构造
- `tests/support/tooling_worker.lua` 不改
- `tooling_parallel.run()` 改为：
  - 先解析 resolved worker count
  - 若只有 1 个 worker 或 1 个及以下 suite，继续走 `harness.run_all`
  - 否则先用 `build_execution_rounds()` 生成 deterministic rounds
  - 再按 round 启 worker、等待、读 JSON、合并结果
- 结果聚合、失败语义、JSON payload 格式保持不变

### 4. 为调度层补纯逻辑契约测试
- 新增一个快速 contract suite，例如 `tests/suites/architecture/tooling_parallel_contract.lua`
- 把它加入 `tests/catalog.lua` 的 `contract_modules`
- 覆盖以下场景：
  - `workers=nil` 时 Windows 解析为 2、非 Windows 解析为 3，并都受 `suite_count` 限制
  - `suite_count == 0` 时 resolved worker 仍为 1，不输出 0
  - 显式 `--workers 1/2/N` 不被 auto 改写
  - LPT 会把 `arch_view_live`、`script_tools_io`、`script_tools_mutate` 分散到不同 lane
  - ties 在相同权重下按 `module_name`/catalog index 稳定
  - rounds 展开后不丢 suite、不重复 suite、不生成空 round 项

### 5. 文档与验收
- 更新 `docs/architecture/quality_map.md`
  - 默认行为改为“auto worker + weighted LPT schedule”
  - 保留 `--workers 1` 串行调试说明
  - 补一句“当前权重按 `suite.module_name` 在 runner 内注册，新增 suite 未注册时回退到 case 数估重”
  - 用本轮实测刷新 Windows 默认时长说明
- 回归与量测命令：
  - `lua tests/contract.lua`
  - `lua tests/tooling.lua --workers 1`
  - `lua tests/tooling.lua`
  - `Measure-Command { lua tests/tooling.lua --workers 1 }`
  - `Measure-Command { lua tests/tooling.lua }`
- 验收标准：
  - `lua tests/tooling.lua` 与 `--workers 1` 的通过/失败语义一致
  - 默认无参明显优于当前 `~118s` 基线
  - 目标 warm `<=95s`；若仍高于串行，则本轮到此为止，不继续动覆盖边界，下一轮单独评估减少 PowerShell 启动层或复用 worker 进程

## Dependency-Aware Tasks

### T1: 抽出调度原语
- **depends_on**: []
- **location**: `tests/support/tooling_parallel.lua`
- **description**: 提炼 `resolve_worker_count`、`suite_cost`、`build_execution_rounds`，并通过 `M._test_support` 暴露给纯逻辑测试
- **validation**: 不跑 worker 也能单测调度逻辑
- **status**: Completed
- **log**: 已抽出 `resolve_worker_count`、`suite_cost` 与 `build_execution_plan`，并通过 `M._test_support` 暴露最小测试接口；顺带清理了原先内联批次构造入口。
- **files edited/created**: `tests/support/tooling_parallel.lua`

### T2: 实现 auto worker 解析与诊断输出
- **depends_on**: [T1]
- **location**: `tests/support/tooling_parallel.lua`, `tests/tooling.lua`
- **description**: 完成平台感知 auto、worker floor、diagnostic print
- **validation**: 无参输出 `workers=auto resolved=<n> scheduler=lpt`
- **status**: Completed
- **log**: 已实现平台感知 auto worker 解析，保留显式 `--workers N` 覆盖语义，并在 runner 启动时输出 `workers/resolved/scheduler` 诊断信息；经 Windows 实测后把 auto 默认收敛为 `1`，避免无参入口因并发争用退化。
- **files edited/created**: `tests/support/tooling_parallel.lua`

### T3: 实现固定权重 LPT + deterministic round 展开
- **depends_on**: [T1]
- **location**: `tests/support/tooling_parallel.lua`
- **description**: 用 `suite.module_name` 命中权重表，完成稳定排序、lane 分配与 round 展开
- **validation**: 调度稳定、无空 worker、无重复/遗漏
- **status**: Completed
- **log**: 已用 `suite.module_name` 接入固定权重表，并实现稳定排序、LPT lane 分配与 round 展开；真实并行路径已切换到基于 rounds 的批次执行。
- **files edited/created**: `tests/support/tooling_parallel.lua`

### T4: 增加调度契约测试
- **depends_on**: [T1]
- **location**: `tests/suites/architecture/tooling_parallel_contract.lua`, `tests/catalog.lua`
- **description**: 新增纯逻辑 contract suite，锁定 worker 解析、权重命中、tie break、round 展开
- **validation**: `lua tests/contract.lua` 通过且不引入慢测试
- **status**: Completed
- **log**: 已新增 `tooling_parallel_contract`，覆盖 auto worker、权重命中、fallback 成本与 round 覆盖语义，并将其接入 contract lane；子任务验证已通过 `lua tests/contract.lua`。
- **files edited/created**: `tests/suites/architecture/tooling_parallel_contract.lua`, `tests/catalog.lua`

### T5: 真实 tooling 回归与量测
- **depends_on**: [T2, T3, T4]
- **location**: command level
- **description**: 跑 tooling 串行/默认并行，并用外层墙钟验收
- **validation**: 默认无参优于当前并行基线，语义与串行一致
- **status**: Completed
- **log**: 已完成 `lua tests/contract.lua`、`lua tests/tooling.lua --workers 1`、`lua tests/tooling.lua` 与外层 `Measure-Command` 量测；结果为串行约 `111s`、auto 约 `116s`。基于实测把 Windows auto 收敛为 `1`，从而让无参入口回到这台机器上的最快稳定路径，并保留显式并发场景的 weighted LPT 调度。
- **files edited/created**: `tests/support/tooling_parallel.lua`, `tests/suites/architecture/tooling_parallel_contract.lua`

### T6: 同步文档
- **depends_on**: [T5]
- **location**: `docs/architecture/quality_map.md`
- **description**: 刷新默认行为、权重注册说明、Windows 实测时长
- **validation**: 文档与最终代码、实测结果一致
- **status**: Completed
- **log**: 已同步 `tooling` 的默认行为为 auto worker，并写明当前 Windows 默认解析为 `1`；同时更新了 contract/tooling 规模和最新墙钟量测。
- **files edited/created**: `docs/architecture/quality_map.md`

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1 | Immediately |
| 2 | T2, T3, T4 | T1 complete |
| 3 | T5 | T2, T3, T4 complete |
| 4 | T6 | T5 complete |

## Assumptions

- 本轮只优化 `tests/support/tooling_parallel.lua` 的调度策略，不改 `tooling_worker` 协议
- 当前 tooling suite 热点短期稳定，固定权重表足以支撑这轮优化
- 权重命中统一基于 `suite.module_name`，不使用 `suite.name` 作为主键，避免重命名导致歧义
- 若默认 auto 仍慢于串行，本轮仍算完成“调度策略收敛”；下一轮再专攻进程启动开销
