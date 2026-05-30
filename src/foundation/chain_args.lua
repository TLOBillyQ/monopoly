local M = {}

function M.patch(next_state, next_args, match_state, default_next_state, default_next_args)
  if next_state ~= match_state or type(next_args) ~= "table" then
    return next_state, next_args
  end
  next_args.next_state = next_args.next_state or default_next_state
  next_args.next_args = next_args.next_args or default_next_args
  return next_state, next_args
end

function M.resolve_after_action_anim(args, res, match_state)
  args = args or {}
  local default_next_state = args.next_state
  local default_next_args = args.next_args
  local after_action_anim = type(res) == "table" and res.after_action_anim or nil
  if type(after_action_anim) ~= "table" then
    return default_next_state, default_next_args
  end
  return M.patch(
    after_action_anim.next_state or default_next_state,
    after_action_anim.next_args or default_next_args,
    match_state,
    default_next_state,
    default_next_args
  )
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=1e5a16dd8c6e1dbe
scope.0.id=chunk:src/foundation/chain_args.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=867bd164b903c533
scope.1.id=function:M.patch:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=10
scope.1.semanticHash=ceb50b5bab48753b
scope.2.id=function:M.resolve_after_action_anim:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=27
scope.2.semanticHash=4e865a160ef6d135
]]
