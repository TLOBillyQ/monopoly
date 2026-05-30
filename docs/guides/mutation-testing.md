---
kind: guide
status: stable
owner: quality
last_verified: 2026-05-22
---
# mutate4lua

`mutate4lua` 是按文件运行的 Lua 变异测试工具。Monopoly 通过子模块 `vendor/mutate4lua/` 引入纯 Lua 实现，再用 `tools/quality/mutate.lua` 和 `tools/quality/mutate/driver.lua` 适配本仓库的测试车道。

如果你想先看它在整套质量入口里的定位、耗时预估和与 `behavior / contract / guard / arch_view / crap` 的分工，先读 `docs/architecture/quality-map.md`。

默认 `~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract` 只保留快速契约；涉及真实 `mutate --index-suites` 的完整 smoke 已挪到 `busted --run tooling`。

## 入口

```sh
lua tools/quality/mutate.lua --help
```

Monopoly 包装层额外支持两个参数：

- `--lane behavior|contract`

默认值：

- lane：`behavior`
- 未显式传 `--test-command` 时，默认测试命令为 `lua tools/quality/mutate/driver.lua --lane behavior --coverage-file <tmp>`

其余参数沿用上游 `mutate4lua`，例如：

```sh
lua tools/quality/mutate.lua src/foundation/identity.lua --scan
lua tools/quality/mutate.lua src/foundation/identity.lua --update-manifest
lua tools/quality/mutate.lua src/foundation/identity.lua --mutate-all
lua tools/quality/mutate.lua src/foundation/identity.lua --lines 12,18
lua tools/quality/mutate.lua src/foundation/identity.lua --lane contract
lua tools/quality/mutate.lua src/foundation/identity.lua --test-command "busted --run behavior"
```

## 差分变异（默认）

自 `vendor/mutate4lua@aaea942` 起，`mutate <file>` 默认按 manifest 做差分变异——
只测 scope hash 与 manifest 不匹配的位点；hash 全匹配的 scope 直接跳过。差分
基线以 **manifest 尾块** 形式存在源文件末尾：

```lua
--[[ mutate4lua-manifest
version=2
projectHash=...
scope.0.id=chunk:src/foo.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=...
...
]]
```

manifest 仅在 mutation lane 全 kill（`survived == 0 && timeout == 0`）且未传
`--lines` 时写入；任何 survived / timeout 都让 manifest 字节级保持不变。
契约细节见 `features/quality/differential_mutation.feature` 与
`docs/decisions/0004-differential-mutation-testing.md`。

关键开关：

- `--mutate-all`：忽略 manifest，强制全 scope 变异
- `--update-manifest`：扫描源码、写入 v2 manifest，不跑测试
- `--lines N,N`：限定行号，并且无论 pass / fail 都不刷新 manifest
- `--max-workers N`：并行 worker 数（默认 CPU 核数的一半，`1` = 串行）

## 并行执行（默认开启）

变异循环对每个 mutant 是独立的，所以默认按 `util.default_max_workers()`（CPU
核数的一半）并行跑。每个 worker 独占一份 workspace 副本，串行跑分给它的 mutant；
**每个 mutant 仍然是一个独立的 `lua` 子进程**——并行只发生在 mutant *之间*，不在
单个进程内复用 Lua state。这是刻意的：见
`docs/decisions/0014-parallel-mutation-execution.md`，同进程复用会撞上
behavior 测试的同进程顺序污染，产生静默错判。

- `--max-workers 1` 完全退回原串行路径（逐位等价，零行为变化），适合调试或 2 核机器。
- 单 mutation 点的文件自动走串行（`worker_count = min(max_workers, #sites)`）。
- 并行裁决与串行**逐位一致**：每个 mutant 跑的是同一套 suite、同一进程，只是分到
  不同 workspace；超时仍由 `timeout_factor`（默认 15× baseline）兜底，竞争下保持
  `--timeout-factor` ≳ worker 数即安全。

实测（10 核机，默认 5 worker）：`src/foundation/identity.lua --mutate-all` 50s→16s
（≈3×）；叠加 L1 懒加载后叶子模块更快。

### Bootstrap-only manifest 守卫

`tools/quality/mutate_bootstrap.lua` 批量写出的 v2 manifest 只有 scope 字节签名，没有任何 `lastMutationStatus` —— 这种"bootstrap-only" manifest 在差分模式里会全部命中"hash 匹配跳过"，看起来"没东西要变异"但其实从没证明过覆盖。

为防止 silent skip，monopoly wrapper 做了 fail-fast：

- `lua tools/quality/mutate.lua src/foo.lua`：若 `src/foo.lua` 的 manifest 是 bootstrap-only，立即 exit 1 并提示先跑 `--mutate-all`
- `lua tools/quality/verify_mutation_diff.lua`：遍历到 bootstrap-only 文件时按 baseline failure 中止整批

绕开方式：`--mutate-all` / `--update-manifest` / `--lines` / `--scan`。首次接入差分流水线前，应该先用 `--mutate-all` 把目标文件的 scope 跑到至少有一次 `passed` / `no_sites` 状态写回 manifest，之后差分模式才会"算数"。

历史背景：commit `f4bb6356` 一次性给 349 个 src 文件 bootstrap 了 manifest；2026-05-23 抽样 8 个文件 `--mutate-all`，全部出现 survivor（53.5% - 94.2% kill 率不等），165 个 mutant 之前被差分模式假装"已覆盖"。

## Monopoly 适配层做了什么

- `tools/quality/mutate.lua` 负责 bootstrap `vendor/mutate4lua/lib/` 并委托 `mutate4lua.cli`
- 默认把上游内置 test driver 替换成 Monopoly 专属 driver
- project hash 改走 `git ls-files` 枚举仓库内 `.lua` / `.rockspec` 文件，避免把子模块内容逐文件扫进单次 mutation 启动成本
- `tools/quality/mutate/driver.lua` 通过 `spec/<lane>/*_spec.lua` 装配 `behavior` 或 `contract` suites（catalog 仍是 tools 流水线内部细节，将在后续 PR 迁到 `tools/quality/shared/`）
- 常规 mutate 仍用 `debug.sethook(..., "l")` 记录运行时命中行，供上游过滤未覆盖变异点
- `--index-suites` 改成单进程批量索引：driver 输出 `suite -> touched files` JSON，避免逐 suite 启进程和逐行 coverage 开销
- suite index 以 `project_hash + lane` 命中缓存；热路径命中时只需读取已有 index 文件

## 什么时候用

- 怀疑某个模块“测试绿，但断言不够锋利”时
- 准备重构高风险逻辑，想先看现有测试能不能杀掉简单变异时
- 做热点治理时，把它和 `tools/quality/crap.lua` 搭配使用：先用 CRAP 找高风险函数，再对单文件做变异测试

## 什么时候不要用

- 不要把它当日常回归 gate；单次只适合盯一个文件
- 不要默认跑全仓；上游工具设计就是单文件诊断，不是全仓 mutation farm
- 如果你已经手写了自定义测试命令，Monopoly 包装层不会再注入默认 driver，也不会帮你采 coverage
