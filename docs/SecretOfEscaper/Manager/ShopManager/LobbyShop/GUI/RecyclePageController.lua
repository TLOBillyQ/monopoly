local RecyclePageView = require "Manager.ShopManager.LobbyShop.GUI.RecyclePageView"

local next_page_button = RecyclePageView.next_page_button
next_page_button:listen("click", function(data)
    RecyclePageView:next_page()
end)

local last_page_button = RecyclePageView.last_page_button
last_page_button:listen("click", function(data)
    RecyclePageView:last_page()
end)

local sell_button = RecyclePageView.sell_button
sell_button:listen("click", function(data)
    RecyclePageView:sell()
end)