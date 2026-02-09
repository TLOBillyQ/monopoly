目标动作镜头、主动行动最短展示、图片接口统一改造计划
摘要
本次改造聚焦 3 件事：

目标选择类 action 动画期间切镜头到目标，结束后回到当前行动角色；
主动行动（投骰、主动用道具、机会卡展示）统一最短可见时长 1.5s，避免“一闪而过”；
把现有图片赋值统一改为 set_image_texture_by_key_with_auto_resize 路径。
用户可见结果：AI/托管与手动流程里，关键主动行为都会被看清；目标类动作会有明确镜头指向；UI 图片设置走统一接口。

范围与文件
ActionAnim.lua
TurnLand.lua
Landing.lua
ItemExecutor.lua
ItemPostEffects.lua
ItemRoadblock.lua
ItemDemolish.lua
ItemSteal.lua
TickUISync.lua
UIView.lua
MarketView.lua
UIAliases.lua（如需补充图片节点别名）
新增：UIImage.lua（统一图片设置 helper）
关键实现设计（已拍板）
1) 目标选择 action 的镜头策略
在 ActionAnim.play 中增加“镜头聚焦控制”：

新增 action anim payload 字段（内部协议）：
focus_target_player_id
focus_target_tile_index
聚焦优先级：focus_target_player_id > focus_target_tile_index。
玩家目标：设置 camera_helper.target_role_id 并触发 follow_camera 事件。
地块目标：对有效角色调用：
role.set_camera_bind_mode(Enums.CameraBindMode.BIND)
role.set_camera_lock_position(tile_pos)
动画结束恢复：
若是地块锁定，恢复 Enums.CameraBindMode.TRACK
再把相机跟随切回 anim.player_id（当前行动角色）
加状态锁：state.camera_focus_active + token，避免并发 timeout 误恢复。
在 TickUISync._refresh_view 中，camera_focus_active=true 时跳过“默认跟随当前玩家”的覆盖行为，防止镜头被抢回。
2) 主动行动最短 1.5s
统一最短时长规则放在 ActionAnim.play（最终 delay 源头）：
effective_duration = max(anim.duration or kind_default, 1.5)
覆盖范围按已确认口径：
投骰（已有 roll action_anim）
主动使用道具（含原有有特效道具 + 原先无动画的主动道具）
机会卡展示
“主动道具但无现有动画”的补齐策略（ItemExecutor.use_item）：
在成功执行、非 waiting、且当前未排队 action_anim 时，自动补一个通用 item_use 动画（1.5s）。
不改变既有返回语义（避免连锁破坏），仅附加排队副作用。
机会卡展示（Landing.chance_draw_and_resolve）：
抽卡并结算后，若可播放 action_anim 且当前无待播，排队 chance 动画（携带 card 描述）。
TurnLand 增加“桥接等待”：
landing 结束后若存在 turn.action_anim，优先进入 wait_action_anim，再回 post_action 或 wait_choice，确保展示先发生。
3) 图片设置统一改为指定接口
新增 UIImage.lua，封装统一方法（按当前 client_role 或 allroles 调用）：

set_texture(node, image_key, reset_size)
内部调用 role.set_image_texture_by_key_with_auto_resize(node.id, image_key, reset_size)。
替换所有直接 node.image_texture = ... 的位置：

UIView.set_item_slot_image
MarketView.refresh_market_selection
MarketView.refresh_market（稀有度底框）
MarketView.close_market_panel
保留现有尺寸语义：

原先 “赋值 + reset_size()” 的点，改为 reset_size=true
其余保持 reset_size=false
公共接口/类型变更
本次不改外部调用 API；仅扩展内部 action_anim payload 协议（向后兼容）：

新增可选字段：
focus_target_player_id: integer?
focus_target_tile_index: integer?
text: string?
item_id/item_name/card_id/card_desc（仅用于展示文案，不影响逻辑分支）
测试计划与验收场景
自动化回归
运行：

regression.lua
新增/调整用例（放入现有 suites）：

ui 套件：

ActionAnim.play 对玩家目标会触发 follow；结束恢复到行动者。
地块目标会调用 set_camera_bind_mode(BIND)+set_camera_lock_position，结束恢复 TRACK。
camera_focus_active 期间 TickUISync 不覆盖镜头。
item 套件：

对“原无动画”的主动道具（如遥控骰子/状态类）使用后会排队 action_anim。
目标玩家道具（item_target_player）会带目标聚焦字段。
chance/landing 套件：

踩机会格后会排队 chance action_anim。
TurnLand 在存在 action_anim 时先进入 wait_action_anim，再继续后续状态。
ui 套件：

图片设置走 set_image_texture_by_key_with_auto_resize 路径（通过 mock role 方法计数验证）。
手工验收（编辑器内）
场景 A：使用“均富/流放/查税”等目标玩家道具：镜头先到目标，再回当前角色。
场景 B：使用“路障/导弹/怪兽”等目标地块道具：镜头锁到目标格，再回当前角色。
场景 C：机会格触发：至少可见 1.5s 的机会卡表现，不再瞬间跳过。
场景 D：回合结束主动用道具（post_action）：行为表现至少 1.5s。
场景 E：道具槽位与黑市卡牌图片正常显示，无拉伸异常、无闪烁。
假设与默认
已确认口径：
最短 1.5s 仅覆盖主动动作（投骰/主动道具/机会卡展示），不扩展到全部被动结算。
目标类动作包含地块目标，镜头也要过去。
图片接口替换范围为当前所有图片写入点（UIView/MarketView）。
若运行环境缺失相机相关 API（Enums.CameraBindMode 或 role 方法），降级为仅跟随玩家，不中断流程。
当前系统仍是“单槽 action_anim”（非队列）；本次不引入多动画队列，避免扩大改动面。
执行顺序
先清空并更新 PLAN_CURRENT.md（按仓库纪律记录本计划）。
实现 UIImage 并替换图片写入点。
改造 ActionAnim（时长下限 + 镜头聚焦/恢复）。
补齐主动道具通用动画（ItemExecutor）与目标字段注入（item/roadblock/demolish/steal）。
接入机会卡动画与 TurnLand 桥接等待。
补测试并跑 regression.lua，修正仅与本改动相关失败。
输出变更说明与验收结果。
