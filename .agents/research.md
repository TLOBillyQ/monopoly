# 架构复杂度深度调研（src / Config / vendor）

更新时间：2026-02-24

调研范围：`ARCHITECTURE.md`、`src/`、`Config/`、`vendor/`、`tests/`

## 1. 结论

结论：**架构已完成初步收敛，但仍存在优化空间**。

核心变化：近期已删除 `UIIntentBuilder.lua`、`UIModelProjection.lua`、`UIModelPanelBuilder.lua` 等转发层，UI 链路和模型链路已缩短。但 `GameplayLoop.tick` 职责仍较集中，部分薄封装文件依然存在。

一句话判断：**方向正确，持续收敛中。**

---

## 2. 调研方法

本次采用"文档-实现对照 + 定量扫描 + 关键链路抽样"：

1. 对照 `ARCHITECTURE.md` 的分层声明与真实代码主链。
2. 统计规模与抽象命名密度（Adapter/Port/Service/Registry/Dispatcher/Handler/Builder/Coordinator）。
3. 抽样薄封装文件（低行数 + 单纯转发）。
4. 评审启动链、Tick 链、UI 交互链的跳转层数。

---

## 3. 定量画像

### 3.1 规模

- `src/` 文件数：**179**（Lua 文件）
- `Config/` 文件数：**19**
- `vendor/` 文件数：**29**

### 3.2 抽象命名密度

- 命中抽象命名模式的 `src` 文件：**~45 / 179（约 25%）**
- 主要模式：Port(5), Adapter(3), Service(8), Registry(4), Dispatcher(2), Handler(12), Builder(6), Coordinator(5)

### 3.3 薄封装文件（<= 25 行）

- `src` 中行数 `<= 25` 的文件：**~25**
- 典型样本：
  - `TurnActionPort.lua`: 22 行（默认回退行为封装）
  - `GameplayLoopPortsAdapter.lua`: 19 行（端口注入适配）
  - `ActionLogIntents.lua`: 18 行（Intent 构造转发）
  - `PopupIntents.lua`: 24 行（Intent 构造转发）

### 3.4 复杂度集中目录

- `src/presentation/interaction`: **12** 文件（已减少，原 18）
- `src/presentation/api`: **6** 文件（已减少，原 15）
- `src/game/flow/turn`: **8** 文件（已减少，原 21）

**关键变化**：`interaction` 和 `api` 目录已合并简化，`UIIntentBuilder` 已删除。

---

## 4. 证据清单（按风险分级）

## 中等风险

### M1. GameplayLoop.tick 职责仍较集中

- `GameplayLoop.tick`（233-307 行，约 75 行）同时处理：
  - 输入锁同步
  - 角色控制锁
  - Auto runner 步进
  - 超时处理（choice + modal + action button + detained）
  - 动画步进（move + action）
  - 倒计时更新
  - Dirty 刷新
  - Debug 同步

- 文件位置：`src/game/flow/turn/GameplayLoop.lua:233-307`

影响：子功能改动可能引发连锁回归；排错边界不够清晰。建议按职责拆分为子函数文件。

### M2. 部分薄封装仍然存在

**已删除**（原高风险，现已解决）：

- ~~`UIIntentBuilder.lua`~~ 已删除
- ~~`UIModelProjection.lua`~~ 已删除
- ~~`UIModelPanelBuilder.lua`~~ 已删除

**仍存在**：

- `TurnActionPort.lua`: 22 行，提供默认回退端口语义
- `GameplayLoopPortsAdapter.lua`: 19 行，测试依赖的端口注入层
- `ActionLogIntents.lua`: 18 行，单纯转发
- `PopupIntents.lua`: 24 行，单纯转发

影响：文件数量和跳转数量仍可增加理解成本。

### M3. UI 输入链仍有 3-4 层

当前链路：

```text
UIEventRouter (105 行)
  -> intent_builders/* (6 个文件)
  -> UIIntentDispatcher (192 行)
    -> TurnActionPort (22 行)
      -> TurnDispatch
```

对比原架构（已优化）：

- ~~`UIIntentBuilder`~~ 已删除，减少了一层门面

影响：新增按钮语义仍需改 2-3 处（intent_builder + router + 可能 dispatcher）。

## 低风险（合理设计）

### L1. Flow + DirtyTracker 设计正确

- `Flow` 保持极简状态步进：`src/core/Flow.lua`
- `DirtyTracker` 结构清晰，适合增量渲染：`src/core/DirtyTracker.lua`

### L2. UIModel 已合并为单一入口

- `UIModel.lua`（约 360 行）现在是唯一 UI 数据组装入口
- 已合并原 `UIModelProjection` 和 `UIModelPanelBuilder` 的功能
- 改一个展示字段只需改 1 处

### L3. 测试入口统一

- 回归测试：`tests/regression.lua`
- 依赖规则检查：`tests/internal/dep_rules.lua`
- GameplayLoop 隔离测试：`tests/internal/gameplay_loop_no_ui.lua`

---

## 5. 反证与边界

"模块多"不必然等于过度设计。本项目的关键判断依据：

1. **抽象层是否有语义增量**：`UIModel` 合并后语义清晰，属于正向改进。
2. **改动链路长度**：从原来的 4-5 层减少到 2-3 层，已显著改善。
3. **主循环复杂度**：`GameplayLoop.tick` 仍承载较多横切关注点，建议继续拆分。

当前判断：**收敛进行中，不是过度设计**。

---

## 6. 收敛方案（M1-M3，更新版）

## M1：拆分 GameplayLoop.tick 子职责

目标：将 `tick` 函数按职责拆分为子函数文件，降低单函数复杂度。

拆分方向：

- `gameplay_loop_auto.lua`：auto runner 相关逻辑
- `gameplay_loop_timeout.lua`：各类超时处理
- `gameplay_loop_anim.lua`：动画步进协调
- `gameplay_loop_sync.lua`：状态同步（input lock, role control）

边界：仅 `src/game/flow/turn/` 目录。

验收：

- `lua tests/regression.lua` 通过
- `lua tests/internal/gameplay_loop_no_ui.lua` 通过

## M2：进一步压平 interaction 链

目标：评估是否将 `intent_builders/*` 内联到 `UIEventRouter`，减少文件分散。

当前状态：6 个 intent_builder 文件，共 250 行。

方案对比：

- **方案 A**：保持现状（文件分散但职责清晰）
- **方案 B**：内联到 UIEventRouter（减少文件，但增加单文件长度）

建议：当前规模（250 行）可接受，暂不改动，观察增长趋势。

## M3：删除或合并剩余薄封装

目标：删除纯转发层，保留真正边界层。

优先级：

1. `ActionLogIntents.lua` + `PopupIntents.lua` -> 内联到调用方
2. `TurnActionPort.lua` -> 评估是否合并到 `TurnDispatch`
3. `GameplayLoopPortsAdapter.lua` -> 评估测试是否可改为依赖注入

边界：优先处理无独立语义且 <=25 行的文件。

验收：

- `lua tests/regression.lua` 通过
- `lua tests/internal/dep_rules.lua` 通过

---

## 7. 建议执行的下一步动作

1. **拆分 GameplayLoop.tick**：按 M1 方案拆分子职责，降低单函数复杂度。

2. **评估 intent_builders 合并**：若未来新增 intent 类型，优先考虑内联到 UIEventRouter。

3. **删除 ActionLogIntents + PopupIntents**：内联到对应调用方，减少文件数。

4. **建立薄封装监控**：新增文件 <=20 行时触发审查，防止薄封装反弹。

---

## 8. 最终判断

当前架构**已进入健康区间**，主要问题（多层转发、模型投影碎片化）已解决。

剩余优化点（GameplayLoop 拆分、剩余薄封装）属于**渐进改进**，不影响功能开发。

建议：

- **短期**：执行 M3，删除剩余薄封装（1-2 天工作量）
- **中期**：执行 M1，拆分 GameplayLoop（3-5 天工作量）
- **长期**：保持监控，防止架构复杂度反弹

**当前架构可支撑业务迭代，无需重写。**
