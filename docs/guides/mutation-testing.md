---
kind: guide
status: stable
owner: quality
last_verified: 2026-05-04
---
# mutate4lua

`mutate4lua` 是按文件运行的 Lua 变异测试工具。Monopoly 通过子模块 `vendor/mutate4lua/` 引入上游实现：现在 scan / mutate / manifest 主流程由上游 Go engine 提供，Monopoly 再用 `tools/quality/mutate.lua` 和 `tools/quality/mutate/driver.lua` 适配本仓库的测试车道。

如果你想先看它在整套质量入口里的定位、耗时预估和与 `behavior / contract / guard / arch_view / crap` 的分工，先读 `docs/architecture/quality-map.md`。

默认 `~/.luarocks/bin/busted --helper=spec/helper.lua --run=contract` 只保留快速契约；涉及真实 `mutate --index-suites` 的完整 smoke 已挪到 `busted -c tooling`。

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
lua tools/quality/mutate.lua src/core/utils/role_id.lua --scan
lua tools/quality/mutate.lua src/core/utils/role_id.lua --since-last-run
lua tools/quality/mutate.lua src/core/utils/role_id.lua --mutate-all
lua tools/quality/mutate.lua src/core/utils/role_id.lua --lines 12,18
lua tools/quality/mutate.lua src/core/utils/role_id.lua --lane contract
lua tools/quality/mutate.lua src/core/utils/role_id.lua --test-command "busted -c behavior"
```

## Monopoly 适配层做了什么

- `tools/quality/mutate.lua` 负责包装 `vendor/mutate4lua/bin/mutate4lua-engine`，缺失时自动从 `vendor/mutate4lua/` 构建
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
