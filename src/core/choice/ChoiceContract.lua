local number_utils = require("src.core.utils.NumberUtils")

local choice_contract = {}

choice_contract.explicit_fields = {
  "route_key",
  "requires_confirm",
  "owner_role_id",
  "confirm_title",
  "confirm_body",
  "uses_item_slots",
  "pre_confirm_before_slot_pick",
  "uses_target_picker",
  "target_picker_owner_role_id",
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
  return choice and number_utils.to_integer(choice.owner_role_id) or nil
end

function choice_contract.resolve_target_picker_owner_role_id(choice)
  local owner_role_id = choice and number_utils.to_integer(choice.target_picker_owner_role_id) or nil
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return choice_contract.resolve_owner_role_id(choice)
end

function choice_contract.uses_target_picker(choice)
  return choice ~= nil and choice.uses_target_picker == true
end

return choice_contract
