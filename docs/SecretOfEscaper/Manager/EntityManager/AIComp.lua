---@class AIComp : LifeEntity, Class
---@field ctrl_unit LifeEntity
---@field origin_position Vector3 初始位置
---@field origin_direction Vector3 初始朝向
---@field handlers table<string?, (table | integer)?> 行为处理器
---@field behavior_tree BehaviorTree 行为树
---@field behavior_handler Frameout
local AIComp = Class("AIComp")

---元方法 - 元索引
function AIComp.__custom_index(tbl, key)
local ctrl_unit = rawget(tbl, "ctrl_unit")
    if ctrl_unit and (type(ctrl_unit[key]) == "function") then
        return function(...)
            return ctrl_unit[key](...)
        end
    end
end

---@param unit LifeEntity
function AIComp:init(unit)
    self.origin_position = unit.get_position()   -- 初始位置
    self.origin_direction = unit.get_direction() -- 初始朝向
    self.ctrl_unit = unit
    self.behavior_handler = SetFrameOut(1, function()
        local blackboard = self.behavior_tree:get_blackboard()
        blackboard:set("tick", self.behavior_handler)
        self.behavior_tree:tick()
    end, -1)
end

function AIComp:start_behavior()
    self.behavior_handler.resume()
end

function AIComp:stop_behavior()
    self.behavior_handler.pause()
end

return AIComp