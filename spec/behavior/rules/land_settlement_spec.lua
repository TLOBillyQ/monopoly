local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local settlement = require("src.rules.land.settlement")

local function _new_game()
  return support.new_game({ map = default_map })
end

local _assert_eq = support.assert_eq
local _first_land_tile = support.first_land_tile
local _tile_state = support.tile_state

describe("rules.land.settlement", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("begin_landing_settlement_opens_buy_choice_without_pipeline_args", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)

    local result = settlement.begin_landing_settlement(game, player.id, {
      tile = tile,
      move_result = {},
    })

    assert(result and result.waiting == true, "empty land should wait on buy choice")
    _assert_eq(result.reason, "landing_optional", "landing seam should expose landing reason")

    local pending = game.turn.pending_choice
    assert(pending and pending.kind == "landing_optional_effect", "landing seam should open landing choice")
    _assert_eq(pending.meta.player_id, player.id, "choice should belong to landing actor")
    _assert_eq(pending.meta.tile_id, tile.id, "choice should target landed tile")
    _assert_eq(pending.options[1].id, "buy_land", "empty land should offer buy_land")
  end)

  it("resolve_landing_settlement_choice_executes_buy_land", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)

    settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
    local pending = assert(game.turn.pending_choice, "missing landing choice")
    local before_cash = player.cash

    local result = settlement.resolve_landing_settlement_choice(game, pending, {
      option_id = "buy_land",
    })

    assert(result and result.ok == true, "buy_land choice should resolve through settlement seam")
    _assert_eq(player.cash, before_cash - tile.price, "buy_land should deduct tile price")
    _assert_eq(_tile_state(game, tile).owner_id, player.id, "buy_land should set owner")
  end)

  it("resolve_landing_settlement_choice_rejects_unoffered_option", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)

    settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
    local pending = assert(game.turn.pending_choice, "missing landing choice")

    local result = settlement.resolve_landing_settlement_choice(game, pending, {
      option_id = "upgrade_land",
    })

    assert(result and result.ok == false, "unoffered option should be rejected")
    _assert_eq(result.reason, "landing_option_not_offered", "rejection reason should be stable")
    _assert_eq(_tile_state(game, tile).owner_id, nil, "rejected choice should not change owner")
  end)

  it("begin_landing_settlement_rejects_missing_actor", function()
    local game = _new_game()
    local _, tile = _first_land_tile(game.board)

    local result = settlement.begin_landing_settlement(game, 9999, { tile = tile })

    assert(result and result.ok == false, "missing actor should be rejected")
    _assert_eq(result.reason, "missing_actor", "missing actor reason should be stable")
  end)
end)
