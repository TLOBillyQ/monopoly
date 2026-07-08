local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local settlement = require("src.rules.land.settlement")
local tax_rules = require("src.rules.land.tax_rules")
local effect_runner = require("src.rules.effects.runner")

local function _new_game()
  return support.new_game({ map = default_map })
end

local _assert_eq = support.assert_eq
local _first_land_tile = support.first_land_tile
local _tile_state = support.tile_state
local with_patches = support.with_patches

local function _manual_landing_choice(player, tile, effect_ids, options)
  return {
    kind = "landing_optional_effect",
    meta = {
      player_id = player.id,
      tile_id = tile.id,
      effect_ids = effect_ids,
    },
    options = options,
  }
end

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
    local before_cash = game:player_cash(player)

    local result = settlement.resolve_landing_settlement_choice(game, pending, {
      option_id = "buy_land",
    })

    assert(result and result.ok == true, "buy_land choice should resolve through settlement seam")
    _assert_eq(result.status, "resolved", "buy_land choice should expose resolved status")
    _assert_eq(game:player_cash(player), before_cash - tile.price, "buy_land should deduct tile price")
    _assert_eq(_tile_state(game, tile).owner_id, player.id, "buy_land should set owner")
  end)

  it("option matching rejects nils and supports serialized option ids", function()
    local option_is_offered = settlement._M_test._option_is_offered

    assert(option_is_offered(nil, "buy_land") == false, "nil choice should not offer an option")
    assert(option_is_offered({ options = { { id = "buy_land" } } }, nil) == false,
      "nil option id should not be offered")
    assert(option_is_offered({ options = { { id = "buy_land" } } }, "upgrade_land") == false,
      "different option id should not be offered")
    assert(option_is_offered({ options = { { id = 7 } } }, "7") == true,
      "serialized option ids should match")
  end)

  it("resolve_landing_settlement_choice_rejects_missing_option_id", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)

    settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
    local pending = assert(game.turn.pending_choice, "missing landing choice")

    local missing = settlement.resolve_landing_settlement_choice(game, pending, {})
    assert(missing and missing.ok == false, "missing option id should be rejected")
    _assert_eq(missing.reason, "missing_landing_option", "missing option reason should be stable")

    local empty = settlement.resolve_landing_settlement_choice(game, pending, { option_id = "" })
    assert(empty and empty.ok == false, "empty option id should be rejected")
    _assert_eq(empty.reason, "missing_landing_option", "empty option reason should be stable")
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

  it("resolve_landing_settlement_choice_rejects_meta_option_not_in_choice_options", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)
    local choice = _manual_landing_choice(player, tile, { "buy_land" }, {})

    local result = settlement.resolve_landing_settlement_choice(game, choice, {
      option_id = "buy_land",
    })

    assert(result and result.ok == false, "meta-only option should be rejected")
    _assert_eq(result.reason, "landing_option_not_offered", "choice options should be authoritative")
    _assert_eq(_tile_state(game, tile).owner_id, nil, "rejected choice should not change owner")
  end)

  it("resolve_landing_settlement_choice_rejects_unknown_landing_effect", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)
    local choice = _manual_landing_choice(player, tile, { "ghost_land_effect" }, {
      { id = "ghost_land_effect" },
    })

    local result = settlement.resolve_landing_settlement_choice(game, choice, {
      option_id = "ghost_land_effect",
    })

    assert(result and result.ok == false, "unknown landing effect should be rejected")
    _assert_eq(result.reason, "landing_effect_not_found", "unknown effect reason should be stable")
    _assert_eq(_tile_state(game, tile).owner_id, nil, "unknown effect should not change owner")
  end)

  it("resolve_landing_settlement_choice_rejects_blocked_effect_execution", function()
    local game = _new_game()
    local player = game.players[1]
    local index, tile = _first_land_tile(game.board)
    game:update_player_position(player, index)

    settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
    local pending = assert(game.turn.pending_choice, "missing landing choice")
    local result

    with_patches({
      {
        target = effect_runner,
        key = "execute",
        value = function()
          return { ok = false, reason = "blocked_for_test" }
        end,
      },
    }, function()
      result = settlement.resolve_landing_settlement_choice(game, pending, {
        option_id = "buy_land",
      })
    end)

    assert(result and result.ok == false, "blocked effect execution should be rejected")
    _assert_eq(result.reason, "blocked_for_test", "blocked effect reason should be preserved")
    _assert_eq(_tile_state(game, tile).owner_id, nil, "blocked effect should not change owner")
  end)

  it("begin_landing_settlement_rejects_missing_actor", function()
    local game = _new_game()
    local _, tile = _first_land_tile(game.board)

    local result = settlement.begin_landing_settlement(game, 9999, { tile = tile })

    assert(result and result.ok == false, "missing actor should be rejected")
    _assert_eq(result.reason, "missing_actor", "missing actor reason should be stable")
  end)

  it("PIN: pay_tax deducts floor(cash*rate) and defers bankruptcy via bankrupt_reason", function()
    local game = _new_game()
    local player = game.players[1]
    local constants = require("src.config.content.constants")
    game:set_player_cash(player, 1000)

    local expected_fee = math.floor(1000 * constants.tax_rate)
    local result = tax_rules.execute_pay_tax(game, player.id)

    assert(game:player_cash(player) == 1000 - expected_fee, "tax deducts floor(cash*rate)")
    assert(result.event == "tax_paid", "event stays tax_paid")
    assert(result.bankrupt_reason == nil, "solvent taxpayer has no bankrupt_reason")
    assert(player.eliminated ~= true, "eliminate is deferred to land_events, not here")
  end)

  it("PIN: pay_tax at zero cash reports bankrupt_reason but does not eliminate in-place", function()
    local game = _new_game()
    local player = game.players[1]
    game:set_player_cash(player, 0)  -- fee = floor(0*rate) = 0 → cash 仍 0,<= 0 → bankrupt_reason

    local result = tax_rules.execute_pay_tax(game, player.id)

    assert(result.bankrupt_reason == player.name .. " 支付税金后破产", "reason set on non-positive")
    assert(player.eliminated ~= true, "still deferred; land_events owns the eliminate call")
  end)
end)
