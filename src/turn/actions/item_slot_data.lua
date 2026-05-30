local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")

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

  local function _resolve_item_ids(actor_role_id)
    if state and actor_role_id and type(state.item_slot_item_ids_by_role) == "table" then
      local ids = role_id_utils.read(state.item_slot_item_ids_by_role, actor_role_id)
      if ids then return ids end
    end
    return state and state.item_slot_item_ids or nil
  end

  return {
    get_item_ids = _resolve_item_ids,
    resolve_slot_action = function(actor_role_id, slot_index_or_id)
      local slot_index = _resolve_slot_index(slot_index_or_id)
      if not slot_index then
        return nil
      end
      local item_ids = _resolve_item_ids(actor_role_id)
      if not item_ids then
        return nil
      end
      return item_ids[slot_index]
    end,
  }
end

return item_slot_data

--[[ mutate4lua-manifest
version=2
projectHash=e40824dccc6a526f
scope.0.id=chunk:src/turn/actions/item_slot_data.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=61333621346ef409
scope.1.id=function:_resolve_slot_index:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=18
scope.1.semanticHash=ba87eec48046df8c
scope.2.id=function:_resolve_item_ids:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=ec43a6052c4bed4c
scope.3.id=function:anonymous@33:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=43
scope.3.semanticHash=d7a58fdc3ddd317f
scope.4.id=function:item_slot_data.from_ui_state:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=45
scope.4.semanticHash=bc1f66286ff1bded
]]
