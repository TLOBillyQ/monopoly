-- Choice resolution deliberately avoids requiring turn.actions.action_dispatcher;
-- dispatch entry points are provided by callers or by game:advance_turn.
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local choice_ports = require("src.turn.deadlines.choice_ports")
local choice_scope = require("src.turn.deadlines.choice_scope")

local choice_resolution = {}

local function _elapsed_from_entry(entry)
  return entry and entry.elapsed_seconds or nil
end

local function _elapsed_from_state(state)
  return runtime_state.get_pending_choice_elapsed(state) or 0
end

local function _resolve_choice_elapsed(api, state, choice)
  if type(state) ~= "table" then
    return 0
  end
  local entry_elapsed = _elapsed_from_entry(api.peek(state, choice_scope.for_choice(choice)))
  if entry_elapsed ~= nil then
    return entry_elapsed
  end
  return _elapsed_from_state(state)
end

local function _try_choice_auto(api, game, state, choice, precomputed_action)
  if precomputed_action ~= nil then
    return precomputed_action
  end
  local elapsed = _resolve_choice_elapsed(api, state, choice)
  return choice_auto_policy.decide(game, state, choice, {
    mode = "tick_timeout",
    elapsed_seconds = elapsed,
    min_visible_seconds = 0,
    allow_first_option_fallback = true,
  })
end

local function _dispatch_choice_action(game, state, choice, action)
  if not choice_ports.is_action_dispatchable(action) then
    return false
  end
  if action.choice_id == nil then
    action.choice_id = choice.id
  end
  choice_ports.ensure_actor_role_id(game, choice, action)
  choice_ports.dispatch_via_close_choice(game, state, action)
  return true
end

local function _resolve_fallback_choice_action(game, choice, action)
  if not (action == nil or (type(action) == "table" and action.type == "choice_force_skip")) then
    return nil
  end
  return fallback_registry.resolve(choice.kind, game, choice)
end

local function _dispatch_auto_or_fallback(api, game, state, choice, precomputed_action)
  local action = _try_choice_auto(api, game, state, choice, precomputed_action)
  if _dispatch_choice_action(game, state, choice, action) then
    return true
  end
  local fallback_action = _resolve_fallback_choice_action(game, choice, action)
  return _dispatch_choice_action(game, state, choice, fallback_action)
end

function choice_resolution.install(api)
  function api.resolve_choice(game, state, choice, reason, precomputed_action)
    if type(choice) ~= "table" or choice.id == nil then
      api.force_skip(game, state, choice, reason or "no_choice")
      return
    end
    if _dispatch_auto_or_fallback(api, game, state, choice, precomputed_action) then
      return
    end
    api.force_skip(game, state, choice, reason or "tick_timeout")
  end

  function api.resolve_target_select(game, state, target_ctx, reason)
    local choice = nil
    if type(target_ctx) == "table" then
      choice = target_ctx.choice
    end
    if choice == nil and game and game.turn then
      choice = game.turn.pending_choice
    end
    api.force_skip(game, state, choice, reason or "target_select_timeout")
  end
end

return choice_resolution

--[[ mutate4lua-manifest
version=2
projectHash=32a409d487ed4db5
scope.0.id=chunk:src/turn/deadlines/choice_resolution.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=93
scope.0.semanticHash=8e59d1d2e4c02674
scope.1.id=function:_elapsed_from_entry:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=0b6be8fa21258c4b
scope.2.id=function:_elapsed_from_state:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=523d5903cc636978
scope.3.id=function:_resolve_choice_elapsed:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=28
scope.3.semanticHash=f4eba4c20fe9b175
scope.4.id=function:_try_choice_auto:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=38
scope.4.semanticHash=140ba3510ad7c43b
scope.5.id=function:_dispatch_choice_action:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=50
scope.5.semanticHash=866d4e2925387edf
scope.6.id=function:_resolve_fallback_choice_action:52
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=57
scope.6.semanticHash=332f4831fc54f602
scope.7.id=function:_dispatch_auto_or_fallback:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=66
scope.7.semanticHash=29b7dc7ccc242fe2
scope.8.id=function:api.resolve_choice:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=78
scope.8.semanticHash=7826a031963cc6b5
scope.9.id=function:api.resolve_target_select:80
scope.9.kind=function
scope.9.startLine=80
scope.9.endLine=89
scope.9.semanticHash=11af01bd44d3be0a
scope.10.id=function:choice_resolution.install:68
scope.10.kind=function
scope.10.startLine=68
scope.10.endLine=90
scope.10.semanticHash=8c74caa104e3a917
]]
