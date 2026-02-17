local support = require("support.regression_support")
local context_helpers = require("support.regression.runtime_context_helpers")
local runtime_cases = require("support.regression.runtime_context_cases")
local autorunner_cases = require("support.regression.gameplay_autorunner_cases")
local loop_builder = require("support.regression.loop_state_builder")
local new_game = support.new_game
local with_turn_flow = support.with_turn_flow
local resolve_landing = support.resolve_landing
local resolve_landing_with_choices = support.resolve_landing_with_choices
local resolve_choice_first = support.resolve_choice_first
local get_choice = support.get_choice
local first_land_tile = support.first_land_tile
local first_tile_by_type = support.first_tile_by_type
local tile_state = support.tile_state
local movement = support.movement
local inventory = support.inventory
local steal = support.steal
local gameplay_loop = support.gameplay_loop
local tick_timeout = support.tick_timeout
local constants = support.constants
local bankruptcy = support.bankruptcy
local turn_move = support.turn_move
local turn_flow = support.turn_flow
local mine_effect = require("game.effect.mine")
local dispatch_validator = require("turn.validator")

local function _test_mandatory_payment_causes_bankruptcy()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  local idx, tile_ref = first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p1.id)
  g:set_tile_level(tile_ref, 3)
  g:set_player_property(p1, tile_ref.id, true)

  g:set_player_cash(p2, 10)

  g:update_player_position(p2, idx)

  local before_eliminated = p2.eliminated
  resolve_landing(g, p2, tile_ref, {})

  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function _test_bankruptcy_resets_owned_tiles()
  local g = new_game()
  local p1 = g.players[1]
  local _, tile1 = first_land_tile(g.board)
  local tile2 = nil
  for i = 1, #g.board.path do
    local t = g.board.path[i]
    if t.type == "land" and t.id ~= tile1.id then
      tile2 = t
      break
    end
  end
  assert(tile2, "should have at least two land tiles")

  g:set_tile_owner(tile1, p1.id)
  g:set_tile_level(tile1, 2)
  g:set_player_property(p1, tile1.id, true)

  g:set_tile_owner(tile2, p1.id)
  g:set_tile_level(tile2, 1)
  g:set_player_property(p1, tile2.id, true)

  bankruptcy.eliminate(g, p1)

  local st1 = tile_state(g, tile1)
  local st2 = tile_state(g, tile2)
  assert(st1.owner_id == nil and st1.level == 0, "bankruptcy clears owned tile1")
  assert(st2.owner_id == nil and st2.level == 0, "bankruptcy clears owned tile2")
  assert(next(p1.properties) == nil, "bankruptcy clears player properties")
end

local function _test_set_tile_owner_without_ui_port_does_not_crash()
  local g = new_game()
  g.ui_port = nil
  local _, tile_ref = first_land_tile(g.board)
  local p1 = g.players[1]

  g:set_tile_owner(tile_ref, p1.id)
  local st_owned = tile_state(g, tile_ref)
  assert(st_owned.owner_id == p1.id, "set_tile_owner should work without ui_port")

  g:reset_tile(tile_ref)
  local st_reset = tile_state(g, tile_ref)
  assert(st_reset.owner_id == nil, "reset_tile should clear owner without ui_port")
  assert(st_reset.level == 0, "reset_tile should clear level without ui_port")
end

local function _test_tile_owner_notifier_receives_owner_changes()
  local g = new_game()
  g.ui_port = nil
  local _, tile_ref = first_land_tile(g.board)
  local p1 = g.players[1]
  local calls = {}
  g.tile_owner_notifier = {
    notify_owner_changed = function(_, tile_id, owner_id)
      calls[#calls + 1] = { tile_id = tile_id, owner_id = owner_id }
    end,
  }

  g:set_tile_owner(tile_ref, p1.id)
  g:reset_tile(tile_ref)

  assert(#calls == 2, "tile_owner_notifier should receive owner set and reset")
  assert(calls[1].tile_id == tile_ref.id and calls[1].owner_id == p1.id, "first notify should be owner set")
  assert(calls[2].tile_id == tile_ref.id and calls[2].owner_id == nil, "second notify should be owner clear")
end

local function _test_dispatch_validator_accepts_ui_state_snapshot()
  local ui_state = {
    input_blocked = true,
    item_slot_item_ids = { [1] = 2001 },
  }
  local blocked = dispatch_validator.should_block_action(ui_state, { type = "ui_button" })
  assert(blocked == true, "validator should block when ui_state.input_blocked")

  local state = {
    pending_choice = {
      id = 1,
      kind = "item_phase_choice",
      options = { { id = 2001 } },
    },
  }
  local res = dispatch_validator.resolve_item_slot_action(ui_state, state, {
    id = "item_slot_1",
    actor_role_id = 1,
  })
  assert(res and res.ok, "validator should resolve item slot action")
end

local function _test_stop_all_players_movement_clears_move_dir_and_stop_event()
  local g = new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  context_helpers.with_vehicle_enabled(function()
    support.with_patches({
      { key = "vehicle_helper", value = {
        resolve_role = function(role_id)
          if role_id == g.players[1].id then
            return { id = role_id }
          end
          return nil
        end,
        forward_eca_event_stop = function(role_id)
          table.insert(stopped_ids, role_id)
        end,
      } },
    }, function()
      g:stop_all_players_movement()
    end)
  end)
  assert(g.players[1].status.move_dir == nil, "player1 move_dir should be cleared")
  assert(g.players[2].status.move_dir == nil, "player2 move_dir should be cleared")
  assert(#stopped_ids == 1, "stop event should only be sent to players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "stop event should target player with valid role")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "stop should bump vehicle_resync_seq")
end

local function _test_end_turn_stops_all_players_movement()
  local g = new_game()
  with_turn_flow(g)
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  context_helpers.with_vehicle_enabled(function()
    support.with_patches({
      { key = "vehicle_helper", value = {
        resolve_role = function(role_id)
          if role_id == g.players[1].id then
            return { id = role_id }
          end
          return nil
        end,
        forward_eca_event_stop = function(role_id)
          table.insert(stopped_ids, role_id)
        end,
      } },
    }, function()
      -- 确保 turn_flow.phases 存在且包含 end_turn
      if not g.turn_flow.phases or not g.turn_flow.phases.end_turn then
        -- 重新创建 turn_flow 以确保 phases 正确
        local phase_registry = require("game.core.phase")
        g.turn_flow = turn_flow:new(g, phase_registry.build_default_phases())
      end
      local phase_end = g.turn_flow.phases and g.turn_flow.phases.end_turn
      assert(type(phase_end) == "function", "end_turn phase should exist")
      phase_end(g.turn_flow, { player = g.players[1] })
    end)
  end)
  assert(g.players[1].status.move_dir == nil, "player1 move_dir should be cleared at end turn")
  assert(g.players[2].status.move_dir == nil, "player2 move_dir should be cleared at end turn")
  assert(#stopped_ids == 1, "end turn should only stop players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "end turn stop should target valid vehicle player")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "end turn should bump vehicle_resync_seq")
end

local function _test_stop_all_players_movement_skips_invalid_role_without_error()
  local g = new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = 4002
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local stopped_ids = {}
  context_helpers.with_vehicle_enabled(function()
    support.with_patches({
      { key = "vehicle_helper", value = {
        resolve_role = function(role_id)
          if role_id == g.players[1].id then
            return { id = role_id }
          end
          return nil
        end,
        forward_eca_event_stop = function(role_id)
          table.insert(stopped_ids, role_id)
        end,
      } },
    }, function()
      g:stop_all_players_movement()
    end)
  end)
  assert(#stopped_ids == 1, "invalid role should be skipped during stop")
  assert(stopped_ids[1] == g.players[1].id, "only valid role should receive stop")
end

local function _test_set_player_seat_emits_exit_then_enter()
  local g = new_game()
  local p = g.players[1]
  p.seat_id = 4001
  local calls = {}
  local helper = {
    needs_enter_wait_by_player = {},
    forward_eca_event_exit = function(role_id)
      calls[#calls + 1] = "exit:" .. tostring(role_id)
    end,
    forward_eca_event_enter = function(role_id, vehicle_id)
      calls[#calls + 1] = "enter:" .. tostring(role_id) .. ":" .. tostring(vehicle_id)
    end,
  }
  context_helpers.with_vehicle_enabled(function()
    support.with_patches({
      { key = "vehicle_helper", value = helper },
    }, function()
      g:set_player_seat(p, 4004)
    end)
  end)
  assert(calls[1] == "exit:1", "seat replace should exit old vehicle first")
  assert(calls[2] == "enter:1:4004", "seat replace should enter new vehicle")
  assert(p.seat_id == 4004, "seat id should update")
  assert(helper.needs_enter_wait_by_player[1] == true, "seat replace should mark enter wait")
end

local function _test_mine_destroy_vehicle_emits_exit_event()
  local g = new_game()
  local p = g.players[1]
  p.seat_id = 4001
  local exited = {}
  context_helpers.with_vehicle_enabled(function()
    support.with_patches({
      { key = "vehicle_helper", value = {
        forward_eca_event_exit = function(role_id)
          exited[#exited + 1] = role_id
        end,
      } },
    }, function()
      mine_effect.apply(g, p, p.position)
    end)
  end)
  assert(p.seat_id == nil, "mine should clear seat_id")
  assert(#exited == 1 and exited[1] == p.id, "mine should emit exit event when vehicle destroyed")
end

local function _test_vehicle_feature_disabled_ignores_seat_bonus()
  local g = new_game()
  local p = g:current_player()
  p.seat_id = 4010

  assert(g:player_dice_count(p) == constants.default_dice_count, "disabled vehicle should not increase dice count")
  assert(g:player_is_vehicle_indestructible(p) == false, "disabled vehicle should not grant mine immunity")
end

local function _test_turn_move_anim_omits_vehicle_id_when_disabled()
  local g = new_game()
  local p = g:current_player()
  p.seat_id = 4001
  g.last_turn = {}
  g.ui_port = support.build_ui_port({ wait_move_anim = true })

  support.with_patches({
    { target = movement, key = "move", value = function()
      return {
        visited = {},
        steps = 1,
        stopped_on_roadblock = false,
        market_interrupt = nil,
        steal_interrupt = nil,
      }
    end },
  }, function()
    local next_state = turn_move({ game = g }, { player = p, total = 1, raw_total = 1 })
    assert(next_state == "wait_move_anim", "move phase should wait for move_anim")
  end)

  assert(g.turn.move_anim ~= nil, "turn move should create move_anim payload")
  assert(g.turn.move_anim.vehicle_id == nil, "disabled vehicle should not be written into move_anim payload")
end

local function _test_tick_headless_ports_cover_anim_phases()
  local g = new_game()
  g.update = nil
  local state = loop_builder.build_loop_state()
  state.ui = nil
  state.wait_move_anim = true
  state.wait_action_anim = true
  local dispatched = {}
  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local calls = {
    move_anim = 0,
    action_anim = 0,
    countdown = 0,
    refresh = 0,
  }

  state.gameplay_loop_ports = loop_builder.build_test_ports({
    play_move_anim = function(_, anim_ctx)
      calls.move_anim = calls.move_anim + 1
      assert(anim_ctx and anim_ctx.seq == 101, "move anim ctx should be injected")
      return 0
    end,
    play_action_anim = function(_, anim_ctx)
      calls.action_anim = calls.action_anim + 1
      assert(anim_ctx and anim_ctx.seq == 201, "action anim ctx should be injected")
      return 0
    end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function()
      calls.countdown = calls.countdown + 1
    end,
    refresh_from_dirty = function()
      calls.refresh = calls.refresh + 1
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  g.turn.phase = "wait_move_anim"
  g.turn.move_anim = { seq = 101 }
  gameplay_loop.tick(g, state, 0.1)
  assert(calls.move_anim == 1, "headless move anim should use injected port")
  assert(dispatched[1] and dispatched[1].type == "move_anim_done", "move anim should dispatch move_anim_done")
  assert(dispatched[1] and dispatched[1].seq == 101, "move anim seq should be forwarded")

  g.turn.phase = "wait_action_anim"
  g.turn.action_anim = { seq = 201 }
  gameplay_loop.tick(g, state, 0.1)
  assert(calls.action_anim == 1, "headless action anim should use injected port")
  assert(dispatched[2] and dispatched[2].type == "action_anim_done", "action anim should dispatch action_anim_done")
  assert(dispatched[2] and dispatched[2].seq == 201, "action anim seq should be forwarded")

  assert(calls.countdown >= 2, "countdown should still step under custom ports")
  assert(calls.refresh >= 2, "refresh_from_dirty should still be called under custom ports")
end

local function _test_action_button_timeout_auto_advances()
  local g = new_game()
  local state = loop_builder.build_loop_state()
  g.ui_port = support.build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = loop_builder.build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  context_helpers.with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 1, "action button timeout should advance turn")
end

local function _test_action_button_timeout_blocked_when_input_locked()
  local g = new_game()
  g.update = nil
  local state = loop_builder.build_loop_state()
  g.ui_port = support.build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action_anim"
  g.turn.pending_choice = nil

  state.ui.input_blocked = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = loop_builder.build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  context_helpers.with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "input locked should block action button timeout")
  assert(state.action_button_active == false, "input locked should disable action timer")
  assert(state.action_button_elapsed == 0, "input locked should reset action timer")
end

local function _test_action_button_timeout_blocked_when_popup_active()
  local g = new_game()
  local state = loop_builder.build_loop_state()
  g.ui_port = support.build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  state.ui.popup_active = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = loop_builder.build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  context_helpers.with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "popup active should block action button timeout")
  assert(state.action_button_active == false, "popup active should disable action timer")
  assert(state.action_button_elapsed == 0, "popup active should reset action timer")
end

local function _test_auto_runner_auto_advances_ai_player()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  state.auto_runner.interval = 0.4
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local a1 = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a1 == nil, "should not trigger before reaching auto interval")
    local a2 = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a2 and a2.type == "ui_button" and a2.id == "next", "ai player should auto dispatch next")
  end)
end

local function _test_auto_runner_human_turn_not_auto_advanced()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[1].id,
      current_player_auto = false,
    })
    assert(action == nil, "human turn should not auto dispatch next")
  end)
end

local function _test_auto_runner_not_advanced_when_input_blocked()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  state.ui.input_blocked = true
  g.turn.current_player_index = 2
  g.turn.phase = "wait_action_anim"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(action == nil, "blocked phase should not auto dispatch next")
  end)
end

local function _test_turn_prompt_initialized_for_first_player()
  local g = new_game()
  local current_player = g:current_player()

  assert((g.turn.turn_start_prompt_seq or 0) == 1, "first turn should initialize prompt seq")
  assert(g.turn.turn_start_prompt_player_id == current_player.id,
    "first turn prompt target should be current player")
end

local function _test_turn_prompt_emitted_on_next_player_switch()
  local g = new_game()
  with_turn_flow(g)
  local before_seq = g.turn.turn_start_prompt_seq or 0
  local before_index = g.turn.current_player_index
  local expected_next_index = before_index % #g.players + 1
  local expected_player = g.players[expected_next_index]

  g.turn_flow:next_player()

  assert(g.turn.current_player_index == expected_next_index, "next_player should switch player index")
  assert((g.turn.turn_start_prompt_seq or 0) == before_seq + 1,
    "next_player should emit one new prompt seq")
  assert(g.turn.turn_start_prompt_player_id == expected_player.id,
    "next_player prompt target should be switched player")
end

local function _test_auto_runner_depends_on_current_player_auto()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  g.players[1].auto = true
  g.players[2].auto = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local action1 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = true,
    })
    assert(action1 and action1.type == "ui_button" and action1.id == "next",
      "current player auto should dispatch next")

    state.next_turn_locked = false
    g.turn.current_player_index = 2
    local action2 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = false,
    })
    assert(action2 == nil, "current player auto=false should not dispatch")
  end)
end

local _tests = {
  _test_mandatory_payment_causes_bankruptcy,
  _test_bankruptcy_resets_owned_tiles,
  _test_set_tile_owner_without_ui_port_does_not_crash,
  _test_tile_owner_notifier_receives_owner_changes,
  _test_dispatch_validator_accepts_ui_state_snapshot,
  _test_stop_all_players_movement_clears_move_dir_and_stop_event,
  _test_end_turn_stops_all_players_movement,
  _test_stop_all_players_movement_skips_invalid_role_without_error,
  runtime_cases.test_runtime_context_get_vehicle_player_no_fallback,
  runtime_cases.test_runtime_context_forward_stop_skips_invalid_role,
  runtime_cases.test_runtime_context_split_install_stages,
  runtime_cases.test_runtime_context_install_environment_fails_fast,
  _test_set_player_seat_emits_exit_then_enter,
  _test_mine_destroy_vehicle_emits_exit_event,
  _test_vehicle_feature_disabled_ignores_seat_bonus,
  _test_turn_move_anim_omits_vehicle_id_when_disabled,
  autorunner_cases.test_autorunner_runs_to_end,
  autorunner_cases.test_complex_consecutive_turn_settlement,
  autorunner_cases.test_complex_market_interrupt_with_rent,
  _test_tick_headless_ports_cover_anim_phases,
  _test_action_button_timeout_auto_advances,
  _test_action_button_timeout_blocked_when_input_locked,
  _test_action_button_timeout_blocked_when_popup_active,
  _test_auto_runner_auto_advances_ai_player,
  _test_auto_runner_human_turn_not_auto_advanced,
  _test_auto_runner_not_advanced_when_input_blocked,
  _test_auto_runner_depends_on_current_player_auto,
  _test_turn_prompt_initialized_for_first_player,
  _test_turn_prompt_emitted_on_next_player_switch,
}

local _cases = {}
for index, run in ipairs(_tests) do
  _cases[#_cases + 1] = {
    id = "gameplay.case_" .. tostring(index),
    desc = "gameplay migrated case " .. tostring(index),
    run = run,
  }
end

return {
  layer = "regression",
  domain = "gameplay",
  cases = _cases,
}
