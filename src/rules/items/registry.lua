local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local handlers = require("src.rules.items.handlers")
require "vendor.third_party.ClassUtils"

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

function registry:target_candidates(game, player, item_id)
  local spec = effects.get_target_spec(item_id)
  assert(spec ~= nil, "missing target spec: " .. tostring(item_id))

  if spec.require_user and not spec.require_user(game, player) then
    return {}
  end

  local candidates = {}
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated then
      if not game:angel_immune_to_item(p, item_id) and
          (not spec.filter_target or spec.filter_target(game, player, p)) then
        table.insert(candidates, p)
      end
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
version=2
projectHash=9af5a8e19ed5db9b
scope.0.id=chunk:src/rules/items/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=69
scope.0.semanticHash=fcc470f914a05b03
scope.0.lastMutatedAt=2026-07-07T03:37:54Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=30
scope.0.lastMutationKilled=30
scope.1.id=function:_inject_target_candidates:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=23
scope.1.semanticHash=f9761e86133f63aa
scope.1.lastMutatedAt=2026-07-07T03:37:54Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:registry:init:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=27
scope.2.semanticHash=4c908a141335a382
scope.3.id=function:registry:register:49
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=51
scope.3.semanticHash=3dfb28c7e382b021
scope.4.id=function:anonymous@60:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=62
scope.4.semanticHash=f2dab78ccb55f750
scope.5.id=function:anonymous@59:59
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=64
scope.5.semanticHash=ac21b61f9f8d904a
]]
