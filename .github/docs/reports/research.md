# 架构复杂度深度调研（src / Config / vendor）

更新时间：2026-02-24  
调研范围：`ARCHITECTURE.md`、`src/`、`Config/`、`vendor/`、`.github/tests/`

## 1. 结论

结论：**存在 over-engineering（部分严重）**。  
核心问题不是“模块多”本身，而是“抽象层级叠加 + 薄封装转发 + 主循环职责过载”同时出现，导致理解成本、改动成本、回归成本都偏高。

一句话判断：**方向合理（状态机 + dirty 增量刷新），实现层数过厚。**

---

## 2. 调研方法

本次采用“文档-实现对照 + 定量扫描 + 关键链路抽样”：

1. 对照 `ARCHITECTURE.md` 的分层声明与真实代码主链。
2. 统计规模与抽象命名密度（Adapter/Port/Policy/Registry/Dispatcher/Service/Builder/Presenter/Bootstrap/Coordinator/Handler）。
3. 抽样薄封装文件（低行数 + 单纯转发）。
4. 评审启动链、Tick 链、UI 交互链的跳转层数。

---

## 3. 定量画像

### 3.1 规模

- `src/` 文件数：**183**
- `Config/` 文件数：**19**
- `vendor/` 文件数：**29**

### 3.2 抽象命名密度

- 命中抽象命名模式的 `src` 文件：**50 / 183（约 27.3%）**

### 3.3 薄封装密度

- `src` 中行数 `<= 25` 的文件：**30**
- 其中命中抽象命名模式且 `<= 25` 的样本：**16**（如 `TurnActionPortAdapter.lua`、`GameplayLoopPortsAdapter.lua`、`MarketService.lua`、`ActionLogIntents.lua`、`PopupIntents.lua`）

### 3.4 复杂度集中目录

- `src/presentation/interaction`：**18** 文件
- `src/presentation/api`：**15** 文件
- `src/game/flow/turn`：**21** 文件

这 3 个目录同时处于“高变更频率 + 高协作冲突概率”位置。

---

## 4. 证据清单（按风险分级）

## 高风险

### H1. Ports 抽象层叠加，协议复杂度偏高

- 文档声明 `GameplayLoop` 依赖 6 组 ports（`modal/anim/ui_sync/debug/clock/state`），并经 adapter 注入：`ARCHITECTURE.md:241-255`
- 实现中 `GameplayLoopPorts.lua` 还包含默认实现、兼容判断、分组合并、fallback 逻辑：`src/game/flow/turn/GameplayLoopPorts.lua:1-226`
- 注入层再次拆一层：`src/presentation/api/GameplayLoopPortsAdapter.lua:1-19`

影响：理解一条 UI 行为需要跨“端口定义 -> 端口合并 -> 端口注入 -> 端口实现 -> 调用方”多跳。

### H2. 主循环职责过载

- `GameplayLoop.tick` 同时处理输入锁、角色控制锁、auto runner、超时、动画、倒计时、dirty 刷新、debug 同步：`src/game/flow/turn/GameplayLoop.lua:233-307`

影响：任何一个子能力改动都可能触发连锁回归；排错边界不清晰。

### H3. UI 输入链路过深

- 路由链在文档中已体现：`UIEventRouter -> UIIntentDispatcher -> TurnDispatchValidator -> TurnDispatch`：`ARCHITECTURE.md:331`
- 代码层还包含 `UIIntentBuilder` + `intent_builders/*` 的分发层：`src/presentation/interaction/UIIntentBuilder.lua:1-42`
- `UIEventRouter` 将多个 intent 构建器拼接再注册：`src/presentation/interaction/UIEventRouter.lua:20-39,87-98`

影响：新增一个按钮语义，需要动多个薄层文件，改动扩散明显。

### H4. 启动链拆分过细

- 启动链跨 `RuntimeInstall`、`GameStartup`、`GameStartupEventBridge`、`UIBootstrap`、`GameRuntimeBootstrap`：`ARCHITECTURE.md:21-27`
- `src/app/init.lua` 串联 5 个 bootstrap 角色：`src/app/init.lua:1-20`

影响：新成员定位“启动失败”要跨多个模块找因果。

## 中风险

### M1. 薄封装模块比例偏高

代表样本（单纯转发或小聚合）：

- `src/app/ports/TurnActionPortAdapter.lua:5-14`
- `src/presentation/api/TurnActionPort.lua:12-20`
- `src/game/systems/market/MarketService.lua:13-17`
- `src/presentation/interaction/intent_builders/ActionLogIntents.lua:5-16`
- `src/presentation/interaction/intent_builders/PopupIntents.lua:3-22`

影响：文件数量和跳转数量增加，但语义增量有限。

### M2. Registry/Handler 体系重复出现

- `ChoiceRegistry`、`ItemRegistry`、`EffectRegistry`、`ActionAnimRegistry` 等多套注册分发并存：`ARCHITECTURE.md:104-123,115-123,194-196`

影响：模式一致但实现分散，学习曲线变陡，容易出现“同类问题多点修复”。

### M3. 状态投影层拆分较碎

- `UIModel` + `UIModelProjection` + `UIModelPanelBuilder` 三层联动：`ARCHITECTURE.md:214-217`

影响：改一个展示字段需要跨多个文件查依赖。

## 低风险（合理设计）

### L1. `Flow + DirtyTracker` 主思路是正确的

- `Flow` 保持极简状态步进：`src/core/Flow.lua:1-22`
- `DirtyTracker` 结构清晰，适合增量渲染：`src/core/DirtyTracker.lua:1-51`

### L2. 测试入口统一，具备改造保护网基础

- 现有回归主入口明确：`.github/tests/regression.lua:1-31`

---

## 5. 反证与边界

“模块多”不必然等于过度设计。  
本项目问题的关键是：

1. 抽象层之间缺少明显“语义增量”（很多层只转发）。
2. 主循环承载了过多横切关注点。
3. 一条常见改动链路需要跨太多文件。

所以判断是“过度抽象”，不是“必须推倒重来”。

---

## 6. 收敛方案（M0-M3）

## M0：冻结基线与依赖图

目标：先把主链和职责边界画清楚，禁止边改边漂移。  
边界：只改文档，不改行为。  
验收：

- `lua .github/tests/regression.lua`

## M1：压平 interaction 链

目标：把 `UIIntentBuilder + intent_builders/* + UIIntentDispatcher + UIEventRouter` 收敛成一个统一路由入口，减少多跳。  
边界：仅 `src/presentation/interaction/` 与 `TurnActionPort*` 相关层。  
验收：

- `lua .github/tests/regression.lua`

## M2：收敛 UI 投影链

目标：把 `UIModelProjection/UIModelPanelBuilder` 的核心投影逻辑并回 `UIModel`，减少状态更新路径分叉。  
边界：`src/presentation/state/` + 少量 `api` 调用位。  
验收：

- `lua .github/tests/regression.lua`

## M3：删薄封装、保留硬边界

目标：删除纯转发层，保留真正边界层（`GameplayLoop`、`Game`、`DirtyTracker`、`UIViewService`）。  
边界：优先删 `<=25` 行且无独立语义文件。  
验收：

- `lua .github/tests/regression.lua`
- `lua .github/tests/internal/dep_rules.lua`
- `lua .github/tests/internal/gameplay_loop_no_ui.lua`

---

## 7. 建议立即执行的 5 个动作

1. 把 `TurnActionPortAdapter + TurnActionPort` 合并成单入口。
2. 将 `MarketService` 的 query/choice/purchase/auto 聚合语义内联到一个明确 API 面。
3. 在 `GameplayLoop` 内按职责拆子函数文件（auto、timeout、anim、sync、debug）。
4. 给 `interaction` 增加“单入口路由”并逐步下线 `intent_builders/*`。
5. 建立“薄封装删除白名单”（先删 10 个最小风险文件）。

---

## 8. 最终判断

当前架构**不是错误架构**，但已经达到“维护成本拐点”。  
若不做收敛，后续每次需求迭代都会继续放大跨层改动成本。  
建议按 M0-M3 逐步收敛，而不是一次性重写。
