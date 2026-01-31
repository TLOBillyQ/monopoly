local EscaperView = require 'Manager.MapManager.Lobby.GUI.EscaperView'
local MainView = require 'Manager.MapManager.Lobby.GUI.MainView'

local show_button = EscaperView.show_button
show_button:listen("click", function(data)
    MainView:show("EscapeSelectorCanvas")
    EscaperView:show()
end)

local back_button = EscaperView.back_button
back_button:listen("click", function(data)
    MainView:show("EscapeSelectorCanvas")
    EscaperView:hide()
end)

local escaper_list = EscaperView.escaper_list
escaper_list.children:forEach(function(escaper)
    escaper:listen("click", function(data)
        local code = escaper.custom_data.code
        local config = escaper.custom_data.config
        EscaperView:show_escaper_info(code, config)
    end)
end)

for _, role in ipairs(ALLROLES) do
    local player = PlayerManager.find_player_by_role(role)
    player:set_escaper("miner")
end
