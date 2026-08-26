local completions = require("src.rules.choice_handlers.item_completions")
local normalize = require("src.rules.choice_handlers.item_normalize")
local phase_handlers = require("src.rules.choice_handlers.item_phase_handlers")

local function _handle_flow_choice(game, choice, action, complete, resolve_item_use_choice, context)
  local result = resolve_item_use_choice(game, choice, action, context)
  local player = result.actor or normalize.validate_item_player(game, choice.kind, choice.meta)
  if result.ok ~= true then
    return { stay = true, reason = result.reason }
  end
  if result.waiting then
    return { stay = true }
  end
  return complete.followup_completion(game, choice, player, result)
end

local function _build_flow_handlers(helpers, kind, handler_opts)
  local complete = completions.build(helpers)
  local resolve_item_use_choice = helpers.resolve_item_use_choice

  local function _handle(game, choice, action)
    return _handle_flow_choice(game, choice, action, complete, resolve_item_use_choice)
  end

  return {
    [kind] = completions.item_target_handler(kind, _handle, complete, handler_opts),
  }
end

local function _build_demolish_handlers(helpers)
  return _build_flow_handlers(helpers, "demolish_target")
end

local function _build_roadblock_handlers(helpers)
  return _build_flow_handlers(helpers, "roadblock_target")
end

local function _build_target_player_handlers(helpers)
  return _build_flow_handlers(helpers, "item_target_player")
end

local function _build_remote_dice_handlers(helpers)
  return _build_flow_handlers(helpers, "remote_dice_value", {
    normalize_meta = normalize.remote_dice_meta,
    meta_validator = normalize.validate_remote_dice_meta,
  })
end

local M = {}

local _handler_builders = {
  phase_handlers.build,
  _build_demolish_handlers,
  _build_roadblock_handlers,
  _build_target_player_handlers,
  _build_remote_dice_handlers,
}

function M.register(registry, helpers)
  for _, builder in ipairs(_handler_builders) do
    local handlers = builder(helpers)
    for kind, handler in pairs(handlers) do
      registry[kind] = handler
    end
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=81f86c59a7aa94b9
scope.0.id=chunk:src/rules/choice_handlers/item.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=69
scope.0.semanticHash=f7b4ed8b9ad2f8ea
scope.1.id=function:_handle_flow_choice
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=15
scope.1.semanticHash=ddd88d9aba793402
scope.2.id=function:_build_flow_handlers
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=28
scope.2.semanticHash=785cda602430e1ef
scope.3.id=function:_handle
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=00d1f8fb89415fdd
scope.4.id=function:_build_demolish_handlers
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=a9c1c4b362850cf7
scope.5.id=function:_build_roadblock_handlers
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=36
scope.5.semanticHash=a9c1c4b362850cf7
scope.6.id=function:_build_target_player_handlers
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=a9c1c4b362850cf7
scope.7.id=function:_build_remote_dice_handlers
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=47
scope.7.semanticHash=f2cd1612a4dd7ba2
scope.8.id=function:M.register
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=66
scope.8.semanticHash=e8b87746015884a7
]]
