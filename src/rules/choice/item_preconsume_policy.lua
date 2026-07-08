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

-- force_skip 等放弃路径的退还入口:薄适配到结算台账(惰性 require,
-- settlement 不得反向依赖本 policy)。
function item_preconsume_policy.refund(game, choice)
  local settlement = require("src.rules.items.settlement")
  return settlement.abandon(game, choice, "preconsume_refund")
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

--[[ mutate4lua-manifest
version=2
projectHash=5506aef73628e3ee
scope.0.id=chunk:src/rules/choice/item_preconsume_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=94
scope.0.semanticHash=c8980f378da8f3e0
scope.0.lastMutatedAt=2026-07-07T04:14:27Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:item_preconsume_policy.is_cancel_action:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=5fdb6497c65ceab6
scope.1.lastMutatedAt=2026-07-07T04:14:27Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:item_preconsume_policy.is_preconsumed:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=24
scope.2.semanticHash=c143abca0a1ca600
scope.2.lastMutatedAt=2026-07-07T04:14:27Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:anonymous@27:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=29
scope.3.semanticHash=250ab200ed3c0f30
scope.4.id=function:item_preconsume_policy.first_option_id:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=30
scope.4.semanticHash=4c17077e3787affc
scope.4.lastMutatedAt=2026-07-07T04:14:27Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:item_preconsume_policy.normalize_cancel_action:32
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=49
scope.5.semanticHash=254c2420fb314d35
scope.5.lastMutatedAt=2026-07-07T04:14:27Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=11
scope.5.lastMutationKilled=11
scope.6.id=function:item_preconsume_policy.disable_followup_cancel:51
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=58
scope.6.semanticHash=cb4d3df64d1e6613
scope.6.lastMutatedAt=2026-07-07T04:14:27Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:item_preconsume_policy.ensure_followup_meta:60
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=67
scope.7.semanticHash=2bf8c450bc1993e8
scope.7.lastMutatedAt=2026-07-07T04:14:27Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:item_preconsume_policy.merge_preconsume_context:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=81
scope.8.semanticHash=be1113e1052c3f56
scope.8.lastMutatedAt=2026-07-07T04:14:27Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=8
scope.8.lastMutationKilled=8
scope.9.id=function:item_preconsume_policy.decorate_followup_choice_spec:83
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=91
scope.9.semanticHash=b2e47765ed8bc976
scope.9.lastMutatedAt=2026-07-07T04:14:27Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=6
scope.9.lastMutationKilled=6
]]
