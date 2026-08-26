local lu = require("luaunit")
local support = require("test.support.shared_support")

local gameplay_loop = require("src.turn.loop")
local gameplay_loop_ports = require("src.turn.loop.ports")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local output_state_adapter = require("src.turn.output.state_adapter")
local action_anim_port = require("src.foundation.ports.action_anim")

local function _merge_group(base_group, override_group)
  local merged = {}
  for key, value in pairs(base_group or {}) do
    merged[key] = value
  end
  for key, value in pairs(override_group or {}) do
    merged[key] = value
  end
  return merged
end

local function _build_output_ports(output_log)
  local base = output_state_adapter.build_runtime_output_ports()
  return {
    invalidate_ui_model = function(state)
      if output_log then
        output_log[#output_log + 1] = {
          kind = "invalidate_ui_model",
          state = state,
        }
      end
      return base.invalidate_ui_model(state)
    end,
    clear_ui_dirty = base.clear_ui_dirty,
    is_ui_dirty = base.is_ui_dirty,
    sync_ui_model = function(state, model)
      if output_log then
        output_log[#output_log + 1] = {
          kind = "sync_ui_model",
          state = state,
          model = model,
        }
      end
      return base.sync_ui_model(state, model)
    end,
    get_ui_model = base.get_ui_model,
    sync_pending_choice = function(state, choice, opts)
      if output_log then
        output_log[#output_log + 1] = {
          kind = "sync_pending_choice",
          state = state,
          choice = choice,
        }
      end
      return base.sync_pending_choice(state, choice, opts)
    end,
    clear_pending_choice = function(state)
      if output_log then
        output_log[#output_log + 1] = {
          kind = "clear_pending_choice",
          state = state,
        }
      end
      return base.clear_pending_choice(state)
    end,
    get_pending_choice = base.get_pending_choice,
    get_pending_choice_id = base.get_pending_choice_id,
    get_pending_choice_elapsed = base.get_pending_choice_elapsed,
    set_pending_choice_elapsed = base.set_pending_choice_elapsed,
    set_pending_choice_id = base.set_pending_choice_id,
    sync_modal_timer = function(state, payload)
      if output_log then
        output_log[#output_log + 1] = {
          kind = "sync_modal_timer",
          state = state,
          payload = payload,
        }
      end
      return base.sync_modal_timer(state, payload)
    end,
    get_modal_elapsed = base.get_modal_elapsed,
    get_modal_ref = base.get_modal_ref,
  }
end

local function _build_guard_ports(output_log, overrides)
  overrides = overrides or {}
  local ui_sync_override = overrides.ui_sync or {}
  local output_override = overrides.output or {}
  local output_ports = _merge_group(_build_output_ports(output_log), output_override)
  return gameplay_loop_ports.resolve({
    output = output_ports,
    ui_sync = {
      resolve_ui_gate = function()
        return {
          input_blocked = false,
          choice_active = false,
          market_active = false,
          popup_active = false,
        }
      end,
      refresh_from_dirty = function()
        return false
      end,
      update_countdown = function() end,
      build_model = ui_sync_override.build_model or function()
        return nil
      end,
    },
    anim = {
      reset_status_3d = function() end,
      sync_status_3d = function() end,
    },
    debug = {
      sync_event_log = function() end,
    },
  })
end

local function _build_loop_state()
  local auto_runner = require("src.turn.policies.auto_runner")
  local ui_port = support.build_ui_port()
  local state = {
    gameplay_loop_ports = _build_guard_ports(),
    ui = ui_port.ui,
    runtime_asset_context = ui_port.runtime_asset_context,
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
      if string.match(tostring(key), "^ui_") and key ~= "ui_runtime" then
        writes[#writes + 1] = key
      end
      rawset(t, key, value)
    end,
  })
  return writes
end

-- describe("architecture_guard_contract") 拍平为文件级 TestArchitectureGuard,
-- 断言词汇从 luassert 兼容层切到 lu.assertXxx(busted (expected, actual) →
-- LuaUnit (actual, expected)),用例数与改写前一一对应(5 例)。
TestArchitectureGuard = {}

function TestArchitectureGuard:test_gameplay_loop_set_game_injects_narrow_runtime_ports()
  local game = support.new_game({ install_ui_port = false })
  local state = _build_loop_state()
  state.wait_move_anim = true
  state.wait_action_anim = true
  state.board_scene = { marker = "scene" }
  state.push_popup = function(_, payload)
    state.last_popup_payload = payload
    return true
  end
  state.on_board_visual_sync = function(_, payload)
    state.last_board_visual_sync = payload
    return true
  end

  gameplay_loop.set_game(state, game)

  lu.assertNil(game.ui_port, "set_game should stop exporting the catch-all runtime ui_port")
  lu.assertNotNil(game.board_scene_port, "set_game should inject board_scene_port dto")
  lu.assertTrue(game.board_scene_port ~= state, "board_scene_port should not expose raw state")
  lu.assertNotNil(game.board_scene_port.get_board_scene, "board_scene_port should expose board scene getter")
  lu.assertNotNil(game.popup_port, "set_game should inject popup_port dto")
  lu.assertNotNil(game.board_visual_feedback_port, "set_game should inject board_visual_feedback_port dto")
  lu.assertNotNil(game.tile_owner_notifier, "set_game should inject tile_owner_notifier dto")
  lu.assertNotNil(game.anim_gate_port, "set_game should inject anim_gate_port dto")
  lu.assertEquals(game.anim_gate_port.wait_move_anim, true, "anim_gate_port should expose wait_move_anim")
  lu.assertEquals(game.anim_gate_port.wait_action_anim, true, "anim_gate_port should expose wait_action_anim")
  lu.assertEquals(game.board_scene_port:get_board_scene(), state.board_scene, "board_scene_port should read board scene from state")

  game.popup_port:push_popup({ kind = "test_popup" })
  lu.assertEquals(state.last_popup_payload.kind, "test_popup", "runtime ui_port should forward popup payload")

  game.tile_owner_notifier:notify_owner_changed(9, 3)
  lu.assertEquals(state.last_board_visual_sync.tile_ids[1], 9, "runtime ui_port should forward tile id via board visual sync")
end

function TestArchitectureGuard:test_turn_dispatch_next_only_marks_ui_dirty()
  local game = support.new_game({ ai = {} })
  local current_player = game:current_player()
  local output_log = {}
  local state = {
    game = game,
    gameplay_loop_ports = _build_guard_ports(output_log),
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

  support.with_patches({
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
    lu.assertEquals(result.status, "applied", "next should apply for current player")
  end)

  lu.assertEquals(stepped, 1, "dispatch should step turn once")
  lu.assertEquals(#ui_writes, 0, "next action should not directly write state.ui_*")
  lu.assertEquals(#output_log, 1, "next action should emit one output invalidate signal")
  lu.assertEquals(output_log[1].kind, "invalidate_ui_model", "next action should invalidate ui_model through output port")
end

function TestArchitectureGuard:test_turn_dispatch_choice_only_marks_ui_dirty()
  local game = support.new_game({ ai = {} })
  local current_player = game:current_player()
  local choice = support.open_choice(game, {
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = false,
    options = {
      { id = "cancel" },
    },
    meta = {
      player_id = current_player.id,
    },
  })
  local output_log = {}
  local state = {
    game = game,
    gameplay_loop_ports = _build_guard_ports(output_log),
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
  support.bind_ui_runtime(state)
  local ui_writes = _record_ui_writes(state)
  local result = nil

  support.with_patches({
    {
      target = game,
      key = "dispatch_action",
      value = function(self, action)
        lu.assertEquals(action.choice_id, choice.id, "choice dispatch should preserve pending choice id")
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

  lu.assertEquals(result.status, "applied", "choice selection should apply for owning player")
  lu.assertEquals(#ui_writes, 0, "choice action should not directly write state.ui_*")
  lu.assertEquals(#output_log, 2, "choice action should invalidate UI and clear choice through output port")
  lu.assertEquals(output_log[1].kind, "invalidate_ui_model", "choice action should invalidate ui_model through output port")
  lu.assertEquals(output_log[2].kind, "clear_pending_choice", "choice action should clear pending choice through output port")
end

function TestArchitectureGuard:test_gameplay_loop_set_game_routes_choice_state_through_output_port()
  local game = support.new_game()
  local current_player = game:current_player()
  local choice = support.open_choice(game, {
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = false,
    options = {
      { id = "cancel" },
    },
    meta = {
      player_id = current_player.id,
    },
  })
  local output_log = {}
  local state = _build_loop_state()
  state.ui = nil
  state.gameplay_loop_ports = _build_guard_ports(output_log, {
    ui_sync = {
      build_model = function()
        return {
          choice = choice,
          market = nil,
        }
      end,
    },
  })
  local ui_writes = _record_ui_writes(state)

  gameplay_loop.set_game(state, game)

  lu.assertEquals(#ui_writes, 0, "set_game should not directly write state.ui_*")
  lu.assertEquals(output_log[1].kind, "sync_pending_choice", "set_game should publish pending choice through output port")
  lu.assertEquals(output_log[2].kind, "sync_ui_model", "set_game should publish UI model through output port")
  lu.assertEquals(output_log[3].kind, "invalidate_ui_model", "set_game should invalidate ui_model through output port")
  lu.assertEquals(state.ui_runtime and state.ui_runtime.pending_choice_id, choice.id,
    "set_game should keep pending choice in ui_runtime")
  lu.assertEquals(state.ui_runtime and state.ui_runtime.ui_model and state.ui_runtime.ui_model.choice.id, choice.id,
    "set_game should keep ui_model in ui_runtime")
end

function TestArchitectureGuard:test_action_anim_port_uses_anim_gate_port_without_ui_port()
  local game = support.new_game({ ai = {} })
  game.ui_port = nil
  game.anim_gate_port = {
    wait_action_anim = true,
  }

  lu.assertEquals(action_anim_port.is_enabled(game), true, "action_anim_port should read anim_gate_port")
end


return TestArchitectureGuard
