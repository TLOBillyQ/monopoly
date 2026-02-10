UI V2 分屏重构设计与迁移计划（弹窗/选择拆分版）
摘要
当前代码仍按旧 UI 结构运行（通用选择屏 + 弹窗屏），而最新 UIManagerNodes.lua 已切为新分屏结构。已确认会导致关键节点失配（至少 8 个旧节点名不存在）。
本方案目标是：在不动态生成 UI前提下，完成新分屏接入，保证现有玩法（popup + choice + market）行为稳定，并提供可回退的迁移路径。

已确认你的产品决策（本方案严格遵循）：

弹窗统一走 机会卡屏
选择按语义分流（玩家类 / 位置类 / 通用类）
按钮语义固定：弹窗确认 确认按钮；选择确认 确定按钮；取消 取消按钮；关闭 仅黑市
remote_dice_value 启用 遥控骰子屏
超出按钮容量时截断；按现有按钮数截断（玩家3、目标7、通用6）
位置脚下 仅在存在“脚下选项”时显示
本次范围仅覆盖已接入玩法，不纳入建筑升级/破产展示逻辑接入
目标 UI 架构（V2）
1) 画布职责
基础屏：常驻 HUD
黑市屏：market_buy
机会卡屏：所有 push_popup
玩家选择屏：玩家目标类选择
目标选择屏：位置目标类选择 + 通用 choice 根屏
遥控骰子屏：remote_dice_value
调试屏：保持独立可见逻辑
其他画布（建筑升级屏、破产展示屏）本次只保留，不接入流程
2) 选择类型路由（决策完成版）
玩家类 -> 玩家选择屏
item_target_player
位置类 -> 目标选择屏
roadblock_target
demolish_target
遥控骰子 -> 遥控骰子屏
remote_dice_value
黑市 -> 黑市屏
market_buy
通用类 -> 目标选择屏（使用 通用选择_* 节点）
item_phase_choice
discard_item
steal_item
steal_prompt
rent_card_prompt
tax_card_prompt
landing_optional_effect
land_optional_effect
market_vehicle_replace
其它未识别 kind（默认兜底）
3) 静态按钮绑定规则（不可动态生成 UI）
玩家屏：固定 玩家槽位1..3，按 options 原顺序取前 3
目标屏：固定 位置前1..3 + 位置后1..3 + 位置脚下，按规则取前 7
通用屏：固定 通用选择_选项_01..06，按原顺序取前 6
统一规则：超出即截断，不分页，不动态增节点
位置脚下：仅当选项显式表达“脚下/当前位置”时启用，否则隐藏
4) 弹窗绑定规则
画布：机会卡屏
标题：触发事件标题
正文：请输入文字（取第一个命中节点）
确认：确认按钮
卡图：机会卡牌（无图时隐藏并重置为 空）
代码改造设计（文件级）
A. 布局与路由抽象（新增）
UILayoutProfile.lua
维护 V1/V2 布局描述（画布名、按钮名、文本节点名、容量）
提供 detect(nodes)：根据 Data.UIManagerNodes 自动判定布局版本
UIChoiceRoutePolicy.lua
resolve_screen(choice_kind)：choice kind -> screen 类型
UIStaticOptionBinder.lua
负责“静态按钮列表 + 截断 + 显隐 + 触控开关”
B. 现有模块改造（最小侵入）
UIView.lua
build_ui_state() 改为读取 UILayoutProfile
去掉旧硬编码 通用选择屏/弹窗屏/弹窗标题...
新增 V2 字段：choice_screens、popup_screen、layout_version
UICanvasCoordinator.lua
常量改为 profile 驱动
保留兼容别名常量（旧调用不崩）
弹窗返回逻辑支持“多选择屏返回”
UIModalPresenter.lua
push_popup 改走 机会卡屏 节点
open_choice_modal 使用 UIChoiceRoutePolicy 分流
静态节点绑定全部走 UIStaticOptionBinder
UIEventRouter.lua
事件入口改为 profile 配置节点
新增玩家槽位、位置按钮、确定按钮/确认按钮/取消按钮 路由
关闭 仅黑市取消
UIAliases.lua
更新别名映射，去除已不存在节点名（保留必要兼容 alias）
ui.lua
mock 节点更新为 V2 命名
增加新分流与截断测试
迁移方案（可回退）
阶段 M0：计划落盘（流程要求）
清空 PLAN_CURRENT.md
写入本次执行版计划（按 PLANS.md）
阶段 M1：双版本共存（安全迁移）
先引入 UILayoutProfile 自动识别 V1/V2
不改外部调用签名（ui_view.open_choice_modal/push_popup 保持不变）
若 V2 必要节点缺失，降级到 V1 并 logger.warn（一次性告警）
阶段 M2：V2 全量接管当前玩法
按本方案接管 popup + choice + market 全链路
保留 V1 兼容分支，确保旧 UI 资源仍可跑
阶段 M3：验证稳定后收口
回归通过后，将 V1 标记为 deprecated
文档更新到新分屏架构（.agents/docs/ui/）
回退策略：

任一阶段异常可通过 profile 强制切回 V1
代码层保持单开关回退，不需要还原 gameplay 逻辑
公共接口 / 类型变更
对外行为保持不变，内部接口新增：

UILayoutProfile.detect(nodes) -> profile
UILayoutProfile.current() -> profile
UIChoiceRoutePolicy.resolve_screen(choice_kind) -> screen_key
UIStaticOptionBinder.bind(ui, screen_cfg, options, opts)
UIView.build_ui_state() 返回结构新增：

ui.layout_version
ui.choice_screens.<player|target|generic|remote>
ui.popup_screen
兼容策略：

保留旧调用入口与业务 intent 类型，不改游戏层 choice_spec
测试与验收场景
核心命令：

regression.lua
新增/调整测试点（ui.lua）：

V2 布局检测：新节点表识别为 V2
弹窗路由：push_popup 显示 机会卡屏，并更新 触发事件标题/请输入文字/确认按钮/机会卡牌
选择分流：
item_target_player -> 玩家选择屏
roadblock_target/demolish_target -> 目标选择屏
remote_dice_value -> 遥控骰子屏
其它 -> 目标选择屏 + 通用选择_*
截断策略：
玩家类 >3 时仅前三
目标类 >7 时仅前七
通用类 >6 时仅前六
位置脚下 仅在显式脚下选项时可见
黑市关闭仍使用 关闭，不影响新选择/弹窗确认语义
回归标准：全量 regression 通过，且 UI 套件新增断言全绿
假设与默认值（已锁定）
不能动态生成 UI 节点（强约束）
截断按后端 options 原顺序，不做重排
本次不接入 建筑升级屏/破产展示屏 业务逻辑
若 请输入文字/标题 多节点同名，默认取可查询到的首节点作为主写入目标
未识别 choice kind 统一走“通用类兜底”