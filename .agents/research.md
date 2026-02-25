# 架构复杂度复审（是否过度工程 + 改进建议）

更新时间：2026-02-25  
范围：`ARCHITECTURE.md`、`src/`、`Config/`、`vendor/`、`tests/`

## 1. 核心判断

结论：**当前不是“系统性过度工程”，但存在“局部过度抽象”与“质量门槛失真”问题。**

- 不是系统性过度工程：主链路已比旧版本收敛，核心能力仍可维护。
- 存在局部过度工程：UI 交互链条仍偏长，少量薄封装增加跳转成本。
- 更高优先级风险：依赖规则检查在 Windows 下存在“假通过”可能，影响架构约束可信度。

一句话：**架构方向正确，但需要先修“约束可信度”，再做复杂度收敛。**

---

## 2. 判断标准（用于定义“是否过度工程”）

本次用 4 条标准判断：

1. 抽象是否带来独立语义，而非仅转发。
2. 新增一个功能是否需要跨 3 层以上同步修改。
3. 分层约束是否可被测试稳定验证（不能“看似通过”）。
4. 关键主循环是否承载过多横切职责，导致回归半径扩大。

只要第 2、3、4 条同时偏弱，就可认定为局部过度工程风险区。

---

## 3. 复核证据（已重算）

### 3.1 规模画像

- `src` Lua 文件：`179`
- `Config` 文件：`19`
- `vendor` 文件：`29`
- `src` 中 `<=25` 行文件：`29`

### 3.2 抽象密度（按文件名命中）

- 文件名包含 `Port/Adapter/Service/Registry/Dispatcher/Handler/Builder/Coordinator` 的文件：`34 / 179`（约 19%）

说明：该比例不高到“必然过度设计”，但应关注命名抽象是否持续增长。

### 3.3 关键链路与职责集中

- `GameplayLoop.tick` 位于 `233-307`，约 `75` 行，仍承担多类横切职责。
- UI 输入主链：

```text
UIEventRouter(91)
  -> intent_builders/* (6 文件, 231 行)
  -> UIIntentDispatcher(172)
  -> TurnActionPort(19)
  -> TurnDispatch
```

### 3.4 已完成收敛（正向）

- `UIIntentBuilder.lua`、`UIModelProjection.lua`、`UIModelPanelBuilder.lua` 已删除。
- `UIModel.lua` 已成为单一入口（当前约 `333` 行）。

### 3.5 约束校验风险（重点）

- `tests/internal/dep_rules.lua` 使用 `ls` 与 `[ -d ]`，在 Windows 环境下会出现命令错误但仍可能输出 `dep_rules ok`。
- 这意味着“依赖约束通过”目前不总是可信，属于流程级风险。

---

## 4. 是否过度工程：分区判断

### A. 非过度工程区（保持）

- `Flow`、`DirtyTracker` 等核心结构仍然直接、可预测。
- 回归与隔离测试可运行（`regression` / `gameplay_loop_no_ui`）。
- 近阶段删除多层门面是明确的去复杂化动作。

### B. 轻度过度工程区（需要收敛）

- `interaction` 层对简单输入语义仍有多跳转发。
- 部分小文件虽短，但承担的语义与边界不一致，导致“看起来薄、实际上不能随便删”。
- `GameplayLoop.tick` 作为协调中心仍偏重，修改局部逻辑时回归半径偏大。

### C. 高优先级修复区（先做）

- `dep_rules` 的跨平台不可靠会削弱所有后续架构改造的验收价值。  
  **先修它，再谈深度重构。**

---

## 5. 改进建议（按优先级）

### P0（1 天内）：先修质量门槛可信度

1. 重写 `dep_rules.lua` 的目录遍历方式，避免依赖 shell 的 `ls` / `[ -d ]`。
2. 在 CI 固定一个 Linux 任务跑 `dep_rules`，并在本地保留 Windows 可运行版本。
3. 验收要求：出现命令错误时必须直接失败，不允许“错误 + 通过”并存。

### P1（2-4 天）：收敛复杂度热点

1. 拆分 `GameplayLoop.tick`，但优先“同文件私有函数 + runtime 模块化”，避免一次性拆太多新文件。
2. 压平 UI 交互链：把无额外状态语义的 intent 构造逻辑合并到 `UIEventRouter` 局部表。
3. 保留 `TurnActionPort` 边界，不建议直接并入 `TurnDispatch`（避免破坏 `presentation -> game` 依赖约束）。

### P2（持续）：建立“薄封装准入规则”

1. 新增小文件时必须满足至少一条：
   - 提供独立语义边界；
   - 隔离跨层依赖；
   - 显著提升测试可注入性。
2. `<=20` 行且仅转发的新增文件，默认进入评审清单。
3. 每两周输出一次“抽象命名密度 + 薄封装数量”趋势，防止反弹。

---

## 6. 可执行落地计划

### Step 1：质量门槛修复

- 修复 `tests/internal/dep_rules.lua` 跨平台执行。
- 验收：
  - `lua tests/internal/dep_rules.lua`
  - 错误场景下退出码必须非 0

### Step 2：Tick 职责收敛

- 对 `GameplayLoop.tick` 做职责分组拆分（同步、超时、动画、刷新）。
- 验收：
  - `lua tests/internal/gameplay_loop_no_ui.lua`
  - `lua tests/regression.lua`

### Step 3：UI 交互链减层

- 合并低语义 intent builder（先从纯节点映射类开始）。
- 验收：
  - `lua tests/regression.lua`
  - `lua tests/internal/dep_rules.lua`

---

## 7. 最终结论

当前架构**可继续支撑迭代，无需重写**。  
本项目的主要问题不是“大而乱”，而是**局部抽象收益不足 + 架构约束验证不够可靠**。

优先顺序应当是：

1. 先修验证可信度（P0）
2. 再降热点复杂度（P1）
3. 最后做长期治理（P2）
