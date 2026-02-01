# UIManager 节点命名同步计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


UIManagerNodes.lua 已更新为中文节点名，但业务代码仍在用旧英文命名，导致查询不到节点、按钮点击无效、文本无法刷新。本计划要从 `Manager/TurnManager/GUI/UIState.lua` 的 `EggyLayerUI.build_ui_state` 起逐段检索并替换旧命名，确保主界面、道具槽、黑市面板、弹窗与选择框在运行时仍可正确显示与交互。完成后应能看到玩家信息正常刷新，且点击“行动/托管/黑市/弹窗确认/取消”等按钮触发对应逻辑，且不再出现“UI 节点未适配”提示。


## 进度


- [x] (2026-02-01 17:04+08:00) 盘点 UIState/MarketUI/UIEventRouter 中旧命名清单并建立新旧映射
- [x] (2026-02-01 17:04+08:00) 更新 UIState、MarketUI、UIEventRouter、UIAliases 与 init.lua 的节点名
- [x] (2026-02-01 17:04+08:00) 完成静态检索验证并记录缺失节点


## 意外与发现


- 观察：Data/UIManagerNodes.lua 中不存在 choice_title/choice_body/popup_title/popup_body 等文本节点，仅能确认弹窗屏/弹窗确认/取消按钮与道具名称等节点存在。
  证据：`rg -n "choice_title|choice_body|popup_title|popup_body" Data/UIManagerNodes.lua` 无输出；`rg -n "弹窗屏|弹窗确认|取消按钮|道具名称" Data/UIManagerNodes.lua` 有命中。


## 决策日志


- 决策：choice 根节点改为复用“黑市屏”，选项节点改为“道具名称1..4”，以保留多选项点击能力。
  理由：Data/UIManagerNodes.lua 中缺少独立的 choice 选项节点，现有可点击且可写文本的节点只有“道具名称”系列。
  日期/作者：2026-02-01 / Codex
- 决策：panel_turn 映射到“倒计时”，用于继续显示回合数；panel_title 不再写入。
  理由：Data/UIManagerNodes.lua 中无独立标题节点，倒计时是唯一通用标签节点。
  日期/作者：2026-02-01 / Codex
- 决策：popup title/body 字段置空，不再写入文本节点。
  理由：Data/UIManagerNodes.lua 中不存在对应节点，写入会触发缺失提示，先保持最小改动等待 Eggy 编辑器确认。
  日期/作者：2026-02-01 / Codex


## 结果与复盘


已同步更新 UI 节点命名并完成静态检索；剩余风险在于弹窗与选择框的文本节点缺失，需要后续在 Eggy 编辑器中确认并补齐。若 UI 侧补齐节点，可再按本计划追加映射并去除临时复用。


## 背景与导读


UI 节点名来自 `Data/UIManagerNodes.lua` 与 `Data/UINodes.lua`，这两份表是唯一可靠来源。`Manager/TurnManager/GUI/UIState.lua` 通过 `UIManager.query_nodes_by_name` 查询节点并设置文本/显示/触控，是主要入口。`Manager/TurnManager/GUI/UIEventRouter.lua` 负责绑定点击事件。`Manager/MarketManager/GUI/MarketUI.lua` 与 `Manager/MarketManager/GUI/UIMarket.lua` 负责黑市面板节点名与刷新。`Manager/ChoiceManager/GUI/UIAliases.lua` 负责别名映射。任务要求从 `EggyLayerUI.build_ui_state` 开始检索旧命名，逐段替换为中文新命名。


## 工作计划


先在 UIState、UIEventRouter、MarketUI 中列出全部旧命名，再与 `Data/UIManagerNodes.lua`/`Data/UINodes.lua` 对照，写出明确的新旧映射。能从语义直接对应的命名（例如 item_slot_1 -> 道具槽位1，panel_player_1_name -> 玩家1名字，market_item_frame_1 -> 底框1）直接替换。对弹窗标题/正文、选择框标题/正文/选项等不明显的节点，必须以 `Data/UINodes.lua` 中存在的节点名为准；若表内无对应节点，则需要进入 Eggy 编辑器核对实际节点名并更新代码，或在保证行为不变的前提下删改调用，并将原因记录到“决策日志”。所有替换优先集中在定义处（UIState、MarketUI）与事件绑定处（UIEventRouter），避免在业务逻辑中散落字符串。


## 子 agent 协调计划


如需并行推进，可按以下分工调度子 agent，并由主 agent 统一汇总与验收。每个子 agent 只负责一个文件或一组强相关文件，避免交叉改动引发冲突。

分工建议：

1) 子 agent A：聚焦 `Manager/TurnManager/GUI/UIState.lua`，只做 build_ui_state、refresh_panel、refresh_item_slots 的节点名替换与拼接逻辑调整，并产出新旧映射清单。
2) 子 agent B：聚焦 `Manager/TurnManager/GUI/UIEventRouter.lua`，只做点击事件绑定节点名替换，记录无法对应的节点名。
3) 子 agent C：聚焦 `Manager/MarketManager/GUI/MarketUI.lua` + `Manager/MarketManager/GUI/UIMarket.lua`，只做黑市面板相关命名常量替换与必要联动检查。
4) 子 agent D：聚焦 `Manager/ChoiceManager/GUI/UIAliases.lua`，维护兼容别名映射，并确保新旧命名双向清晰。

协调流程：

1) 主 agent 先生成统一的新旧命名映射草案（来自 `Data/UIManagerNodes.lua` 与 `Data/UINodes.lua`），在任务开头发给所有子 agent。
2) 子 agent 完成后提交：改动文件清单、未解决的命名问题、以及任何需要主 agent 决策的点。
3) 主 agent 负责合并映射差异、补齐“决策日志”，并在最终检索中验证旧命名消失。

冲突处理：

若多个子 agent 需要修改同一文件，必须合并为单一负责者；其他人只提供建议，不提交补丁，避免合并冲突。


## 具体步骤


在仓库根目录先检索并建立旧命名清单：

    rg -n "EggyLayerUI.build_ui_state" Manager/TurnManager/GUI/UIState.lua
    rg -n "item_slot_|btn_next|btn_auto|panel_|choice_|popup_|market_" Manager

打开 `Data/UIManagerNodes.lua` 与 `Data/UINodes.lua` 对照整理，至少覆盖下列映射，并作为替换基准：

    item_slot_1..5 -> 道具槽位1..5
    panel_player_{i}_name/cash/land_count/detail -> 玩家{i}名字/现金/地块数量/总资产
    btn_next -> 行动按钮
    btn_auto -> 托管按钮
    market_panel -> 黑市屏
    market_confirm_button -> 黑市购买按钮
    market_cancel_button -> 关闭
    market_price_label -> 售价：100
    market_selected_card -> 选中卡牌
    market_item_button1..10 -> 黑市购买项1..10
    market_item_label_1..10 -> 道具名称1..10
    market_item_frame_1..10 -> 底框1..10
    popup_confirm -> 弹窗确认
    modal_popup -> 弹窗屏
    choice_cancel -> 取消按钮

按照映射更新以下文件，所有替换集中在定义与绑定处：

`Manager/TurnManager/GUI/UIState.lua` 中更新 `build_ui_state` 的 item_slots、choice/popup 结构体，以及 `refresh_panel`/`refresh_item_slots` 的字符串拼接规则。`Manager/TurnManager/GUI/UIEventRouter.lua` 中更新按钮/道具槽/弹窗/选择项/黑市关闭的绑定名称。`Manager/MarketManager/GUI/MarketUI.lua` 中更新黑市面板全部节点名常量。`Manager/ChoiceManager/GUI/UIAliases.lua` 中补齐需要兼容的别名映射，例如仍需支持 `choice_option_1` 这类旧格式。

如果发现 `Data/UINodes.lua` 中不存在弹窗标题/正文、选择框标题/正文/选项等节点名，必须在 Eggy 编辑器核对实际节点名并更新代码；若确认 UI 中不存在对应节点，则在保证行为不变的前提下移除相关 set_label/set_visible 调用，并记录原因到“决策日志”。

完成替换后再次检索，确认旧命名不再被使用：

    rg -n "item_slot_|btn_next|btn_auto|panel_|choice_|popup_|market_" Manager


## 验证与验收


先做静态验证：运行上述 `rg` 检索，预期旧命名无命中或仅剩 `UIAliases.lua` 的兼容映射。若命中仍出现在业务文件中则视为未完成。再做运行验证（如可启动 UI）：进入蛋仔大富翁界面，观察玩家信息、道具槽、黑市文本可更新，点击“行动按钮”“托管按钮”“黑市购买按钮”“弹窗确认”“取消按钮”能触发对应逻辑，且无“UI 节点未适配”提示。


## 可重复性与恢复


本修改为字符串命名同步，可重复执行。若需要回退，可用 Git 还原相关文件；若替换后出现缺失提示，可回滚单个文件并重新核对节点名。


## 产物与备注


产物为节点命名更新后的代码文件与映射说明。验收时保留一段简短检索证据即可：

    rg -n "item_slot_|btn_next|btn_auto|panel_|choice_|popup_|market_" Manager
    (无命中或仅剩 UIAliases 兼容映射)


## 接口与依赖


本任务依赖 `Data/UIManagerNodes.lua` 与 `Data/UINodes.lua` 作为节点命名的唯一事实来源。事件绑定仍使用 `UIManager.query_nodes_by_name`，因此名称必须完全一致。若需要兼容旧命名，只允许在 `Manager/ChoiceManager/GUI/UIAliases.lua` 内维护映射，禁止在业务逻辑中散落兼容分支。

变更记录：修复计划文件乱码并恢复完整中文内容，原因是文件出现问号占位导致不可读，影响可执行性。新增“子 agent 协调计划”，用于并行拆分与合并验收。补记执行结果与决策，原因是完成实际改名同步与缺失节点处理。
