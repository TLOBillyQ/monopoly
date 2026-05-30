---
kind: spec
status: implemented
owner: specifier
---

# 质量工具 LuaJIT + Filter 模式统一

## 当前约束

arch_view、crap4lua、mutate4lua、dry4lua 统一采用 4lua 质量工具模式：

1. 核心逻辑使用 Lua 实现，不依赖非 Lua 二进制。
2. 工具代码放在各自 `vendor/<tool>/` 子模块内。
3. Monopoly 根部 `tools/quality/<tool>.lua` 只做 bootstrap、默认参数和委托。
4. 语义配置保留在 Monopoly 仓库内，例如架构规则、coverage adapter 和 tier 配置。
5. CLI 路径输入优先，配置文件只承载工具语义。
6. 公开 CLI 只保留在 `tools/quality/*.lua`；vendor 子模块不再提供 `bin/` 入口。

## 工具状态

| 工具 | Wrapper | Vendor 核心 | 主要职责 |
|------|---------|-------------|----------|
| `arch_view` | `tools/quality/arch.lua` | `vendor/arch_view/lib/arch_view/` | 扫描静态 `require` 依赖、分类、边界检查、viewer 导出 |
| `crap4lua` | `tools/quality/crap.lua` | `vendor/crap4lua/lib/crap4lua/` | coverage 收集、`luac -p -l` 复杂度解析、CRAP 报告、viewer 导出 |
| `mutate4lua` | `tools/quality/mutate.lua` | `vendor/mutate4lua/lib/mutate4lua/` | 变异扫描、manifest、隔离工作区执行、报告 |
| `dry4lua` | `tools/quality/dry.lua` | `vendor/dry4lua/lib/dry4lua/` | 结构重复检测 |

## 验收命令

```sh
lua vendor/arch_view/tests/run.lua
lua vendor/crap4lua/tests/run.lua
lua vendor/mutate4lua/test/run.lua
lua tools/quality/arch.lua check
lua tools/quality/crap.lua report --lane behavior --out /tmp/crap_report.json
lua tools/quality/mutate.lua src/foundation/identity.lua --scan --json
busted --run tooling
```

## 非范围

`tools/loc_engine` 是 Monopoly 的 LOC 引擎，不属于 4lua 质量工具统一范围。
