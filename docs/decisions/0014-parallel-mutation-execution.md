---
kind: adr
status: accepted
owner: quality
last_verified: 2026-05-29
---
# ADR 0014 — 变异测试并行执行

**Status**: Accepted (2026-05-29)
**Trigger**: 用户委派 mutate 提速（L1 懒加载 + L2 fail-fast + L3 并行执行器）
**Related**: `vendor/mutate4lua` engine.mutate / `internal/parallel.lua` / `util.default_max_workers`，
`docs/guides/mutation-testing.md`，ADR 0004（差分变异契约），
内存 `project_behavior_test_intra_process_pollution`

---

## 上下文（Why）

mutate 的变异循环原本是纯串行的：逐个 mutant 重开 `lua` 子进程跑相关 suite，
10 核机器只用 1 核（实测 93% 单核）。`--max-workers` flag 早已在 CLI 解析但
"初版忽略"，`util.default_max_workers()` 是死代码。深扫 / `--mutate-all` 全量
覆盖闭合按小时计，瓶颈完全压在串行单核上。

变异测试对每个 mutant 是 embarrassingly parallel——每个 mutant 内容独立、测试
运行独立。把空转的核用起来是最大杠杆。

---

## 决策（What）

### D1 — 进程级并行，保留一进程一 mutant 的隔离

新增 `internal/parallel.lua` 有界 worker 池：K 个 worker 各占一份 workspace 副本，
串行跑分给它的 mutant；最多 K 个并发。每个 mutant 仍是一个独立 `lua` 子进程
（detached `sh` launcher 写 sentinel 退出码，池轮询 sentinel 回填空闲 worker）。
**并行只发生在 mutant 之间，绝不在单进程内复用 Lua state。**

`worker_count = min(max_workers, #sites)`；`worker_count == 1` 严格走原串行路径
（逐位等价，零行为变化兜底）。

### D2 — 默认开启，默认 = CPU 核数的一半

默认 `util.default_max_workers()`（`floor(ncpu/2)`，留余量）。`--max-workers 1`
退回串行。2 核 / 高负载机器优雅降级，不回归。

顺手修了 `util.default_max_workers` 的上游 bug：候选表 `{ os.getenv("NUMBER_OF_PROCESSORS"), ... }`
在 Unix 上首项为 nil → `ipairs` 在第一个洞处停住，永远读不到 getconf/sysctl 探针 →
一直返回 1。只在 Windows 才"碰巧能用"。改为惰性函数探针，无 nil 洞。

### D3 — 拒绝 in-process 持久 worker（L4）

理论最快的方案是一个 Lua state 复用、每个 mutant 只重载 target 模块。**否决。**
内存 `project_behavior_test_intra_process_pollution` 记录本项目 behavior 测试有
同进程兄弟测试顺序依赖、coverage 已在漂。同一 state 连跑多个 mutant 会继承同样的
污染 → 静默错误 kill/survive 裁决，直接毁掉 mutation 测试的全部价值。

D1 的进程级并行正是为了在拿到并行收益的同时**保留隔离**：每个 mutant 的裁决由
和串行完全相同的单进程 suite 运行算出，污染面不变。这是 L3 安全而 L4 不安全的根因。

### D4 — 裁决等价是验收红线

并行必须与串行产出逐位一致的 kill/survive/timeout。下游聚合 / manifest 写入逻辑
对 `results` 数组无感（串/并行填的是同一个数组），所以裁决等价即全链路等价。

超时：launcher 用同一个 `timeout T cmd`（`T = max(5, (baseline+1)*timeout_factor)`，
默认 factor 15）。K 路抢核最多 ~K× 变慢，15× baseline 对 K≤5 安全。文档钉
`--timeout-factor` ≳ worker 数。

---

## 后果（Consequences）

**正向**：
- 单文件 `--mutate-all` 实测 ~3×（10 核 / 5 worker，`identity.lua` 50s→16s），深扫同比例放大
- `--max-workers` 转正，`util.default_max_workers` bug 修复（之前所有 Unix 都退化成 1）
- 隔离不变，裁决可信度不变

**代价**：
- 每文件多 K-1 份 workspace 副本（13M 仓库一份 `cp -r` ≈0.43s，K=5 ≈2s setup，已被并行收益摊掉）
- 引入 detached 进程 + sentinel 轮询机制（`internal/parallel.lua`），新代码面需 spec 兜底（已补 `spec/parallel_spec.lua` + `engine_spec` 并行 parity）
- 上游改动 + submodule bump：bump 的 gitlink 指向 mutate4lua 本地提交，合并前必须把该提交推到 mutate4lua 远端，否则 gitlink 悬空（参见内存 submodule 漂移风险）

---

## 相关任务

- coder：上游 `vendor/mutate4lua` 提交（engine/cli/util/parallel + spec）+ parent bump gitlink
- release/architect：把 mutate4lua 子模块提交推到其远端，再分享本分支
- 验证：vendor `busted`（45 case）+ `busted --run tooling`（277）+ 真实 `--mutate-all` 串/并行 parity

---

## Addendum（2026-05-29，architect 重测）— 轮询粒度顶替成新瓶颈

**触发**：用户问「并行优化到位了吗」。当前 HEAD 重测，「正向」段的 ~3× 未达成。

| 文件 | sites | 串行 | 并行（默认 5 worker） | 加速 |
|---|---|---|---|---|
| `identity.lua` | 41 | 10s | ~14s | **<1×（净亏）** |
| `log.lua` | 183 | 31s | ~23s | ~1.35× |

裁决逐位一致（identity 92.7% 38/41、log 98.4% 180/183，串=并），D3/D4 隔离红线未破——**纯加速缺口**。

**根因**：`internal/parallel.lua` `DEFAULT_POLL_INTERVAL = 0.2s` + `_sleep` 用 `os.execute("sleep")`
每次空轮询 fork 一个 shell；`engine.run_parallel{...}` 未透传 `poll_interval`，CLI 也未暴露 → 死钉 0.2s。
**与 L1 的交互是核心**：`mutate-perf-l123` 懒加载把每 mutant 砍到亚秒级（log.lua 183 中 156 个 <1s），
worker 每 0.2s 才轮询回填 → 大半时间空等。ADR 原文 3× 测于每 mutant ~1s 的年代，那时 poll 可忽略。
**L1 把 mutant 做得太便宜，反把 L3 的粗轮询顶成新瓶颈——两个优化互相打架。**

**修复杠杆（均在 vendor/mutate4lua 上游）**：
1. `DEFAULT_POLL_INTERVAL` 收到 ~0.02–0.05s；
2. 同步把 `os.execute("sleep")` 换成不 fork shell 的睡眠（luaposix `nanosleep`/`poll`/`select`），
   否则高频轮询自己 fork shell 又成新开销；
3. 可选：engine + CLI 暴露 `--poll-interval`。

**验收红线**：沿用 D4（identity 38/41、log 180/183 串=并不变）+ vendor `busted`（含 parallel/engine parity）
+ `busted --run tooling` 全绿 + log.lua 并行加速显著高于 1.35×。

**派发**：`mutate-perf-poll`（`mutate-perf-l123` 续）→ coder。子模块上游改 + bump gitlink + 推 mutate4lua 远端。

### Resolution（2026-05-29，refactorer 交付 → architect 合并验收）

修复落地（mutate4lua `92ef4069 → 2968a1aa`，已推 origin/main；parent gitlink bump + `tools/quality/mutate.lua` 暴露 `--poll-interval`）：
- `DEFAULT_POLL_INTERVAL 0.2 → 0`（忙等：不 sleep、不 fork shell，最紧回填）；
- `_sleep` 非正值直接 `return`（只有正 `--poll-interval` 才 sleep，作受限机器逃生阀）。

architect 重测：

| 文件 | 串行 | 并行 | 加速 | 裁决 parity |
|---|---|---|---|---|
| `log.lua` | 30s | 17s | **1.76×**（原 1.35×）| 98.4% 180/183 串=并 ✓ |
| `identity.lua` | 9s | 10s | 近持平（原 10→14s 净亏已缓和）| 92.7% 38/41 串=并 ✓ |

**结论**：poll 瓶颈消除，加速从 1.35× 提到 1.76×，小文件净亏基本消失，D4 裁决等价守住。红线达成。
**残余**：未到 ~5×，剩余瓶颈是每 mutant 的进程 spawn + suite 加载 + 多 worker I/O 争用，**非轮询**。
更进一步需 in-process 复用，但 D3 已为隔离否决——本线不追，残余收益不值隔离风险。
验证：vendor `busted` 50/0（含并行 parity）、`tooling` 281、`verify` 9/9、DRY 清零（spec flag-跳过用例抽成数据驱动循环）。**mutate-perf-poll 关闭。**
