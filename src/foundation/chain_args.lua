local M = {}

function M.patch(next_state, next_args, match_state, default_next_state, default_next_args)
  if next_state ~= match_state or type(next_args) ~= "table" then
    return next_state, next_args
  end
  next_args.next_state = next_args.next_state or default_next_state
  next_args.next_args = next_args.next_args or default_next_args
  return next_state, next_args
end

local function _after_action_anim_table(res)
  if type(res) ~= "table" then
    return nil
  end
  local after_action_anim = res.after_action_anim
  if type(after_action_anim) ~= "table" then
    return nil
  end
  return after_action_anim
end

function M.resolve_after_action_anim(args, res, match_state)
  args = args or {}
  local default_next_state = args.next_state
  local default_next_args = args.next_args
  local after_action_anim = _after_action_anim_table(res)
  if after_action_anim == nil then
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
version=4
projectHash=8a9fb4c60834b92a
scope.0.id=chunk:src/foundation/chain_args.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=ae13a761953c9a2c
scope.1.id=function:M.patch
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=10
scope.1.semanticHash=92470fe6fca908d3
scope.2.id=function:_after_action_anim_table
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=21
scope.2.semanticHash=abf463ed46af8fe6
scope.3.id=function:M.resolve_after_action_anim
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=38
scope.3.semanticHash=4a4755108108f241
]]
