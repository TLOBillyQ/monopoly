---
name: dry
description: 用 dry4lua 检测结构相似的函数；抽函数 / 重构前先扫一遍。触发：结构重复、重复检测。不用于：merge gate、自动化告警。
---

# Dry

结构重复检测。抽公共函数或重构前快速看候选。

## 何时用 / 何时不用

- 用：抽函数前选目标；refactorer 完工后抽样确认治理面；新模块进来前比对老代码
- 不用：CI gate；自动化告警；当成"结构相似 = 语义重复"的判定（命中是讨论起点，不是工单）

## 决策树

1. **目录扫** → `lua tools/quality/dry.lua src/`
2. **单文件 / 子目录** → `lua tools/quality/dry.lua src/rules/`
3. **降阈值看候选** → `--threshold 0.7`（默认 0.82；低于 0.7 噪声会很快淹没真信号）
4. **降片段下限** → `--min-lines 3` 或 `--min-nodes 15`（默认 4 / 20）
5. **JSON 给下游消费** → `--json`

## 红线

- **建议性产物，不当 gate**：命中后是人工讨论入口，不直接生成 todo 或 issue。
- **阈值不要随手降**：< 0.7 噪声放大很快；非要降时先 `--json` 抽样确认。
- **结构相似 ≠ 语义重复**：host_types 的 vec3/quat 等数据类是已知重复地板，不需要治理。
- **不替代 CRAP / arch-view**：复杂度看 `/crap`，依赖边界看 `/arch-view`。

## 真源

- 工具机制、算法、参数：`swarmforge/tools.lock` 钉定的 `dry4lua` 参考实现 README，按需缓存到 `.swarmforge/tools/dry4lua@<sha>/`
- 项目集成、4lua 系列统一：`docs/product/specs/luajit-filter-unification.md`

## 输出汇报

- 命令 + 目标
- 命中数 + 阈值
- 前 N 个最值得抽 / 最值得忽略的 cluster（一行一个）
- 建议下一步（抽函数 / 改写 / 忽略）

## 工具链改动

动到 `tools/quality/*` 任何文件 → handoff 跑 `lua tools/quality/verify_full.lua` + `busted --run tooling` 兜底（前者跑 shell-out 端到端，后者跑工具模块单测）。
