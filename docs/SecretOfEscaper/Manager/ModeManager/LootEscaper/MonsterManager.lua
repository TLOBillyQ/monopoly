---@class MonsterManager
---@field monster Monster
local MonsterManager = {}

---@param role Role
MonsterManager.watch = function(role)
    MonsterManager.watch_frameout = SetFrameOut(1, function()
        local monster = MonsterManager.monster
        if monster then
            role.set_camera_lock_position(monster.get_position() + math.Vector3(0, 2.0, 0))
            role.set_camera_rotation_by_direction(monster.get_direction(), 1.0)
        end
    end, -1, true)
end

return MonsterManager