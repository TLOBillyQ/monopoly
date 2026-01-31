local MainView = require 'Manager.MapManager.Lobby.GUI.MainView'
local ShopView = require 'Manager.ShopManager.LobbyShop.GUI.MainView'
require 'Manager.ShopManager.LobbyShop.__init'

local button = UIManager.get_first_node_by_name("ShopButton") --[[@as UIManager.EImage]]
button:listen("click", function(data)
    MainView:show("ShopCanvas")
    ShopView:show("BuyPage")
end)