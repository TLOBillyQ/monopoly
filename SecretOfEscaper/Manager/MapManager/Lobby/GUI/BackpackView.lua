---@class Lobby.BackpackView
---@field info_frame UIManager.EImage
---@field info_frame_name UIManager.ELabel
---@field info_frame_description UIManager.ELabel
---@field show_button UIManager.EImage
---@field general_coin_info UIManager.EImage
---@field general_coin_amount UIManager.ELabel
---@field hide_button UIManager.EImage
---@field equip_button UIManager.EImage
---@field tag_bar ArrayReadOnly<UIManager.EImage>
---@field new fun(self: Lobby.BackpackView): Lobby.BackpackView
local BackpackView = Class("Lobby.BackpackView")
local MainView = require 'Manager.MapManager.Lobby.GUI.MainView'

function BackpackView:init()
    local canvas = UIManager.query_nodes_by_name("BackpackCanvas")[1] --[[@as UIManager.EImage]]
    self.canvas = canvas
    self.hide_button = canvas:get_first_node_by_name_dfs("CloseButton") --[[@as UIManager.EImage]]
    self.show_button = MainView.lobby_canvas:get_first_node_by_name_dfs("BackpackButton") --[[@as UIManager.EImage]]
    self.info_frame = canvas:get_first_node_by_name_dfs("InfoFrame") --[[@as UIManager.EImage]]
    self.info_frame_name = self.info_frame:get_first_node_by_name("Name")
    self.info_frame_description = self.info_frame:get_first_node_by_name("Description")
    self.equip_button = self.info_frame:get_first_node_by_name("EquipButton")
    self.tag_bar = canvas:get_first_node_by_name_dfs("TagBar") --[[@as UIManager.EImage]].children
    local general_coin_info = canvas:get_first_node_by_name_dfs("GeneralCoinInfo") --[[@as UIManager.EImage]]
    self.general_coin_info = general_coin_info
    self.general_coin_amount = general_coin_info:get_first_node_by_name("Amount")
end

---@enum Lobby.Backpackview.Tag
local Tag = {
    All = "全部",
    Recycle = "回收物",
    Equip = "特殊道具"
}


---@param tag Lobby.Backpackview.Tag
function BackpackView:show(tag)
    local role = UIManager.client_role --[[@as Role]]
    role.get_ctrl_unit().clear_selected_equipment_slot()
    local player = PlayerManager.find_player_by_role(role)
    local e = nil --[[@as UIManager.EImage?]]
    self.tag_bar:forEach(function(tag_ele)
        local other_text = tag_ele:get_first_node_by_name("Text") --[[@as UIManager.ELabel]]
        other_text.text_color = 0xffffff
        if Tag[tag_ele.name] == tag then
            e = tag_ele
        end
    end)
    if e then
        local text = e:get_first_node_by_name("Text") --[[@as UIManager.ELabel]]
        text.text_color = 0xff8800
    end
    self.canvas.custom_data.current_tag = tag
    if tag == Tag.All then
        player.inventory:show(player, Enums.EquipmentSlotType.BACKPACK)
        player.equipment:show(player, Enums.EquipmentSlotType.EQUIPPED)
    else
        player.inventory:show(player, Enums.EquipmentSlotType.BACKPACK, function(item, config)
            return config.tag == tag
        end)
        player.equipment:show(player, Enums.EquipmentSlotType.EQUIPPED)
    end
    self:update_coin(0)
end

function BackpackView:hide()
    self.canvas.visible = false
end

---@param amount integer
function BackpackView:update_coin(amount)
    local role = UIManager.client_role --[[@as Role]]
    local player = PlayerManager.find_player_by_role(role)
    local vault = player.vault
    vault:update_render(role, "coin", amount, self.general_coin_amount)
end

BackpackView = BackpackView:new()

return BackpackView
