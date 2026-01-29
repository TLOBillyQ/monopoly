---@namespace ChooseOption
local ChooseOption = {}

---@enum Reward
local Reward = {}
ChooseOption.Reward = Reward

---@class Reward.Ability
---@field ability_key AbilityKey
---@field slot AbilitySlot
Reward.Ability = "Ability"

---@class Config
---@field container ENode 容器ID
---@field title string 标题
---@field description string 描述
---@field choose_event string 选择卡牌事件
---@field confirm_event string 确认事件
---@field confirm_button ENode 确认按钮ID
local Config = {}

---@alias CardLevel 1 | 2 | 3

---@class CardConfig
---@field icon ImageKey 图标预设
---@field icon_description? string 图标描述
---@field label? string 卡牌标签文本
---@field title string 卡牌标题
---@field description string 卡牌描述
---@field level CardLevel 卡牌等阶
local CardConfig = {}

---@type table<ENode, Container?>
local ContainerMapping = {}

---构建三选一
---@param config Config
---@return Container?
function ChooseOption.build(config)
    if ContainerMapping[config.container] then
        error(("Container '%s' exists"):format(config.container))
        return
    end
    local Container = require "ChooseOption.Container"
    return Container(config)
end

return ChooseOption
