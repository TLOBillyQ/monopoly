local Choice = require("src.gameplay.choice")
local logger = require("src.util.logger")

local Resolver = {}

local function as_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    local n = tonumber(v)
    return n
  end
  return nil
end

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

function Resolver.resolve(game, choice, action)
  if not game or not choice then
    return { stay = false }
  end

  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "land_optional_effect" then
    local effect_id = action.option_id
    if effect_id then
      local land_effects = require("src.gameplay.effects.land")
      local target_eff = nil
      for _, eff in ipairs(land_effects.defs or {}) do
        if eff.id == effect_id then
          target_eff = eff
          break
        end
      end
      if target_eff and target_eff.apply then
        local meta = choice.meta or {}
        local player = meta.player_id and game.players[meta.player_id] or game:current_player()
        local tile = meta.tile_id and game.board:get_tile_by_id(meta.tile_id) or game.board:get_tile(player.position)
        target_eff.apply({ player = player, tile = tile, on_landing = true, game = game })
      end
    end
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "missile_target" then
    local idx = as_number(action.option_id)
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
    if idx and player then
      local ItemService = require("src.gameplay.services.item_service")
      ItemService.consume_item(player, 2013)
      ItemService.apply_missile(game, player, idx)
    end
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "steal_target" then
    local target_id = as_number(action.option_id)
    local meta = choice.meta or {}
    local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
    local target = target_id and game.players[target_id]
    if not stealer or not target or target.eliminated then
      Choice.clear(game)
      return { stay = false }
    end

    local ItemService = require("src.gameplay.services.item_service")
    if target.inventory:count() <= 1 then
      ItemService.steal_item_at_index(game, stealer, target, 1)
      Choice.clear(game)
      return { stay = false }
    end

    local lines = {}
    local options = {}
    for i, it in ipairs(target.inventory.items) do
      local label = ItemService.item_name(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    Choice.open(game, {
      kind = "steal_item",
      title = "选择要偷的道具",
      body_lines = lines,
      options = options,
      allow_cancel = true,
      cancel_label = "取消",
      meta = { stealer_id = stealer.id, target_id = target.id },
    })
    return { stay = true }
  end

  if choice.kind == "steal_item" then
    local idx = as_number(action.option_id)
    local meta = choice.meta or {}
    local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
    local target = meta.target_id and game.players[meta.target_id]
    if stealer and target and idx then
      local ItemService = require("src.gameplay.services.item_service")
      ItemService.steal_item_at_index(game, stealer, target, idx)
    end
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "item_target_player" then
    local target_id = as_number(action.option_id)
    local meta = choice.meta or {}
    local item_id = meta.item_id
    local user = meta.user_id and game.players[meta.user_id] or game:current_player()
    local target = target_id and game.players[target_id]
    if user and target and item_id then
      local ItemService = require("src.gameplay.services.item_service")
      local ok = ItemService.apply_target_item_effect(game, user, item_id, target)
      if ok then
        ItemService.consume_item(user, item_id)
      end
    end
    Choice.clear(game)
    return { stay = false }
  end

  logger.warn("unknown choice kind:", tostring(choice.kind))
  Choice.clear(game)
  return { stay = false }
end

return Resolver
