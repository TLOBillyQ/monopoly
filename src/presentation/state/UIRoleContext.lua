local logger = require("src.core.Logger")
local role_id_utils = require("src.core.RoleId")

local role_context = {}

local warned_unmapped_role_ids = {}

function role_context.resolve(role, ui_model, deps)
  local runtime = deps and deps.runtime or nil
  assert(runtime ~= nil and runtime.resolve_role_id ~= nil, "missing runtime.resolve_role_id")
  local current_player_id = role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
  local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
  local by_player = ui_model and (ui_model.item_slots_by_player_id or ui_model.item_slots_by_player) or nil
  local mapped = role_id ~= nil and role_id_utils.read(by_player, role_id) ~= nil

  if role_id == nil and role == nil then
    return {
      role_id = nil,
      display_player_id = current_player_id,
      can_operate = true,
      is_player_role = true,
    }
  end

  if mapped then
    return {
      role_id = role_id,
      display_player_id = role_id,
      can_operate = role_id_utils.equals(role_id, current_player_id),
      is_player_role = true,
    }
  end

  if role_id ~= nil and not warned_unmapped_role_ids[role_id] then
    warned_unmapped_role_ids[role_id] = true
    logger.warn(
      "role->player 映射失败，按观战回退:",
      "role_id=" .. tostring(role_id),
      "current_player_id=" .. tostring(current_player_id)
    )
  end

  return {
    role_id = role_id,
    display_player_id = current_player_id,
    can_operate = false,
    is_player_role = false,
  }
end

return role_context
