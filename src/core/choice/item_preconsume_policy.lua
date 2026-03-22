local item_preconsume_policy = {}

local function _is_cancel_action(action)
  return action ~= nil and action.type == "choice_cancel"
end

local function _each_option(choice, visitor)
  local options = choice and choice.options or nil
  if type(options) ~= "table" then
    return nil
  end
  for index, option in ipairs(options) do
    local option_id = type(option) == "table" and option.id or option
    local result = visitor(option, option_id, index)
    if result ~= nil then
      return result
    end
  end
  return nil
end

function item_preconsume_policy.is_preconsumed(choice)
  return choice ~= nil and choice.meta ~= nil and choice.meta.item_preconsumed == true
end

function item_preconsume_policy.first_option_id(choice)
  return _each_option(choice, function(_, option_id)
    return option_id
  end)
end

function item_preconsume_policy.normalize_cancel_action(choice, action)
  if not _is_cancel_action(action) then
    return action
  end
  if not item_preconsume_policy.is_preconsumed(choice) then
    return action
  end
  local fallback_option_id = item_preconsume_policy.first_option_id(choice)
  if fallback_option_id == nil then
    return action
  end
  return {
    type = "choice_select",
    choice_id = choice and choice.id or nil,
    option_id = fallback_option_id,
    actor_role_id = action and action.actor_role_id or nil,
  }
end

function item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)
  if type(choice_spec) ~= "table" then
    return choice_spec
  end
  local ctx = context or {}
  choice_spec.allow_cancel = false
  choice_spec.cancel_label = nil
  choice_spec.meta = choice_spec.meta or {}
  choice_spec.meta.item_preconsumed = true
  if ctx.item_id ~= nil then
    choice_spec.meta.item_id = choice_spec.meta.item_id or ctx.item_id
  end
  if ctx.player_id ~= nil then
    choice_spec.meta.player_id = choice_spec.meta.player_id or ctx.player_id
  end
  return choice_spec
end

return item_preconsume_policy
