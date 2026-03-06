local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local gameplay_loop = require("src.game.flow.turn.GameplayLoop")
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")

local function _build_guard_ports()
  return gameplay_loop_ports.resolve({
    ui_sync = {
      resolve_ui_gate = function()
        return {
          input_blocked = false,
          choice_active = false,
          market_active = false,
          popup_active = false,
        }
      end,
      build_model = function()
        return nil
      end,
      refresh_from_dirty = function()
        return false
      end,
      update_countdown = function() end,
    },
    anim = {
      reset_status_3d = function() end,
      sync_status_3d = function() end,
    },
    debug = {
      log_status = function() end,
      sync_debug_log = function() end,
    },
  })
end

local function _build_loop_state()
  local auto_runner = require("src.game.flow.turn.AutoRunner")
  local ui_port = support.build_ui_port()
  local state = {
    gameplay_loop_ports = _build_guard_ports(),
    ui = ui_port.ui,
    ui_refs = ui_port.ui_refs,
    set_label = ui_port.set_label,
    set_visible = ui_port.set_visible,
    set_touch_enabled = ui_port.set_touch_enabled,
    query_node = ui_port.query_node,
    auto_runner = auto_runner:new({ interval = 0.01 }),
    turn_runtime = {
      next_turn_locked = false,
      next_turn_last_click = nil,
      next_turn_lock_phase = nil,
      role_control_lock_active = false,
      role_control_lock_suppress = 0,
    },
    debug_runtime = {
      log_once = {},
    },
  }
  state.auto_runner:set_enabled(true)
  return state
end

local function _record_ui_writes(state)
  local writes = {}
  setmetatable(state, {
    __newindex = function(t, key, value)
      if string.match(tostring(key), "^ui_") then
        writes[#writes + 1] = key
      end
      rawset(t, key, value)
    end,
  })
  return writes
end

local function _test_gameplay_loop_set_game_injects_runtime_ui_port_dto()
  local game = support.new_game()
  local state = _build_loop_state()
  state.wait_move_anim = true
  state.wait_action_anim = true
  state.board_scene = { marker = "scene" }
  state.push_popup = function(_, payload)
    state.last_popup_payload = payload
    return true
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    state.last_tile_owner_event = { tile_id = tile_id, owner_id = owner_id }
  end

  gameplay_loop.set_game(state, game)

  assert(game.ui_port ~= state, "set_game should inject a runtime ui_port dto instead of raw state")
  assert(game.ui_port.wait_move_anim == true, "runtime ui_port should expose wait_move_anim")
  assert(game.ui_port.wait_action_anim == true, "runtime ui_port should expose wait_action_anim")
  assert(game.ui_port.get_board_scene ~= nil, "runtime ui_port should expose board scene getter")
  _assert_eq(game.ui_port:get_board_scene(), state.board_scene, "runtime ui_port should read board scene from state")

  game.ui_port:push_popup({ kind = "test_popup" })
  _assert_eq(state.last_popup_payload.kind, "test_popup", "runtime ui_port should forward popup payload")

  game.ui_port:on_tile_owner_changed(9, 3)
  _assert_eq(state.last_tile_owner_event.tile_id, 9, "runtime ui_port should forward tile id")
  _assert_eq(state.last_tile_owner_event.owner_id, 3, "runtime ui_port should forward owner id")
end

local function _test_turn_dispatch_next_only_marks_ui_dirty()
  local game = support.new_game({ ai = {} })
  local current_player = game:current_player()
  local state = {
    game = game,
    gameplay_loop_ports = _build_guard_ports(),
    turn_runtime = {
      next_turn_locked = false,
      next_turn_last_click = nil,
      next_turn_lock_phase = nil,
      role_control_lock_active = false,
      role_control_lock_suppress = 0,
    },
    debug_runtime = {
      log_once = {},
    },
  }
  local ui_writes = _record_ui_writes(state)
  local stepped = 0

  _with_patches({
    {
      target = turn_dispatch,
      key = "step_turn",
      value = function()
        stepped = stepped + 1
      end,
    },
  }, function()
    local result = turn_dispatch.dispatch_action(game, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    _assert_eq(result.status, "applied", "next should apply for current player")
  end)

  _assert_eq(stepped, 1, "dispatch should step turn once")
  _assert_eq(#ui_writes, 1, "next action should only emit one ui_* write")
  _assert_eq(ui_writes[1], "ui_dirty", "next action should only mark ui_dirty")
end

local function _test_turn_dispatch_choice_only_marks_ui_dirty()
  local game = support.new_game({ ai = {} })
  local current_player = game:current_player()
  local choice = support.open_choice(game, {
    kind = "item_phase_choice",
    options = {
      { id = "cancel" },
    },
    meta = {
      player_id = current_player.id,
    },
  })
  local state = {
    game = game,
    gameplay_loop_ports = _build_guard_ports(),
    pending_choice = choice,
    pending_choice_elapsed = 0,
    pending_choice_id = choice.id,
    turn_runtime = {
      next_turn_locked = false,
      next_turn_last_click = nil,
      next_turn_lock_phase = nil,
      role_control_lock_active = false,
      role_control_lock_suppress = 0,
    },
    debug_runtime = {
      log_once = {},
    },
  }
  local ui_writes = _record_ui_writes(state)
  local result = nil

  _with_patches({
    {
      target = game,
      key = "dispatch_action",
      value = function(self, action)
        _assert_eq(action.choice_id, choice.id, "choice dispatch should preserve pending choice id")
        self.turn.pending_choice = nil
      end,
    },
  }, function()
    result = turn_dispatch.dispatch_action(game, state, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = "cancel",
      actor_role_id = current_player.id,
    })
  end)

  _assert_eq(result.status, "applied", "choice selection should apply for owning player")
  _assert_eq(#ui_writes, 1, "choice action should only emit one ui_* write")
  _assert_eq(ui_writes[1], "ui_dirty", "choice action should only mark ui_dirty")
end

return {
  name = "architecture_guard_contract",
  tests = {
    { name = "gameplay_loop_set_game_injects_runtime_ui_port_dto", run = _test_gameplay_loop_set_game_injects_runtime_ui_port_dto },
    { name = "turn_dispatch_next_only_marks_ui_dirty", run = _test_turn_dispatch_next_only_marks_ui_dirty },
    { name = "turn_dispatch_choice_only_marks_ui_dirty", run = _test_turn_dispatch_choice_only_marks_ui_dirty },
  },
}
