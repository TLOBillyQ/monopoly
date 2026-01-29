local MainView = require 'Manager.MapManager.Lobby.GUI.MainView'

MainView:show("LobbyCanvas")

local ready_button = MainView.ready_button
ready_button:listen("click", function(data)
    local role = data.role
    local text = ready_button:get_first_node_by_name_dfs("Text") --[[@as UIManager.ELabel]]
    if role.has_tag("ready") then
        role.remove_tag("ready")
        text.text = "准备"
    else
        role.add_tag("ready")
        text.text = "已准备"
    end
end)

local start_game_button = MainView.start_game_button
start_game_button:listen("click", function(data)
    local role = data.role
    local could_start = true
    for _, _role in ipairs(ALLROLES) do
        if not _role.has_tag("ready") then
            could_start = false
            role.show_tips("请等待其他玩家准备", 2.0)
            break
        end
    end
    if could_start and not GameManager.gaming then
        GameManager.start_game()
    end
end)
