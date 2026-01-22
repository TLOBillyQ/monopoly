local Class = require "ChooseOption.Utils"

---@class UICard
---@field label EImage
---@field label_text ELabel
---@field icon EImage
---@field icon_label EImage
---@field icon_label_text ELabel
---@field title ELabel
---@field description ELabel
---@field layout EImage
---@field card EImage
---@field display? fun(role: Role)
---@field reward fun(role: Role)

---@namespace ChooseOption
---@class Container : ClassUtil
---@field private container ENode
---@field private background EImage
---@field private title ELabel
---@field private description ELabel
---@field private card_dict table<ENode, UICard>
---@field private card_dict_name_list ENode[]
---@overload fun(config: Config): Container
local Container = Class("ChooseOption.Container")

---@param node ENode
local function disable_touch(node)
    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        role.set_node_touch_enabled(node, false)
    end
end

---@private
---@param config Config
function Container:init(config)
    self.card_dict_name_list = {}
    self.container = config.container
    self:init_nodes()
    self:register_handler(config)
    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        self:hide(role)
    end
end

---@private
function Container:init_nodes()
    local card_dict = {}

    local node = self.container
    self.background = GameAPI.get_eui_child_by_index(node, 0)
    self.title = GameAPI.get_eui_child_by_index(node, 1)
    self.description = GameAPI.get_eui_child_by_index(node, 2)
    disable_touch(self.background)
    disable_touch(self.title)
    disable_touch(self.description)

    self.card_dict = card_dict
    for i = 1, 3 do
        local child = GameAPI.get_eui_child_by_index(node, 2 + i)

        local name = ("1519736575|%s"):format(child)
        self.card_dict_name_list[i] = name
        ---@type UICard
        card_dict[name] = {} --[[@as UICard]]
        local ui_card = card_dict[name] --[[@as UICard]]

        ui_card.label = GameAPI.get_eui_child_by_index(child, 0)
        ui_card.label_text = GameAPI.get_eui_child_by_index(ui_card.label, 0)

        ui_card.icon = GameAPI.get_eui_child_by_index(child, 1)
        ui_card.icon_label = GameAPI.get_eui_child_by_index(ui_card.icon, 0)
        ui_card.icon_label_text = GameAPI.get_eui_child_by_index(ui_card.icon_label, 0)

        ui_card.title = GameAPI.get_eui_child_by_index(child, 2)

        ui_card.description = GameAPI.get_eui_child_by_index(child, 3)

        ui_card.layout = GameAPI.get_eui_child_by_index(child, 4)


        for n, key in pairs(ui_card) do
            if n ~= "layout" then
                disable_touch(key --[[@as ENode]])
            end
        end

        ui_card.reward = function(role) end
        ui_card.card = child
    end
end

---@private
---@param config Config
function Container:register_handler(config)
    ---@param data {eui_node_id: ENode, role: Role}
    LuaAPI.global_register_custom_event(config.confirm_event, function(_, _, data)
        local role = data.role

        if not role.has_kv("ChooseOption:card_name") then
            return
        end
        local card_name = role.get_kv_by_type("Str", "ChooseOption:card_name")
        local ui_card = self.card_dict[card_name]
        ui_card.reward(role)
        self:hide(role)
    end)

    ---@param data {eui_node_id: ENode, role: Role}
    LuaAPI.global_register_custom_event(config.choose_event, function(_, _, data)
        local role = data.role
        local event_node = data.eui_node_id

        local target = self.card_dict[event_node]
        if not target then
            return
        end
        for _, card in pairs(self.card_dict) do
            role.set_node_visible(card.layout, false)
        end
        role.set_node_visible(target.layout, true)
        role.set_kv_by_type("Str", "ChooseOption:card_name", event_node)
    end)
end

---显示三选一
---@param role Role
function Container:show(role)
    role.set_node_visible(self.container, true)
    for _, ui_card in pairs(self.card_dict) do
        if ui_card.display then
            ui_card.display(role)
        else
            role.set_node_visible(ui_card.card, false)
        end
    end
end

---隐藏三选一
---@param role Role
function Container:hide(role)
    role.set_node_visible(self.container, false)
end

---@alias CardIndex 1 | 2 | 3

---设置奖励函数
---@param index CardIndex 卡牌索引
---@param _callback fun(role: Role) 奖励函数
function Container:set_reward(index, _callback)
    local card_name = self.card_dict_name_list[index] --[[@as ENode]]
    local ui_card = self.card_dict[card_name]
    ui_card.reward = _callback
end

---UI样式
---@param index CardIndex 卡牌索引
---@param card_config? CardConfig UI配置
function Container:set_display(index, card_config)
    local card_name = self.card_dict_name_list[index] --[[@as ENode]]
    local ui_card = self.card_dict[card_name]
    local background_mapping = { 31008, 31009, 31010 }
    local label_mapping = { 11133, 11134, 11135 }
    if not card_config then
        ui_card.display = nil
        return
    end
    ---@param role Role
    ui_card.display = function(role)
        ---卡牌标签
        if card_config.label then
            role.set_label_text(ui_card.label_text, card_config.label)
        else
            role.set_node_visible(ui_card.label, false)
        end
        ---图标描述
        if card_config.icon_description then
            role.set_label_text(ui_card.icon_label_text, card_config.icon_description)
        else
            role.set_node_visible(ui_card.icon_label, false)
        end
        ---图标
        role.set_image_texture_by_key_with_auto_resize(ui_card.icon, card_config.icon, false)
        ---标题
        role.set_label_text(ui_card.title, card_config.title)
        ---描述
        role.set_label_text(ui_card.description, card_config.description)

        local background = background_mapping[ card_config.level --[[@as integer]] ]
        if background then
            role.set_image_texture_by_key_with_auto_resize(ui_card.card, background, false)
        end
        local label = label_mapping[ card_config.level --[[@as integer]] ]
        if label then
            role.set_image_texture_by_key_with_auto_resize(ui_card.label, label, false)
        end
    end
end

return Container
