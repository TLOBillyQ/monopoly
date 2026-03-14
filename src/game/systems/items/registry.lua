local effects = require("src.game.systems.items.post_effects")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local handlers = require("src.game.systems.items.handlers")
require "vendor.third_party.ClassUtils"

local item_ids = gameplay_rules.item_ids
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
      if not spec.filter_target or spec.filter_target(game, player, p) then
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
  self:register(item_ids.missile, handlers.handle_demolish)

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
