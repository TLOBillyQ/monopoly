local support = require("spec.support.gameplay_support")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")

local function _new_manual_game()
  return support.new_game({ ai = {}, auto_all = false })
end

local function _run_landing_turn(game, player, move_result)
  local session = assert(game.turn_runtime and game.turn_runtime.session, "missing turn session")
  session.current_state = "landing"
  session.current_args = { player = player, move_result = move_result or {} }
  session.wait_state = nil
  session.finished = false
  session.queue = {}
  session.choice_elapsed_seconds = 0
  session:clear_pending_action()
  session.script = session:create_script()
  game:advance_turn()
end

local function _set_all_market_goods_unbuyable(game)
  for product_id in pairs(game.market_limits or {}) do
    game.market_limits[product_id] = 0
  end
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(inventory.items(player)) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

describe("landing auto advance", function()
  it("sold_out_market_landing_skips_choice_and_continues_to_inter_turn_wait", function()
    local game = _new_manual_game()
    local player = game.players[1]
    local market_index = assert(support.first_tile_by_type(game.board, "market"))

    _set_all_market_goods_unbuyable(game)
    game:update_player_position(player, market_index)

    _run_landing_turn(game, player)

    assert.is_nil(game.turn.pending_choice)
    assert.equals("inter_turn_wait", game.turn.phase)
    assert.is_true(game.turn.inter_turn_wait_active)
  end)

  it("free_rent_card_on_enemy_land_is_consumed_without_waiting_for_choice", function()
    local game = _new_manual_game()
    local player = game.players[1]
    local owner = game.players[2]
    local land_index, land_tile = support.first_land_tile(game.board)
    local player_cash = player.cash
    local owner_cash = owner.cash

    game:set_tile_owner(land_tile, owner.id)
    game:set_player_property(owner, land_tile.id, true)
    inventory.add(player, { id = item_ids.free_rent })
    game:update_player_position(player, land_index)

    _run_landing_turn(game, player)

    assert.is_nil(game.turn.pending_choice)
    assert.equals("inter_turn_wait", game.turn.phase)
    assert.equals(0, _count_item(player, item_ids.free_rent))
    assert.equals(player_cash, player.cash)
    assert.equals(owner_cash, owner.cash)
  end)

  it("declining_strong_card_uses_free_rent_and_does_not_open_second_choice", function()
    local game = _new_manual_game()
    local player = game.players[1]
    local owner = game.players[2]
    local land_index, land_tile = support.first_land_tile(game.board)
    local player_cash = player.cash
    local owner_cash = owner.cash

    game:set_tile_owner(land_tile, owner.id)
    game:set_player_property(owner, land_tile.id, true)
    inventory.add(player, { id = item_ids.strong })
    inventory.add(player, { id = item_ids.free_rent })
    game:update_player_position(player, land_index)

    _run_landing_turn(game, player)

    local strong_choice = assert(game.turn.pending_choice, "strong card prompt should open first")
    assert.equals("rent_card_prompt", strong_choice.kind)
    assert.equals("strong", strong_choice.meta.card_kind)

    game:dispatch_action({
      type = "choice_cancel",
      choice_id = strong_choice.id,
      actor_role_id = player.id,
    })

    assert.is_nil(game.turn.pending_choice)
    assert.equals("inter_turn_wait", game.turn.phase)
    assert.equals(1, _count_item(player, item_ids.strong))
    assert.equals(0, _count_item(player, item_ids.free_rent))
    assert.equals(player_cash, player.cash)
    assert.equals(owner_cash, owner.cash)
  end)
end)
