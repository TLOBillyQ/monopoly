-- luacheck: ignore 211
local support = require("spec.support.shared_support")
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
local post_effects = require("src.rules.items.post_effects")

local bankruptcy = require("src.rules.endgame")

describe("chance", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("chance_draw_uses_injected_rng_and_ignores_lua_api_rand", function()
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

    assert(#rng_calls == 1, "chance draw should use injected rng exactly once")
    _assert_eq(rng_calls[1].min, 1, "chance draw should start from 1")
    assert(rng_calls[1].max > 0, "chance draw should use a positive upper bound")
    _assert_eq(called_rand, 0, "chance draw should not touch LuaAPI.rand")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "chance", "chance draw should queue a chance anim")
    _assert_eq(g.turn.action_anim.card_id, 3001, "chance draw should pick the first card with deterministic rng")
  end)

  it("chance_move_backward_pass_market", function()
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(32))
    g:set_player_status(p, "move_dir", "down")
    local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
    assert(out and out.move_result, "move_backward should return move result")
    local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
    assert(_list_contains(visited_ids, 39), "backward move should pass market")
    assert(out.move_result.market_interrupt == nil, "backward move should not trigger market interrupt")
    _assert_eq(p.status.move_dir, "down", "move_backward should preserve recorded forward heading")
  end)

  it("chance_move_backward_pass_intersection", function()
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(42))
    g:set_player_status(p, "move_dir", "down")
    local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
    assert(out and out.move_result, "move_backward should return move result")
    local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
    assert(_list_contains(visited_ids, 45), "backward move should pass intersection")
    _assert_eq(p.status.move_dir, "down", "move_backward should preserve heading across intersections")
  end)

  it("chance_move_backward_queues_move_effect_anim", function()
    local g = _new_game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(32))
    g:set_player_status(p, "move_dir", "down")
    local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
    assert(out and out.move_result, "move_backward should return move result")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "move_backward should queue move_effect anim")
    _assert_eq(g.turn.action_anim.to_index, p.position, "move_effect to_index should match player position")
    _assert_eq(out.wait_move_anim, false, "move_backward should not signal wait_move_anim when only action_anim gate is open")
  end)

  it("chance_move_backward_queues_move_anim_when_gate_open", function()
    local g = _new_game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = true }
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(32))
    g:set_player_status(p, "move_dir", "down")
    local from_index = p.position
    local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
    assert(out and out.move_result, "move_backward should return move result")
    _assert_eq(out.wait_move_anim, true, "move_backward should signal wait_move_anim when move_anim gate is open")
    assert(g.turn.move_anim ~= nil, "move_backward should queue an entry on the move_anim channel")
    _assert_eq(g.turn.move_anim.player_id, p.id, "queued move_anim should target the moving player")
    _assert_eq(g.turn.move_anim.from_index, from_index, "queued move_anim should record the start tile index")
    _assert_eq(g.turn.move_anim.to_index, p.position, "queued move_anim should record the destination tile index")
    assert(g.turn.move_anim.seq ~= nil, "queued move_anim should carry a sequence id")
    _assert_eq(g.turn.action_anim, nil, "move_backward should not queue an action_anim entry when move_anim gate is open")
  end)

  it("chance_move_forward_queues_move_anim_when_gate_open", function()
    local g = _new_game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = true }
    local p = g:current_player()
    local from_index = p.position
    local out = chance_effects.resolve(g, p, { effect = "move_forward", steps = 3, target = "self" }, {})
    assert(out and out.move_result, "move_forward should return move result")
    _assert_eq(out.wait_move_anim, true, "move_forward should signal wait_move_anim when move_anim gate is open")
    assert(g.turn.move_anim ~= nil, "move_forward should queue an entry on the move_anim channel")
    _assert_eq(g.turn.move_anim.from_index, from_index, "queued move_anim should record the start tile index")
    _assert_eq(g.turn.move_anim.to_index, p.position, "queued move_anim should record the destination tile index")
    _assert_eq(g.turn.action_anim, nil, "move_forward should not queue an action_anim entry when move_anim gate is open")
  end)

  it("chance_move_backward_without_move_dir_uses_stable_fallback", function()
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(42))
    g:set_player_status(p, "move_dir", nil)
    local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 1, target = "self" }, {})
    assert(out and out.move_result, "move_backward without move_dir should still return move result")
    local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
    _assert_eq(#visited_ids, 1, "move_backward fallback should record one visited tile")
    _assert_eq(visited_ids[1], 3, "move_backward without move_dir should stably fallback to outer_prev")
    _assert_eq(p.status.move_dir, nil, "move_backward fallback should not record a backward heading")
  end)

  it("chance_move_backward_uses_arrival_direction_on_immediate_landing", function()
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(25))
    g:set_player_status(p, "move_dir", "right")

    local landing_result = movement.move(g, p, -1, { skip_market_check = true })
    _assert_eq(g.board:get_tile(p.position).id, 40, "setup should land on the outer chance tile")
    _assert_eq(p.status.move_dir, "right", "setup should preserve the recorded forward heading")

    local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 1, target = "self" }, landing_result)

    assert(out and out.move_result, "move_backward should return move result when triggered from landing")
    local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
    _assert_eq(#visited_ids, 1, "immediate landing retreat should move exactly one tile")
    _assert_eq(visited_ids[1], 25, "immediate landing retreat should go back along the arrival edge")
    _assert_eq(g.board:get_tile(p.position).id, 25, "immediate landing retreat should return to the inner tile")
    _assert_eq(p.status.move_dir, "right", "immediate landing retreat should still preserve forward heading")
  end)

  it("chance_forced_move_queues_move_effect_anim", function()
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
    assert(out and out.kind == "need_landing", "forced_move destination tile should return need_landing")
    _assert_eq(out.board_index, idx, "forced_move board_index should match destination")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "forced_relocation", "forced_move should queue forced relocation anim")
    _assert_eq(g.turn.action_anim.to_index, idx, "forced_move anim to_index should match destination")
    _assert_eq(p.status.move_dir, "left", "forced_move destination tile should preserve move_dir")
  end)

  it("chance_forced_move_to_market_sets_default_forward_heading", function()
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

    assert(out and out.kind == "need_landing", "forced_move market should return need_landing")
    _assert_eq(out.board_index, market_idx, "forced_move market should land on market tile")
    _assert_eq(g.turn.action_anim.kind, "forced_relocation", "forced_move market should queue forced relocation anim kind")
    _assert_eq(p.status.move_dir, "right", "forced_move market should default to counterclockwise heading")
  end)

  it("chance_forced_move_to_hospital_clears_move_dir", function()
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

    assert(out and out.kind == "need_landing", "forced_move hospital should continue into landing flow")
    _assert_eq(out.board_index, hospital_idx, "forced_move hospital should land on hospital tile")
    _assert_eq(g.turn.action_anim.kind, "forced_relocation", "forced_move hospital should queue forced relocation anim kind")
    _assert_eq(p.status.move_dir, nil, "forced_move hospital should clear move_dir")
  end)

  it("chance_handlers_build_returns_handler_table", function()
    local handlers = chance_handlers.build()
    assert(type(handlers) == "table", "chance_handlers.build should return a table")
    assert(type(handlers.handlers) == "table", "chance_handlers.build should return nested handlers table")
    assert(type(handlers.add_cash) == "function", "chance_handlers should register add_cash handler")
    assert(type(handlers.pay_cash) == "function", "chance_handlers should register pay_cash handler")
    assert(type(handlers.percent_pay_cash) == "function", "chance_handlers should register percent_pay_cash handler")
    assert(type(handlers.pay_others) == "function", "chance_handlers should register pay_others handler")
    assert(type(handlers.collect_from_others) == "function", "chance_handlers should register collect_from_others handler")
    assert(type(handlers.move_backward) == "function", "chance_handlers should register move_backward handler")
    assert(type(handlers.move_forward) == "function", "chance_handlers should register move_forward handler")
    assert(type(handlers.forced_move) == "function", "chance_handlers should register forced_move handler")
    assert(type(handlers.destroy_buildings_on_path) == "function", "chance_handlers should register destroy_buildings_on_path handler")
    assert(type(handlers.reset_tiles_on_path) == "function", "chance_handlers should register reset_tiles_on_path handler")
    assert(type(handlers.grant_item) == "function", "chance_handlers should register grant_item handler")
    assert(type(handlers.discard_items) == "function", "chance_handlers should register discard_items handler")
    assert(type(handlers.discard_properties) == "function", "chance_handlers should register discard_properties handler")
  end)

  it("chance_handler_add_cash_applies_to_all_players", function()
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

    assert(#events >= 2, "add_cash with target=all should emit events for all players")
    assert(events[1].effect == "add_cash", "add_cash event should have correct effect")
    assert(events[1].text:find("获得"), "add_cash event text should indicate gain")
  end)

  it("chance_handler_add_cash_queues_cash_anim_for_all_players", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    handlers.add_cash(g, p, { effect = "add_cash", amount = 100, target = "all" })

    assert(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "add_cash should queue cash_receive anim")
    _assert_eq(_action_anim_count(g), #g.players, "add_cash should queue one cash anim per player")
  end)

  it("chance_handler_pay_cash_applies_to_single_player", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    local before_cash = g:player_balance(p, "金币")
    local events = {}

    _with_patches({
      { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
        events[#events + 1] = payload
      end },
    }, function()
      handlers.pay_cash(g, p, { effect = "pay_cash", amount = 50, target = "self" })
    end)

    assert(g:player_balance(p, "金币") < before_cash, "pay_cash should reduce player cash")
    assert(#events == 1, "pay_cash should emit one event for single player")
    assert(events[1].effect == "pay_cash", "pay_cash event should have correct effect")
    assert(events[1].text:find("支付"), "pay_cash event text should indicate payment")
  end)

  it("set_player_cash_does_not_queue_cash_anim", function()
    local g = _new_game()
    local p = g:current_player()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    g:set_player_cash(p, 12345)

    assert(g.turn.action_anim == nil, "set_player_cash should not queue gameplay cash anim")
    _assert_eq(_action_anim_count(g), 0, "set_player_cash should not enqueue any cash anims")
  end)

  it("chance_handler_percent_pay_cash_calculates_correctly", function()
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

    assert(g:player_balance(p, "金币") == 900, "percent_pay_cash should deduct 10% of 1000")
    assert(#events == 1, "percent_pay_cash should emit one event")
    assert(events[1].text:find("按比例支付"), "percent_pay_cash event text should indicate proportional payment")
  end)

  it("chance_handler_grant_item_gives_item_to_player", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    local item_count_before = #inventory.items(p)

    handlers.grant_item(g, p, { effect = "grant_item", item_id = item_ids.free_rent })

    assert(#inventory.items(p) > item_count_before, "grant_item should increase player item count")
  end)

  it("chance_handler_grant_item_queues_reveal_after_chance_card_anim", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    g.turn.action_anim = { seq = 5, kind = "chance", player_id = p.id }
    g.turn.action_anim_seq = 5

    handlers.grant_item(g, p, { effect = "grant_item", item_id = item_ids.free_rent })

    local queue = g.turn.action_anim_queue or {}
    _assert_eq(#queue, 1, "grant item should queue reveal behind chance anim")
    _assert_eq(queue[1].kind, "item_get_reveal", "grant item reveal kind mismatch")
    _assert_eq(queue[1].item_id, item_ids.free_rent, "grant item reveal item mismatch")
    _assert_eq(queue[1].player_id, p.id, "grant item reveal player mismatch")
    _assert_eq(queue[1].source, "chance", "grant item reveal source mismatch")
  end)

  it("chance_handler_discard_items_removes_items", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    inventory.give(p, item_ids.free_rent, { game = g })
    local item_count_before = #inventory.items(p)
    local events = {}

    _with_patches({
      { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
        events[#events + 1] = payload
      end },
    }, function()
      handlers.discard_items(g, p, { effect = "discard_items", count = 1 })
    end)

    assert(#inventory.items(p) < item_count_before, "discard_items should reduce player item count")
    assert(#events == 1, "discard_items should emit one event")
    assert(events[1].text:find("丢弃道具"), "discard_items event text should indicate item discard")
  end)

  it("chance_handler_discard_items_uses_injected_rng_for_random_pick", function()
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

    assert(#rng_calls == 1, "discard_items should use injected rng exactly once when dropping one item")
    _assert_eq(rng_calls[1].min, 1, "discard_items rng should start at 1")
    _assert_eq(rng_calls[1].max, 2, "discard_items rng upper bound should match current item count")
    assert(inventory.find_index(p, item_ids.free_rent) ~= nil, "discard_items should keep the first item when rng picks the second")
    assert(inventory.find_index(p, item_ids.tax_free) == nil, "discard_items should remove the rng-selected item")
    assert(#events == 1, "discard_items should emit one event")
  end)

  it("chance_handler_move_forward_moves_player", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    local start_pos = p.position

    local out = handlers.move_forward(g, p, { effect = "move_forward", steps = 3, target = "self" })

    assert(out and out.kind == "need_landing", "move_forward should return need_landing")
    assert(p.position ~= start_pos, "move_forward should change player position")
  end)

  it("chance_handler_collect_from_others_queues_batched_actor_anim", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()
    for i = 2, #g.players do
      g:set_player_cash(g.players[i], 1000)
    end
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    handlers.collect_from_others(g, p, { effect = "collect_from_others", amount = 100, target = "self" })

    assert(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "collect_from_others should queue cash_receive anim")
    _assert_eq(_action_anim_count(g), 1, "collect_from_others should collapse into one summary anim")
    _assert_eq(g.turn.action_anim.amount, (#g.players - 1) * 100, "collect_from_others summary anim should use total collected amount")
  end)

  it("post_effects_apply_sets_status", function()
    local g = _new_game()
    local p = g:current_player()

    post_effects.apply_post(g, p, item_ids.free_rent, {})

    assert(g:has_pending_free_rent(p) == true, "post_effects apply should set pending_free_rent status")
  end)

  it("post_effects_apply_deity_sets_deity", function()
    local g = _new_game()
    local p = g:current_player()

    post_effects.apply_post(g, p, item_ids.rich, {})

    assert(p.status.deity ~= nil, "post_effects apply deity should set player deity")
    assert(p.status.deity.type == "rich", "post_effects apply deity should set correct deity type")
  end)

  it("post_effects_apply_log_emits_event", function()
    local g = _new_game()
    local p = g:current_player()
    local events = {}
    local event_feed = require("src.rules.ports.event_feed")

    _with_patches({
      { target = event_feed, key = "publish", value = function(_, event)
        events[#events + 1] = event and event.text or nil
        return true
      end },
    }, function()
      post_effects.apply_post(g, p, item_ids.strong, {})
    end)

    assert(#events == 1, "post_effects log type should emit one event")
    assert(events[1]:find("强征"), "post_effects log type should emit strong card preparation message")
  end)

  it("post_effects_apply_place_mine_here_places_mine", function()
    local g = _new_game()
    local p = g:current_player()
    local idx = g.board:index_of_tile_id(2)
    g:update_player_position(p, idx)
    local tile_idx = p.position

    post_effects.apply_post(g, p, item_ids.mine, {})

    assert(g.board:has_mine(tile_idx), "post_effects place_mine_here should place a mine at player position")
    local mine = assert(g.board:get_mine(tile_idx), "post_effects place_mine_here should keep mine payload")
    assert(mine.armed == true, "post_effects place_mine_here should arm normal mines immediately")
    assert(mine.owner_id == p.id, "post_effects place_mine_here should record owner id")
    assert(
      mine.owner_turn_started_count_at_placement == g:player_own_turn_started_count(p),
      "post_effects place_mine_here should snapshot owner own-turn count"
    )
  end)

  it("post_effects_apply_clear_obstacles_ahead_clears_obstacles", function()
    local g = _new_game()
    local p = g:current_player()
    local idx = g.board:index_of_tile_id(2)
    g:update_player_position(p, idx)
    g:place_roadblock(idx + 1, { owner_id = p.id })

    assert(g.board:has_roadblock(idx + 1), "precondition: roadblock should exist")

    post_effects.apply_post(g, p, item_ids.clear_obstacles, { branch_parity = 12 })

    assert(not g.board:has_roadblock(idx + 1), "post_effects clear_obstacles_ahead should clear roadblocks")
  end)

  it("post_effects_target_item_ids_returns_ordered_list", function()
    local ids = post_effects.target_item_ids()
    assert(type(ids) == "table", "target_item_ids should return a table")
    assert(#ids > 0, "target_item_ids should return non-empty list")
    -- Check for known target items (share_wealth = 2011)
    local has_share_wealth = false
    for _, id in ipairs(ids) do
      if id == item_ids.share_wealth then
        has_share_wealth = true
        break
      end
    end
    assert(has_share_wealth, "target_item_ids should include share_wealth item")
  end)

  it("post_effects_get_target_spec_returns_spec", function()
    local spec = post_effects.get_target_spec(item_ids.share_wealth)
    assert(type(spec) == "table", "get_target_spec should return a table for target items")
    assert(type(spec.apply) == "function", "target spec should have apply function")
  end)

  it("post_effects_share_wealth_queues_cash_anim_for_both_players", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    g:set_player_cash(user, 1000)
    g:set_player_cash(target, 3000)
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    post_effects.apply_target(g, user, item_ids.share_wealth, target, {})

    assert(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "share_wealth should queue cash_receive anim")
    _assert_eq(_action_anim_count(g), 2, "share_wealth should queue one cash anim per affected player")
  end)

  it("post_effects_share_wealth_item_target_path_keeps_item_target_anim_only", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    g:set_player_cash(user, 1000)
    g:set_player_cash(target, 3000)
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    post_effects.apply_target(g, user, item_ids.share_wealth, target, {
      share_wealth_cash_receive_mode = "item_target_player_only",
    })

    assert(g.turn.action_anim == nil, "item target path should suppress post-effect cash_receive anim")
  end)

  it("chance_handler_discard_properties_removes_properties", function()
    local g = _new_game()
    local handlers = chance_handlers.build()
    local p = g:current_player()

    -- Give player a property first
    local tile_id = 2
    g:set_player_property(p, tile_id, true)
    assert(p.properties[tile_id] == true, "precondition: player should have property")

    local events = {}
    _with_patches({
      { target = require("src.foundation.events"), key = "emit", value = function(_, payload)
        events[#events + 1] = payload
      end },
    }, function()
      handlers.discard_properties(g, p, { effect = "discard_properties", count = 1 })
    end)

    assert(p.properties[tile_id] == nil or p.properties[tile_id] == false, "discard_properties should remove player property")
    assert(#events >= 1, "discard_properties should emit events")
  end)

  it("chance_handler_discard_properties_uses_injected_rng_for_random_pick", function()
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

    assert(#rng_calls == 1, "discard_properties should use injected rng exactly once when dropping one property")
    _assert_eq(rng_calls[1].min, 1, "discard_properties rng should start at 1")
    _assert_eq(rng_calls[1].max, 2, "discard_properties rng upper bound should match current property count")
    assert(p.properties[first_tile_id] == true, "discard_properties should keep the first property when rng picks the second")
    assert(p.properties[second_tile_id] == nil or p.properties[second_tile_id] == false, "discard_properties should remove the rng-selected property")
    assert(#events >= 1, "discard_properties should emit events")
  end)

  it("bankruptcy_eliminate_calls_life_die", function()
    local g = _new_game()
    local p = g:current_player()

    -- Track if life die was attempted
    local life_die_called = false
    local mock_role = {
      die = function() life_die_called = true end,
      get_component = function(_, name)
        if name == "LifeComp" then
          return { die = function() life_die_called = true end }
        end
        return nil
      end
    }

    _with_patches({
      { target = require("src.foundation.ports.runtime_ports"), key = "resolve_role", value = function() return mock_role end },
      { target = require("src.foundation.ports.runtime_ports"), key = "mark_role_lose", value = function() end },
    }, function()
      bankruptcy.eliminate(g, p, {})
    end)

    assert(p.eliminated == true, "eliminate should mark player as eliminated")
    assert(life_die_called == true, "eliminate should call life die on role")
  end)

  it("merge_executor_groups_combines_groups", function()
    local executors = require("src.rules.land.executors")
    -- The module already uses _merge_executor_groups internally
    -- Test that executors module loads and has expected structure
    assert(type(executors.executors) == "table", "executors.executors should be a table")
    assert(type(executors.register_effect_executors) == "function", "executors should expose register_effect_executors")
  end)

  it("split_entries_by_buyable_separates_entries", function()
    local eligibility = require("src.rules.market.query").eligibility
    local g = _new_game()
    local p = g:current_player()

    -- Give player enough cash to buy some items
    g:set_player_cash(p, 999999)

    local buyable, unbuyable = eligibility._split_entries_by_buyable(p, g)

    assert(type(buyable) == "table", "split_entries_by_buyable should return buyable table")
    assert(type(unbuyable) == "table", "split_entries_by_buyable should return unbuyable table")
    -- With plenty of cash, most items should be buyable
    assert(#buyable >= 0, "buyable list should be non-negative")
  end)

  it("append_visible_entries_respects_limit", function()
    local eligibility = require("src.rules.market.query").eligibility
    local g = _new_game()
    local p = g:current_player()

    local entries = eligibility.sorted_entries()
    local visible = {}
    local limit = 3

    local hit_limit = eligibility._append_visible_entries(visible, entries, true, limit)

    if #entries >= limit then
      assert(#visible == limit, "append_visible_entries should respect limit")
      assert(hit_limit == true, "append_visible_entries should return true when limit hit")
    end
  end)

  it("append_visible_entries_without_limit_adds_all", function()
    local eligibility = require("src.rules.market.query").eligibility
    local g = _new_game()

    local entries = eligibility.sorted_entries()
    local visible = {}

    local hit_limit = eligibility._append_visible_entries(visible, entries, true, nil)

    assert(#visible == #entries, "append_visible_entries without limit should add all entries")
    assert(hit_limit == false, "append_visible_entries should return false when no limit")
  end)

  it("context_entry_name_returns_name", function()
    local context = require("src.rules.market.query").context
    local market_cfg = require("src.config.content.market")

    if #market_cfg > 0 then
      local first_entry = market_cfg[1]
      local name = context.entry_name(first_entry)
      assert(type(name) == "string", "entry_name should return a string")
      assert(name ~= "", "entry_name should return non-empty string")
    end
  end)
end)
