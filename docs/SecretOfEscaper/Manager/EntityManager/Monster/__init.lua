local MonsterAIList = {}

---@class Monster : AIComp
---@field ctrl_unit LifeEntity
---@field origin_position Vector3 初始位置
---@field origin_direction Vector3 初始朝向
---@field handlers table<string?, (table | integer)?> 行为处理器
---@field behavior_tree BehaviorTree 行为树
local AIComp = require 'Manager.EntityManager.AIComp'
local Monster = Class("MonsterAI", AIComp)

---@param unit LifeEntity
function Monster:init(unit)
    AIComp.init(self, unit)
    MonsterAIList[unit.get_id()] = self
    local blackboard = self.behavior_tree:get_blackboard()
    blackboard:set("entity", self)
end

return Monster