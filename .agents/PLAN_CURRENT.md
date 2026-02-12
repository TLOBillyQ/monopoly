# 下一轮：UI 事件路由拆分与节点校验


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本轮目标是把 UI 事件路由拆分为职责清晰的模块，增加 UI 节点启动期校验，并去除 UI 事件对全局角色的隐式依赖。完成后，UI 交互逻辑更容易定位与测试，节点缺失可在启动时暴露而不是运行时才提示。可见结果：UI 初始化时会执行节点校验并给出明确错误信息，`UIEventRouter` 体积显著缩小，测试脚本在无 `all_roles` 情况也能运行。

## 进度

- [x] (2025-03-04 13:30Z) 拆分 UIEventRouter 的职责（状态判断 / 输入解析 / 节点注册）。
- [x] (2025-03-04 13:30Z) 增加 UI 节点启动期校验。
- [x] (2025-03-04 13:30Z) 为 UIEvents 增加角色注入接口，移除隐式全局依赖。
- [x] (2025-03-04 13:30Z) 回归验证与新增测试。

## 意外与发现

- 观察：`UIEventBindings.register_missing_button_tip` 迭代时遇到 `validate` 函数导致崩溃。
  证据：过滤非 table 后回归通过。

## 决策日志

- 决策：UI 事件路由拆成 3 个模块，`UIEventRouter` 仅做协调。
  理由：减少单文件职责混杂，便于测试与维护。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

完成 UI 事件路由拆分、节点校验与角色注入，回归通过，UI 逻辑更易测试与维护。

## 背景与导读

目前 `src/presentation/interaction/UIEventRouter.lua` 同时承担节点注册、状态判断、输入解析、调试开关与提示输出，违反 SRP。`src/presentation/shared/UIEvents.lua` 直接读取全局 `all_roles`，导致 UI 事件不可在无运行时环境复用。`Data/UIManagerNodes.lua` 是 UI 节点映射，但缺少启动期校验，节点漂移只能在运行时提示。

相关文件：
- `src/presentation/interaction/UIEventRouter.lua`
- `src/presentation/shared/UIEvents.lua`
- `Data/UIManagerNodes.lua`
- `src/app/init.lua`
- `.agents/tests/suites/presentation_ui.lua`

## 工作计划

先拆分 `UIEventRouter`：把节点注册与事件监听移动到 `UIEventBindings.lua`，把 UI 状态判断逻辑移动到 `UIEventState.lua`，把输入解析/意图生成移动到 `UIEventIntents.lua`。`UIEventRouter` 仅负责调用新模块的公开接口。随后在 UI 初始化链路中加入 `UIManagerNodes` 的校验函数，检查必要节点是否存在。最后在 `UIEvents` 中增加 `set_roles(roles)` 或 `configure({ roles = ... })`，在初始化阶段注入角色列表并移除对 `all_roles` 的直接依赖。

## 具体步骤

1) 拆分 UIEventRouter。

新增以下模块：
- `src/presentation/interaction/UIEventState.lua`：提供 `is_base_screen_active(state)`、`resolve_debug_enabled(state)` 等纯状态判断。
- `src/presentation/interaction/UIEventBindings.lua`：提供 `register_node_click(...)` 等节点注册与监听安装。
- `src/presentation/interaction/UIEventIntents.lua`：提供 `choice_cancel_intent(...)`、`choice_select_intent(...)`、`choice_confirm_intent(...)` 等输入解析。

修改 `UIEventRouter.lua`：移除上述函数实现，改为调用新模块。保持现有对外 API 与行为不变。

2) 增加 UI 节点启动期校验。

在 `Data/UIManagerNodes.lua` 新增导出函数 `validate(required_names)`，返回缺失列表。调用点放在 `src/app/init.lua` 的 UI 初始化后，传入当前业务所需节点集合（从 `UIEventRouter` 与 `UIStatus3DLayer` 使用的节点名称抽取）。缺失时使用 `error` 报出清晰提示。

3) UIEvents 注入角色列表。

在 `src/presentation/shared/UIEvents.lua` 增加 `set_roles(roles)`，内部保存角色列表；`send_to_all` 从内部角色列表读取，不再直接访问 `all_roles`。在 `src/app/init.lua` 初始化阶段调用 `UIEvents.set_roles(all_roles)`。

4) 回归与新增测试。

在 `.agents/tests/suites/presentation_ui.lua` 增加节点校验失败/成功用例与 `UIEvents` 无全局角色测试。运行现有回归脚本，确保行为不变。

## 验证与验收

在仓库根目录执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

新增测试预期：
- 缺失节点时提示明确错误信息。
- `UIEvents.send_to_all` 在未注入 roles 时无崩溃。

## 可重复性与恢复

每一步为独立改动，若 UI 路由拆分导致行为偏差，可先回滚新模块并恢复到单文件实现。节点校验如影响旧数据，可先降级为 warning 并记录缺失列表。

## 产物与备注

预期新增/修改：

    src/presentation/interaction/UIEventState.lua
    src/presentation/interaction/UIEventBindings.lua
    src/presentation/interaction/UIEventIntents.lua
    src/presentation/interaction/UIEventRouter.lua
    src/presentation/shared/UIEvents.lua
    Data/UIManagerNodes.lua
    src/app/init.lua
    .agents/tests/suites/presentation_ui.lua

## 接口与依赖

- `UIEventState` 只读 state，不触发副作用。
- `UIEventBindings` 只处理节点查询与监听注册。
- `UIEventIntents` 只生成意图，不执行动作。
- `UIEvents` 必须通过 `set_roles` 注入角色列表。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入“UI 事件路由拆分与节点校验”可执行计划。
变更说明（2025-03-04 / Codex）：完成全部步骤与回归验证，记录按钮提示注册的迭代修复。
