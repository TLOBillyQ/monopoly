local P = require("support.presentation_action_status_prelude")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local _wrap_ui_refs = P.wrap_ui_refs
local support = require("support.presentation_support")
local gameplay_loop = support.gameplay_loop
local event_handlers = require("src.ui.coord.event_handlers")
local paid_currency_bridge = require("src.rules.commerce.paid_currency_bridge")
local gameplay_rules = require("src.config.gameplay.debug_flags")
local action_anim = require("src.ui.render.anim")
local runtime_cls = require("src.turn.loop.scheduler_runtime")
local role_control_lock_policy = require("src.ui.input.role_control_lock")
local timing = require("src.config.gameplay.timing")









local function _make_unit(initial_count)
  local unit = {
    count = initial_count or 0,
    add_calls = 0,
    remove_calls = 0,
  }
  function unit.get_state_count()
    return unit.count
  end
  function unit.add_state()
    unit.add_calls = unit.add_calls + 1
    unit.count = unit.count + 1
  end
  function unit.remove_state()
    unit.remove_calls = unit.remove_calls + 1
    unit.count = math.max(0, unit.count - 1)
  end
  return unit
end

describe("presentation_action_anim_queue_and_turn_lock", function()
  it("_test_tick_skips_anim_when_no_anim", function()
    local dirty_tracker = require("src.state.dirty_tracker")
    local main_view = require("src.ui.coord.ui_runtime")
    local ui_model = require("src.ui.view")
    local board_view_mod = require("src.ui.render.board")

    local game_api = GameAPI or {}
    local patches = {
      { target = main_view, key = "refresh_panel", value = function() end },
      { target = board_view_mod, key = "refresh", value = function() end },
      { target = require("src.ui.coord.modal"), key = "open_choice_modal", value = function() end },
      { target = ui_model, key = "build", value = function(game_ctx)
        return {
          current_player_name = "P",
          current_player_cash = 0,
          turn_count = game_ctx.turn.turn_count,
          panel = { turn_label = "" },
          board = {},
        }
      end },
      { target = ui_model, key = "update", value = function(_, game_ctx)
        return {
          current_player_name = "P",
          current_player_cash = 0,
          turn_count = game_ctx.turn.turn_count,
          panel = { turn_label = "" },
          board = {},
        }
      end },
      { key = "GameAPI", value = game_api },
      { target = game_api, key = "get_role", value = function()
        return {
          set_camera_bind_mode = function() end,
          set_camera_lock_position = function() end,
        }
      end },
      { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
    }

    local game = {
      finished = false,
      winner = nil,
      players = { [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } } },
      board = {
        get_overlays = function() return { roadblocks = {}, mines = {} } end,
        tile_lookup = {},
      },
      turn = {
        phase = "move",
        current_player_index = 1,
        turn_count = 0,
        pending_choice = nil,
        move_anim = nil,
        action_anim = nil,
      },
      dirty = dirty_tracker.new(),
    }
    function game:consume_dirty()
      return dirty_tracker.consume(self.dirty)
    end
    function game:current_player()
      return self.players[self.turn.current_player_index]
    end
    local state = {
      auto_runner = {
        next_action = function() return nil end,
        reset_timer = function() end,
      },
      _log_once = {},
      pending_choice = nil,
      pending_choice_elapsed = 0,
      pending_choice_id = nil,
      ui_modal_elapsed = 0,
      ui_modal_ref = nil,
      board_last_phase = nil,
      board_sync_pending = false,
      next_turn_locked = false,
      next_turn_lock_phase = nil,
      player_units = {
        [1] = {
          get_position = function() return { x = 0, y = 0, z = 0 } end
        }
      },
      ui = { input_blocked = false },
    }

    local ok, err = pcall(function()
      _with_patches(patches, function()
        gameplay_loop.tick(game, state, 0.1)
      end)
    end)

    assert(ok, "tick should not error without anim: " .. tostring(err))
  end)

  it("_test_action_anim_queue_consumes_in_order", function()
    local phases = {
      start = function()
        return "wait_action_anim", { next_state = "done", next_args = {} }
      end,
      done = function()
        return nil
      end,
    }
    local g = {
      turn = {
        phase = "start",
        current_player_index = 1,
        turn_count = 0,
        pending_choice = nil,
        action_anim = { seq = 1, kind = "item_use", player_id = 1 },
        action_anim_queue = { { seq = 2, kind = "item_use", player_id = 1 } },
      },
      dirty = { turn = false, any = false },
      board = {
        get_tile_by_id = function()
          return { level = 0, name = "" }
        end,
      },
      players = {
        [1] = {
          id = 1,
          name = "P1",
          cash = 0,
          status = { stay_turns = 0, deity = nil },
          inventory = { items = {} },
          properties = {},
        }
      },
    }
    function g:current_player()
      return self.players[self.turn.current_player_index]
    end
    function g:player_balance(player)
      return player.cash
    end
    local engine = runtime_cls:new(g, phases)

    local state = engine:run_turn()
    _assert_eq(state, "wait_action_anim", "should wait action anim")
    _assert_eq(g.turn.action_anim.seq, 1, "current anim should be seq1")

    engine:dispatch({ type = "action_anim_done", seq = 999 })
    _assert_eq(g.turn.phase, "wait_action_anim", "wrong seq should keep wait_action_anim")
    _assert_eq(g.turn.action_anim.seq, 1, "wrong seq should keep current anim")

    engine:dispatch({ type = "action_anim_done", seq = 1 })
    _assert_eq(g.turn.phase, "wait_action_anim", "should still wait second anim")
    _assert_eq(g.turn.action_anim.seq, 2, "current anim should switch to seq2")

    engine:dispatch({ type = "action_anim_done", seq = 2 })
    assert(g.turn.phase ~= "wait_action_anim", "should leave action anim wait after queue drained")
    assert(g.turn.action_anim == nil, "action_anim should be nil after queue drained")
  end)

  it("_test_action_anim_default_duration", function()
    local durations = {}
    local state = {
      game = { turn = { current_player_index = 1 }, players = { [1] = { id = 1 } } },
    }
    _with_patches({
      { key = "GlobalAPI", value = { show_tips = function(_, duration) durations[#durations + 1] = duration end } },
      { key = "SetTimeOut", value = function() end },
    }, function()
      local d1 = action_anim.play(state, { kind = "item_use", player_id = 1 })
      local d2 = action_anim.play(state, { kind = "item_use", player_id = 1, duration = 1.8 })
      _assert_eq(d1, timing.action_anim_default_seconds, "default action anim duration should follow gameplay rule")
      _assert_eq(d2, 1.8, "explicit action anim duration should override")
    end)
    _assert_eq(#durations, 0, "default action anim should not consume tip queue")
  end)

  it("_test_action_anim_no_camera_focus_side_effect", function()
    local follow_events = 0
    local state = {
      game = {
        turn = { current_player_index = 1 },
        players = { [1] = { id = 1 }, [2] = { id = 2 } },
      },
    }
    _with_patches({
      { key = "GlobalAPI", value = { show_tips = function() end } },
      { key = "TriggerCustomEvent", value = function() follow_events = follow_events + 1 end },
    }, function()
      local duration = action_anim.play(state, {
        kind = "item_use",
        player_id = 1,
        duration = 0.5,
      })
      _assert_eq(duration, 0.5, "action anim should still return duration")
    end)
    _assert_eq(follow_events, 0, "action anim should not trigger camera follow events")
  end)

  it("_test_ui_sync_defers_choice_modal_during_wait_action_anim", function()
    local ui_view_service = require("src.ui.coord.ui_runtime")
    local ui_model = require("src.ui.view")
    local ui_model_sync = require("src.ui.ports.ui_sync.model")
    local opened = 0
    local game = {
        turn = {
          phase = "wait_action_anim",
          current_player_index = 1,
          turn_count = 1,
          pending_choice = {
            id = 7,
            kind = "market_buy",
            route_key = "market",
            title = "黑市",
          body_lines = { "A" },
          options = { { id = 1, label = "A" } },
          allow_cancel = true,
          cancel_label = "取消",
        },
      },
      players = {
        [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
      },
    }
    local state = {
      ui = ui_view_service.build_ui_state(),
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
      ui_dirty = true,
      ui_model = nil,
    }
    _with_patches({
      { target = ui_view_service, key = "render", value = function() end },
      { target = require("src.ui.coord.modal"), key = "open_choice_modal", value = function()
        opened = opened + 1
      end },
      { target = ui_model, key = "build", value = function()
        return {
          panel = { turn_label = "" },
          board = {},
          choice = { id = 7, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 7, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
      { target = ui_model, key = "update", value = function()
        return {
          panel = { turn_label = "" },
          board = {},
          choice = { id = 7, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 7, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
    }, function()
      ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
        log_once = function() end,
        build_log_prefix = function() return "[test]" end,
      })
    end)
    _assert_eq(opened, 0, "wait_action_anim should defer opening choice modal")
  end)

  it("_test_ui_sync_opens_choice_modal_after_wait_action_anim", function()
    local ui_view_service = require("src.ui.coord.ui_runtime")
    local ui_model = require("src.ui.view")
    local ui_model_sync = require("src.ui.ports.ui_sync.model")
    local opened = 0
    local game = {
      turn = {
        phase = "wait_action_anim",
        current_player_index = 1,
        turn_count = 1,
          pending_choice = {
            id = 8,
            kind = "market_buy",
            route_key = "market",
            title = "黑市",
          body_lines = { "A" },
          options = { { id = 1, label = "A" } },
          allow_cancel = true,
          cancel_label = "取消",
        },
      },
      players = {
        [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
      },
    }
    local state = {
      ui = ui_view_service.build_ui_state(),
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
      ui_dirty = true,
      ui_model = nil,
    }
    _with_patches({
      { target = ui_view_service, key = "render", value = function() end },
      { target = require("src.ui.coord.modal"), key = "open_choice_modal", value = function()
        opened = opened + 1
      end },
      { target = ui_model, key = "build", value = function()
        return {
          current_player_id = 1,
          panel = { turn_label = "" },
          board = {},
          choice = { id = 8, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 8, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
      { target = ui_model, key = "update", value = function()
        return {
          current_player_id = 1,
          panel = { turn_label = "" },
          board = {},
          choice = { id = 8, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 8, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
    }, function()
      ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
        log_once = function() end,
        build_log_prefix = function() return "[test]" end,
      })
      _assert_eq(opened, 0, "choice modal should remain deferred during wait_action_anim")
      game.turn.phase = "wait_choice"
      state.ui_dirty = true
      ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
        log_once = function() end,
        build_log_prefix = function() return "[test]" end,
      })
    end)
    _assert_eq(opened, 1, "choice modal should open once after leaving wait_action_anim")
  end)

  it("_test_ui_sync_defers_choice_modal_during_wait_move_anim", function()
    local ui_view_service = require("src.ui.coord.ui_runtime")
    local ui_model = require("src.ui.view")
    local ui_model_sync = require("src.ui.ports.ui_sync.model")
    local opened = 0
    local game = {
      turn = {
        phase = "wait_move_anim",
        current_player_index = 1,
        turn_count = 1,
          pending_choice = {
            id = 9,
            kind = "market_buy",
            route_key = "market",
            title = "黑市",
          body_lines = { "A" },
          options = { { id = 1, label = "A" } },
          allow_cancel = true,
          cancel_label = "取消",
        },
      },
      players = {
        [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
      },
    }
    local state = {
      ui = ui_view_service.build_ui_state(),
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
      ui_dirty = true,
      ui_model = nil,
    }
    _with_patches({
      { target = ui_view_service, key = "render", value = function() end },
      { target = require("src.ui.coord.modal"), key = "open_choice_modal", value = function()
        opened = opened + 1
      end },
      { target = ui_model, key = "build", value = function()
        return {
          panel = { turn_label = "" },
          board = {},
          choice = { id = 9, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 9, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
      { target = ui_model, key = "update", value = function()
        return {
          panel = { turn_label = "" },
          board = {},
          choice = { id = 9, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 9, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
    }, function()
      ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
        log_once = function() end,
        build_log_prefix = function() return "[test]" end,
      })
    end)
    _assert_eq(opened, 0, "wait_move_anim should defer opening choice modal")
  end)

  it("_test_ui_sync_defers_choice_modal_during_wait_landing_visual", function()
    local ui_view_service = require("src.ui.coord.ui_runtime")
    local ui_model = require("src.ui.view")
    local ui_model_sync = require("src.ui.ports.ui_sync.model")
    local opened = 0
    local game = {
      turn = {
        phase = "wait_landing_visual",
        current_player_index = 1,
        turn_count = 1,
        pending_choice = {
          id = 10,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
          body_lines = { "A" },
          options = { { id = 1, label = "A" } },
          allow_cancel = true,
          cancel_label = "取消",
        },
      },
      players = {
        [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
      },
    }
    local state = {
      ui = ui_view_service.build_ui_state(),
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
      ui_dirty = true,
      ui_model = nil,
    }
    _with_patches({
      { target = ui_view_service, key = "render", value = function() end },
      { target = require("src.ui.coord.modal"), key = "open_choice_modal", value = function()
        opened = opened + 1
      end },
      { target = ui_model, key = "build", value = function()
        return {
          panel = { turn_label = "" },
          board = {},
          choice = { id = 10, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 10, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
      { target = ui_model, key = "update", value = function()
        return {
          panel = { turn_label = "" },
          board = {},
          choice = { id = 10, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
          market = { choice_id = 10, options = { { id = 1, label = "A" } }, allow_cancel = true },
        }
      end },
    }, function()
      ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
        log_once = function() end,
        build_log_prefix = function() return "[test]" end,
      })
    end)
    _assert_eq(opened, 0, "wait_landing_visual should defer opening choice modal")
  end)

  it("_test_role_control_lock_add_remove_owned_only", function()
    local unit1 = _make_unit(0)
    local unit2 = _make_unit(2)
    local role1 = {
      get_roleid = function() return 1 end,
      get_ctrl_unit = function() return unit1 end,
    }
    local role2 = {
      get_roleid = function() return 2 end,
      get_ctrl_unit = function() return unit2 end,
    }
    local roles = { role1, role2 }
    local runtime = {
      for_each_role_or_global = function(fn)
        for _, role in ipairs(roles) do
          fn(role)
        end
      end,
      resolve_role_id = function(role)
        return role.get_roleid()
      end,
    }
    local state = { role_control_lock = { by_role = {} } }

    _with_patches({
      { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
    }, function()
      role_control_lock_policy.sync(state, true, { runtime = runtime })
      role_control_lock_policy.sync(state, false, { runtime = runtime })
    end)

    assert(unit1.add_calls == 1, "role1 should add buff when empty")
    assert(unit1.remove_calls == 1, "role1 should remove owned buff")
    assert(unit2.add_calls == 0, "role2 should not add when already locked")
    assert(unit2.remove_calls == 0, "role2 should not remove external lock")
  end)

  it("_test_role_control_lock_unit_swap_release_old_and_lock_new", function()
    local unit1 = _make_unit(0)
    local unit2 = _make_unit(0)
    local current_unit = unit1
    local role = {
      get_roleid = function() return 1 end,
      get_ctrl_unit = function() return current_unit end,
    }
    local runtime = {
      for_each_role_or_global = function(fn)
        fn(role)
      end,
      resolve_role_id = function(r)
        return r.get_roleid()
      end,
    }
    local state = { role_control_lock = { by_role = {} } }

    _with_patches({
      { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
    }, function()
      role_control_lock_policy.sync(state, true, { runtime = runtime })
      current_unit = unit2
      role_control_lock_policy.sync(state, true, { runtime = runtime })
    end)

    assert(unit1.add_calls == 1, "old unit should be locked once")
    assert(unit1.remove_calls == 1, "old unit should be released on swap")
    assert(unit2.add_calls == 1, "new unit should be locked on swap")
  end)

  it("_test_gameplay_loop_full_turn_lock_toggle", function()
    local calls = {}
    local ports = {
      modal = {
        close_choice_modal = function() end,
        open_choice_modal = function() end,
        close_popup = function() end,
      },
      state = {
        apply_role_control_lock = function(_, enabled)
          table.insert(calls, enabled)
        end,
        install_event_handlers = function() end,
        on_bankruptcy_tiles_cleared = function() end,
      },
      anim = {
        reset_status_3d = function() end,
        play_move_anim = function() end,
        play_action_anim = function() end,
        sync_status_3d = function() end,
      },
      ui_sync = {
        apply_input_lock = function() end,
        step_choice_timeout = function() end,
        step_modal_timeout = function() end,
        update_countdown = function() end,
        build_model = function() return {} end,
        refresh_from_dirty = function() return false end,
        get_ui_state = function(state)
          return state and state.ui or nil
        end,
        is_input_blocked = function(state)
          local ui = state and state.ui or nil
          return ui and ui.input_blocked == true or false
        end,
        is_popup_active = function(state)
          local ui = state and state.ui or nil
          return ui and ui.popup_active == true or false
        end,
        is_choice_active = function(state)
          local ui = state and state.ui or nil
          return ui and ui.choice_active == true or false
        end,
        is_market_active = function(state)
          local ui = state and state.ui or nil
          return ui and ui.market_active == true or false
        end,
        get_popup_owner_index = function() return nil end,
        set_input_blocked = function(state, blocked)
          local ui = state and state.ui or nil
          if not ui then
            return false
          end
          if ui.input_blocked == blocked then
            return false
          end
          ui.input_blocked = blocked
          return true
        end,
      },
      debug = {
        log_status = function() end,
        sync_event_log = function() end,
        resolve_event_log_enabled = function() return false end,
      },
    }
    local state = {
      ui = { input_blocked = false },
      gameplay_loop_ports = ports,
      auto_runner = { set_enabled = function() end, reset_timer = function() end, next_action = function() end },
      pending_choice = nil,
      pending_choice_elapsed = 0,
      pending_choice_id = nil,
      ui_modal_elapsed = 0,
      ui_modal_ref = nil,
      _log_once = {},
      item_name_by_id = {},
      ui_dirty = false,
      board_last_phase = nil,
      board_sync_pending = false,
      next_turn_locked = false,
      next_turn_lock_phase = nil,
      board_last_positions = {},
      countdown_last = nil,
      countdown_active_last = nil,
      action_button_elapsed = 0,
      action_button_active = false,
      role_control_lock_active = false,
    }
    local game = {
      finished = false,
      players = { [1] = { id = 1, name = "P1", auto = false } },
      turn = { current_player_index = 1, phase = "start", turn_count = 1 },
      logger = { info = function() end },
      advance_turn = function() end,
      dispatch_action = function() end,
      consume_dirty = function() return { any = false } end,
    }
    function game:pending_choice()
      return nil
    end

    _with_patches({
      { target = gameplay_rules, key = "role_control_lock_enabled", value = true },
      { target = event_handlers, key = "install", value = function() end },
      { target = paid_currency_bridge, key = "setup_for_game", value = function() end },
    }, function()
      gameplay_loop.set_game(state, game)
      gameplay_loop.tick(game, state, 0.1)
      game.finished = true
      gameplay_loop.tick(game, state, 0.1)
    end)

    _assert_eq(calls[1], false, "set_game should clear lock first")
    _assert_eq(calls[2], true, "active game should enable lock")
    _assert_eq(calls[3], false, "finished game should clear lock")
  end)
end)
