local BuyPageView = require 'Manager.ShopManager.LobbyShop.GUI.BuyPageView'
local ItemConfig = require "Config.ItemConfig"

local goods_list = BuyPageView.goods_list.children --[[@as ArrayReadOnly<UIManager.EImage>]]
for i = 13, 24 do
    local good = goods_list[i]
    good.visible = false
    good:listen("click", function(data)
        for j = 13, 24 do
            goods_list[j].image_color = 0xffffff
        end
        good.image_color = 0xff8800
        local config = good.custom_data.config
        BuyPageView:show_item_info(config)
    end)
end

local goods_info = BuyPageView.goods_info
local display_buy_group = goods_info:get_first_node_by_name_dfs("DisplayBuy") --[[@as UIManager.EImage]]
local buy_text = display_buy_group:get_first_node_by_name_dfs("BuyText") --[[@as UIManager.ELabel]]
buy_text:listen("click", function(data)
    local role = data.role
    local player = PlayerManager.find_player_by_role(role)
    local inventory = player.inventory
    local vault = player.vault
    local goods_info_custom_data = goods_info.custom_data
    local config = goods_info.custom_data.config --[[@as Config.LobbyShop?]]
    if config then
        if config.status ~= ShopManager.Status.NORMAL then
            role.show_tips("该商品上架状态异常，无法购买")
            return
        end
        local count = goods_info_custom_data.count or 1
        local capacity = 99 - #inventory.items - count
        if count > 0 then
            local price = config.buy_price * count
            local coin = vault:get_balance("coin")
            if coin >= price and capacity > 0 then
                vault:withdraw("coin", price)
                for i = 1, count do
                    inventory:append(config.code)
                end
                BuyPageView:hide_item_info()
                BuyPageView:show()
                player:save_data()
                role.show_tips("购买成功")
            elseif capacity <= 0 then
                role.show_tips("容量不足")
            else
                role.show_tips("金币不足")
            end
        end
    end
end)

local add_button = display_buy_group:get_first_node_by_name_dfs("Add") --[[@as UIManager.EImage]]
add_button:listen("click", function(data)
    local goods_info_custom_data = goods_info.custom_data
    local config = goods_info_custom_data.config
    if not goods_info_custom_data.count then
        goods_info_custom_data.count = 1
    end
    if config then
        local count = goods_info_custom_data.count
        if count < 10 then
            goods_info_custom_data.count = count + 1
            buy_text.text = ("购买 %d 个"):format(goods_info_custom_data.count)
        end
    end
    BuyPageView:show_item_info(config)
end)

local minus_button = display_buy_group:get_first_node_by_name_dfs("Minus") --[[@as UIManager.EImage]]
minus_button:listen("click", function(data)
    local goods_info_custom_data = goods_info.custom_data
    local config = goods_info_custom_data.config
    if not goods_info_custom_data.count then
        goods_info_custom_data.count = 1
    end
    if config then
        local count = goods_info_custom_data.count
        if count > 1 then
            goods_info_custom_data.count = count - 1
            buy_text.text = ("购买 %d 个"):format(goods_info_custom_data.count)
        end
    end
    BuyPageView:show_item_info(config)
end)
