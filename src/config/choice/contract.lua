local number_utils = require("src.foundation.number")

local choice_contract = {}

local function _resolve_role_id_field(choice, field_key)
  if type(choice) ~= "table" then
    return nil
  end
  return number_utils.to_integer(choice[field_key])
end

-- Handler-specific payload like phase, queue, effect_ids, and move_result stays in meta.
choice_contract.explicit_fields = {
  "route_key",
  "requires_confirm",
  "pre_confirm_on_select",
  "owner_role_id",
  "confirm_title",
  "confirm_body",
  "uses_item_slots",
  "pre_confirm_before_slot_pick",
  "target_slot_layout",
  "active_tab",
  "page_index",
  "page_count",
}

function choice_contract.copy_explicit_fields(source, target)
  assert(type(target) == "table", "missing target")
  if type(source) ~= "table" then
    return target
  end
  for _, key in ipairs(choice_contract.explicit_fields) do
    target[key] = source[key]
  end
  return target
end

function choice_contract.resolve_owner_role_id(choice)
  return _resolve_role_id_field(choice, "owner_role_id")
end

local function _resolve_meta_player_role_id(choice)
  local meta = type(choice) == "table" and choice.meta or nil
  if type(meta) ~= "table" then
    return nil
  end
  return number_utils.to_integer(meta.player_id)
end

function choice_contract.resolve_owner_or_meta_role_id(choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return _resolve_meta_player_role_id(choice)
end

return choice_contract

--[[ mutate4lua-manifest
version=4
projectHash=7272d92c9c45a717
scope.0.id=chunk:src/config/choice/contract.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=92ddad80335d0387
scope.1.id=function:_resolve_role_id_field
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=6dfbdf7b4f6283eb
scope.2.id=function:choice_contract.copy_explicit_fields
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=37
scope.2.semanticHash=4eae71446a3971fb
scope.3.id=function:choice_contract.resolve_owner_role_id
scope.3.kind=function
scope.3.startLine=39
scope.3.endLine=41
scope.3.semanticHash=a9c1c4b362850cf7
scope.4.id=function:_resolve_meta_player_role_id
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=49
scope.4.semanticHash=e6c564ee9d18c538
scope.5.id=function:choice_contract.resolve_owner_or_meta_role_id
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=57
scope.5.semanticHash=c4b6c83ac8f7bb13
]]
