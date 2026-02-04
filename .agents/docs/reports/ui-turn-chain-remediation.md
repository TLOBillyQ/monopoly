# UI 事件到回合链路彻底修复方案

目标：
消除道具槽断言崩溃与 UI 重载失效问题，收敛输入规则，拆分职责并建立可测试的依赖边界。

范围：
- src/ui/UIEventRouter.lua
- src/ui/UIEventHandlers.lua
- src/ui/UIView.lua
- src/ui/UIModel.lua
- src/game/turn/TurnDispatch.lua
- src/game/turn/TurnManager.lua
- src/game/choice/ChoiceManager.lua
- src/game/game/CompositionRoot.lua
- vendor/third_party/UIManager/Listener.lua

总览步骤：
1. 引入 InputGate 统一输入规则。
2. 拆分 UIEventRouter 为绑定、映射、派发三层。
3. 增加 Listener 生命周期管理与 UI 重建支持。
4. 修复道具槽点击在非道具阶段触发断言。
5. 使 UIEventHandlers 可重复安装与重置。
6. 可选引入时间源注入提升测试性。

详细实施：
- 新增模块 src/ui/InputGate.lua。
- 功能：统一判断 intent 是否允许，覆盖 input_blocked、choice/market/popup 的允许列表与阶段约束。
- 目的：避免 UI 与 TurnDispatch 的规则分裂。

- 拆分 UIEventRouter：
- 新建 src/ui/UIEventBinder.lua 负责 query_nodes_by_name、listen、listener 句柄保存。
- 新建 src/ui/UIIntentMapper.lua 负责 _resolve_option_id 与 intent 构建。
- 新建 src/ui/UIIntentDispatcher.lua 负责调用 TurnDispatch 或 UIView。
- 保留 UIEventRouter 作为装配与对外入口，内部组合以上三者。

- 监听生命周期：
- UIEventBinder 返回 listener 列表并保存到 state.ui_event_router_listeners。
- 增加 UIEventRouter.unbind(state) 释放所有 listener，并清理 state.ui_event_router_registered。
- 在 UI 重建或退出流程中调用 unbind 再 bind。

- 道具槽点击修复：
- InputGate 中加入 item_slot_* 仅在 pending_choice.kind == item_phase_choice 时允许。
- 或在 UIView.refresh_item_slots 里根据回合阶段禁用触摸。
- 保留 TurnDispatch 的断言，作为最后防线。

- UIEventHandlers.install 重入：
- 将 installed 替换为 version 或维护当前 logger/state 引用。
- 若已安装则更新闭包使用的新 logger/state。
- 或提供 event_handlers.reset() 供外部调用。

- 可测试性提升：
- TurnDispatch 接收 clock 或时间函数注入，默认落回 GameAPI。
- 便于对 next_turn 冷却与锁定行为进行单元测试。

接口与数据结构变化：
- 新增 InputGate 模块。
- state 新增 ui_event_router_listeners。
- UIEventRouter 增加 unbind API。
- 可选：TurnDispatch 新增时间源注入参数。

测试与验收：
- 验证 item_slot_* 在非道具阶段不会触发断言。
- input_blocked 与允许列表在 UI 层与 TurnDispatch 一致。
- UI 重载后按钮可点击，且重复 bind 不会产生双重触发。
- Choice 流程与 market/popup 不受回归影响。
- next_turn 冷却逻辑在可控时间源下可稳定复现。

风险与缓解：
- 拆分后文件数量增加，需同步更新 require 路径与装配逻辑。
- 生命周期变更需找到 UI 重建时机，先在现有入口加日志验证。
- 规则集中后行为可能变更，先加开关或对比日志观察差异。
