local post = require("game.item.post")
local gameplay_rules = require("cfg.GameplayRules")
local handler = require("game.item.handler.init")
require "lib.third_party.ClassUtils"

local item_ids = gameplay_rules.item_ids
local registry = Class("ItemRegistry")

function registry:init()
  self.handlers = {}
end

function registry:target_candidates(game, player, item_id)
  local spec = post.get_target_spec(item_id)
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

function registry:register(item_id, handler_fn)
  self.handlers[item_id] = handler_fn
end

function registry:register_defaults()
  self:register(item_ids.remote_dice, handler.handle_remote_dice)
  self:register(item_ids.roadblock, handler.handle_roadblock)
  self:register(item_ids.monster, handler.handle_demolish)
  self:register(item_ids.missile, handler.handle_demolish)

  for _, id in ipairs(post.target_item_ids()) do
    self:register(id, function(game, player, item_id, context)
      local next_context = {}
      if type(context) == "table" then
        for key, value in pairs(context) do
          next_context[key] = value
        end
      end
      next_context.resolve_target_candidates = function(target_game, target_player, target_item_id)
        return self:target_candidates(target_game, target_player, target_item_id)
      end
      return handler.handle_target_player_item(game, player, item_id, next_context)
    end)
  end
end

return registry
