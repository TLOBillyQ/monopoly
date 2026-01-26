local ChooseOption = require "ChooseOption.__init"
local Container = ChooseOption.build({
    choose_event = "click", --选择卡牌事件
    confirm_event = "confirm", --确认事件
    container = "1849988781", --容器ID
    description = "选择一项技能", --描述
    title = "技能选择", --标题
})
if not Container then
    return
end
Container:set_reward(1, function(role)
    print("奖励1")
end)
Container:set_reward(2, function(role)
    print("奖励2")
end)
Container:set_reward(3, function(role)
    print("奖励3")
end)
Container:set_display(1, {
    icon_description = "0级",
    icon = 14956,
    description = "六百六十六",
    title = "小丑戏法",
    label = "绿色技能",
    level = 3
})
Container:set_display(2, {
    icon_description = "4级",
    icon = 14228,
    description = "把你摔下去",
    title = "过肩摔",
    label = "红色技能",
    level = 2
})
Container:set_display(3, {
    icon_description = "2级",
    icon = 14223,
    description = "我要藏起来",
    title = "隐身技能",
    label = "紫色技能",
    level = 2
})
Container:show(GameAPI.get_all_valid_roles()[1] --[[@as Role]])
