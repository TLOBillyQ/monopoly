local support = require("TestSupport")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local gameplay_loop = support.gameplay_loop
local turn_flow = support.turn_flow
local turn_move = support.turn_move

local function _test_move_anim_callback_and_delay()
  local dispatched = {}
  local layer = { wait_move_anim = true }
  local game = {
    turn = {
      move_anim = { seq = 1 },
      phase = "wait_move_anim",
    },
    dispatch_action = function(_, action)
      table.insert(dispatched, action)
    end,
  }
  local delay_called = nil
  local function call_delay(delay, cb)
    delay_called = delay
    cb()
  end
  _with_patches({
    { key = "LuaAPI", value = { call_delay_time = call_delay } },
    { key = "SetTimeOut", value = call_delay },
  }, function()
    turn_anim.step_move_anim(game, layer, {
      on_move_anim = function(_, anim)
        _assert_eq(anim.seq, 1, "anim seq forwarded")
        return 0.2
      end,
    })
  end)
  _assert_eq(delay_called, 0.2, "delay requested")
  _assert_eq(#dispatched, 1, "move_anim_done dispatched")
  _assert_eq(dispatched[1].seq, 1, "move_anim_done seq")
end

local function _test_popup_timeout_auto_confirm()
  local g = _new_game()
  local layer = {}
  layer.ui_modal_elapsed = 0
  layer.ui_modal_ref = nil
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    return
  end
  local near_timeout = timeout * 0.9
  local popup = {
    active = true,
    confirm_called = 0,
    confirm = function(self)
      self.confirm_called = self.confirm_called + 1
      self.active = false
      return true
    end,
  }
  layer.modal = { active = popup }
  local timeout_opts = {
    is_active = function(l)
      return l.modal and l.modal.active and l.modal.active.active
    end,
    get_ref = function(l)
      return l.modal and l.modal.active
    end,
    on_timeout = function(l)
      l.modal.active:confirm()
    end,
  }
  tick_timeout.step_modal_timeout(layer, near_timeout, timeout_opts)
  _assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
  tick_timeout.step_modal_timeout(layer, near_timeout + 1, timeout_opts)
  _assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
end

local function _test_invalid_choice_option_rejected()
  local g = _new_game()
  local choice = _open_choice(g, {
    kind = "market_buy",
    options = { { id = 1, label = "X" } },
    meta = { player_id = g:current_player().id },
  })
  choice_resolver.resolve(g, choice, { option_id = 999 })
  assert(_get_choice(g) ~= nil, "invalid option should keep choice")
end

local function _test_move_anim_wait_and_resume()
  local g = _new_game()
  g.ui_port = _build_ui_port({ wait_move_anim = true })
  local player = g:current_player()
  g.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  local phases = {
    start = function()
      return "move", { player = player, total = 1, raw_total = 1 }
    end,
    move = turn_move,
    landing = function()
      return nil
    end,
  }
  g.turn_flow = turn_flow:new(g, phases)

  local res = g.turn_flow:run_until_wait()
  assert(res == "wait_move_anim", "should wait for move anim")
  local seq = g.turn.move_anim and g.turn.move_anim.seq
  assert(seq, "move_anim seq should be set")

  g:dispatch_action({ type = "move_anim_done", seq = seq })

  assert(g.turn.move_anim == nil, "move_anim should be cleared")
  local phase = g.turn.phase
  assert(phase ~= "wait_move_anim", "should resume after move anim done")
end

local function _test_ui_model_structure()
  local ui_model = require("src.ui.UIModel")
  local g = _new_game()
  local player = g:current_player()
  player.inventory:add({ id = 2001 })
  local ui_state = {
    ui = {
      auto_play = false,
      item_slots = { 1, 2, 3, 4, 5 },
    },
  }
  local model = ui_model.build(g, {
    game = g,
    ui_state = ui_state,
    last_turn = g.last_turn,
    finished = g.finished,
  })
  assert(model.panel and model.panel.turn_label, "ui_model.panel.turn_label expected")
  assert(type(model.item_slots) == "table" and model.item_slots[1] == 2001, "ui_model.item_slots[1] expected")
  assert(model.board and model.board.tiles and model.board.tile_states, "ui_model.board data")
end

local function _test_tick_skips_anim_when_no_anim()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.ui.UIView")
  local ui_model = require("src.ui.UIModel")
  local board_view_mod = require("src.ui.BoardView")

  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh_board", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
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
end

return {
  _test_move_anim_callback_and_delay,
  _test_popup_timeout_auto_confirm,
  _test_invalid_choice_option_rejected,
  _test_move_anim_wait_and_resume,
  _test_ui_model_structure,
  _test_tick_skips_anim_when_no_anim,
}
