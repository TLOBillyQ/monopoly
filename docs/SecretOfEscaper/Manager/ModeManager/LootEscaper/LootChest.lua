local ItemConfig = require "Config.ItemConfig"

---@class LootChest
---@field body UnitGroup
---@field config ChestConfig
---@field space UnitGroup
---@field box UnitGroup
---@field top UnitGroup
---@field world_position Vector3
---@field world_orientation Quaternion
---@field decode_list table<RoleID, {player: Player, handler: Frameout, interface: integer}>
---@field decode_progress integer
---@field decoded boolean
---@field handlers table<RoleID, {ability: Ability, handler: integer}>
---@field new fun(self: LootChest, unit: UnitGroup, config: ChestConfig): LootChest
local LootChest = Class("LootChest")

---@param unit UnitGroup
---@param config ChestConfig
function LootChest:init(unit, config)
    self.body = unit
    self.config = config
    self.space = unit.get_child_by_name("区域")
    self.box = unit.get_child_by_name("箱体")
    self.top = unit.get_child_by_name("盖子")
    self.decode_list = {}
    self.decoded = false
    self.decode_progress = 0
    self.handlers = {}
    self:init_space()
end

function LootChest:__get_world_position()
    local parent = self.body.get_parent()
    local position = self.body.get_position()
    local result_position = parent.get_position() + position
    return result_position
end

function LootChest:__set_world_position(position)
    local parent = self.body.get_parent()
    local relative_position = position - parent.get_position()
    self.body.set_position(relative_position)
end

function LootChest:__get_world_orientation()
    return self.body.get_orientation()
end

function LootChest:__set_world_orientation(orientation)
    self.body.set_orientation(orientation)
end

function LootChest:init_space()
    ---@param data { event_unit: Character }
    LuaAPI.global_register_trigger_event(
        { EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, Enums.TriggerSpaceEventType.ENTER, self.space.get_id() },
        function(_, _, data)
            local player = PlayerManager.find_player_by_role(data.event_unit.get_ctrl_role())
            self:enter_space(player)
        end
    )

    ---@param data { event_unit: Character }
    LuaAPI.global_register_trigger_event(
        { EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, Enums.TriggerSpaceEventType.LEAVE, self.space.get_id() },
        function(_, _, data)
            local player = PlayerManager.find_player_by_role(data.event_unit.get_ctrl_role())
            self:leave_space(player)
        end
    )
end

---@param player Player
function LootChest:enter_space(player)
    local unit = player.get_ctrl_unit()
    local ability = unit.add_ability_to_slot(2, 1073807466)

    local handler = LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CAST_BEGIN }, function(_, _, data)
        self:start_decode(player)
    end)
    self.handlers[player.get_roleid()] = { ability = ability, handler = handler }
end

---@param player Player
function LootChest:leave_space(player)
    local unit = player.get_ctrl_unit()
    local handler = self.handlers[player.get_roleid()]
    if handler then
        LuaAPI.unit_unregister_trigger_event(handler.ability, handler.handler)
    end
    unit.remove_ability_by_key(1073807466)
    unit.stop_play_body_anim_by_id(1)

    local task = self.decode_list[player.get_roleid()] --[[@as {player: Player, handler: Frameout}?]]
    local progress_bar = UIManager.get_first_node_by_name("ProgressBar") --[[@as UIManager.EProgressbar]]
    local temp = UIManager.client_role
    UIManager.client_role = player.role
    progress_bar.visible = false
    UIManager.client_role = temp
    if task then
        local frameout = task.handler
        frameout.destroy()
        self.decode_list[player.get_roleid()] = nil
    end
end

---@param player Player
function LootChest:start_decode(player)
    if not self.decode_list[player.get_roleid()] and not self.decoded then
        player.get_ctrl_unit().play_body_anim_by_id(1, 0.0, -1.0, true)
        local unit = player.get_ctrl_unit()
        self.decode_list[player.get_roleid()] = {
            player = player,
            interface = LuaAPI.unit_register_custom_event(unit, "增加宝箱进度", function()
                local value = unit.get_kv_by_type(Enums.ValueType.Int, "improve_value")
                self:increase_progress(value)
                unit.add_tag("improve_value_success")
            end),
            handler = SetFrameOut(1, function(frameout)
                self:increase_progress()
            end, -1, true)
        }
    end
end

---@param value? integer
function LootChest:increase_progress(value)
    value = value or 1
    if self.decoded then
        return
    end
    self.decode_progress = self.decode_progress + value
    local progress_bar = UIManager.get_first_node_by_name("ProgressBar") --[[@as UIManager.EProgressbar]]
    for _, task in pairs(self.decode_list) do
        local player = task.player
        local temp = UIManager.client_role
        UIManager.client_role = player.role
        progress_bar.max_value = self.config.max_progress
        progress_bar.value = self.decode_progress
        progress_bar.visible = true
        UIManager.client_role = temp
    end
    if self.decode_progress >= self.config.max_progress then
        self:decode()
    end
end

function LootChest:decode()
    if self.decoded then
        return
    end
    self.decoded = true
    for _, task in pairs(self.decode_list) do
        local player = task.player
        self:leave_space(player)
        local frameout = task.handler
        frameout.destroy()
        local interface = task.interface
        LuaAPI.unit_unregister_custom_event(player.get_ctrl_unit(), interface)
    end
    GameAPI.destroy_unit(self.space)
    GameAPI.destroy_unit(self.top)
    self:generate_items()
    LootEscaper.LootChestManager:complete_decode(self)
end

function LootChest:generate_items()
    local item_source_configs = Utils.choice_weight_list(self.config.rewards, GameAPI.random_int(1, 2), function(e)
        return e.weight
    end, true)
    for _, item_source in ipairs(item_source_configs) do
        local code = item_source.code
        local item_config = ItemConfig[code]
        local position = self.world_position + math.Vector3(0, 1.0, 0)
        local item = GameAPI.create_equipment(item_config.id, position)
        ---@param data {owner: Character}
        LuaAPI.unit_register_trigger_event(item, { EVENT.SPEC_EQUIPMENT_OBTAIN }, function(_, _, data)
            local unit = data.owner
            local role = data.owner.get_ctrl_role()
            local player = PlayerManager.find_player_by_role(role)
            local item_count = #player.inventory.items
            local pre_item_count = item_count + #unit.get_equipment_list_by_slot_type(Enums.EquipmentSlotType.BACKPACK)
            if pre_item_count >= 99 then
                item.set_droppable(true)
                item.drop()
                role.show_tips("大厅背包已满，无法拾取。", 2.0)
            else
                item.set_kv_by_type(Enums.ValueType.Str, "code", code)
            end
        end)
    end
end

function LootChest:destroy()
    self.decoded = true
    for _, task in pairs(self.decode_list) do
        local player = task.player
        self:leave_space(player)
        local frameout = task.handler
        frameout.destroy()
    end
    GameAPI.destroy_unit(self.space)
end

return LootChest
