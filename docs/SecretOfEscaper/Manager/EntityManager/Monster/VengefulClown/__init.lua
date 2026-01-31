local VengefulClownList = {}
local Monster = require 'Manager.EntityManager.Monster.__init'
---@class VengefulClown : Monster
---@field ctrl_unit LifeEntity
---@field new fun(self: VengefulClown, unit: LifeEntity): VengefulClown
local VengefulClown = Class("VengefulClown", Monster)

---@param unit LifeEntity
function VengefulClown:init(unit)
    self.behavior_tree = Behavior.build_tree(require 'Config.EntityBehaviorTree.Monster.VengefulClown')
    Monster.init(self, unit)
    VengefulClownList[unit.get_id()] = self
    self.ctrl_unit.add_ability_to_slot(2, 1073799230) ---开车
    self.ctrl_unit.add_ability_to_slot(1, 1073803342) ---抽刀
    local blackboard = self.behavior_tree:get_blackboard()
    blackboard:set("entity", self)
    self.attack_area = unit.get_child_by_name("判定区域")
    self:init_attack_area()
    self:init_interface()
    x = self
end

function VengefulClown:init_attack_area()
    local blackboard = self.behavior_tree:get_blackboard()
    ---@param data { event_unit: LifeEntity }
    LuaAPI.global_register_trigger_event(
        {
            EVENT.ANY_LIFEENTITY_TRIGGER_SPACE,
            Enums.TriggerSpaceEventType.ENTER,
            self.attack_area.get_id()
        },
        function(_, _, data)
            local ability = self.ctrl_unit.get_ability_by_slot(1)
            if not ability.is_in_cd() and not blackboard:get("BanInterrupt") then
                LuaAPI.global_send_custom_event("进入小丑普攻范围", {})
            end
        end
    )
end

function VengefulClown:init_interface()
    local ability = self.ctrl_unit.add_ability_to_slot(3, 1073754128)
    LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CAST_BEGIN }, function()
        self:stop_behavior()
    end)
    LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CD_END }, function()
        self:start_behavior()
    end)
end

return VengefulClown
