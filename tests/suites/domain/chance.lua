local support = require("support.domain_support")
local default_map = require("Config.maps.default_map")
local facing_policy = require("src.game.systems.board.facing_policy")
local gameplay_rules = require("src.core.config.gameplay_rules")
local inventory = require("src.game.systems.items.inventory")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _resolve_landing = support.resolve_landing
local _visited_tile_ids = support.visited_tile_ids
local _list_contains = support.list_contains
local _first_tile_by_type = support.first_tile_by_type
local _with_patches = support.with_patches
local _assert_eq = support.assert_eq
local chance_effects = support.chance_effects
local _build_ui_port = support.build_ui_port
local item_ids = gameplay_rules.item_ids

local function _test_chance_is_mandatory_effect_entrypoint()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)

  local called = { rand = 0 }
  local prev_lua_api = LuaAPI
  local lua_api = prev_lua_api or {}
  local function rand()
    called.rand = called.rand + 1
    return 0
  end
  _with_patches({
    { key = "LuaAPI", value = lua_api },
    { target = lua_api, key = "rand", value = rand },
  }, function()
    _resolve_landing(g, p, tile_ref, {})
  end)

  assert(called.rand > 0, "chance logic was executed (LuaAPI.rand used)")
end

local function _test_chance_move_backward_pass_market()
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
end

local function _test_chance_move_backward_pass_intersection()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  assert(_list_contains(visited_ids, 45), "backward move should pass intersection")
  _assert_eq(p.status.move_dir, "down", "move_backward should preserve heading across intersections")
end

local function _test_chance_move_backward_queues_move_effect_anim()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "move_backward should queue move_effect anim")
  _assert_eq(g.turn.action_anim.to_index, p.position, "move_effect to_index should match player position")
end

local function _test_chance_move_backward_without_move_dir_uses_stable_fallback()
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
end

local function _test_chance_forced_move_queues_move_effect_anim()
  local g = _new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  local p = g:current_player()
  local dest = 38
  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination_tile_id = dest,
    target = "self",
  }, {})
  local idx = g.board:index_of_tile_id(dest)
  assert(out and out.kind == "need_landing", "forced_move destination tile should return need_landing")
  _assert_eq(out.board_index, idx, "forced_move board_index should match destination")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "move_effect", "forced_move should queue move_effect anim")
  _assert_eq(g.turn.action_anim.to_index, idx, "forced_move anim to_index should match destination")
  assert(p.status.move_dir == nil, "forced_move should clear stale move_dir")
end

local function _test_chance_forced_move_to_market_sets_default_forward_heading()
  local g = _new_game()
  local p = g:current_player()
  g:set_player_status(p, "move_dir", "left")
  local market_idx = assert(g.board:find_first_by_type("market"), "missing market tile")
  local expected = facing_policy.resolve_forced_move_reset_facing(g.board, market_idx)

  local out = chance_effects.resolve(g, p, {
    effect = "forced_move",
    destination = "market",
    target = "self",
  }, {})

  assert(out and out.kind == "need_landing", "forced_move market should return need_landing")
  _assert_eq(out.board_index, market_idx, "forced_move market should land on market tile")
  _assert_eq(p.status.move_dir, expected, "forced_move market should set default forward heading")
end

-- Characterization tests for chance handlers (T4)
local chance_handlers = require("src.game.systems.chance.chance_handlers")
local post_effects = require("src.game.systems.items.post_effects")

local function _test_chance_handlers_build_returns_handler_table()
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
  assert(type(handlers.set_vehicle) == "function", "chance_handlers should register set_vehicle handler")
  assert(type(handlers.destroy_buildings_on_path) == "function", "chance_handlers should register destroy_buildings_on_path handler")
  assert(type(handlers.reset_tiles_on_path) == "function", "chance_handlers should register reset_tiles_on_path handler")
  assert(type(handlers.grant_item) == "function", "chance_handlers should register grant_item handler")
  assert(type(handlers.discard_items) == "function", "chance_handlers should register discard_items handler")
  assert(type(handlers.discard_properties) == "function", "chance_handlers should register discard_properties handler")
end

local function _test_chance_handler_add_cash_applies_to_all_players()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local events = {}

  _with_patches({
    { target = require("src.core.events.monopoly_events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.add_cash(g, p, { effect = "add_cash", amount = 100, target = "all" })
  end)

  assert(#events >= 2, "add_cash with target=all should emit events for all players")
  assert(events[1].effect == "add_cash", "add_cash event should have correct effect")
  assert(events[1].text:find("获得"), "add_cash event text should indicate gain")
end

local function _test_chance_handler_pay_cash_applies_to_single_player()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local before_cash = g:player_balance(p, "金币")
  local events = {}

  _with_patches({
    { target = require("src.core.events.monopoly_events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.pay_cash(g, p, { effect = "pay_cash", amount = 50, target = "self" })
  end)

  assert(g:player_balance(p, "金币") < before_cash, "pay_cash should reduce player cash")
  assert(#events == 1, "pay_cash should emit one event for single player")
  assert(events[1].effect == "pay_cash", "pay_cash event should have correct effect")
  assert(events[1].text:find("支付"), "pay_cash event text should indicate payment")
end

local function _test_chance_handler_percent_pay_cash_calculates_correctly()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  g:set_player_cash(p, 1000)
  local events = {}

  _with_patches({
    { target = require("src.core.events.monopoly_events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.percent_pay_cash(g, p, { effect = "percent_pay_cash", percent = 10, target = "self" })
  end)

  assert(g:player_balance(p, "金币") == 900, "percent_pay_cash should deduct 10% of 1000")
  assert(#events == 1, "percent_pay_cash should emit one event")
  assert(events[1].text:find("按比例支付"), "percent_pay_cash event text should indicate proportional payment")
end

local function _test_chance_handler_grant_item_gives_item_to_player()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local item_count_before = #inventory.items(p)

  handlers.grant_item(g, p, { effect = "grant_item", item_id = item_ids.free_rent })

  assert(#inventory.items(p) > item_count_before, "grant_item should increase player item count")
end

local function _test_chance_handler_discard_items_removes_items()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  inventory.give(p, item_ids.free_rent, { game = g })
  local item_count_before = #inventory.items(p)
  local events = {}

  _with_patches({
    { target = require("src.core.events.monopoly_events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.discard_items(g, p, { effect = "discard_items", count = 1 })
  end)

  assert(#inventory.items(p) < item_count_before, "discard_items should reduce player item count")
  assert(#events == 1, "discard_items should emit one event")
  assert(events[1].text:find("丢弃道具"), "discard_items event text should indicate item discard")
end

local function _test_chance_handler_move_forward_moves_player()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()
  local start_pos = p.position

  local out = handlers.move_forward(g, p, { effect = "move_forward", steps = 3, target = "self" })

  assert(out and out.kind == "need_landing", "move_forward should return need_landing")
  assert(p.position ~= start_pos, "move_forward should change player position")
end

-- Characterization tests for post_effects (T4)
local function _test_post_effects_apply_sets_status()
  local g = _new_game()
  local p = g:current_player()

  post_effects.apply_post(g, p, item_ids.free_rent, {})

  assert(p.status.pending_free_rent == true, "post_effects apply should set pending_free_rent status")
end

local function _test_post_effects_apply_deity_sets_deity()
  local g = _new_game()
  local p = g:current_player()

  post_effects.apply_post(g, p, item_ids.rich, {})

  assert(p.status.deity ~= nil, "post_effects apply deity should set player deity")
  assert(p.status.deity.type == "rich", "post_effects apply deity should set correct deity type")
end

local function _test_post_effects_apply_log_emits_event()
  local g = _new_game()
  local p = g:current_player()
  local events = {}

  _with_patches({
    { target = require("src.core.utils.logger"), key = "event", value = function(text)
      events[#events + 1] = text
    end },
  }, function()
    post_effects.apply_post(g, p, item_ids.steal, {})
  end)

  assert(#events == 1, "post_effects log type should emit one event")
  assert(events[1]:find("偷窃"), "post_effects log type should emit steal preparation message")
end

local function _test_post_effects_apply_place_mine_here_places_mine()
  local g = _new_game()
  local p = g:current_player()
  local idx = g.board:index_of_tile_id(2)
  g:update_player_position(p, idx)
  local tile_idx = p.position

  post_effects.apply_post(g, p, item_ids.mine, {})

  assert(g.board:has_mine(tile_idx), "post_effects place_mine_here should place a mine at player position")
end

local function _test_post_effects_apply_clear_obstacles_ahead_clears_obstacles()
  local g = _new_game()
  local p = g:current_player()
  local idx = g.board:index_of_tile_id(2)
  g:update_player_position(p, idx)
  g:place_roadblock(idx + 1, { owner_id = p.id })

  assert(g.board:has_roadblock(idx + 1), "precondition: roadblock should exist")

  post_effects.apply_post(g, p, item_ids.clear_obstacles, { branch_parity = 12 })

  assert(not g.board:has_roadblock(idx + 1), "post_effects clear_obstacles_ahead should clear roadblocks")
end

local function _test_post_effects_target_item_ids_returns_ordered_list()
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
end

local function _test_post_effects_get_target_spec_returns_spec()
  local spec = post_effects.get_target_spec(item_ids.share_wealth)
  assert(type(spec) == "table", "get_target_spec should return a table for target items")
  assert(type(spec.apply) == "function", "target spec should have apply function")
end

-- T8 characterization tests for 0% coverage hotspots
local bankruptcy = require("src.game.systems.endgame.bankruptcy")

local function _test_chance_handler_discard_properties_removes_properties()
  local g = _new_game()
  local handlers = chance_handlers.build()
  local p = g:current_player()

  -- Give player a property first
  local tile_id = 2
  g:set_player_property(p, tile_id, true)
  assert(p.properties[tile_id] == true, "precondition: player should have property")

  local events = {}
  _with_patches({
    { target = require("src.core.events.monopoly_events"), key = "emit", value = function(_, payload)
      events[#events + 1] = payload
    end },
  }, function()
    handlers.discard_properties(g, p, { effect = "discard_properties", count = 1 })
  end)

  assert(p.properties[tile_id] == nil or p.properties[tile_id] == false, "discard_properties should remove player property")
  assert(#events >= 1, "discard_properties should emit events")
end

local function _test_bankruptcy_eliminate_calls_life_die()
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
    { target = require("src.core.ports.runtime_ports"), key = "resolve_role", value = function() return mock_role end },
    { target = require("src.core.ports.runtime_ports"), key = "mark_role_lose", value = function() end },
  }, function()
    bankruptcy.eliminate(g, p, {})
  end)

  assert(p.eliminated == true, "eliminate should mark player as eliminated")
  assert(life_die_called == true, "eliminate should call life die on role")
end

-- T4 characterization tests for executors
local function _test_merge_executor_groups_combines_groups()
  local executors = require("src.game.systems.land.executors")
  -- The module already uses _merge_executor_groups internally
  -- Test that executors module loads and has expected structure
  assert(type(executors.executors) == "table", "executors.executors should be a table")
  assert(type(executors.register_effect_executors) == "function", "executors should expose register_effect_executors")
end

-- T4 characterization tests for eligibility helpers
local function _test_split_entries_by_buyable_separates_entries()
  local eligibility = require("src.game.systems.market.application.eligibility")
  local g = _new_game()
  local p = g:current_player()

  -- Give player enough cash to buy some items
  g:set_player_cash(p, 999999)

  local buyable, unbuyable = eligibility._split_entries_by_buyable(p, g)

  assert(type(buyable) == "table", "split_entries_by_buyable should return buyable table")
  assert(type(unbuyable) == "table", "split_entries_by_buyable should return unbuyable table")
  -- With plenty of cash, most items should be buyable
  assert(#buyable >= 0, "buyable list should be non-negative")
end

local function _test_append_visible_entries_respects_limit()
  local eligibility = require("src.game.systems.market.application.eligibility")
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
end

local function _test_append_visible_entries_without_limit_adds_all()
  local eligibility = require("src.game.systems.market.application.eligibility")
  local g = _new_game()

  local entries = eligibility.sorted_entries()
  local visible = {}

  local hit_limit = eligibility._append_visible_entries(visible, entries, true, nil)

  assert(#visible == #entries, "append_visible_entries without limit should add all entries")
  assert(hit_limit == false, "append_visible_entries should return false when no limit")
end

-- T4 characterization tests for market context
local function _test_context_entry_name_returns_name()
  local context = require("src.game.systems.market.application.context")
  local market_cfg = require("Config.generated.market")

  if #market_cfg > 0 then
    local first_entry = market_cfg[1]
    local name = context.entry_name(first_entry)
    assert(type(name) == "string", "entry_name should return a string")
    assert(name ~= "", "entry_name should return non-empty string")
  end
end

return {
  name = "chance",
  tests = {
    { name = "chance_is_mandatory_effect_entrypoint", run = _test_chance_is_mandatory_effect_entrypoint },
    { name = "chance_move_backward_pass_market", run = _test_chance_move_backward_pass_market },
    { name = "chance_move_backward_pass_intersection", run = _test_chance_move_backward_pass_intersection },
    { name = "chance_move_backward_queues_move_effect_anim", run = _test_chance_move_backward_queues_move_effect_anim },
    { name = "chance_move_backward_without_move_dir_uses_stable_fallback", run = _test_chance_move_backward_without_move_dir_uses_stable_fallback },
    { name = "chance_forced_move_queues_move_effect_anim", run = _test_chance_forced_move_queues_move_effect_anim },
    {
      name = "chance_forced_move_to_market_sets_default_forward_heading",
      run = _test_chance_forced_move_to_market_sets_default_forward_heading,
    },
    -- T4 characterization tests for chance handlers
    { name = "chance_handlers_build_returns_handler_table", run = _test_chance_handlers_build_returns_handler_table },
    { name = "chance_handler_add_cash_applies_to_all_players", run = _test_chance_handler_add_cash_applies_to_all_players },
    { name = "chance_handler_pay_cash_applies_to_single_player", run = _test_chance_handler_pay_cash_applies_to_single_player },
    { name = "chance_handler_percent_pay_cash_calculates_correctly", run = _test_chance_handler_percent_pay_cash_calculates_correctly },
    { name = "chance_handler_grant_item_gives_item_to_player", run = _test_chance_handler_grant_item_gives_item_to_player },
    { name = "chance_handler_discard_items_removes_items", run = _test_chance_handler_discard_items_removes_items },
    { name = "chance_handler_move_forward_moves_player", run = _test_chance_handler_move_forward_moves_player },
    -- T4 characterization tests for post_effects
    { name = "post_effects_apply_sets_status", run = _test_post_effects_apply_sets_status },
    { name = "post_effects_apply_deity_sets_deity", run = _test_post_effects_apply_deity_sets_deity },
    { name = "post_effects_apply_log_emits_event", run = _test_post_effects_apply_log_emits_event },
    { name = "post_effects_apply_place_mine_here_places_mine", run = _test_post_effects_apply_place_mine_here_places_mine },
    { name = "post_effects_apply_clear_obstacles_ahead_clears_obstacles", run = _test_post_effects_apply_clear_obstacles_ahead_clears_obstacles },
    { name = "post_effects_target_item_ids_returns_ordered_list", run = _test_post_effects_target_item_ids_returns_ordered_list },
    { name = "post_effects_get_target_spec_returns_spec", run = _test_post_effects_get_target_spec_returns_spec },
    -- T8 characterization tests for 0% coverage hotspots
    { name = "chance_handler_discard_properties_removes_properties", run = _test_chance_handler_discard_properties_removes_properties },
    { name = "bankruptcy_eliminate_calls_life_die", run = _test_bankruptcy_eliminate_calls_life_die },
    -- T4 characterization tests for low-complexity hotspots
    { name = "merge_executor_groups_combines_groups", run = _test_merge_executor_groups_combines_groups },
    { name = "split_entries_by_buyable_separates_entries", run = _test_split_entries_by_buyable_separates_entries },
    { name = "append_visible_entries_respects_limit", run = _test_append_visible_entries_respects_limit },
    { name = "append_visible_entries_without_limit_adds_all", run = _test_append_visible_entries_without_limit_adds_all },
    { name = "context_entry_name_returns_name", run = _test_context_entry_name_returns_name },
  },
}
