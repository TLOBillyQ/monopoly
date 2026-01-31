---@class LootEscaper.MainView
---@field new fun(self: LootEscaper.MainView): LootEscaper.MainView
local MainView = Class("LootEscaper.MainView")

function MainView:init()
    local canvas = UIManager.get_first_node_by_name("ExploreCanvas") --[[@as UIManager.EImage]]
    self.canvas = canvas
    local team_mate_group = canvas:get_first_node_by_name_dfs("TeamMateInfoGroup") --[[@as UIManager.EImage]]
    .children --[[@as ArrayReadOnly<UIManager.EImage>]]
    self.team_mate_group = team_mate_group
end

function MainView:update_team_mate_group()
    local temp = UIManager.client_role
    UIManager.client_role = nil
    local team_mate_group = self.team_mate_group
    team_mate_group:forEach(function(team_mate)
        local Name = team_mate:get_first_node_by_name("Name") --[[@as UIManager.ELabel]]
        local HealthBar = team_mate:get_first_node_by_name("HealthBar") --[[@as UIManager.EProgressbar]]
        local player = team_mate.custom_data.player --[[@as Player?]]
        if player then
            team_mate.visible = true
            HealthBar.max_value = player.health_system.max_value
            HealthBar.value = player.health_system.value
            Name.text = player.get_name()
            if player.health_system.is_dead then
                Name.text = Name.text .. " #f(c:ff0000)已阵亡#l"
            end
        else
            team_mate.visible = false
        end
    end)
    UIManager.client_role = temp
end

MainView = MainView:new()

return MainView
