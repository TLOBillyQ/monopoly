local support = require("support.regression_support")
local context_helpers = require("support.regression.runtime_context_helpers")
local runtime_cases = require("support.regression.runtime_context_cases")
local autorunner_cases = require("support.regression.gameplay_autorunner_cases")
local loop_cases = require("support.regression.gameplay_loop_cases")
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
  loop_cases.test_tick_headless_ports_cover_anim_phases,
  loop_cases.test_action_button_timeout_auto_advances,
  loop_cases.test_action_button_timeout_blocked_when_input_locked,
  loop_cases.test_action_button_timeout_blocked_when_popup_active,
  loop_cases.test_auto_runner_auto_advances_ai_player,
  loop_cases.test_auto_runner_human_turn_not_auto_advanced,
  loop_cases.test_auto_runner_not_advanced_when_input_blocked,
  loop_cases.test_auto_runner_depends_on_current_player_auto,
  loop_cases.test_turn_prompt_initialized_for_first_player,
  loop_cases.test_turn_prompt_emitted_on_next_player_switch,
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
