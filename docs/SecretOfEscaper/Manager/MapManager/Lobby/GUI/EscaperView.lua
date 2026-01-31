local AbilityConfig = require("Config.AbilityConfig")
---@class Lobby.EscaperView
---@field back_button UIManager.EImage
---@field show_button UIManager.EImage
---@field new fun(self: Lobby.EscaperView): Lobby.EscaperView
local EscaperView = Class("Lobby.EscaperView")

function EscaperView:init()
    local canvas = UIManager.query_nodes_by_name("EscapeSelectorCanvas")[1] --[[@as UIManager.EImage]]
    self.canvas = canvas
    self.back_button = UIManager.get_first_node_by_name("EscaperSelectExitButton") --[[@as UIManager.EImage]]
    self.show_button = UIManager.get_first_node_by_name("EscaperSelectButton") --[[@as UIManager.EImage]]
    self.escaper_list = UIManager.get_first_node_by_name("EscaperList") --[[@as UIManager.EImage]]
    self.escaper_introduction = UIManager.get_first_node_by_name("EscaperIntroduction") --[[@as UIManager.EImage]]
end

function EscaperView:show()
    local role = UIManager.client_role --[[@as Role]]
    local node = self.show_button
    local back_node = self.back_button
    node.disabled = true
    role.send_ui_custom_event("选择逃生动画", {})
    SetTimeOut(0.45, function()
        local temp = UIManager.client_role --[[@as Role?]]
        UIManager.client_role = role
        back_node.disabled = false
        UIManager.client_role = temp
    end)
    self:reset_escaper_list()
end

function EscaperView:reset_escaper_list()
    local escaper_list = self.escaper_list.children
    local config = require "Config.EscaperConfig"
    local i = 1
    for code, escaper_config in pairs(config) do
        local escaper = escaper_list[i]
        escaper.visible = true
        escaper.custom_data.config = escaper_config
        escaper.custom_data.code = code
        local icon = escaper:get_first_node_by_name("Icon") --[[@as UIManager.EImage]]
        local name = escaper:get_first_node_by_name("Name") --[[@as UIManager.ELabel]]

        icon.image_texture = escaper_config.icon
        name.text = escaper_config.name
        name.text_color = 0xffffff
        i = i + 1
    end
    for j = i, escaper_list.length do
        escaper_list[j].visible = false
    end
    local custom_data = self.show_button.custom_data
    custom_data.code = custom_data.code or "miner"
    custom_data.config = custom_data.config or config["miner"] --[[@as EscaperConfig]]
    self:show_escaper_info(custom_data.code, custom_data.config)
end

---@param code EscaperCode
---@param config EscaperConfig
function EscaperView:show_escaper_info(code, config)
    local role = UIManager.client_role --[[@as Role]]
    local player = PlayerManager.find_player_by_role(role)
    player:set_escaper(code)
    self.escaper_introduction.visible = true
    local custom_data = self.escaper_introduction.custom_data
    custom_data.config = config
    local escaper_introduction = self.escaper_introduction
    local icon = self.escaper_introduction:get_first_node_by_name_dfs("Icon") --[[@as UIManager.EImage]]
    local name = escaper_introduction:get_first_node_by_name_dfs("Name") --[[@as UIManager.ELabel]]
    local description = escaper_introduction:get_first_node_by_name_dfs("Description") --[[@as UIManager.ELabel]]
    local ability_list = escaper_introduction:get_first_node_by_name_dfs("AbilityList") --[[@as UIManager.EImage]]
    icon.image_texture = config.icon
    name.text = config.name
    description.text = config.introduce
    self.escaper_list.children:forEach(function(e)
        e:get_first_node_by_name_dfs("Name") --[[@as UIManager.ELabel]].text_color = 0xffffff
        if e.custom_data.config == config then
            e:get_first_node_by_name_dfs("Name") --[[@as UIManager.ELabel]].text_color = 0xff8800
        end
    end)
    for i = 1, 3 do
        local ability = ability_list.children[i]
        local ability_code = config.ability[i]
        if ability_code then
            local ability_config = AbilityConfig[ability_code]
            ability.visible = true
            local ability_icon = ability:get_first_node_by_name_dfs("Icon") --[[@as UIManager.EImage]]
            local ability_name = ability:get_first_node_by_name_dfs("Name") --[[@as UIManager.ELabel]]
            local ability_introduce = ability:get_first_node_by_name_dfs("Description") --[[@as UIManager.ELabel]]
            ability_icon.image_texture = ability_config.icon
            ability_name.text = ability_config.name
            ability_introduce.text = ability_config.introduce
        else
            ability.visible = false
        end
    end
end

function EscaperView:hide()
    local node = self.back_button
    local select_node = self.show_button
    node.disabled = true
    if UIManager.client_role then
        UIManager.client_role.send_ui_custom_event("选择逃生收回动画", {})
    else
        for _, role in ipairs(ALLROLES) do
            role.send_ui_custom_event("选择逃生收回动画", {})
        end
    end
    local role = UIManager.client_role
    SetTimeOut(0.45, function()
        local temp = UIManager.client_role --[[@as Role?]]
        UIManager.client_role = role
        select_node.disabled = false
        UIManager.client_role = temp
    end)
end

EscaperView = EscaperView:new()

return EscaperView
