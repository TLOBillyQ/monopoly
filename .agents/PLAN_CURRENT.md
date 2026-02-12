# 接入新 UI（Eggy UIManagerNodes）可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

目标是把新 UI 资源接入现有 Lua 逻辑，确保所有界面能显示、可交互、逻辑响应正确。完成后，玩家能正常进入基础屏，触发选择类弹窗、黑市、卡牌展示、破产展示与调试开关；并且 UI 事件能驱动游戏回合逻辑。验证方式是：跑回归脚本通过，并在编辑器内完成一次完整交互流程（显示/隐藏各屏、点击按钮触发行为）。

## 进度

- [ ] (2025-03-04 15:00Z) 清点新 UI 节点与旧逻辑的映射差异。
- [ ] (2025-03-04 15:00Z) 更新 UI 节点表与依赖配置。
- [ ] (2025-03-04 15:00Z) 修正 UI 事件绑定与面板渲染。
- [ ] (2025-03-04 15:00Z) 补充交互与回归验证记录。

## 意外与发现

暂无。实施过程中记录发现与证据。

## 决策日志

- 决策：以 `Data/UIManagerNodes.lua` 为单一事实源，所有 UI 名称以此为准。
  理由：Eggy 导出文件是 UI 实际节点来源，能避免逻辑与 UI 名称不一致。
  日期/作者：2025-03-04 / Codex

- 决策：保持“基础屏常驻，其他屏叠加”的切屏逻辑不变。
  理由：`UICanvasCoordinator` 与 `UIModalPresenter` 已形成稳定的状态机，变更风险高。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

未开始。完成后补充“做到了什么、仍缺什么、经验教训”。

## 背景与导读

本项目 UI 由 Eggy 编辑器导出，节点清单位于 `Data/UIManagerNodes.lua`。显示/隐藏逻辑通过 `src/presentation/shared/UIEvents.lua` 生成 UI 事件，`src/presentation/interaction/UICanvasCoordinator.lua` 负责屏幕切换。交互输入在 `src/presentation/interaction/UIEventRouter.lua` 中绑定，UI 文本与图像渲染由 `src/presentation/api/UIView.lua` 与 `src/presentation/ui/UIPanelPresenter.lua` 驱动。黑市与弹窗相关逻辑在 `src/presentation/render/MarketView.lua`、`src/presentation/ui/UIModalPresenter.lua`。

术语解释：
- “ECanvas”是 UI 的顶层屏幕节点，相当于一个整屏界面（例如基础屏、黑市屏）。
- “节点名”是 Eggy UI 元素的唯一名称（例如“行动按钮”、“取消按钮”）。逻辑必须通过名称查询节点。
- “UI 事件”是 UIManager 触发的自定义事件，前缀为“显示/隐藏 + 屏幕名”。

## 工作计划

先确认新 UI 节点与现有逻辑的名称是否一致，并列出所有必须存在的节点。以 `Data/UIManagerNodes.lua` 为权威，逐一对照以下逻辑依赖：
1) `UIView.build_ui_state` 里的基础节点（道具槽位、基础屏节点、弹窗根节点等）。
2) `UICanvasCoordinator` 与 `UIEvents` 的所有 ECanvas 名称。
3) `UIEventRouter` 的所有可点击节点与事件绑定。
4) `MarketLayout` 与 `MarketView` 的黑市面板节点。

若发现名称变化，统一在逻辑层替换为新名称；若新 UI 缺失节点，补充 UI 导出或用占位节点替代，并在计划里记录原因。

然后更新 UI 接入的关键文件，保持行为不变：
- 更新 `Data/UIManagerNodes.lua` 为新 UI 导出内容（整表替换）。
- 若新 UI 的黑市面板节点不同，更新 `src/presentation/shared/MarketLayout.lua` 的 `container` 与按钮列表。
- 若选择屏、弹窗、破产屏节点名发生变化，更新 `src/presentation/api/UIView.lua` 中 `choice_screens`、`popup_screen`、`bankruptcy_screen` 的名称。
- 若按钮/点击节点名变化，更新 `src/presentation/interaction/UIEventRouter.lua` 的路由规格。
- 若基础屏玩家信息/道具槽位名称变化，更新 `src/presentation/ui/UIPanelPresenter.lua` 与 `UIView.refresh_item_slots` 的节点名。

最后跑回归与人工验收，确保切屏、交互与渲染正常。

## 具体步骤

1) 清点 UI 节点差异。

在仓库根目录执行：

    rg -n "ECanvas" Data/UIManagerNodes.lua
    rg -n "行动按钮|取消按钮|建筑升级|遥控骰子|黑市|卡牌展示|破产|玩家选择|位置选择" Data/UIManagerNodes.lua

把结果与现有逻辑中对应节点名逐条对照，形成“保持/替换/缺失”列表。

2) 更新 UI 节点表。

用新 UI 导出文件替换 `Data/UIManagerNodes.lua`。若导出文件缺失必要节点，回到 Eggy UI 补齐并重新导出，然后再次替换。

3) 同步逻辑依赖名称。

按以下文件顺序更新：
- `src/presentation/api/UIView.lua`：更新 `choice_screens`、`popup_screen`、`bankruptcy_screen` 中的根节点、标题节点、按钮节点。
- `src/presentation/interaction/UIEventRouter.lua`：更新 `_build_route_specs` 中绑定的按钮/节点名称。
- `src/presentation/shared/MarketLayout.lua` 与 `src/presentation/render/MarketView.lua`：更新黑市面板的容器与按钮列表。
- `src/presentation/ui/UIPanelPresenter.lua`：更新玩家信息、道具槽位、倒计时、托管按钮等节点名。

每修改一处，立刻在 `Data/UIManagerNodes.lua` 中确认名称存在，避免运行时 query_nodes 失败。

4) 跑回归脚本。

在仓库根目录执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

全部通过后进入人工验收。

5) 人工验收（编辑器内）。

在 Eggy 编辑器启动游戏，验证以下流程：
- 启动时显示“加载屏”，1 秒后切回“基础屏”。
- 触发玩家选择、位置选择、遥控骰子、建筑升级，按钮可点且返回逻辑正确。
- 触发黑市面板，商品列表可选、确认/取消正常。
- 触发卡牌展示弹窗，确认/点击灰底可关闭。
- 触发破产展示屏，文字与头像正确显示。
- 点击“图片_82”连续 10 次切换调试屏显示。

## 验证与验收

验证命令与预期：
- `lua .agents/tests/regression.lua`：无错误退出。
- `lua .agents/tests/gameplay_loop_no_ui.lua`：无错误退出。
- `lua .agents/tests/dep_rules.lua`：无错误退出。

人工验收：完成“加载屏 → 基础屏 → 选择屏/黑市/弹窗/破产/调试屏”全流程，观察 UI 可见与交互响应符合预期。

## 可重复性与恢复

以上步骤可重复执行。若更新 UI 节点表后出现运行时节点缺失，优先回退到旧版 `Data/UIManagerNodes.lua` 或补齐 UI 导出。所有逻辑层改名均可通过 `git checkout -- <file>` 回滚。

## 产物与备注

预期改动文件（按需）：

    Data/UIManagerNodes.lua
    src/presentation/api/UIView.lua
    src/presentation/interaction/UIEventRouter.lua
    src/presentation/shared/MarketLayout.lua
    src/presentation/render/MarketView.lua
    src/presentation/ui/UIPanelPresenter.lua

关键证据（示例）：

    [INFO] UI 节点校验通过
    [INFO] 显示基础屏
    [INFO] 调试屏切换完成

## 接口与依赖

依赖 UI 节点名称稳定可查询。以下节点在逻辑层必须存在：
- ECanvas：基础屏、玩家选择屏、位置选择屏、遥控骰子屏、建筑升级屏、黑市屏、卡牌展示屏、破产展示屏、调试屏、加载屏。
- 按钮：行动按钮、托管按钮、取消按钮、建筑升级_确定按钮、建筑升级_取消、遥控骰子_取消、黑市购买按钮、关闭。
- 选择项：玩家选择_槽位1-3、位置前1-3/后1-3/脚下、遥控骰子_选项_01-06。
- 展示：卡牌展示_标题、卡牌展示_图片、卡牌展示_灰底、破产_文字、破产玩家头像。

若新 UI 名称不同，必须在逻辑层完成同义替换或补充映射。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入“接入新 UI”可执行计划，补齐所有必备章节与验收标准。
