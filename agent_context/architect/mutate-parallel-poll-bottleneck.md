# mutate4lua 并行：轮询粒度瓶颈（ADR 0014 后果未达成）

**测量日期**: 2026-05-29（architect，10 核机）
**关联**: ADR 0014（并行执行）、`mutate-perf-l123`（L1 懒加载）、
`vendor/mutate4lua/lib/mutate4lua/internal/parallel.lua`、`.../engine.lua`

## 缺陷

ADR 0014 后果段写「单文件 `--mutate-all` 实测 ~3×」。当前 HEAD 实测达不到：

| 文件 | sites | 串行（--max-workers 1） | 并行（默认 5 worker） | 加速 |
|---|---|---|---|---|
| `src/foundation/identity.lua` | 41 | 10s | ~14s | **<1×（净亏）** |
| `src/foundation/log.lua` | 183 | 31s | ~23s | ~1.35× |

裁决逐位一致（identity 92.7% 38/41、log 98.4% 180/183，串=并），隔离红线 D3/D4 未破——**只是加速没拉满**。

## 根因

`internal/parallel.lua`：
- `DEFAULT_POLL_INTERVAL = 0.2`（秒）。
- `_sleep` = `os.execute("sleep " .. n)`，每次空轮询 fork 一个 `/bin/sh` + `sleep`。
- `engine.lua` 的 `run_parallel{...}` 调用**未透传 `poll_interval`**，CLI 也未暴露 → 死钉 0.2s。

**与 L1 的交互（核心）**：`mutate-perf-l123` 的懒加载把每个 mutant 的 suite 成本砍到亚秒级——
log.lua 实测 183 个 mutant 中 156 个 <1s。当单个 mutant 只跑 0.1–0.2s，而 worker 每 0.2s
才轮询一次回填空闲，worker 大半时间在等轮询 → 5 核只换来 ~1.35× 有效并行；小文件连
workspace 复制开销都摊不回，净亏。ADR 测出 3× 是在每 mutant ~1s 的年代，0.2s poll 当时可忽略。
**L1 把 mutant 做得太便宜，把 L3 的粗轮询顶成了新瓶颈。**

## 修复杠杆（均在 vendor/mutate4lua 上游）

1. `DEFAULT_POLL_INTERVAL` 收到 ~0.02–0.05s。
2. 同步把 `os.execute("sleep")` 换成不 fork shell 的睡眠（luaposix `nanosleep` / `poll` /
   `select`）；否则高频轮询自己 fork shell 又成新开销，按下葫芦起瓢。
3. 可选：engine + CLI 暴露 `--poll-interval`，按文件 per-mutant 成本调。

## 验收红线（沿用 ADR 0014 D4）

- 并行裁决与串行逐位一致（identity 38/41、log 180/183 不变）。
- vendor `busted`（含 `parallel_spec` / `engine_spec` 并行 parity）+ `busted --run tooling` 全绿。
- 重测 log.lua 并行加速显著高于 1.35×（目标接近 worker 数的可观比例）。

## 合并/推送约束（ADR 0014 后果段 + submodule 漂移内存）

改的是子模块上游：coder 需在 `vendor/mutate4lua` 上游提交（parallel.lua [+ engine/cli]）
+ parent bump gitlink；**合并前必须把该提交推到 mutate4lua 远端**，否则 gitlink 悬空。
当前 gitlink `92ef4069` 已在 `origin/main` 可达（本轮已核）。
