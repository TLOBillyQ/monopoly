local choice_kind_aliases = {}

local canonical_by_kind = {
  land_optional_effect = "landing_optional_effect",
  landing_optional_effect = "landing_optional_effect",
}

function choice_kind_aliases.to_canonical(choice_kind)
  if choice_kind == nil then
    return nil
  end
  return canonical_by_kind[choice_kind] or choice_kind
end

function choice_kind_aliases.is_alias(choice_kind)
  if choice_kind == nil then
    return false
  end
  return canonical_by_kind[choice_kind] ~= nil and canonical_by_kind[choice_kind] ~= choice_kind
end

return choice_kind_aliases
