local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local handlers = require("src.rules.items.handlers")
local Class = require("src.foundation.class")
local tables = require("src.foundation.tables")

local registry = Class("ItemRegistry")

local function _inject_target_candidates(context, resolve_target_candidates)
  local next_context = tables.copy_table(context)
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
projectHash=6b7d94db7dc3c0dd
scope.0.id=chunk:src/rules/items/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=66
scope.0.semanticHash=d9390cbc2872b5aa
scope.1.id=function:_inject_target_candidates
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=13
scope.1.semanticHash=9adef315c32e0290
scope.2.id=function:registry:init
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=71cf7d660694c7cf
scope.3.id=function:_is_target_candidate
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=27
scope.3.semanticHash=ce15763cd44edbbe
scope.4.id=function:registry:target_candidates
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=44
scope.4.semanticHash=d85c6f61cb049ee8
scope.5.id=function:registry:register
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=48
scope.5.semanticHash=4218fa0408531805
scope.6.id=function:registry:register_defaults
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=63
scope.6.semanticHash=7018dadca7039f56
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=61
scope.7.semanticHash=694f3a446b581b83
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=57
scope.8.endLine=59
scope.8.semanticHash=f22a39706bed814f
]]
