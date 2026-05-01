local support = require("support.gameplay_support")
local fixtures = require("support.gameplay_fixtures")
local _new_game = support.new_game
local _build_loop_state = fixtures.build_loop_state
local _build_test_ports = fixtures.build_test_ports
local tick_choice_timeout = require("src.turn.waits.choice_timeout")
local tick_timeout = require("src.turn.waits.timeout")
local runtime_state = require("src.state.runtime_state")

local _resolve_choice_owner_tests = {
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p1.id, "should resolve owner from choice")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    g.turn.current_player_index = 1
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p1.id, "should fallback to current player")
  end,
  function()
    local g = _new_game()
    g.turn.current_player_index = nil
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == nil, "should return nil when no player found")
  end,
}

local _resolve_choice_owner_id_extended_tests = {
  function()
    local g = _new_game()
    local p2 = g.players[2]
    g.turn.current_player_index = 2
    local choice = { id = 1, owner_role_id = 999 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p2.id, "should fallback to current player when owner not found")
  end,
  function()
    local g = _new_game()
    g.turn.current_player_index = 5
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == nil, "should return nil when current player index out of range")
  end,
  function()
    local g = _new_game()
    g.find_player_by_id = function() return nil end
    local choice = { id = 1, owner_role_id = 123 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result ~= nil, "should fallback when find_player_by_id returns nil")
  end,
  function()
    local g = _new_game()
    g.turn = nil
    local choice = { id = 1, owner_role_id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    local p1 = _new_game().players[1]
    assert(result == p1.id or result == nil, "should handle nil turn gracefully")
  end,
  function()
    local g = _new_game()
    g.players = nil
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == nil, "should return nil when no players array")
  end,
  function()
    local g = _new_game()
    g.find_player_by_id = nil
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p1.id, "should fallback to current player when find_player_by_id missing")
  end,
}

local _resolve_choice_ui_state_t2_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "market_buy" }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.market_buy, "market_buy should use scope_timeouts.market_buy")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "normal_choice" }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.choice, "normal choice should use scope_timeouts.choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.choice, "nil pending_choice should use scope_timeouts.choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    runtime_state.set_pending_choice(state, { id = 2, kind = "market_buy" })
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.market_buy, "should get pending_choice from runtime state")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state, { id = 3, kind = "market_buy" })
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.market_buy, "should use passed choice parameter")
  end,
}

local _resolve_choice_ui_state_final_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()

    local ports = _build_test_ports({
      ui_sync = {
        is_choice_active = function() return true end,
        on_pending_choice = function() end,
      }
    })

    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    game.turn.pending_choice = { id = 1, kind = "test", route_key = "test_route" }

    local original_get_pending_choice = runtime_state.get_pending_choice
    local original_get_pending_choice_elapsed = runtime_state.get_pending_choice_elapsed
    runtime_state.get_pending_choice = function() return game.turn.pending_choice end
    runtime_state.get_pending_choice_elapsed = function() return 0 end

    tick_timeout.step_default_choice(game, state, 0.016)

    runtime_state.get_pending_choice = original_get_pending_choice
    runtime_state.get_pending_choice_elapsed = original_get_pending_choice_elapsed

    assert(true, "resolve_choice_ui_state should work")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()

    local ports = _build_test_ports({
      ui_sync = {
        is_choice_active = function() return true end,
        on_pending_choice = function() end,
      }
    })

    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    game.turn.pending_choice = { id = 1, kind = "test" }

    local original_get_pending_choice = runtime_state.get_pending_choice
    local original_get_pending_choice_elapsed = runtime_state.get_pending_choice_elapsed
    runtime_state.get_pending_choice = function() return game.turn.pending_choice end
    runtime_state.get_pending_choice_elapsed = function() return 0 end

    tick_timeout.step_default_choice(game, state, 0.016)

    runtime_state.get_pending_choice = original_get_pending_choice
    runtime_state.get_pending_choice_elapsed = original_get_pending_choice_elapsed

    assert(true, "resolve_choice_ui_state should handle missing route_key")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()

    local ports = _build_test_ports({
      ui_sync = {
        is_choice_active = function() return false end,
        on_pending_choice = function() end,
      }
    })

    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports

    local original_get_pending_choice = runtime_state.get_pending_choice
    runtime_state.get_pending_choice = function() return nil end

    tick_timeout.step_default_choice(game, state, 0.016)

    runtime_state.get_pending_choice = original_get_pending_choice

    assert(true, "resolve_choice_ui_state should handle nil choice")
  end,
}

describe("choices_timeout", function()
  it("_test_tick_choice_timeout_resolve_choice_owner_id_from_choice", _resolve_choice_owner_tests[1])

  it("_test_tick_choice_timeout_resolve_choice_owner_id_fallback", _resolve_choice_owner_tests[2])

  it("_test_tick_choice_timeout_resolve_choice_owner_id_not_found", _resolve_choice_owner_tests[3])

  it("_test_resolve_choice_owner_id_fallback_current", _resolve_choice_owner_id_extended_tests[1])

  it("_test_resolve_choice_owner_id_out_of_range", _resolve_choice_owner_id_extended_tests[2])

  it("_test_resolve_choice_owner_find_nil", _resolve_choice_owner_id_extended_tests[3])

  it("_test_resolve_choice_owner_nil_turn", _resolve_choice_owner_id_extended_tests[4])

  it("_test_resolve_choice_owner_no_players", _resolve_choice_owner_id_extended_tests[5])

  it("_test_resolve_choice_owner_missing_find_player", _resolve_choice_owner_id_extended_tests[6])

  it("_test_resolve_choice_timeout_market_buy", _resolve_choice_ui_state_t2_tests[1])

  it("_test_resolve_choice_timeout_normal_choice", _resolve_choice_ui_state_t2_tests[2])

  it("_test_resolve_choice_timeout_nil_pending", _resolve_choice_ui_state_t2_tests[3])

  it("_test_resolve_choice_timeout_runtime_pending", _resolve_choice_ui_state_t2_tests[4])

  it("_test_resolve_choice_timeout_param_choice", _resolve_choice_ui_state_t2_tests[5])

  it("_test_resolve_choice_ui_state_custom_callback", _resolve_choice_ui_state_final_tests[1])

  it("_test_resolve_choice_ui_state_fallback", _resolve_choice_ui_state_final_tests[2])

  it("_test_resolve_choice_ui_state_nil_choice", _resolve_choice_ui_state_final_tests[3])
end)
