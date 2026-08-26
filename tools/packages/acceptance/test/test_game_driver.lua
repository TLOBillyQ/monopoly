local lu = require("luaunit")
local game_driver = require("packages.acceptance.game_driver")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")

local TEST_PRODUCT_ID = 2003

local function _land_with_building(ctx, owner_id, level)
  local idx = game_driver.first_land_tile(ctx)
  local tile = ctx.game.board:get_tile(idx)
  ctx.game:set_tile_owner(tile, owner_id)
  ctx.game:set_tile_level(tile, level)
  return idx, tile
end

local function _saw_event(ctx, kind)
  for _, event in ipairs(game_driver.events(ctx)) do
    if event.kind == kind then
      return true
    end
  end
  return false
end

local function _option(view, product_id)
  for _, opt in ipairs(view.options or {}) do
    if opt.id == product_id then
      return opt
    end
  end
  return nil
end

TestGameDriver = {}

function TestGameDriver:test_returns_a_context_with_a_real_game_instance()
  local ctx = game_driver.new_game()
  lu.assertIsTable(ctx)
  lu.assertIsTable(ctx.game)
  lu.assertIsTable(ctx.game.players)
  lu.assertTrue(#ctx.game.players >= 2)
end

function TestGameDriver:test_creates_players_starting_at_position_1()
  local ctx = game_driver.new_game()
  local player = ctx.game.players[1]
  lu.assertIs(player.position, 1)
end

function TestGameDriver:test_provides_outer_ring_size()
  local ctx = game_driver.new_game()
  lu.assertIs(ctx.outer_ring_size, 32)
end

-- #164：new_game 必须先把会触碰的进程级全局端口 reset 到已知基线再 configure，
-- 每个 ctx 不依赖上一个套件善后（原先只是注释纪律）。
TestGameDriverGlobalPortBaseline = {}

function TestGameDriverGlobalPortBaseline:tearDown()
  runtime_ports.reset_for_tests()
  paid_purchase_port.reset_for_tests()
end

function TestGameDriverGlobalPortBaseline:test_resets_both_global_ports_before_configuring_its_own()
  local calls = {}
  local originals = {
    runtime_reset = runtime_ports.reset_for_tests,
    paid_reset = paid_purchase_port.reset_for_tests,
    runtime_configure = runtime_ports.configure,
    paid_configure = paid_purchase_port.configure,
  }
  runtime_ports.reset_for_tests = function()
    calls[#calls + 1] = "runtime_reset"
    return originals.runtime_reset()
  end
  paid_purchase_port.reset_for_tests = function()
    calls[#calls + 1] = "paid_reset"
    return originals.paid_reset()
  end
  runtime_ports.configure = function(...)
    calls[#calls + 1] = "runtime_configure"
    return originals.runtime_configure(...)
  end
  paid_purchase_port.configure = function(...)
    calls[#calls + 1] = "paid_configure"
    return originals.paid_configure(...)
  end
  local ok, err = pcall(game_driver.new_game)
  runtime_ports.reset_for_tests = originals.runtime_reset
  paid_purchase_port.reset_for_tests = originals.paid_reset
  runtime_ports.configure = originals.runtime_configure
  paid_purchase_port.configure = originals.paid_configure
  lu.assertEvalToTrue(ok, err)
  local first_configure, last_reset = nil, nil
  for index, name in ipairs(calls) do
    if name:find("configure", 1, true) and first_configure == nil then
      first_configure = index
    end
    if name:find("reset", 1, true) then
      last_reset = index
    end
  end
  lu.assertIsNumber(first_configure, "new_game should configure its ports")
  lu.assertIsNumber(last_reset, "new_game should reset both global ports")
  lu.assertTrue(last_reset < first_configure,
    "every reset must happen before the first configure")
  local reset_count = 0
  for _, name in ipairs(calls) do
    if name:find("reset", 1, true) then
      reset_count = reset_count + 1
    end
  end
  lu.assertIs(reset_count, 2, "both global ports should be reset")
end

function TestGameDriverGlobalPortBaseline:test_clears_leftover_runtime_port_config_from_a_previous_suite()
  runtime_ports.configure({
    rng_next_int = function() return 1 end,
    resolve_role = function() return "leftover" end,
  })
  game_driver.new_game()
  lu.assertNil(runtime_ports.resolve_role(1))
  lu.assertIsNumber(runtime_ports.rng_next_int(1, 6))
end

function TestGameDriverGlobalPortBaseline:test_replaces_a_leftover_paid_gateway_with_the_driver_noop_gateway()
  paid_purchase_port.configure({
    setup_for_game = function() end,
    can_start = function() return true, "leftover" end,
    start = function() return true, "leftover" end,
  })
  local ctx = game_driver.new_game()
  local ok, reason = paid_purchase_port.can_start(ctx.game, ctx.game.players[1], {})
  lu.assertFalse(ok)
  lu.assertIs(reason, "acceptance_noop")
end

function TestGameDriver:test_returns_the_first_player()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  lu.assertIs(player, ctx.game.players[1])
end

function TestGameDriver:test_updates_player_position_via_game_api()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  game_driver.set_player_position(ctx, player, 10)
  lu.assertIs(player.position, 10)
end

function TestGameDriver:test_moves_player_forward_using_rules_movement_move()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  local result = game_driver.move(ctx, player, 3)
  lu.assertIs(player.position, 4)
  lu.assertIs(result.passed_start, 0)
  lu.assertIs(#result.visited, 3)
end

function TestGameDriver:test_tracks_pass_start_when_wrapping_around_outer_ring()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  game_driver.set_player_position(ctx, player, 30)
  game_driver.clear_move_state(ctx, player)
  local result = game_driver.move(ctx, player, 5)
  lu.assertIs(result.passed_start, 1)
end

function TestGameDriver:test_queues_deterministic_dice_results()
  local ctx = game_driver.new_game()
  game_driver.set_next_rolls(ctx, {3, 5, 7})
  lu.assertIs(ctx.game.rng:next_int(1, 6), 3)
  lu.assertIs(ctx.game.rng:next_int(1, 6), 5)
  lu.assertIs(ctx.game.rng:next_int(1, 6), 7)
end

function TestGameDriver:test_returns_current_player_position()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  game_driver.set_player_position(ctx, player, 15)
  lu.assertIs(game_driver.player_position(ctx, player), 15)
end

-- #165:道具/棋盘观察动词——step 模块经 driver 而非直 require src.rules 内部。
function TestGameDriver:test_clear_items_items_of_round_trip_through_real_inventory()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  game_driver.give_item(ctx, player, 1)
  lu.assertTrue(#game_driver.items_of(ctx, player) >= 1)
  game_driver.clear_items(ctx, player)
  lu.assertIs(#game_driver.items_of(ctx, player), 0)
end

function TestGameDriver:test_open_item_phase_opens_a_pending_choice_and_reports_availability()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  game_driver.give_item(ctx, player, item_ids.remote_dice)
  lu.assertTrue((game_driver.item_offer_allowed(ctx, player, item_ids.remote_dice, "pre_action")))
  local spec = game_driver.open_item_phase(ctx, player, "pre_action", { next_state = "wait_action" })
  lu.assertIsTable(spec)
  lu.assertIsTable(ctx.game.turn.pending_choice)
end

function TestGameDriver:test_target_candidates_reads_the_real_item_registry_candidate_face()
  local ctx = game_driver.new_game()
  local user = game_driver.current_player(ctx)
  local opponent = ctx.game.players[2]

  lu.assertIs(#game_driver.target_candidates(ctx, user, item_ids.invite_deity), 0)
  game_driver.set_player_deity(ctx, opponent, "rich", 3)
  local candidates = game_driver.target_candidates(ctx, user, item_ids.invite_deity)
  lu.assertIs(#candidates, 1)
  lu.assertIs(candidates[1], opponent)
end

function TestGameDriver:test_tile_indices_in_range_reflects_real_board_geometry()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  local indices = game_driver.tile_indices_in_range(ctx, player.position, 3)
  lu.assertTrue(#indices > 0)
end

function TestGameDriver:test_returns_player_balance_via_game_api()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  local cash = game_driver.player_cash(ctx, player)
  lu.assertIsNumber(cash)
  lu.assertTrue(cash > 0)
end

-- #199:拆除类道具「使用」动词——真实消耗卡牌 + 真实拆迁应用(含送医),
-- 绑定层不再用夹具模型模拟应用结果。
function TestGameDriver:test_consumes_the_monster_card_and_levels_the_target_building_through_the_real_apply()
  local ctx = game_driver.new_game()
  local player, opponent = ctx.game.players[1], ctx.game.players[2]
  local idx, tile = _land_with_building(ctx, opponent.id, 2)
  game_driver.give_item(ctx, player, item_ids.monster)

  local result = game_driver.use_demolish_on(ctx, player, idx, item_ids.monster)

  lu.assertIsTable(result)
  lu.assertIs(tile.level, 0, "the building is demolished by the real apply")
  lu.assertFalse(game_driver.has_item(ctx, player, item_ids.monster),
    "the monster card is consumed by the use")
end

function TestGameDriver:test_missile_injures_occupants_the_bombed_opponent_relocates_to_the_hospital_tile()
  local ctx = game_driver.new_game()
  local player, opponent = ctx.game.players[1], ctx.game.players[2]
  local idx, tile = _land_with_building(ctx, player.id, 2)
  game_driver.set_player_position(ctx, opponent, idx)
  game_driver.give_item(ctx, player, item_ids.missile)

  game_driver.use_demolish_on(ctx, player, idx, item_ids.missile)

  lu.assertIs(tile.level, 0, "missile demolishes the building on the bombed tile")
  lu.assertIs(game_driver.tile_at(ctx, opponent.position).type, "hospital",
    "the bombed opponent is sent to hospital")
  lu.assertFalse(game_driver.has_item(ctx, player, item_ids.missile),
    "the missile card is consumed by the use")
end

function TestGameDriver:test_angel_immunity_blocks_the_demolition_and_publishes_the_feedback_event()
  local ctx = game_driver.new_game()
  local player, opponent = ctx.game.players[1], ctx.game.players[2]
  local _, tile = _land_with_building(ctx, opponent.id, 2)
  game_driver.set_player_deity(ctx, opponent, "angel")
  game_driver.give_item(ctx, player, item_ids.monster)

  local idx = game_driver.first_land_tile(ctx)
  game_driver.use_demolish_on(ctx, player, idx, item_ids.monster)

  lu.assertIs(tile.level, 2, "angel immunity keeps the building standing")
  lu.assertTrue(_saw_event(ctx, event_kinds.item_immune),
    "the angel protection feedback event is published")
end

function TestGameDriver:test_refuses_items_that_are_not_demolish_items()
  local ctx = game_driver.new_game()
  local player = ctx.game.players[1]
  local idx = game_driver.first_land_tile(ctx)
  game_driver.give_item(ctx, player, item_ids.roadblock)
  lu.assertError(function()
    game_driver.use_demolish_on(ctx, player, idx, item_ids.roadblock)
  end)
end

-- #199:item_slot 点击派发动词——封装「点击某槽位」的 UI 意图到 action dispatch,
-- 绑定层不再直接触碰 src.turn.actions 内部模块。
function TestGameDriver:test_dispatches_a_real_slot_click_applied_and_the_item_follow_up_choice_opens()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  game_driver.clear_items(ctx, player)
  game_driver.give_item(ctx, player, item_ids.remote_dice)
  local spec = game_driver.open_item_phase(ctx, player, "pre_action", { next_state = "wait_action" })
  lu.assertIsTable(spec)
  local phase_choice_id = assert(ctx.game.turn.pending_choice).id

  local result = game_driver.click_item_slot(ctx, player, 1)

  lu.assertIs(result and result.status, "applied")
  local pending = ctx.game.turn.pending_choice
  lu.assertEvalToTrue(pending ~= nil and pending.id ~= phase_choice_id,
    "the slot click opens the item's follow-up choice")
end

-- #201:黑市只读视角——不开窗读取陈列与售罄/可购标记。
function TestGameDriver:test_returns_the_catalog_view_without_opening_a_market_window()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)
  ctx.game.market_limits[TEST_PRODUCT_ID] = 0

  local view = game_driver.peek_market(ctx, player)

  lu.assertIsTable(view)
  lu.assertNil(ctx.game.turn.pending_choice, "peek must not open a market window")
  local opt = assert(_option(view, TEST_PRODUCT_ID), "sold-out product stays listed")
  lu.assertTrue(opt.sold_out, "sold-out flag is visible in the read-only view")
  lu.assertFalse(opt.can_buy, "a sold-out product is not buyable")
end

function TestGameDriver:test_marks_a_stocked_product_as_buyable()
  local ctx = game_driver.new_game()
  local player = game_driver.current_player(ctx)

  local view = game_driver.peek_market(ctx, player)

  local opt = assert(_option(view, TEST_PRODUCT_ID), "stocked product is listed")
  lu.assertFalse(opt.sold_out, "a stocked product is not marked sold out")
  lu.assertTrue(opt.can_buy, "a stocked product is buyable")
end


return TestGameDriver
