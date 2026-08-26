---@diagnostic disable
-- luacheck: ignore 113 211
local control = require("src.player.control")
local function make_cases(helpers)
  local _ENV = helpers

local function _test_turn_prompt_initialized_for_first_player()
  local g = _new_game()

  assert((g.turn.turn_start_prompt_seq or 0) == 0, "first turn should not pre-seed prompt seq")
  assert(g.turn.turn_start_prompt_player_id == nil,
    "first turn prompt target should be nil until runtime emits it")
end

local function _test_turn_prompt_emitted_on_next_player_switch()
  local g = _new_game()
  local before_seq = g.turn.turn_start_prompt_seq or 0
  local before_index = g.turn.current_player_index
  local expected_next_index = before_index % #g.players + 1
  local expected_player = g.players[expected_next_index]

  g.turn_runtime = TurnScheduler:new(g, {
    start = function(_, args)
      if args and args.finished then
        return nil
      end
      return "inter_turn_wait", { finished = true }
    end,
  })
  g.turn_runtime:run_turn()

  assert(g.turn.current_player_index == expected_next_index, "inter-turn completion should switch player index")
  assert((g.turn.turn_start_prompt_seq or 0) == before_seq + 1,
    "inter-turn completion should emit one new prompt seq")
  assert(g.turn.turn_start_prompt_player_id == expected_player.id,
    "inter-turn prompt target should be switched player")
end

local function _test_auto_runner_depends_on_current_player_computer_controlled()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local auto_decision_delay = timing.auto_decision_delay_seconds or 0
  control.toggle_manual_delegation(g.players[1])
  control.initialize(g.players[2])
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action1 = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_computer_controlled = true,
    })
    assert(action1 and action1.type == "ui_button" and action1.id == "next",
      "current player auto should dispatch next")

    state.turn_runtime.next_turn_locked = false
    g.turn.current_player_index = 2
    local action2 = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_computer_controlled = false,
    })
    assert(action2 == nil, "current player auto=false should not dispatch")
  end)
end

local function _test_turn_dispatch_uses_clock_ports_without_game_api()
  local g = _new_game()
  local state = _build_loop_state()
  state.game = g
  g.ui_port = state
  local current_player = g:current_player()
  local now = 1.0
  local stepped = 0

  state.gameplay_loop_ports = _build_test_ports({
    wall_now_seconds = function()
      return now
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      return (timestamp_1 or 0) - (timestamp_2 or 0)
    end,
  })
  state.turn_runtime.next_turn_locked = true
  state.turn_runtime.next_turn_last_click = 1.0
  state.turn_runtime.next_turn_lock_phase = g.turn.phase

  support.with_patches({
    { target = turn_dispatch, key = "step_turn", value = function()
      stepped = stepped + 1
    end },
    { key = "GameAPI", value = {} },
  }, function()
    now = 1.2
    local rejected = turn_dispatch.dispatch_action(g, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    assert(rejected.status == "rejected", "next should respect cooldown via clock port")

    now = 1.6
    local applied = turn_dispatch.dispatch_action(g, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    assert(applied.status == "applied", "next should pass when clock diff reaches cooldown")
  end)

  assert(stepped == 1, "step_turn should run exactly once")
end

local function _test_gameplay_loop_set_game_uses_narrow_runtime_ports()
  local g = _new_game()
  local state = _build_loop_state()
  state.wait_move_anim = true
  state.wait_action_anim = true
  state.board_scene = { marker = "scene" }
  state.push_popup = function(_, payload)
    state._last_popup = payload
    return true
  end
  state.on_board_visual_sync = function(_, payload)
    state._last_board_visual_sync = payload
    return true
  end

  gameplay_loop.set_game(state, g)

  assert(g.ui_port ~= state, "set_game should not inject raw state as catch-all runtime ui port")
  assert(g.board_scene_port ~= state, "set_game should inject a narrow board_scene_port instead of raw state")
  assert(g.board_scene_port:get_board_scene() == state.board_scene, "board_scene_port should expose board_scene getter")
  assert(g.board_visual_feedback_port ~= nil, "set_game should inject board_visual_feedback_port dto")

  g.popup_port:push_popup({ kind = "test_popup" })
  assert(state._last_popup and state._last_popup.kind == "test_popup", "popup_port should forward popup calls")

  g.tile_owner_notifier:notify_owner_changed(11, 22)
  assert(state._last_board_visual_sync and state._last_board_visual_sync.tile_ids[1] == 11,
    "tile_owner_notifier should forward tile id through board visual sync")
end

local function _test_gameplay_loop_refresh_drives_camera_follow_via_port()
  local g = _new_game()
  local state = _build_loop_state()
  local followed_player_id = nil
  g.turn.current_player_index = 2
  g.dirty.any = true
  g.dirty.ui = true

  state.gameplay_loop_ports = _build_test_ports({
    refresh_from_dirty = function()
      return true
    end,
    follow_camera = function(_, player_id)
      followed_player_id = player_id
      return true
    end,
    update_countdown = function() end,
    sync_status_3d = function() end,
    sync_event_log = function() end,
  })

  gameplay_loop.tick(g, state, 0.1)

  assert(followed_player_id == g.players[2].id, "camera follow should be driven by use-case loop with current player id")
end

local function _test_gameplay_loop_camera_follow_skips_eliminated_current_player()
  local g = _new_game()
  local state = _build_loop_state()
  local followed_player_id = nil
  g.turn.current_player_index = 1
  g.players[1].eliminated = true
  g.players[2].eliminated = false
  g.dirty.any = true
  g.dirty.ui = true

  state.gameplay_loop_ports = _build_test_ports({
    refresh_from_dirty = function()
      return true
    end,
    follow_camera = function(_, player_id)
      followed_player_id = player_id
      return true
    end,
    update_countdown = function() end,
    sync_status_3d = function() end,
    sync_event_log = function() end,
  })

  gameplay_loop.tick(g, state, 0.1)

  assert(followed_player_id == g.players[2].id,
    "camera follow should move to next alive player when current player is eliminated")
end

local function _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics()
  support.with_patches({
    { key = "GameAPI", value = {} },
    { target = os, key = "clock", value = function() return 9.25 end },
  }, function()
    local ports = gameplay_loop_ports.resolve(nil)
    local clock = ports.clock
    assert(clock.wall_now_seconds() == 0, "wall clock should not fallback to cpu clock when GameAPI timestamp is unavailable")
    assert(clock.cpu_now_seconds() == 0, "default cpu clock should be environment-agnostic before runtime injection")
  end)

  local ports = gameplay_loop_ports.resolve({
    clock = {
      wall_now_seconds = function() return 77 end,
      wall_diff_seconds = function() return 0.6 end,
      cpu_now_seconds = function() return 3.5 end,
      cpu_diff_seconds = function(a, b) return a - b end,
    },
  })
  local clock = ports.clock
  assert(clock.wall_now_seconds() == 77, "wall clock should use injected wall source")
  assert(clock.wall_diff_seconds(10, 9) == 0.6, "wall diff should use injected wall semantics")
  assert(clock.cpu_now_seconds() == 3.5, "cpu clock should use injected cpu source")
  assert(clock.cpu_diff_seconds(10, 9) == 1, "cpu diff should stay arithmetic and source-agnostic")
end

local function _test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  control.toggle_manual_delegation(auto_player)
  local state = _bind_ui_runtime({ pending_choice_elapsed = 1.2 })
  local choice = {
    id = 1001,
    kind = "market_buy",
    route_key = "market",
    allow_cancel = true,
    meta = { player_id = auto_player.id, active_tab = "item", page_index = 1, page_count = 1 },
    options = { { id = "buy", label = "购买" } },
  }

  local from_wait = choice_auto_policy.decide(g, state, choice, {
    mode = "wait_choice",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })
  local from_timeout = choice_auto_policy.decide(g, state, choice, {
    mode = "tick_timeout",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })
  assert(from_wait and from_timeout, "auto policy should return actions for auto actor")
  assert(from_wait.type == "choice_cancel", "wait_choice should keep market auto-cancel behavior")
  assert(from_timeout.type == "choice_cancel", "tick_timeout should default to cancel when choice allows cancel")
  assert(from_wait.choice_id == from_timeout.choice_id, "wait/timeout should target same choice")
  assert(from_wait.option_id == nil, "wait_choice cancel should not carry option_id")
  assert(from_timeout.option_id == nil, "timeout cancel should not carry option_id")
end

local function _test_choice_auto_policy_preconsumed_wait_choice_picks_first_option()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  control.toggle_manual_delegation(auto_player)
  local choice = {
    id = 1004,
    kind = "remote_dice_value",
    allow_cancel = false,
    meta = {
      player_id = auto_player.id,
      item_preconsumed = true,
    },
    options = { { id = 5, label = "5" }, { id = 6, label = "6" } },
  }

  local action = choice_auto_policy.decide(g, nil, choice, {
    mode = "wait_choice",
    elapsed_seconds = 1,
  })

  assert(action ~= nil, "preconsumed choice should produce fallback action in wait_choice mode")
  assert(action.type == "choice_select", "preconsumed choice should select instead of cancel")
  assert(action.option_id == 5, "preconsumed choice should select the first option")
end

local function _test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed()
  local g = _new_game()
  local state = {}
  local stepped = 0
  g.turn.detained_wait_active = true
  g.turn.detained_wait_elapsed = 0.4
  g.turn.detained_wait_seconds = 0.5

  turn_timer_policy.update_detained_wait_timer(g, state, 0.2, function(game)
    assert(game == g, "detained wait should step the current game")
    stepped = stepped + 1
  end)

  assert(stepped == 1, "detained wait should step turn after timeout")
  assert(g.turn.detained_wait_active == false, "detained wait should clear active flag after timeout")
  assert(g.turn.detained_wait_elapsed == 0, "detained wait should reset elapsed after timeout")
end

  local function _test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed()
    local g = _new_game()
    local state = {}
    local stepped = 0
  g.turn.inter_turn_wait_active = true
  g.turn.inter_turn_wait_elapsed = 0.4
  g.turn.inter_turn_wait_seconds = 0.5

  turn_timer_policy.update_inter_turn_wait_timer(g, state, 0.2, function(game)
    assert(game == g, "inter-turn wait should step the current game")
    stepped = stepped + 1
  end)

  assert(stepped == 1, "inter-turn wait should step turn after timeout")
    assert(g.turn.inter_turn_wait_active == false, "inter-turn wait should clear active flag after timeout")
    assert(g.turn.inter_turn_wait_elapsed == 0, "inter-turn wait should reset elapsed after timeout")
  end


local function _test_gameplay_loop_ports_rejects_legacy_flat_override()
  local ok, err = pcall(function()
    gameplay_loop_ports.resolve({
      close_choice_modal = function() end,
    })
  end)

  assert(ok == false, "legacy flat gameplay_loop_ports override should be rejected")
  assert(tostring(err):find("legacy flat gameplay_loop_ports is not supported", 1, true) ~= nil,
    "legacy flat gameplay_loop_ports override should explain grouped-port requirement")
end

local function _test_build_noop_group_characterization()
  local loop_ports = require("src.turn.loop.ports")

  local group1 = loop_ports._build_noop_group({ "key1", "key2", "key3" }, nil)
  assert(type(group1) == "table", "should return a table")
  assert(type(group1.key1) == "function", "key1 should be a function")
  assert(type(group1.key2) == "function", "key2 should be a function")
  assert(type(group1.key3) == "function", "key3 should be a function")
  group1.key1()
  group1.key2()
  group1.key3()

  local override_fn = function() return "overridden" end
  local group2 = loop_ports._build_noop_group({ "key1", "key2" }, { key2 = override_fn })
  assert(type(group2.key1) == "function", "key1 should be a function")
  assert(group2.key2() == "overridden", "key2 should use override function")

  local group3 = loop_ports._build_noop_group({}, nil)
  assert(type(group3) == "table", "should return empty table for empty keys")
  local count = 0
  for _ in pairs(group3) do count = count + 1 end
  assert(count == 0, "group should have no keys when keys is empty")

  local group4 = loop_ports._build_noop_group({ "key1" }, nil)
  assert(type(group4.key1) == "function", "key1 should be a function even with nil overrides")
  group4.key1()
end

local function _test_popup_countdown_uses_effective_modal_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  state.ui.popup_active = true
  state.ui.popup_payload = { auto_close_seconds = 3 }
  state.ui_modal_elapsed = 1.2
  state.pending_choice = nil
  _bind_ui_runtime(state)
  state.action_button_active = false
  state.countdown_last = nil
  state.countdown_active_last = nil

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 10 },
    { target = timing, key = "popup_auto_close_seconds", value = 8 },
  }, function()
    tick_ui_sync.update_countdown(g, state)
  end)

  assert(g.turn.countdown_seconds == 2, "popup countdown should use popup effective timeout")
  assert(g.turn.countdown_active == true, "popup countdown should stay active")
end

local function _test_market_countdown_uses_double_action_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  local timing = require("src.config.gameplay.timing")
  g.turn.current_player_index = 2
  state.pending_choice = {
    id = 2001,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = g.players[2].id,
    meta = { player_id = g.players[2].id },
  }
  state.pending_choice_elapsed = 12.2
  _bind_ui_runtime(state)
  state.ui_runtime.pending_choice = state.pending_choice
  state.ui_runtime.pending_choice_elapsed = state.pending_choice_elapsed
  state.action_button_active = false
  state.countdown_last = nil
  state.countdown_active_last = nil
  g.turn.pending_choice = state.pending_choice

  tick_ui_sync.update_countdown(g, state)
  local market_timeout = choice_timeout.resolve_choice_timeout_seconds(g, state, state.pending_choice)
  assert(market_timeout == timing.scope_timeouts.market_buy,
    "market choice timeout should use scope_timeouts.market_buy, got " .. tostring(market_timeout))

  -- countdown_seconds 由 ui_sync 计算（market_timeout - elapsed），向上取整
  -- DeadlineService 优先：market_buy 60s，elapsed 12.2 → remaining 47.8 → ceil 48
  -- 旧路径：60 - 12.2 = 47.8 → ceil 48
  assert(g.turn.countdown_seconds == 48, "market countdown should be 60-12.2=47.8 ceil to 48, got " .. tostring(g.turn.countdown_seconds))
  assert(g.turn.countdown_active == true, "market countdown should stay active")
end

local function _test_dispatch_gate_blocks_next_when_choice_active()
  local g = _new_game()
  local state = _build_loop_state()
  state.game = g
  state.ui.input_blocked = false
  state.ui.choice_active = true
  state.ui.market_active = false
  state.ui.popup_active = false
  local current_player = g:current_player()

  local should_block_next = turn_dispatch.should_block_action(state, {
    type = "ui_button",
    id = "next",
    actor_role_id = current_player.id,
  })
  local should_block_choice = turn_dispatch.should_block_action(state, {
    type = "choice_select",
    choice_id = 1,
    option_id = 1,
    actor_role_id = current_player.id,
  })

  assert(should_block_next == true, "choice active should block next")
  assert(should_block_choice == false, "choice active should not block choice confirm")
end

local function _test_game_startup_role_roster_retries_before_debug_players_fallback()
  local state = nil
  local resolve_calls = 0
  local created_opts = nil
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  support.with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function()
      resolve_calls = resolve_calls + 1
      if resolve_calls == 1 then
        return {}
      end
      return {
        {
          get_roleid = function() return 101 end,
          get_name = function() return "Role101" end,
        },
      }
    end },
    { target = app, key = "new", value = function(_, opts)
      created_opts = opts
      return {}
    end },
  }, function()
    state = _build_startup_state(function()
      return nil
    end)
    state.game_factory()
  end)

  assert(type(created_opts) == "table", "game startup should create game options")
  assert(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4,
    "game startup should build a 4-slot role_roster after retry")
  assert(created_opts.role_roster[1].role_id == 101, "role_roster should include retried role id")
  assert(created_opts.role_roster[1].name == "Role101", "role_roster should include retried role name")
  assert(created_opts.role_roster[2].synthetic == true and created_opts.role_roster[3].synthetic == true
    and created_opts.role_roster[4].synthetic == true,
    "game startup should synthesize missing slots when retry succeeds")
  assert(created_opts.players == nil, "game startup should keep role_roster startup when retry succeeds")
end

  return {
    _test_turn_prompt_initialized_for_first_player = _test_turn_prompt_initialized_for_first_player,
    _test_turn_prompt_emitted_on_next_player_switch = _test_turn_prompt_emitted_on_next_player_switch,
    _test_auto_runner_depends_on_current_player_computer_controlled = _test_auto_runner_depends_on_current_player_computer_controlled,
    _test_turn_dispatch_uses_clock_ports_without_game_api = _test_turn_dispatch_uses_clock_ports_without_game_api,
    _test_gameplay_loop_set_game_uses_narrow_runtime_ports = _test_gameplay_loop_set_game_uses_narrow_runtime_ports,
    _test_gameplay_loop_refresh_drives_camera_follow_via_port = _test_gameplay_loop_refresh_drives_camera_follow_via_port,
    _test_gameplay_loop_camera_follow_skips_eliminated_current_player = _test_gameplay_loop_camera_follow_skips_eliminated_current_player,
    _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics = _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics,
    _test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy = _test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy,
    _test_choice_auto_policy_preconsumed_wait_choice_picks_first_option = _test_choice_auto_policy_preconsumed_wait_choice_picks_first_option,
    _test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed = _test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed,
    _test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed = _test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed,
    _test_gameplay_loop_ports_rejects_legacy_flat_override = _test_gameplay_loop_ports_rejects_legacy_flat_override,
    _test_build_noop_group_characterization = _test_build_noop_group_characterization,
    _test_popup_countdown_uses_effective_modal_timeout = _test_popup_countdown_uses_effective_modal_timeout,
    _test_market_countdown_uses_double_action_timeout = _test_market_countdown_uses_double_action_timeout,
    _test_dispatch_gate_blocks_next_when_choice_active = _test_dispatch_gate_blocks_next_when_choice_active,
    _test_game_startup_role_roster_retries_before_debug_players_fallback = _test_game_startup_role_roster_retries_before_debug_players_fallback,
  }
end

return { make_cases = make_cases }
