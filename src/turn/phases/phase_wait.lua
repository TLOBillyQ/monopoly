local phase_wait = {}

local function _default_args(player, total, raw_total)
  return {
    player = player,
    total = total,
    raw_total = raw_total,
  }
end

local function _next_args_of(phase_res, player, total, raw_total)
  local next_args = phase_res and phase_res.next_args or nil
  if next_args == nil then
    return _default_args(player, total, raw_total)
  end
  return next_args
end

function phase_wait.resolve_result(phase_res, default_next_state, player, total, raw_total)
  local next_state = phase_res and phase_res.next_state or default_next_state
  local next_args = _next_args_of(phase_res, player, total, raw_total)
  if phase_res and phase_res.wait_action_anim == true then
    return "wait_action_anim", {
      next_state = next_state,
      next_args = next_args,
    }
  end
  return "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }
end

return phase_wait

--[[ mutate4lua-manifest
version=4
projectHash=a2a0c8750674451d
scope.0.id=chunk:src/turn/phases/phase_wait.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=b017ce1f9e2ba14f
scope.1.id=function:_default_args
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=9
scope.1.semanticHash=1c7ecff3901ec8e5
scope.2.id=function:_next_args_of
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=17
scope.2.semanticHash=8e8f4725f8691709
scope.3.id=function:phase_wait.resolve_result
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=32
scope.3.semanticHash=e372d926e2affb41
]]
