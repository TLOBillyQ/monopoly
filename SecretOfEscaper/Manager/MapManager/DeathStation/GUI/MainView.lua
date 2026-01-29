---@class DeathStation.MainView
---@field lobby_canvas UIManager.EImage 大厅画布
---@field shop_button UIManager.EImage 商店按钮
---@field equip_button UIManager.EImage 装备按钮
---@field ready_button UIManager.EImage 准备按钮
---@field game_over_button UIManager.EImage 游戏结束按钮
---@field backpack_button UIManager.EImage 背包按钮
---@field start_game_button UIManager.EImage 开始游戏按钮
---@field escaper_select_button UIManager.EImage 选择逃生按钮
---@field new fun(self: DeathStation.MainView): DeathStation.MainView
local MainView = Class("Lobby.MainView")
local AllCanvas = require "Globals.Canvas"

function MainView:init()
    local lobby_canvas = UIManager.query_nodes_by_name("LobbyCanvas")[1] --[[@as UIManager.EImage]]
    self.lobby_canvas = lobby_canvas
    self.shop_button = lobby_canvas:get_first_node_by_name_dfs("ShopButton")
    self.equip_button = lobby_canvas:get_first_node_by_name_dfs("EquipButton")
    self.ready_button = lobby_canvas:get_first_node_by_name_dfs("ReadyButton")
    self.game_over_button = lobby_canvas:get_first_node_by_name_dfs("GameOverButton")
    self.backpack_button = lobby_canvas:get_first_node_by_name_dfs("BackpackButton")
    self.start_game_button = lobby_canvas:get_first_node_by_name_dfs("StartGameButton")
    self.escaper_select_button = lobby_canvas:get_first_node_by_name_dfs("EscaperSelectButton")
end

---@param canvas_name string 画布名称
function MainView:show(canvas_name)local canvas = UIManager.get_first_node_by_name(canvas_name)
    if UIManager.typeof(canvas, "UIManager.EImage") then
        canvas.visible = true
    end
end

MainView = MainView:new()

return MainView