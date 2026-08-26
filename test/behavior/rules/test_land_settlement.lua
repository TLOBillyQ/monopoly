---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local pricing = require("src.rules.land.pricing")
local settlement = require("src.rules.land.settlement")
local tax_rules = require("src.rules.land.tax_rules")
local effect_runner = require("src.rules.effects.runner")

-- 原生 LuaUnit 转换(busted → LuaUnit):describe 拍平为文件级 Test 类,
-- before_each → setUp,断言词汇切到 lu.assertXxx,用例数与改写前一一对应(14 例)。

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

local _config_reset = require("test.support.config_reset")

TestLandSettlement = {}

function TestLandSettlement:setUp()
  _config_reset.reset_all()
end

function TestLandSettlement:test_begin_landing_settlement_opens_buy_choice_without_pipeline_args()
  local game = _new_game()
  local player = game.players[1]
  local index, tile = _first_land_tile(game.board)
  game:update_player_position(player, index)

  local result = settlement.begin_landing_settlement(game, player.id, {
    tile = tile,
    move_result = {},
  })

  lu.assertEvalToTrue(result and result.waiting == true, "empty land should wait on buy choice")
  _assert_eq(result.reason, "landing_optional", "landing seam should expose landing reason")

  local pending = game.turn.pending_choice
  lu.assertEvalToTrue(pending and pending.kind == "landing_optional_effect", "landing seam should open landing choice")
  _assert_eq(pending.meta.player_id, player.id, "choice should belong to landing actor")
  _assert_eq(pending.meta.tile_id, tile.id, "choice should target landed tile")
  _assert_eq(pending.options[1].id, "buy_land", "empty land should offer buy_land")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_executes_buy_land()
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

  lu.assertEvalToTrue(result and result.ok == true, "buy_land choice should resolve through settlement seam")
  _assert_eq(result.status, "resolved", "buy_land choice should expose resolved status")
  _assert_eq(game:player_cash(player), before_cash - tile.price, "buy_land should deduct tile price")
  _assert_eq(_tile_state(game, tile).owner_id, player.id, "buy_land should set owner")
end

function TestLandSettlement:test_option_matching_rejects_nils_and_supports_serialized_option_ids()
  local option_is_offered = settlement._M_test._option_is_offered

  lu.assertEvalToTrue(option_is_offered(nil, "buy_land") == false, "nil choice should not offer an option")
  lu.assertEvalToTrue(option_is_offered({ options = { { id = "buy_land" } } }, nil) == false,
    "nil option id should not be offered")
  lu.assertEvalToTrue(option_is_offered({ options = { { id = "buy_land" } } }, "upgrade_land") == false,
    "different option id should not be offered")
  lu.assertEvalToTrue(option_is_offered({ options = { { id = 7 } } }, "7") == true,
    "serialized option ids should match")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_dispatches_the_wrapper_when_the_effect_has_no_payload()
  -- kills _execute_landing_optional_target's `result.result or result` `or` -> `and`:
  -- buy_land's success apply returns no payload, so result.result is nil and
  -- the intent port must receive the wrapper result itself (the `and` mutant
  -- passes nil instead).
  local game = _new_game()
  local player = game.players[1]
  local index, tile = _first_land_tile(game.board)
  game:update_player_position(player, index)
  settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
  local pending = assert(game.turn.pending_choice, "missing landing choice")

  local intent_output_port = require("src.rules.ports.intent_output")
  local dispatched = {}
  with_patches({
    { target = intent_output_port, key = "dispatch", value = function(_, payload)
      dispatched[#dispatched + 1] = payload
    end },
  }, function()
    settlement.resolve_landing_settlement_choice(game, pending, { option_id = "buy_land" })
  end)
  _assert_eq(#dispatched, 1, "exactly one intent should be dispatched")
  lu.assertEvalToTrue(dispatched[1] ~= nil and dispatched[1].ok == true,
    "the dispatched payload should be the effect wrapper result, not nil")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_rejects_missing_option_id()
  local game = _new_game()
  local player = game.players[1]
  local index, tile = _first_land_tile(game.board)
  game:update_player_position(player, index)

  settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
  local pending = assert(game.turn.pending_choice, "missing landing choice")

  local missing = settlement.resolve_landing_settlement_choice(game, pending, {})
  lu.assertEvalToTrue(missing and missing.ok == false, "missing option id should be rejected")
  _assert_eq(missing.reason, "missing_landing_option", "missing option reason should be stable")

  local empty = settlement.resolve_landing_settlement_choice(game, pending, { option_id = "" })
  lu.assertEvalToTrue(empty and empty.ok == false, "empty option id should be rejected")
  _assert_eq(empty.reason, "missing_landing_option", "empty option reason should be stable")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_rejects_unoffered_option()
  local game = _new_game()
  local player = game.players[1]
  local index, tile = _first_land_tile(game.board)
  game:update_player_position(player, index)

  settlement.begin_landing_settlement(game, player.id, { tile = tile, move_result = {} })
  local pending = assert(game.turn.pending_choice, "missing landing choice")

  local result = settlement.resolve_landing_settlement_choice(game, pending, {
    option_id = "upgrade_land",
  })

  lu.assertEvalToTrue(result and result.ok == false, "unoffered option should be rejected")
  _assert_eq(result.reason, "landing_option_not_offered", "rejection reason should be stable")
  _assert_eq(_tile_state(game, tile).owner_id, nil, "rejected choice should not change owner")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_rejects_meta_option_not_in_choice_options()
  local game = _new_game()
  local player = game.players[1]
  local index, tile = _first_land_tile(game.board)
  game:update_player_position(player, index)
  local choice = _manual_landing_choice(player, tile, { "buy_land" }, {})

  local result = settlement.resolve_landing_settlement_choice(game, choice, {
    option_id = "buy_land",
  })

  lu.assertEvalToTrue(result and result.ok == false, "meta-only option should be rejected")
  _assert_eq(result.reason, "landing_option_not_offered", "choice options should be authoritative")
  _assert_eq(_tile_state(game, tile).owner_id, nil, "rejected choice should not change owner")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_rejects_unknown_landing_effect()
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

  lu.assertEvalToTrue(result and result.ok == false, "unknown landing effect should be rejected")
  _assert_eq(result.reason, "landing_effect_not_found", "unknown effect reason should be stable")
  _assert_eq(_tile_state(game, tile).owner_id, nil, "unknown effect should not change owner")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_rejects_blocked_effect_execution()
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

  lu.assertEvalToTrue(result and result.ok == false, "blocked effect execution should be rejected")
  _assert_eq(result.reason, "blocked_for_test", "blocked effect reason should be preserved")
  _assert_eq(_tile_state(game, tile).owner_id, nil, "blocked effect should not change owner")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_dispatches_rent_card_prompt_to_rent_settlement()
  -- 分发器的四条臂里,rent 这条此前只有「choice 已开出」和 handler stub 掉分发的测试,
  -- 没有任何 spec 把 rent_card_prompt 真驱过 settlement 分发。于是 kind 比较值可以被
  -- 改掉而不被任何测试察觉(变异幸存)。tax 臂有端到端覆盖,rent 臂补齐对称。
  local game = _new_game()
  local tenant = game.players[1]
  local owner = game.players[2]
  local index, tile = _first_land_tile(game.board)

  game:set_tile_owner(tile, owner.id)
  game:set_tile_level(tile, 1)
  game:set_player_property(owner, tile.id, true)
  game:update_player_position(tenant, index)

  local before_cash = game:player_cash(tenant)
  -- card_kind = "free" 且 option_id 非 "use":绕开选卡执行与 strong 的自动免租回退,
  -- 让结算必然落到付租金那一路,断言不依赖道具库存。
  local result = settlement.resolve_landing_settlement_choice(game, {
    kind = "rent_card_prompt",
    meta = { player_id = tenant.id, tile_id = tile.id, card_kind = "free" },
  }, { option_id = "pay" })

  lu.assertEvalToTrue(result and result.ok == true, "rent_card_prompt should resolve through the rent settlement arm")
  _assert_eq(result.status, "resolved", "rent prompt should expose resolved status")
  _assert_eq(result.effect_id, "pay_rent", "declining the card should settle as pay_rent")
  _assert_eq(before_cash - game:player_cash(tenant), pricing.rent_for_level(tile, 1),
    "rent arm should deduct the tile rent from the tenant")
end

function TestLandSettlement:test_resolve_landing_settlement_choice_rejects_unknown_choice_kind()
  local game = _new_game()
  local player = game.players[1]
  local _, tile = _first_land_tile(game.board)

  local result = settlement.resolve_landing_settlement_choice(game, {
    kind = "ghost_prompt",
    meta = { player_id = player.id, tile_id = tile.id },
  }, { option_id = "pay" })

  lu.assertEvalToTrue(result and result.ok == false, "an unknown choice kind should be rejected")
  _assert_eq(result.reason, "not_landing_choice", "unknown kind reason should be stable")
end

function TestLandSettlement:test_begin_landing_settlement_rejects_missing_actor()
  local game = _new_game()
  local _, tile = _first_land_tile(game.board)

  local result = settlement.begin_landing_settlement(game, 9999, { tile = tile })

  lu.assertEvalToTrue(result and result.ok == false, "missing actor should be rejected")
  _assert_eq(result.reason, "missing_actor", "missing actor reason should be stable")
end

function TestLandSettlement:test_pin_pay_tax_deducts_floor_cash_rate_and_defers_bankruptcy_via_bankrupt_reason()
  local game = _new_game()
  local player = game.players[1]
  local constants = require("src.config.content.constants")
  game:set_player_cash(player, 1000)

  local expected_fee = math.floor(1000 * constants.tax_rate)
  local result = tax_rules.execute_pay_tax(game, player.id)

  lu.assertEvalToTrue(game:player_cash(player) == 1000 - expected_fee, "tax deducts floor(cash*rate)")
  lu.assertEvalToTrue(result.event == "tax_paid", "event stays tax_paid")
  lu.assertEvalToTrue(result.bankrupt_reason == nil, "solvent taxpayer has no bankrupt_reason")
  lu.assertEvalToTrue(player.eliminated ~= true, "eliminate is deferred to land_events, not here")
end

function TestLandSettlement:test_pin_pay_tax_at_zero_cash_reports_bankrupt_reason_but_does_not_eliminate_in_place()
  local game = _new_game()
  local player = game.players[1]
  game:set_player_cash(player, 0)  -- fee = floor(0*rate) = 0 → cash 仍 0,<= 0 → bankrupt_reason

  local result = tax_rules.execute_pay_tax(game, player.id)

  lu.assertEvalToTrue(result.bankrupt_reason == player.name .. " 支付税金后破产", "reason set on non-positive")
  lu.assertEvalToTrue(player.eliminated ~= true, "still deferred; land_events owns the eliminate call")
end



function TestLandSettlement:test_landing_effect_failure_without_reason_uses_fallback()
  -- #293:_execute_landing_optional_target 的 `result.reason or "landing_effect_blocked"`
  -- 兜底(→ nil 变异)未测——effect 失败且无 reason 时走兜底文案。
  local saved_execute = effect_runner.execute
  effect_runner.execute = function()
    return { ok = false }
  end
  local player = { id = "p1" }
  local game = {
    turn = { choice_elapsed_seconds = 0 },
    dirty = {},
    players = { player },
    find_player_by_id = function(_, role_id)
      if role_id == "p1" then return player end
      return nil
    end,
    board = {
      get_tile = function(_, index) return { id = index, type = "land" } end,
      get_tile_by_id = function(_, tile_id) return { id = tile_id, type = "land" } end,
    },
  }
  local result = settlement.resolve_landing_settlement_choice(
    game,
    {
      kind = "landing_optional_effect",
      options = { { id = "buy_land" } },
      meta = {
        target_effect = { effect_id = "buy_land" },
        move_result = {},
        player_id = "p1",
        tile_id = "t3",
      },
    },
    { option_id = "buy_land" }
  )
  effect_runner.execute = saved_execute
  lu.assertEvalToTrue(result ~= nil and result.ok == false,
    "failing effect should reject the choice")
  lu.assertEvalToTrue(tostring(result.reason) == "landing_effect_blocked",
    "reason-less failure should use the landing_effect_blocked fallback; got "
      .. tostring(result.reason))
end

return TestLandSettlement
