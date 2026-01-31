local MainView = require 'Manager.ShopManager.LobbyShop.GUI.MainView'

local tab_list = MainView.tab_list
tab_list.children:forEach(function(tab)
    tab:listen("click", function(data)
        MainView.current_tab = tab
        MainView:show(tab.name .. "Page")
    end)
end)

local close_button = MainView.close_button
close_button:listen("click", function(data)
    MainView:hide()
end)