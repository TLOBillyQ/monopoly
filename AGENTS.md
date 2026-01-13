# AGENTS.md

## 项目概览

- 大富翁回合制棋盘游戏
- 尽量表驱动，可维护性优化
- lua语言
- 核心gameplay代码架构要满足好莱坞原则和SOLID原则
- 切分适配层，love2d环境注入
 
## 自检
- 通过脚本测试：`scripts/deps_check.lua`和`scripts/regression.lua`
  
## Coding Rules

**Primary rule: prefer deleting or reusing code over adding new code.**

### 1. No default abstractions
- Do not add interfaces, layers, or helpers unless there are **at least two real call sites**.
- No future-proofing.

### 2. Single implementation per feature
- If similar logic exists, **merge it**.
- New code must replace old code, not coexist with it.

### 3. Delete aggressively
- Remove unused functions, modules, parameters, and branches.
- Delete wrappers that only forward calls.

### 4. Keep Lua simple
- Prefer plain tables and functions.
- Avoid metatables, inheritance-like patterns, and over-general utilities.

### 5. Limit growth
- Prefer editing existing files.
- Adding a new file requires justification.

### 6. Mandatory cleanup
- After every change, ask: *“What code can be removed now?”*
- If nothing can be removed, explain why.

**Goal: minimal code, minimal concepts, minimal files.**