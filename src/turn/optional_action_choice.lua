local optional_action_choice = {}

function optional_action_choice.is_optional_action_choice(choice)
  local kind = choice and choice.kind or nil
  return kind == "item_phase_passive" or kind == "landing_optional_effect"
end

function optional_action_choice.is_cancelable_optional_action_choice(choice)
  return optional_action_choice.is_optional_action_choice(choice) and choice.allow_cancel ~= false
end

-- A pre_action item phase passive choice is opened at turn start, before the roll.
-- Unlike post_action/landing optional phases (which resolve through the 结束 button),
-- skipping it belongs on the 行动 button so 行动 precedes the roll even while a
-- pre-action card is still in the bag. Item target selection (passive_origin) keeps
-- its own 取消 affordance and is excluded here.
function optional_action_choice.is_pre_action_item_phase_choice(choice)
  if not optional_action_choice.is_cancelable_optional_action_choice(choice) then
    return false
  end
  if choice.kind ~= "item_phase_passive" then
    return false
  end
  local meta = choice.meta
  return type(meta) == "table" and meta.phase == "pre_action" and meta.passive_origin ~= true
end

-- Item target selection opens a dedicated target screen that owns its own cancel,
-- so the base screen hides its cancel button while a target is being picked.
function optional_action_choice.is_item_target_selection_choice(choice)
  local meta = choice and choice.meta
  return choice ~= nil and choice.kind == "item_phase_passive"
    and type(meta) == "table" and meta.passive_origin == true
end

-- The base cancel button belongs to the item phase (道具阶段): a specific card is
-- being used on the base screen (meta.item_name), and cancelling backs out of the
-- usage without consuming the card. This is distinct from the generic optional
-- action phase (which drives 结束) and from a pre/post-action skip gate (meta.phase
-- drives 行动/结束) and from target selection (passive_origin opens its own screen).
function optional_action_choice.is_item_usage_phase_choice(choice)
  if not optional_action_choice.is_cancelable_optional_action_choice(choice) then
    return false
  end
  if choice.kind ~= "item_phase_passive" then
    return false
  end
  local meta = choice.meta
  if type(meta) ~= "table" then
    return false
  end
  if meta.passive_origin == true or meta.phase ~= nil then
    return false
  end
  return meta.item_name ~= nil
end

return optional_action_choice

--[[ mutate4lua-manifest
version=2
projectHash=07736d1f9a0681bb
scope.0.id=chunk:src/turn/optional_action_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=c6f838b53ada2750
scope.1.id=function:optional_action_choice.is_optional_action_choice:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=dcaa3635497530ba
scope.1.lastMutatedAt=2026-07-07T06:08:18Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:optional_action_choice.is_cancelable_optional_action_choice:8
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=43fb97456d0b3233
scope.2.lastMutatedAt=2026-07-07T06:08:18Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:optional_action_choice.is_pre_action_item_phase_choice:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=26
scope.3.semanticHash=835eb586d69f5693
scope.3.lastMutatedAt=2026-07-07T06:08:18Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=15
scope.3.lastMutationKilled=15
]]
