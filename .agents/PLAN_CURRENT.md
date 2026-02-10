# UI 职责解耦与依赖倒置重构（UIView/UIEventRouter/UIModel/MoveAnim）

本可执行计划是活文档。实施过程中持续维护“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次重构解决 `src/ui` 当前最核心的结构问题：`UIView` 职责过重、流程状态被视图直接改写、事件路由靠硬编码分支、UI 层对引擎全局细节耦合过深。改造后，UI 状态变更集中到协调器，渲染与锁定策略拆分，事件绑定切换为声明式路由，动画计算补齐零距离防护。用户可见行为保持不变，但后续需求的改动面和回归风险显著下降。

## 进度

- [x] (2026-02-10) 新增 `UIModalStateCoordinator` 并接管 modal/choice 状态写入。
- [x] (2026-02-10) 新增 `UIRoleContext`、`UIPanelPresenter`、`UIInputLockPolicy`、`UIModalPresenter` 并让 `UIView` 委托调用。
- [x] (2026-02-10) 新增 `UIRuntimePort`，收口 `UIManager/all_roles` 访问。
- [x] (2026-02-10) 把 `UIEventRouter.bind` 重构为声明式路由表。
- [x] (2026-02-10) 修复 `MoveAnim` 零距离除零风险。
- [x] (2026-02-10) 更新/新增回归测试并跑全量 `regression`（72 通过）。

## 意外与发现

- 观察：`Config/RuntimeConstants.lua` 的 `eca_event` 表缺失分隔符，导致 `require` 语法报错，中断全部回归。
  证据：`lua .agents/tests/regression.lua` 初次执行报错 `'}' expected ... near 'camera'`。
- 观察：补上分隔符后，全量回归恢复可执行。
  证据：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (72)`。

## 决策日志

- 决策：先做“行为等价重构”，不改变 UI 对外函数签名。
  理由：保证现有测试和调用链最小扰动。
  日期/作者：2026-02-10 / Codex
- 决策：声明式路由优先覆盖现有按钮，不扩大新节点语义。
  理由：先降低复杂度，再做功能扩展。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

- 已完成本次 UI 解耦重构：`UIView` 改为编排层，modal/面板/锁定/角色上下文/运行时访问下沉到独立模块；`UIEventRouter` 完成声明式路由化；`MoveAnim` 增加零距离与非法速度防护。
- 目标达成：对外接口保持兼容，行为回归通过；后续新增 UI 按钮和 modal 流程时，只需改独立模块，避免继续膨胀 `UIView`。
- 剩余缺口：本轮未扩展功能面，仅做结构重构与边界修复，后续若做新功能可在新计划里按模块增量推进。

## 背景与导读

本次改动重点文件：

- `src/ui/UIView.lua`：当前 UI 入口，职责过重。
- `src/ui/UIEventRouter.lua`：当前事件绑定中心，硬编码分支过多。
- `src/ui/MoveAnim.lua`：存在零距离除零风险。
- `src/ui/UIModel.lua`：提供渲染数据。

新增模块规划：

- `src/ui/UIModalStateCoordinator.lua`
- `src/ui/UIRoleContext.lua`
- `src/ui/UIPanelPresenter.lua`
- `src/ui/UIInputLockPolicy.lua`
- `src/ui/UIModalPresenter.lua`
- `src/ui/UIRuntimePort.lua`

## 工作计划

先引入状态协调器并替换 `UIView/MarketView` 中直接写时序字段的路径，确保“状态写入唯一入口”。再拆出角色上下文、面板渲染、输入锁策略和 modal 展示逻辑，并让 `UIView` 仅保留编排职责。随后加入运行时端口封装，把 UI 层直接全局调用收口，最后把 `UIEventRouter.bind` 迁移成声明式路由。并在最后修复 `MoveAnim` 的零距离边界，补齐回归。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 新增 `UIModalStateCoordinator`，迁移 `pending_choice_elapsed/pending_choice_id/pending_choice_selected_option_id` 的写入。
2. 新增 `UIRoleContext` + `UIPanelPresenter` + `UIInputLockPolicy` + `UIModalPresenter`，改 `UIView` 为委托。
3. 新增 `UIRuntimePort`，封装节点查询、可见/触摸/文案与角色迭代。
4. 重写 `UIEventRouter.bind` 为路由表驱动绑定。
5. 修改 `MoveAnim._calc_step` 增加 `len<=0` 防护。
6. 更新 `/.agents/tests/suites/ui.lua`（必要时 `gameplay.lua`），执行：
   lua .agents/tests/regression.lua

## 验证与验收

- 自动化：`lua .agents/tests/regression.lua` 全量通过。
- 行为一致：
  - 选择框、黑市、弹窗与输入锁行为不退化。
  - 道具槽位 role 隔离与点击门禁保持。
  - 托管按钮状态展示保持正确。
- 边界增强：
  - `MoveAnim` 在 from/to 重合时不报错、不除零。

## 可重复性与恢复

本次重构按模块增量推进，可分文件回滚。若任一步失败，按文件粒度回退新增模块与 `UIView/UIEventRouter/MoveAnim` 变更，再执行回归确认。

## 产物与备注

- 预期产物：6 个新增模块 + 3 个核心文件重构 + 回归用例更新。
- 保持 API 兼容：`UIView` 对外函数签名不变。

## 接口与依赖

新增内部接口（模块级）：

- `UIModalStateCoordinator`：只负责 modal/choice 状态写入，不做渲染。
- `UIRoleContext`：role->player 映射和 per-role 渲染上下文。
- `UIRuntimePort`：封装 `UIManager/all_roles` 细节，向上提供稳定调用面。

计划更新说明（2026-02-10）：为“执行 uncle-bob-reviewer 重构方案”新建并覆盖本计划。
计划更新说明（2026-02-10）：完成全部里程碑并补充回归结果、意外发现与复盘结论。
