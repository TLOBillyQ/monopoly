local ItemConfig = require "Config.ItemConfig"

---@class LootChestManager
---@field position_unit_list Unit[]
---@field chest_list LootChest[]
---@field decoded_chest_list table<UnitID, LootChest>
---@field last_decoded_index integer
---@field ui_progress_group UIManager.EImage
---@field ui_tipper UIManager.ELabel
---@field new fun(self: LootChestManager, config: LootChestManagerConfig): LootChestManager
local LootChestManager = Class("LootChestManager")
local LootChest = require "Manager.ModeManager.LootEscaper.LootChest"

---@alias ChestConfig {
---     experience: integer,
---     color: integer,
---     max_progress: integer,
---     rewards: {
---         weight: integer,
---         code: ItemCode
---     }[],
---     used: Unit[]
--- }

---@alias LootChestManagerConfig {
---     position_unit_list: Unit[],
---     chest: ChestConfig[]
--- }

---@param config LootChestManagerConfig
function LootChestManager:init(config)
    self.config = config
    self.position_unit_list = Utils.choice_list(config.position_unit_list, 12, false)
    local ui_explore_canvas = UIManager.get_first_node_by_name("ExploreCanvas") --[[@as UIManager.EImage]]
    self.ui_explore_canvas = ui_explore_canvas
    self.ui_progress_group = ui_explore_canvas:get_first_node_by_name_dfs("ProgressGroup")
    self.ui_tipper = ui_explore_canvas:get_first_node_by_name_dfs("Tipper") --[[@as UIManager.ELabel]]
    self.ui_tipper.text = "宝箱挖掘进度"
    self.ui_tipper.text_color = 0xffffff
    self.last_decoded_index = 1
    self.decoded_chest_list = {}
    self:init_chest()
    self:init_ui()
end

function LootChestManager:init_ui()
    self.ui_progress_group.children--[[@as ArrayReadOnly<UIManager.EImage>]]:forEach(function(ui_chest)
        local temp = UIManager.client_role
        UIManager.client_role = nil
        ui_chest.image_color = 0x000000
        UIManager.client_role = temp
    end)
end

function LootChestManager:init_chest()
    for _, position_unit in ipairs(self.config.position_unit_list) do
        local top = position_unit.get_child_by_name("盖子")
        local box = position_unit.get_child_by_name("箱体")
        top.set_model_visible(false)
        box.set_model_visible(false)
        top.set_physics_active(false)
        box.set_physics_active(false)
    end
    local chest_config_list = self.config.chest
    self.chest_list = {}
    for _, chest_config in ipairs(chest_config_list) do
        local used = chest_config.used
        for _, chest in ipairs(used) do
            local loot_chest = LootChest:new(chest, chest_config)
            table.insert(self.chest_list, loot_chest)
        end
    end

    for idx, loot_chest in ipairs(self.chest_list) do
        local position_unit = self.position_unit_list[idx] --[[@as Unit]]
        local position_parent = position_unit.get_parent()
        local world_position = position_parent.get_position() + position_unit.get_position() + math.Vector3(0, 0.2, 0)
        loot_chest.world_position = world_position
        loot_chest.world_orientation = position_parent.get_orientation()
    end
end

---@param chest LootChest
function LootChestManager:complete_decode(chest)
    local chest_id = chest.body.get_id()
    if not self.decoded_chest_list[chest_id] then
        self.decoded_chest_list[chest_id] = chest
        local children = self.ui_progress_group.children
        local end_index = math.min(children.length, self.last_decoded_index + chest.config.experience - 1)
        for i = self.last_decoded_index, end_index do
            local ui_chest = children[i] --[[@as UIManager.EImage]]
            local temp = UIManager.client_role
            UIManager.client_role = nil
            ui_chest.image_color = chest.config.color
            UIManager.client_role = temp
        end
        self.last_decoded_index = end_index + 1
        if self.last_decoded_index > children.length then
            self:complete_target()
        end
    end
end

function LootChestManager:complete_target()
    for _, chest in ipairs(self.chest_list) do
        chest:destroy()
    end
    self.ui_tipper.text = "挖掘完成，前往开启逃生门！"
    self.ui_tipper.text_color = 0xff8800
    for _, role in ipairs(ALLROLES) do
        role.play_2d_sound_with_params(6325, 3.0, 50.0, 1.0)
    end
    LootEscaper.could_leave = true
end

return LootChestManager
