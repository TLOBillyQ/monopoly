local ItemConfig = require "Config.ItemConfig"

---@class LobbyShop.RecyclePageView
---@field recycle_page UIManager.EImage 回收页
---@field recycle_container UIManager.EImage 回收容器
---@field recycle_list ArrayReadOnly<UIManager.EBagSlot> 回收列表
---@field next_page_button UIManager.EImage 下一页按钮
---@field last_page_button UIManager.EImage 上一页按钮
---@field pre_recycle_container UIManager.EImage 预出售容器
---@field pre_recycle_list ArrayReadOnly<UIManager.EBagSlot> 预出售列表
---@field pre_recycle_info UIManager.ELabel 信息
---@field sell_button UIManager.EImage 出售按钮
---@field select_handlers table<RoleID?, integer[]?> 选择物品句柄
---@field new fun(self: LobbyShop.RecyclePageView): LobbyShop.RecyclePageView
local RecyclePageView = Class("LobbyShop.RecyclePageView")
local ShopView = require 'Manager.ShopManager.LobbyShop.GUI.MainView'
local MainView = require("Manager.ShopManager.LobbyShop.GUI.MainView")
local LobbyShop = require("Config.ShopConfig.LobbyShop")
function RecyclePageView:init()
    self.select_handlers = {}
    local recycle_page = ShopView.page_list:get_first_node_by_name("RecyclePage") --[[@as UIManager.EImage]]
    self.recycle_page = recycle_page
    local recycle_container = recycle_page:get_first_node_by_name("RecycleContainer") --[[@as UIManager.EImage]]
    self.recycle_container = recycle_container
    self.recycle_list = recycle_container:get_first_node_by_name("RecycleList") --[[@as UIManager.EImage]].children
    self.next_page_button = recycle_container:get_first_node_by_name("NextPageButton")
    self.last_page_button = recycle_container:get_first_node_by_name("LastPageButton")
    local pre_recycle_container = recycle_page:get_first_node_by_name("PreRecycleContainer") --[[@as UIManager.EImage]]
    self.pre_recycle_container = pre_recycle_container
    self.pre_recycle_list = pre_recycle_container:get_first_node_by_name("PreRecycleList")
    self.pre_recycle_info = pre_recycle_container:get_first_node_by_name("Info")
    self.sell_button = pre_recycle_container:get_first_node_by_name("SellButton")
end

function RecyclePageView:show()
    self.recycle_page.visible = true
    self.recycle_container.custom_data = {}
    local role = UIManager.client_role --[[@as Role]]
    local unit = role.get_ctrl_unit()
    for _, item in ipairs(unit.get_equipment_list_by_slot_type(Enums.EquipmentSlotType.BACKPACK)) do
        item.destroy_equipment()
    end
    self:reset_select_item()
    self:set_page(1)
end

function RecyclePageView:hide()
    self.recycle_page.visible = false
    local recycle_list = self.recycle_list
    for _, role in ipairs(ALLROLES) do
        local role_id = role.get_roleid()
        local unit = role.get_ctrl_unit()
        if self.select_handlers[role_id] then
            for _, handler in ipairs(self.select_handlers[role_id]) do
                LuaAPI.unit_unregister_trigger_event(unit, handler)
            end
        end
    end
end

function RecyclePageView:reset_select_item()
    local recycle_list = self.recycle_list
    for _, role in ipairs(ALLROLES) do
        local role_id = role.get_roleid()
        local unit = role.get_ctrl_unit()
        if self.select_handlers[role_id] then
            for _, handler in ipairs(self.select_handlers[role_id]) do
                LuaAPI.unit_unregister_trigger_event(unit, handler)
            end
        else
            self.select_handlers[role_id] = {}
        end
        local slot_index = 1
        recycle_list:forEach(function(slot)
            local actual_slot_index = slot_index
            local handler = LuaAPI.unit_register_trigger_event(
                unit,
                {
                    EVENT.SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT,
                    Enums.EquipmentSlotType.BACKPACK,
                    slot_index },
                function()
                    local temp = UIManager.client_role
                    UIManager.client_role = role
                    RecyclePageView:swap_item(actual_slot_index)
                    UIManager.client_role = temp
                end
            )
            table.insert(self.select_handlers[role_id], handler)
            slot_index = slot_index + 1
        end)
    end
end

local unit_page_count = 16

---@param page integer
function RecyclePageView:set_page(page)
    self.recycle_container.custom_data.page = page
    local role = UIManager.client_role --[[@as Role]]
    local unit = role.get_ctrl_unit()
    local player = PlayerManager.find_player_by_role(role)
    local inventory = player.inventory
    local max_page = math.ceil(#inventory.items / unit_page_count)
    page = math.max(1, math.min(page, max_page))
    page = math.tointeger(page)
    for i = 1, unit_page_count do
        local item = unit.get_equipment_by_slot(Enums.EquipmentSlotType.BACKPACK, i) --[[@as Equipment?]]
        if item then
            item.destroy_equipment()
        end
    end
    local slot_index = 1
    local custom_data = self.recycle_container.custom_data
    custom_data.record_indices = custom_data.record_indices or {}
    self.recycle_list:forEach(function(_)
        local actual_index = slot_index + (page - 1) * 15
        local item = inventory.items[actual_index]
        if not item then
            return
        end
        if not custom_data.record_indices[actual_index] then
            local equip = item:create_to_slot(player, Enums.EquipmentSlotType.BACKPACK, slot_index)
            equip.set_kv_by_type(Enums.ValueType.Int, "actual_index", actual_index)
        end
        slot_index = slot_index + 1
    end)
end

function RecyclePageView:next_page()
    ---@type integer
    local page = self.recycle_container.custom_data.page or 1
    self:set_page(page + 1)
end

function RecyclePageView:last_page()
    ---@type integer
    local page = self.recycle_container.custom_data.page or 1
    self:set_page(page - 1)
end

---@param slot_index integer
function RecyclePageView:swap_item(slot_index)
    local custom_data = self.recycle_container.custom_data
    local role = UIManager.client_role --[[@as Role]]
    local unit = role.get_ctrl_unit()
    local item = unit.get_equipment_by_slot(Enums.EquipmentSlotType.BACKPACK, slot_index)
    if not item then
        return
    end
    local actual_index = item.get_kv_by_type(Enums.ValueType.Int, "actual_index")
    local insert_index = nil --[[@as integer?]]
    for i = unit_page_count + 1, unit_page_count + 8 do
        local check_item = unit.get_equipment_by_slot(Enums.EquipmentSlotType.BACKPACK, i)
        if not check_item then
            insert_index = i
            break
        end
    end
    if insert_index then
        custom_data.record_indices = custom_data.record_indices or {}
        custom_data.record_indices[actual_index] = true
        item.move_to_slot(Enums.EquipmentSlotType.BACKPACK, insert_index)
        self:show_price()
        self:set_page(custom_data.page or 1)
    else
        role.show_tips("预售格满了，请先出售吧！")
    end
end

function RecyclePageView:show_price()
    local role = UIManager.client_role --[[@as Role]]
    local unit = role.get_ctrl_unit()
    local player = PlayerManager.find_player_by_role(role)
    local inventory = player.inventory
    local count = 0
    local value = 0
    for i = unit_page_count + 1, unit_page_count + 8 do
        local check_item = unit.get_equipment_by_slot(Enums.EquipmentSlotType.BACKPACK, i) --[[@as Equipment?]]
        if check_item then
            count = count + 1
            local actual_index = check_item.get_kv_by_type(Enums.ValueType.Int, "actual_index")
            local item_code = inventory.items[actual_index] --[[@as Item]].code
            local item_config = ItemConfig[item_code]
            value = value + item_config.value or 0
        end
    end
    self.pre_recycle_info.text = ("共计 %d 个物品，价值：%d"):format(count, value)
    MainView:update_coin(value)
end

function RecyclePageView:sell()
    local role = UIManager.client_role --[[@as Role]]
    local unit = role.get_ctrl_unit()
    local player = PlayerManager.find_player_by_role(role)
    local inventory = player.inventory
    local count = 0
    local value = 0
    local remove_list = {}
    local custom_data = self.recycle_container.custom_data
    for i = unit_page_count + 1, unit_page_count + 8 do
        local check_item = unit.get_equipment_by_slot(Enums.EquipmentSlotType.BACKPACK, i) --[[@as Equipment?]]
        if check_item then
            count = count + 1
            local actual_index = check_item.get_kv_by_type(Enums.ValueType.Int, "actual_index")
            local item_code = inventory.items[actual_index] --[[@as Item]].code
            local item_config = ItemConfig[item_code]
            table.insert(remove_list, actual_index)
            check_item.destroy_equipment()
            value = value + item_config.value or 0
        end
    end
    self.pre_recycle_info.text = ""
    if count == 0 then
        role.show_tips("请选择需要出售的物品", 2.0)
        return
    end
    Utils.remove_indices(inventory.items, remove_list)
    local vault = player.vault
    vault:deposit("coin", value)
    player.show_tips("出售成功！", 2.0)
    MainView:update_coin(0)
    player:save_data()
    RecyclePageView:set_page(custom_data.page or 1)
end

RecyclePageView = RecyclePageView:new()

return RecyclePageView
