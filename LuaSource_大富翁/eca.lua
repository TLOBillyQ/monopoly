---@export
---@desc 获取进入载具的玩家
---@return Role
function get_enter_vehicle_player()
    return GameAPI.get_role(1)
end

---@export
---@desc 获取刷载具的ID
---@return integer
function get_spawn_vehicle_id()
    return 4002
end

---@export
---@desc 被转发的界面事件
---@return string
function get_forward_ui_event()
    return UIManager.EcaEvent or ""
end

UIManager.ForwardUIEvent = function(event)
    UIManager.EcaEvent = event
    LuaAPI.global_send_custom_event(FORWAR_UI_EVENT, {})
end
