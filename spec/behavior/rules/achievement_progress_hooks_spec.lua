local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local achievement_progress_port = require("src.rules.ports.achievement_progress")
local effect_base = require("src.rules.land.effect_base")
local effect_chance = require("src.rules.land.effect_chance")
local land_rules = require("src.rules.land.landing_rules")
local chance_handlers = require("src.rules.chance.handlers")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local item_executor = require("src.rules.items.executor")
local post_effects = require("src.rules.items.post_effects")
local demolish = require("src.rules.items.demolish")
local market = require("src.rules.market")

local function _capture_events()
  local events = {}
  local function push(kind)
    return function(_, player, amount)
      events[#events + 1] = { kind = kind, player = player, amount = amount }
      return true
    end
  end
  achievement_progress_port.configure({
    game_won = push("game_won"),
    land_purchased = push("land_purchased"),
    cash_received = push("cash_received"),
    tax_paid = push("tax_paid"),
    item_used = push("item_used"),
    chance_card_drawn = push("chance_card_drawn"),
    market_item_bought = push("market_item_bought"),
    building_upgraded = push("building_upgraded"),
    contiguous_lands = push("contiguous_lands"),
    monster_demolished_building = push("monster_demolished_building"),
    typhoon_demolished_building = push("typhoon_demolished_building"),
    deity_attached = function(_, player, deity_type)
      events[#events + 1] = { kind = "deity_attached", player = player, deity_type = deity_type }
      return true
    end,
    location_effect = function(_, player, effect)
      events[#events + 1] = { kind = "location_effect", player = player, effect = effect }
      return true
    end,
    skin_equipped = function(_, role_id, skin)
      events[#events + 1] = { kind = "skin_equipped", role_id = role_id, skin = skin }
      return true
    end,
  })
  return events
end

local function _find_event(events, kind, player, field, value)
  for _, event in ipairs(events) do
    if event.kind == kind
        and (player == nil or event.player == player)
        and (field == nil or event[field] == value) then
      return event
    end
  end
  return nil
end

local function _land_neighbor_ids(board, tile_id)
  local out = {}
  local neighbors = board.map and board.map.neighbors or {}
  for _, next_id in pairs(neighbors[tile_id] or {}) do
    local tile = board:get_tile_by_id(next_id)
    if tile and tile.type == "land" then
      out[#out + 1] = next_id
    end
  end
  return out
end

local function _find_land_cluster(board, count)
  for _, tile in ipairs(board.path) do
    if tile.type == "land" then
      local ids = {}
      local queue = { tile.id }
      local seen = { [tile.id] = true }
      local head = 1
      while head <= #queue and #ids < count do
        local current_id = queue[head]
        head = head + 1
        ids[#ids + 1] = current_id
        for _, next_id in ipairs(_land_neighbor_ids(board, current_id)) do
          if not seen[next_id] then
            seen[next_id] = true
            queue[#queue + 1] = next_id
          end
        end
      end
      if #ids >= count then
        local tiles = {}
        for index = 1, count do
          tiles[index] = assert(board:get_tile_by_id(ids[index]), "missing land tile")
        end
        return tiles
      end
    end
  end
  error("no connected land cluster with " .. tostring(count) .. " tiles")
end

describe("achievement_progress gameplay hooks", function()
  local _config_reset = require("spec.support.config_reset")

  before_each(function()
    _config_reset.reset_all()
    achievement_progress_port.reset_for_tests()
  end)

  after_each(function()
    achievement_progress_port.reset_for_tests()
  end)

  it("emits land purchase, rent income, tax, and upgrade gameplay facts", function()
    local game = support.new_game()
    local player = game.players[1]
    local owner = game.players[2]
    local events = _capture_events()
    local _, tile = support.first_land_tile(game.board)

    game:set_player_cash(player, 999999)
    effect_base.executors.buy_land.apply({ game = game, player = player, tile = tile })
    assert(_find_event(events, "land_purchased", player), "land purchase should emit an achievement fact")

    effect_base.executors.upgrade_land.apply({ game = game, player = player, tile = tile })
    assert(_find_event(events, "building_upgraded", player, "amount", 1),
      "first upgrade should emit level-1 achievement fact")

    game:set_tile_owner(tile, owner.id)
    game:set_player_property(player, tile.id, false)
    game:set_player_property(owner, tile.id, true)
    game:set_player_cash(owner, 0)
    local rent_result = land_rules.execute_pay_rent(game, player.id, tile.id)
    _assert_eq(rent_result.ok, true, "rent payment should succeed")
    assert(_find_event(events, "cash_received", owner), "rent owner should receive cash achievement fact")

    game:set_player_cash(player, 10000)
    local tax_result = land_rules.execute_pay_tax(game, player.id)
    _assert_eq(tax_result.ok, true, "tax payment should succeed")
    assert(_find_event(events, "tax_paid", player, "amount", tax_result.payload.amount),
      "tax payment should emit paid amount")
  end)

  it("emits a contiguous-land fact when the third connected land is acquired", function()
    local game = support.new_game()
    local player = game.players[1]
    local events = _capture_events()

    game:set_player_cash(player, 999999)
    for _, tile in ipairs(_find_land_cluster(game.board, 3)) do
      effect_base.executors.buy_land.apply({ game = game, player = player, tile = tile })
    end

    assert(_find_event(events, "contiguous_lands", player),
      "third connected land purchase should emit contiguous achievement fact")
  end)

  it("emits chance draw, chance cash, and typhoon demolition gameplay facts", function()
    local game = support.new_game()
    local player = game.players[1]
    local owner = game.players[2]
    local events = _capture_events()
    local chance_index, chance_tile = support.first_tile_by_type(game.board, "chance")

    game:update_player_position(player, chance_index)
    game.rng = { next_int = function() return 1 end }
    effect_chance.executors.chance_draw_and_resolve.apply({
      game = game,
      player = player,
      tile = chance_tile,
      move_result = {},
    })
    assert(_find_event(events, "chance_card_drawn", player), "chance draw should emit achievement fact")
    assert(_find_event(events, "cash_received", player, "amount", 10000),
      "positive chance cash should emit received amount")

    local land_index, land_tile = support.first_land_tile(game.board)
    game:set_tile_owner(land_tile, owner.id)
    game:set_player_property(owner, land_tile.id, true)
    game:set_tile_level(land_tile, 1)
    chance_handlers.build().destroy_buildings_on_path(game, nil, nil, { visited = { land_index } })
    assert(_find_event(events, "typhoon_demolished_building", owner),
      "typhoon building destruction should emit owner achievement fact")
  end)

  it("emits item, deity, location, item target, demolish, and market gameplay facts", function()
    local game = support.new_game()
    local player = game.players[1]
    local target = game.players[2]
    local events = _capture_events()

    inventory.give(player, item_ids.dice_multiplier)
    local item_result = item_executor.use_item(game, player, item_ids.dice_multiplier, { by_ai = true })
    _assert_eq(type(item_result) == "table" and item_result.ok or item_result, true,
      "dice multiplier item should succeed")
    assert(_find_event(events, "item_used", player), "successful item use should emit achievement fact")

    game:set_player_deity(player, "rich", 3)
    assert(_find_event(events, "deity_attached", player, "deity_type", "rich"),
      "deity attachment should emit achievement fact")

    game:set_player_cash(player, 999999)
    game:player_apply_hospital_effects(player)
    assert(_find_event(events, "location_effect", player, "effect", "hospital"),
      "hospital effect should emit achievement fact")
    game:player_apply_mountain_effects(target)
    assert(_find_event(events, "location_effect", target, "effect", "mountain"),
      "mountain effect should emit achievement fact")

    game:set_player_cash(player, 0)
    game:set_player_cash(target, 10000)
    post_effects.apply_target(game, player, item_ids.share_wealth, target, {})
    assert(_find_event(events, "cash_received", player, "amount", 5000),
      "share wealth positive delta should emit received cash")
    post_effects.apply_target(game, player, item_ids.tax, target, {})
    assert(_find_event(events, "tax_paid", target, "amount", 2500),
      "tax card should emit target tax payment")

    local land_index, land_tile = support.first_land_tile(game.board)
    game:set_tile_owner(land_tile, target.id)
    game:set_player_property(target, land_tile.id, true)
    game:set_tile_level(land_tile, 1)
    demolish.apply(game, player, land_index, { item_id = item_ids.monster })
    assert(_find_event(events, "monster_demolished_building", target),
      "monster demolition should emit owner achievement fact")

    game:set_player_cash(player, 999999)
    local purchase_result = market.purchase.execute(game, player, item_ids.dice_multiplier)
    _assert_eq(type(purchase_result) == "table" and purchase_result.ok or purchase_result, true,
      "coin market purchase should succeed")
    assert(_find_event(events, "market_item_bought", player),
      "successful market item purchase should emit achievement fact")
  end)

  it("emits a game-win fact when victory is resolved", function()
    local game = support.new_game()
    local winner = game.players[1]
    local loser = game.players[2]
    local events = _capture_events()

    game:set_player_eliminated(loser, true)
    _assert_eq(game:check_victory(), true, "one surviving player should win")
    assert(_find_event(events, "game_won", winner), "victory should emit achievement fact")
  end)
end)
