-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _resolve_landing = support.resolve_landing
local _visited_tile_ids = support.visited_tile_ids
local _list_contains = support.list_contains
local _first_tile_by_type = support.first_tile_by_type
local _with_patches = support.with_patches
local _assert_eq = support.assert_eq
local chance_effects = require("src.rules.chance.resolver")
local movement = require("src.rules.movement")
local function _action_anim_count(game)
  local count = 0
  if game.turn.action_anim then
    count = count + 1
  end
  return count + #(game.turn.action_anim_queue or {})
end

local chance_handlers = require("src.rules.chance.handlers")

TestChance = {}

function TestChance:setUp()
  local _config_reset = require("test.support.config_reset")
  _config_reset.reset_all()
end

function TestChance:test_chance_draw_uses_injected_rng_and_ignores_lua_api_rand()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)

  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local rng_calls = {}
  g.rng = {
    next_int = function(_, min, max)
      rng_calls[#rng_calls + 1] = { min = min, max = max }
      return 1
    end,
  }

  local prev_lua_api = LuaAPI
  local lua_api = prev_lua_api or {}
  local called_rand = 0
  _with_patches({
    { key = "LuaAPI", value = lua_api },
    { target = lua_api, key = "rand", value = function()
      called_rand = called_rand + 1
      error("chance draw should not call LuaAPI.rand")
    end },
  }, function()
    _resolve_landing(g, p, tile_ref, {})
  end)

  lu.assertEvalToTrue(#rng_calls == 1, "chance draw should use injected rng exactly once")
  _assert_eq(rng_calls[1].min, 1, "chance draw should start from 1")
  lu.assertEvalToTrue(rng_calls[1].max > 0, "chance draw should use a positive upper bound")
  _assert_eq(called_rand, 0, "chance draw should not touch LuaAPI.rand")
  lu.assertEvalToTrue(g.turn.action_anim and g.turn.action_anim.kind == "chance", "chance draw should queue a chance anim")
  _assert_eq(g.turn.action_anim.card_id, 3001, "chance draw should pick the first card with deterministic rng")
end

function TestChance:test_chance_move_backward_pass_market()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  lu.assertEvalToTrue(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  lu.assertEvalToTrue(_list_contains(visited_ids, 39), "backward move should pass market")
  lu.assertEvalToTrue(out.move_result.market_interrupt == nil, "backward move should not trigger market interrupt")
  _assert_eq(p.status.move_dir, "down", "move_backward should preserve recorded forward heading")
end

function TestChance:test_chance_move_backward_pass_intersection()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  lu.assertEvalToTrue(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  lu.assertEvalToTrue(_list_contains(visited_ids, 45), "backward move should pass intersection")
  _assert_eq(p.status.move_dir, "down", "move_backward should preserve heading across intersections")
end

function TestChance:test_chance_move_backward_queues_move_effect_anim()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  lu.assertEvalToTrue(out and out.move_result, "move_backward should return move result")
  lu.assertEvalToTrue(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "move_backward should queue move_effect anim")
  _assert_eq(g.turn.action_anim.to_index, p.position, "move_effect to_index should match player position")
  _assert_eq(out.wait_move_anim, false, "move_backward should not signal wait_move_anim when only action_anim gate is open")
end

function TestChance:test_chance_move_backward_queues_move_anim_when_gate_open()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = true }
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local from_index = p.position
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  lu.assertEvalToTrue(out and out.move_result, "move_backward should return move result")
  _assert_eq(out.wait_move_anim, true, "move_backward should signal wait_move_anim when move_anim gate is open")
  lu.assertEvalToTrue(g.turn.move_anim ~= nil, "move_backward should queue an entry on the move_anim channel")
  _assert_eq(g.turn.move_anim.player_id, p.id, "queued move_anim should target the moving player")
  _assert_eq(g.turn.move_anim.from_index, from_index, "queued move_anim should record the start tile index")
  _assert_eq(g.turn.move_anim.to_index, p.position, "queued move_anim should record the destination tile index")
  lu.assertEvalToTrue(g.turn.move_anim.seq ~= nil, "queued move_anim should carry a sequence id")
  _assert_eq(g.turn.action_anim, nil, "move_backward should not queue an action_anim entry when move_anim gate is open")
end

function TestChance:test_chance_move_forward_queues_move_anim_when_gate_open()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = true }
  local p = g:current_player()
  local from_index = p.position
  local out = chance_effects.resolve(g, p, { effect = "move_forward", steps = 3, target = "self" }, {})
  lu.assertEvalToTrue(out and out.move_result, "move_forward should return move result")
  _assert_eq(out.wait_move_anim, true, "move_forward should signal wait_move_anim when move_anim gate is open")
  lu.assertEvalToTrue(g.turn.move_anim ~= nil, "move_forward should queue an entry on the move_anim channel")
  _assert_eq(g.turn.move_anim.from_index, from_index, "queued move_anim should record the start tile index")
  _assert_eq(g.turn.move_anim.to_index, p.position, "queued move_anim should record the destination tile index")
  _assert_eq(g.turn.action_anim, nil, "move_forward should not queue an action_anim entry when move_anim gate is open")
end

function TestChance:test_chance_move_backward_without_move_dir_uses_stable_fallback()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", nil)
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 1, target = "self" }, {})
  lu.assertEvalToTrue(out and out.move_result, "move_backward without move_dir should still return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  _assert_eq(#visited_ids, 1, "move_backward fallback should record one visited tile")
  _assert_eq(visited_ids[1], 3, "move_backward without move_dir should stably fallback to outer_prev")
  _assert_eq(p.status.move_dir, nil, "move_backward fallback should not record a backward heading")
end

function TestChance:test_chance_move_backward_uses_arrival_direction_on_immediate_landing()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(25))
  g:set_player_status(p, "move_dir", "right")

  local landing_result = movement.move(g, p, -1, { skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 40, "setup should land on the outer chance tile")
  _assert_eq(p.status.move_dir, "right", "setup should preserve the recorded forward heading")

  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 1, target = "self" }, landing_result)

  lu.assertEvalToTrue(out and out.move_result, "move_backward should return move result when triggered from landing")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  _assert_eq(#visited_ids, 1, "immediate landing retreat should move exactly one tile")
  _assert_eq(visited_ids[1], 25, "immediate landing retreat should go back along the arrival edge")
  _assert_eq(g.board:get_tile(p.position).id, 25, "immediate landing retreat should return to the inner tile")
  _assert_eq(p.status.move_dir, "right", "immediate landing retreat should still preserve forward heading")
end

function TestChance:test_chance_forced_move_queues_move_effect_anim()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  g:set_player_status(p, "move_dir", "left")
  local dest = 38
  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination_tile_id = dest,
    target = "self",
  }, {})
  local idx = g.board:index_of_tile_id(dest)
  lu.assertEvalToTrue(out and out.kind == "need_landing", "forced_move destination tile should return need_landing")
  _assert_eq(out.board_index, idx, "forced_move board_index should match destination")
  lu.assertEvalToTrue(g.turn.action_anim and g.turn.action_anim.kind == "forced_relocation", "forced_move should queue forced relocation anim")
  _assert_eq(g.turn.action_anim.to_index, idx, "forced_move anim to_index should match destination")
  _assert_eq(p.status.move_dir, "left", "forced_move destination tile should preserve move_dir")
end

function TestChance:test_chance_forced_move_to_market_sets_default_forward_heading()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  g:set_player_status(p, "move_dir", "left")
  local market_idx = assert(g.board:find_first_by_type("market"), "missing market tile")

  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination_tile_id = 39,
    target = "self",
  }, {})

  lu.assertEvalToTrue(out and out.kind == "need_landing", "forced_move market should return need_landing")
  _assert_eq(out.board_index, market_idx, "forced_move market should land on market tile")
  _assert_eq(g.turn.action_anim.kind, "forced_relocation", "forced_move market should queue forced relocation anim kind")
  _assert_eq(p.status.move_dir, "right", "forced_move market should default to counterclockwise heading")
end

function TestChance:test_chance_forced_move_to_hospital_clears_move_dir()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  g:set_player_status(p, "move_dir", "left")
  local hospital_idx = assert(g.board:find_first_by_type("hospital"), "missing hospital tile")

  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination_tile_id = 36,
    target = "self",
  }, {})

  lu.assertEvalToTrue(out and out.kind == "need_landing", "forced_move hospital should continue into landing flow")
  _assert_eq(out.board_index, hospital_idx, "forced_move hospital should land on hospital tile")
  _assert_eq(g.turn.action_anim.kind, "forced_relocation", "forced_move hospital should queue forced relocation anim kind")
  _assert_eq(p.status.move_dir, nil, "forced_move hospital should clear move_dir")
end

function TestChance:test_chance_handlers_build_returns_handler_table()
  local handlers = chance_handlers.build()
  lu.assertEvalToTrue(type(handlers) == "table", "chance_handlers.build should return a table")
  lu.assertEvalToTrue(type(handlers.handlers) == "table", "chance_handlers.build should return nested handlers table")
  lu.assertEvalToTrue(type(handlers.add_cash) == "function", "chance_handlers should register add_cash handler")
  lu.assertEvalToTrue(type(handlers.pay_cash) == "function", "chance_handlers should register pay_cash handler")
  lu.assertEvalToTrue(type(handlers.percent_pay_cash) == "function", "chance_handlers should register percent_pay_cash handler")
  lu.assertEvalToTrue(type(handlers.pay_others) == "function", "chance_handlers should register pay_others handler")
  lu.assertEvalToTrue(type(handlers.collect_from_others) == "function", "chance_handlers should register collect_from_others handler")
  lu.assertEvalToTrue(type(handlers.move_backward) == "function", "chance_handlers should register move_backward handler")
  lu.assertEvalToTrue(type(handlers.move_forward) == "function", "chance_handlers should register move_forward handler")
  lu.assertEvalToTrue(type(handlers.forced_move) == "function", "chance_handlers should register forced_move handler")
  lu.assertEvalToTrue(type(handlers.destroy_buildings_on_path) == "function", "chance_handlers should register destroy_buildings_on_path handler")
  lu.assertEvalToTrue(type(handlers.reset_tiles_on_path) == "function", "chance_handlers should register reset_tiles_on_path handler")
  lu.assertEvalToTrue(type(handlers.grant_item) == "function", "chance_handlers should register grant_item handler")
  lu.assertEvalToTrue(type(handlers.discard_items) == "function", "chance_handlers should register discard_items handler")
  lu.assertEvalToTrue(type(handlers.discard_properties) == "function", "chance_handlers should register discard_properties handler")
end

function TestChance:test_chance_handler_add_cash_applies_to_all_players()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local events = {}

  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.add_cash(g, p, { effect = "add_cash", amount = 100, target = "all" })
  end)

  lu.assertEvalToTrue(#events >= 2, "add_cash with target=all should emit events for all players")
  lu.assertEvalToTrue(events[1].effect == "add_cash", "add_cash event should have correct effect")
  lu.assertEvalToTrue(events[1].text:find("获得"), "add_cash event text should indicate gain")
end

function TestChance:test_chance_handler_add_cash_queues_cash_anim_for_all_players()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

  handlers.add_cash(g, p, { effect = "add_cash", amount = 100, target = "all" })

  lu.assertEvalToTrue(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "add_cash should queue cash_receive anim")
  _assert_eq(_action_anim_count(g), #g.players, "add_cash should queue one cash anim per player")
end

function TestChance:test_chance_handler_pay_cash_applies_to_single_player()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local before_cash = g:player_cash(p)
  local events = {}

  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.pay_cash(g, p, { effect = "pay_cash", amount = 50, target = "self" })
  end)

  lu.assertEvalToTrue(g:player_cash(p) < before_cash, "pay_cash should reduce player cash")
  lu.assertEvalToTrue(#events == 1, "pay_cash should emit one event for single player")
  lu.assertEvalToTrue(events[1].effect == "pay_cash", "pay_cash event should have correct effect")
  lu.assertEvalToTrue(events[1].text:find("支付"), "pay_cash event text should indicate payment")
end

function TestChance:test_set_player_cash_does_not_queue_cash_anim()
  local g = _new_game()
  local p = g:current_player()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

  g:set_player_cash(p, 12345)

  lu.assertEvalToTrue(g.turn.action_anim == nil, "set_player_cash should not queue gameplay cash anim")
  _assert_eq(_action_anim_count(g), 0, "set_player_cash should not enqueue any cash anims")
end

function TestChance:test_chance_handler_percent_pay_cash_calculates_correctly()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  g:set_player_cash(p, 1000)
  local events = {}

  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.percent_pay_cash(g, p, { effect = "percent_pay_cash", percent = 10, target = "self" })
  end)

  lu.assertEvalToTrue(g:player_cash(p) == 900, "percent_pay_cash should deduct 10% of 1000")
  lu.assertEvalToTrue(#events == 1, "percent_pay_cash should emit one event")
  lu.assertEvalToTrue(events[1].text:find("按比例支付"), "percent_pay_cash event text should indicate proportional payment")
end

function TestChance:test_chance_handler_grant_item_gives_item_to_player()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local item_count_before = inventory.count(p)

  handlers.grant_item(g, p, { effect = "grant_item", item_id = item_ids.free_rent })

  lu.assertEvalToTrue(inventory.count(p) > item_count_before, "grant_item should increase player item count")
end

function TestChance:test_chance_handler_grant_item_queues_reveal_after_chance_card_anim()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  g.turn.action_anim = { seq = 5, kind = "chance", player_id = p.id }
  g.turn.action_anim_seq = 5

  handlers.grant_item(g, p, { effect = "grant_item", item_id = item_ids.free_rent })

  local queue = g.turn.action_anim_queue or {}
  _assert_eq(#queue, 1, "grant item should queue reveal behind chance anim")
  _assert_eq(queue[1].kind, "item_gain_popup", "grant item reveal kind mismatch")
  _assert_eq(queue[1].item_id, item_ids.free_rent, "grant item reveal item mismatch")
  _assert_eq(queue[1].player_id, p.id, "grant item reveal player mismatch")
  _assert_eq(queue[1].source, "chance", "grant item reveal source mismatch")
end

function TestChance:test_chance_handler_discard_items_removes_items()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  inventory.give(p, item_ids.free_rent, { game = g })
  local item_count_before = inventory.count(p)
  local events = {}

  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.discard_items(g, p, { effect = "discard_items", count = 1 })
  end)

  lu.assertEvalToTrue(inventory.count(p) < item_count_before, "discard_items should reduce player item count")
  lu.assertEvalToTrue(#events == 1, "discard_items should emit one event")
  lu.assertEvalToTrue(events[1].text:find("丢弃道具"), "discard_items event text should indicate item discard")
end

function TestChance:test_chance_handler_discard_items_uses_injected_rng_for_random_pick()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  inventory.give(p, item_ids.free_rent, { game = g })
  inventory.give(p, item_ids.tax_free, { game = g })
  local events = {}
  local rng_calls = {}

  g.rng = {
    next_int = function(_, min, max)
      rng_calls[#rng_calls + 1] = { min = min, max = max }
      return 2
    end,
  }

  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.discard_items(g, p, { effect = "discard_items", count = 1 })
  end)

  lu.assertEvalToTrue(#rng_calls == 1, "discard_items should use injected rng exactly once when dropping one item")
  _assert_eq(rng_calls[1].min, 1, "discard_items rng should start at 1")
  _assert_eq(rng_calls[1].max, 2, "discard_items rng upper bound should match current item count")
  lu.assertEvalToTrue(inventory.find_index(p, item_ids.free_rent) ~= nil, "discard_items should keep the first item when rng picks the second")
  lu.assertEvalToTrue(inventory.find_index(p, item_ids.tax_free) == nil, "discard_items should remove the rng-selected item")
  lu.assertEvalToTrue(#events == 1, "discard_items should emit one event")
end

function TestChance:test_chance_handler_move_forward_moves_player()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local start_pos = p.position

  local out = handlers.move_forward(g, p, { effect = "move_forward", steps = 3, target = "self" })

  lu.assertEvalToTrue(out and out.kind == "need_landing", "move_forward should return need_landing")
  lu.assertEvalToTrue(p.position ~= start_pos, "move_forward should change player position")
end

function TestChance:test_chance_handler_collect_from_others_queues_batched_actor_anim()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  for i = 2, #g.players do
    g:set_player_cash(g.players[i], 1000)
  end
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

  handlers.collect_from_others(g, p, { effect = "collect_from_others", amount = 100, target = "self" })

  lu.assertEvalToTrue(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "collect_from_others should queue cash_receive anim")
  _assert_eq(_action_anim_count(g), 1, "collect_from_others should collapse into one summary anim")
  _assert_eq(g.turn.action_anim.amount, (#g.players - 1) * 100, "collect_from_others summary anim should use total collected amount")
end

function TestChance:test_chance_handler_discard_properties_removes_properties()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()

  -- Give player a property first
  local tile_id = 2
  g:set_player_property(p, tile_id, true)
  lu.assertEvalToTrue(p.properties[tile_id] == true, "precondition: player should have property")

  local events = {}
  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.discard_properties(g, p, { effect = "discard_properties", count = 1 })
  end)

  lu.assertEvalToTrue(p.properties[tile_id] == nil or p.properties[tile_id] == false, "discard_properties should remove player property")
  lu.assertEvalToTrue(#events >= 1, "discard_properties should emit events")
end

function TestChance:test_chance_handler_discard_properties_uses_injected_rng_for_random_pick()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local first_tile_id = 2
  local second_tile_id = 4
  g:set_player_property(p, first_tile_id, true)
  g:set_player_property(p, second_tile_id, true)
  local events = {}
  local rng_calls = {}

  g.rng = {
    next_int = function(_, min, max)
      rng_calls[#rng_calls + 1] = { min = min, max = max }
      return 2
    end,
  }

  _with_patches({
    { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.discard_properties(g, p, { effect = "discard_properties", count = 1 })
  end)

  lu.assertEvalToTrue(#rng_calls == 1, "discard_properties should use injected rng exactly once when dropping one property")
  _assert_eq(rng_calls[1].min, 1, "discard_properties rng should start at 1")
  _assert_eq(rng_calls[1].max, 2, "discard_properties rng upper bound should match current property count")
  lu.assertEvalToTrue(p.properties[first_tile_id] == true, "discard_properties should keep the first property when rng picks the second")
  lu.assertEvalToTrue(p.properties[second_tile_id] == nil or p.properties[second_tile_id] == false, "discard_properties should remove the rng-selected property")
  lu.assertEvalToTrue(#events >= 1, "discard_properties should emit events")
end

function TestChance:test_resolve_asserts_missing_registries_with_messages()
  -- #293:resolve 的两处装配断言消息未测,消息→nil 变异存活。
  local ok_registries, err_registries = pcall(chance_effects.resolve, {}, {}, {}, {})
  lu.assertEvalToTrue(ok_registries == false, "resolve without registries should assert")
  lu.assertEvalToTrue(tostring(err_registries):find("missing game.registries", 1, true) ~= nil,
    "assert should carry the registries message: " .. tostring(err_registries))

  local ok_chances, err_chances = pcall(chance_effects.resolve, { registries = {} }, {}, {}, {})
  lu.assertEvalToTrue(ok_chances == false, "resolve without chances should assert")
  lu.assertEvalToTrue(tostring(err_chances):find("missing chance handlers", 1, true) ~= nil,
    "assert should carry the chances message: " .. tostring(err_chances))
end


return TestChance
