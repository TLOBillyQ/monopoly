local number_utils = require("src.foundation.number")

local item_slot_utils = {}

function item_slot_utils.resolve_slot_index(slot_index_or_id)
  if number_utils.is_numeric(slot_index_or_id) then
    return number_utils.to_integer(slot_index_or_id)
  end
  if type(slot_index_or_id) ~= "string" then
    return nil
  end
  local matched = string.match(slot_index_or_id, "^item_slot_(%d+)$")
  if matched == nil then
    return nil
  end
  return number_utils.to_integer(matched)
end

return item_slot_utils

--[[ mutate4lua-manifest
version=4
projectHash=e89fd1fc3fdef222
scope.0.id=chunk:src/turn/actions/item_slot_utils.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=20
scope.0.semanticHash=e906b6b5a7237689
scope.1.id=function:item_slot_utils.resolve_slot_index
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=17
scope.1.semanticHash=7d213389d553f356
]]
