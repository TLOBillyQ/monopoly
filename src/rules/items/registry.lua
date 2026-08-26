local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local handlers = require("src.rules.items.handlers")
local Class = require("src.foundation.class")

local registry = Class("ItemRegistry")

local function _copy_context(context)
  local next_context = {}
  if type(context) ~= "table" then
    return next_context
  end
  for key, value in pairs(context) do
    next_context[key] = value
  end
  return next_context
end

local function _inject_target_candidates(context, resolve_target_candidates)
  local next_context = _copy_context(context)
  next_context.resolve_target_candidates = resolve_target_candidates
  return next_context
end

function registry:init()
  self.handlers = {}
end

local function _is_target_candidate(game, player, item_id, spec, candidate)
  if candidate.id == player.id or candidate.eliminated then
    return false
  end
  if game:angel_immune_to_item(candidate, item_id) then
    return false
  end
  return not spec.filter_target or spec.filter_target(game, player, candidate)
end

function registry:target_candidates(game, player, item_id)
  local spec = effects.get_target_spec(item_id)
  assert(spec ~= nil, "missing target spec: " .. tostring(item_id))

  if spec.require_user and not spec.require_user(game, player) then
    return {}
  end

  local candidates = {}
  for _, p in ipairs(game.players) do
    if _is_target_candidate(game, player, item_id, spec, p) then
      table.insert(candidates, p)
    end
  end
  return candidates
end

function registry:register(item_id, handler)
  self.handlers[item_id] = handler
end

function registry:register_defaults()
  self:register(item_ids.remote_dice, handlers.handle_remote_dice)
  self:register(item_ids.roadblock, handlers.handle_roadblock)
  self:register(item_ids.monster, handlers.handle_demolish)

  for _, id in ipairs(effects.target_item_ids()) do
    self:register(id, function(game, player, item_id, context)
      local next_context = _inject_target_candidates(context, function(target_game, target_player, target_item_id)
        return self:target_candidates(target_game, target_player, target_item_id)
      end)
      return handlers.handle_target_player_item(game, player, item_id, next_context)
    end)
  end
end

return registry

--[[ mutate4lua-manifest
version=4
projectHash=f6db405ee6cab950
scope.0.id=chunk:src/rules/items/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=76
scope.0.semanticHash=4dbe1206996738c4
scope.1.id=function:_copy_context
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=17
scope.1.semanticHash=cda80b580f6fded9
scope.2.id=function:_inject_target_candidates
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=23
scope.2.semanticHash=9adef315c32e0290
scope.3.id=function:registry:init
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=71cf7d660694c7cf
scope.4.id=function:_is_target_candidate
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=37
scope.4.semanticHash=ce15763cd44edbbe
scope.5.id=function:registry:target_candidates
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=54
scope.5.semanticHash=d85c6f61cb049ee8
scope.6.id=function:registry:register
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=58
scope.6.semanticHash=4218fa0408531805
scope.7.id=function:registry:register_defaults
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=73
scope.7.semanticHash=7018dadca7039f56
scope.8.id=function:<anonymous>
scope.8.kind=function
scope.8.startLine=66
scope.8.endLine=71
scope.8.semanticHash=694f3a446b581b83
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=69
scope.9.semanticHash=f22a39706bed814f
]]
