local MainView = require("Manager.ModeManager.LootEscaper.GUI.MainView")

local team_mate_group = MainView.team_mate_group
for i, role in ipairs(ALLROLES) do
    local player = PlayerManager.find_player_by_role(role)
    team_mate_group[i].custom_data.player = player
    player.escaper--[[@as Escaper]].update_view = function()
        MainView:update_team_mate_group()
    end
end
MainView:update_team_mate_group()