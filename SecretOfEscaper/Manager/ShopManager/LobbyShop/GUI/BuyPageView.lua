local ItemConfig = require "Config.ItemConfig"

---@class LobbyShop.BuyPageView
---@field buy_page UIManager.EImage 购买页
---@field goods_list UIManager.EImage 商品列表
---@field goods_info UIManager.EImage 商品信息
---@field new fun(self: LobbyShop.BuyPageView): LobbyShop.BuyPageView
local BuyPageView = Class("LobbyShop.BuyPageView")
local ShopView = require 'Manager.ShopManager.LobbyShop.GUI.MainView'
local MainView = require("Manager.ShopManager.LobbyShop.GUI.MainView")
function BuyPageView:init()
    local buy_page = ShopView.page_list:get_first_node_by_name("BuyPage") --[[@as UIManager.EImage]]
    self.buy_page = buy_page
    self.goods_list = buy_page:get_first_node_by_name_dfs("GoodsList") --[[@as UIManager.EImage]]
    self.goods_info = buy_page:get_first_node_by_name_dfs("GoodsInfo") --[[@as UIManager.EImage]]
end

function BuyPageView:show()
    self.buy_page.visible = true
    self:reset_goods_list()
end

function BuyPageView:reset_goods_list()
    local goods_list = self.goods_list.children
    local config = require 'Config.ShopConfig.LobbyShop'
    for i = 13, 24 do
        local good = goods_list[i]
        local good_config = config[i - 12]
        if good_config then
            local item = ItemConfig[good_config.code]
            good.visible = true
            good.custom_data.config = good_config
            local icon = good.children[1] --[[@as UIManager.EImage]]
            local price = good.children[2] --[[@as UIManager.ELabel]]
            local name = good.children[3] --[[@as UIManager.ELabel]]
            icon.image_texture = item.icon or 10065
            if good_config.status == ShopManager.Status.NORMAL then
                icon.image_color = 0xffffff
                price.text = tostring(good_config.buy_price)
                price.text_color = 0xffffff
            elseif good_config.status == ShopManager.Status.COMING_OFF_SOON then
                icon.image_color = 0x000000
                price.text = "即将下架"
                price.text_color = 0xff0000
            elseif good_config.status == ShopManager.Status.COMING_ON_SOON then
                icon.image_color = 0x000000
                price.text = "即将上架"
                price.text_color = 0x0088ff
            end
            name.text = item.name
        else
            good.visible = false
            good.custom_data.config = nil
        end
    end
end

function BuyPageView:hide()
    self.buy_page.visible = false
end

---@param good_config Config.LobbyShop
function BuyPageView:show_item_info(good_config)
    self.goods_info.visible = true
    local custom_data = self.goods_info.custom_data
    custom_data.config = good_config
    local item_config = ItemConfig[good_config.code]
    local goods_info = self.goods_info
    local display_icon_group = goods_info:get_first_node_by_name_dfs("DisplayIcon") --[[@as UIManager.EImage]]
    local icon = display_icon_group:get_first_node_by_name_dfs("Icon") --[[@as UIManager.EImage]]
    local title = display_icon_group:get_first_node_by_name_dfs("Title") --[[@as UIManager.ELabel]]
    local display_description_group = goods_info:get_first_node_by_name_dfs("DisplayDescription") --[[@as UIManager.EImage]]
    local description = display_description_group:get_first_node_by_name_dfs("Description") --[[@as UIManager.ELabel]]

    icon.image_texture = item_config.icon or 10065
    title.text = item_config.name

    local count = custom_data.count or 1
    local buy_price = good_config.buy_price
    description.text = ([[
当前价格: #f(c:ffff00)%d#l （#f(c:ff0000)%d#l）个
%s
    ]]):format(buy_price * count, count, item_config.desc)
    local amount = -buy_price * count --[[@as integer]]
    MainView:update_coin(amount)
end

function BuyPageView:hide_item_info()
    self.goods_info.visible = false
    MainView:update_coin(0)
end

BuyPageView = BuyPageView:new()

return BuyPageView
