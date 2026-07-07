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

return optional_action_choice

--[[ mutate4lua-manifest
version=2
projectHash=5de47f76fe542c1c
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
scope.2.id=function:optional_action_choice.is_cancelable_optional_action_choice:8
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=43fb97456d0b3233
scope.3.id=function:optional_action_choice.is_pre_action_item_phase_choice:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=26
scope.3.semanticHash=835eb586d69f5693
]]
