local item_effects = require("src.game.systems.items.ItemPostEffects")
local gameplay_rules = require("Config.GameplayRules")
local item_handlers = require("src.game.systems.items.ItemHandlers")

local item_registry = {}
local handlers = {}
local defaults_registered = false
local item_ids = gameplay_rules.item_ids
item_registry.handlers = handlers

function item_registry.target_candidates(game, player, item_id)
  local spec = item_effects.get_target_spec(item_id)
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

function item_registry.register(item_id, handler)
  handlers[item_id] = handler
end

function item_registry.register_defaults()
  if defaults_registered then
    return
  end
  defaults_registered = true

  item_registry.register(item_ids.remote_dice, item_handlers.handle_remote_dice)
  item_registry.register(item_ids.roadblock, item_handlers.handle_roadblock)
  item_registry.register(item_ids.monster, item_handlers.handle_demolish)
  item_registry.register(item_ids.missile, item_handlers.handle_demolish)

  for _, id in ipairs(item_effects.target_item_ids()) do
    item_registry.register(id, function(game, player, item_id, context)
      local next_context = {}
      if type(context) == "table" then
        for key, value in pairs(context) do
          next_context[key] = value
        end
      end
      next_context.resolve_target_candidates = item_registry.target_candidates
      return item_handlers.handle_target_player_item(game, player, item_id, next_context)
    end)
  end
end

return item_registry
