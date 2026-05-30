local phase_wait = {}

function phase_wait.resolve_result(phase_res, default_next_state, player, total, raw_total)
  local next_state = phase_res and phase_res.next_state or default_next_state
  local next_args = phase_res and phase_res.next_args or nil
  if next_args == nil then
    next_args = {
      player = player,
      total = total,
      raw_total = raw_total,
    }
  end
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
version=2
projectHash=f6b83191f68758c5
scope.0.id=chunk:src/turn/phases/phase_wait.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=77ad66bede7bd468
scope.1.id=function:phase_wait.resolve_result:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=23
scope.1.semanticHash=d38746a521463302
]]
