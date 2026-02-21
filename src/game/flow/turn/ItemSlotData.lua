local number_utils = require("src.core.NumberUtils")

local item_slot_data = {}

local function _resolve_slot_index(slot_index_or_id)
  if number_utils.is_numeric(slot_index_or_id) then
    return number_utils.to_integer(slot_index_or_id)
  end
  if type(slot_index_or_id) ~= "string" then
    return nil
  end
  local slot_index = string.match(slot_index_or_id, "^item_slot_(%d+)$")
  if not slot_index then
    return nil
  end
  return number_utils.to_integer(slot_index)
end

function item_slot_data.from_ui_state(ui_state)
  local state = type(ui_state) == "table" and ui_state or nil
  return {
    get_item_ids = function(actor_role_id)
      if not state then
        return nil
      end
      if actor_role_id and type(state.item_slot_item_ids_by_role) == "table" then
        local item_ids = state.item_slot_item_ids_by_role[actor_role_id]
        if item_ids then
          return item_ids
        end
      end
      return state.item_slot_item_ids
    end,
    resolve_slot_action = function(actor_role_id, slot_index_or_id)
      local slot_index = _resolve_slot_index(slot_index_or_id)
      if not slot_index then
        return nil
      end
      local item_ids = nil
      if actor_role_id and type(state and state.item_slot_item_ids_by_role) == "table" then
        item_ids = state.item_slot_item_ids_by_role[actor_role_id]
      end
      if not item_ids then
        item_ids = state and state.item_slot_item_ids or nil
      end
      if not item_ids then
        return nil
      end
      return item_ids[slot_index]
    end,
  }
end

return item_slot_data
