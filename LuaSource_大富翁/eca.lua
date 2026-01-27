---@export
---@desc 获取进入载具的玩家
---@return Role
function get_enter_vehicle_player()
    return GameAPI.get_role(1)
end

local refs = require "refs"

local vehicle_name_by_id = nil
do
    local ok, vehicles_cfg = pcall(require, "src.config.vehicles")
    if ok and vehicles_cfg then
        vehicle_name_by_id = {}
        for _, cfg in ipairs(vehicles_cfg) do
            vehicle_name_by_id[cfg.id] = cfg.name
        end
    end
end

local function resolve_vehicle_spawn_id(vehicle_id)
    if not vehicle_id then
        return nil
    end
    local ref_id = refs[vehicle_id] or refs[tostring(vehicle_id)]
    if ref_id then
        return ref_id
    end
    if vehicle_name_by_id then
        local name = vehicle_name_by_id[vehicle_id]
        if name then
            ref_id = refs[name]
        end
    end
    return ref_id or vehicle_id
end

---@export
---@desc 获取刷载具的ID
---@return integer
function get_spawn_vehicle_id()
    local vehicle_id = UIManager.EcaVehicleId or 4002
    return resolve_vehicle_spawn_id(vehicle_id)
end

---@export
---@desc 被转发的界面事件
---@return string
function get_forward_ui_event()
    return UIManager.EcaEvent or ""
end

UIManager.ForwardVehicleEvent = function(vehicle_id)
    UIManager.EcaVehicleId = vehicle_id
    LuaAPI.global_send_custom_event("玩家上载具", {})
end

UIManager.ForwardUIEvent = function(event)
    UIManager.EcaEvent = event
    LuaAPI.global_send_custom_event(FORWAR_UI_EVENT, {})
end
