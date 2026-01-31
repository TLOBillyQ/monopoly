---@class LobbyShop.MainView : Class
---@field goods_list [] 商品列表
---@field shop_canvas UIManager.EImage 商店画布
---@field tab_list UIManager.EImage 标签列表
---@field page_list UIManager.EImage 标签页列表
---@field close_button UIManager.EImage 关闭按钮
---@field current_tab UIManager.EImage 当前标签
---@field general_coin_info UIManager.EImage 通用金币信息
---@field general_coin_amount UIManager.ELabel 通用金币数量
---@field new fun(self: LobbyShop.MainView): LobbyShop.MainView
local MainView = Class("LobbyShop.MainView")

function MainView:init()
    local shop_canvas = UIManager.query_nodes_by_name("ShopCanvas")[1] --[[@as UIManager.EImage]]
    self.shop_canvas = shop_canvas
    self.last_canvas = nil
    self.tab_list = shop_canvas:get_first_node_by_name("TabList") --[[@as UIManager.EImage]]
    self.current_tab = self.tab_list:get_first_node_by_name("Buy")
    self.page_list = shop_canvas:get_first_node_by_name("PageList")
    self.close_button = shop_canvas:get_first_node_by_name("CloseButton")
    local general_coin_info = shop_canvas:get_first_node_by_name("GeneralCoinInfo") --[[@as UIManager.EImage]]
    self.general_coin_info = general_coin_info
    self.general_coin_amount = general_coin_info:get_first_node_by_name("Amount")
end

---@param page_name string 标签名称
function MainView:show(page_name)
    local role = UIManager.client_role --[[@as Role]]
    role.get_ctrl_unit().clear_selected_equipment_slot()
    for _, page in ipairs(self.page_list.children) do
        page.visible = false
    end
    for _, tab in ipairs(self.tab_list.children) do
        local text = tab:get_first_node_by_name("Text")
        if text then
            text.text_color = 0xffffff
        end
    end
    local text = self.current_tab:get_first_node_by_name("Text")
    if text then
        text.text_color = 0xff8800
    end
    local page = self.page_list:get_first_node_by_name(page_name)
    if UIManager.typeof(page, "UIManager.EImage") then
        local PageView = require("Manager.ShopManager.LobbyShop.GUI." .. page_name .. "View")
        if PageView then
            PageView:show(page)
            page.visible = true
        end
    end
    self:update_coin(0)
end

---@param amount integer
function MainView:update_coin(amount)
    local role = UIManager.client_role --[[@as Role]]
    local player = PlayerManager.find_player_by_role(role)
    local vault = player.vault
    vault:update_render(role, "coin", amount, self.general_coin_amount)
end

function MainView:hide()
    self.shop_canvas.visible = false
    local RecyclePageView = require("Manager.ShopManager.LobbyShop.GUI.RecyclePageView")
    local BuyPageView = require("Manager.ShopManager.LobbyShop.GUI.BuyPageView")
    RecyclePageView:hide()
    BuyPageView:hide()
    self.current_tab = self.tab_list:get_first_node_by_name("Buy")
end

MainView = MainView:new()

return MainView
