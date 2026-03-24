local item_preconsume_policy = {}

function item_preconsume_policy.is_cancel_action(action)
  return action ~= nil and action.type == "choice_cancel"
end

function item_preconsume_policy.each_option(choice, visitor)
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
  return item_preconsume_policy.each_option(choice, function(_, option_id)
    return option_id
  end)
end

function item_preconsume_policy.normalize_cancel_action(choice, action)
  if not item_preconsume_policy.is_cancel_action(action) then
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

function item_preconsume_policy.disable_followup_cancel(choice_spec)
  if type(choice_spec) ~= "table" then
    return choice_spec
  end
  choice_spec.allow_cancel = false
  choice_spec.cancel_label = nil
  return choice_spec
end

function item_preconsume_policy.ensure_followup_meta(choice_spec)
  if type(choice_spec) ~= "table" then
    return nil
  end
  choice_spec.meta = choice_spec.meta or {}
  choice_spec.meta.item_preconsumed = true
  return choice_spec.meta
end

function item_preconsume_policy.merge_preconsume_context(meta, context)
  if type(meta) ~= "table" then
    return meta
  end
  local ctx = context or {}
  if ctx.item_id ~= nil then
    meta.item_id = meta.item_id or ctx.item_id
  end
  if ctx.player_id ~= nil then
    meta.player_id = meta.player_id or ctx.player_id
  end
  return meta
end

function item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)
  if type(choice_spec) ~= "table" then
    return choice_spec
  end
  item_preconsume_policy.disable_followup_cancel(choice_spec)
  local meta = item_preconsume_policy.ensure_followup_meta(choice_spec)
  item_preconsume_policy.merge_preconsume_context(meta, context)
  return choice_spec
end

return item_preconsume_policy
