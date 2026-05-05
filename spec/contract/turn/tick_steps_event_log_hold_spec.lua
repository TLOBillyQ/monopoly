---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local tick_steps = require("src.turn.loop.tick_steps")
local runtime_state = require("src.state.runtime")

local function _new_ports(calls)
  return {
    ui_sync = {
      update_countdown = function() calls[#calls + 1] = "update_countdown" end,
      refresh_from_dirty = function() return false end,
      is_input_blocked = function() return false end,
      get_ui_state = function() return nil end,
      apply_input_lock = function() end,
    },
    anim = {
      sync_status_3d = function() calls[#calls + 1] = "sync_status_3d" end,
    },
    debug = {
      log_status = function() calls[#calls + 1] = "log_status" end,
      sync_event_log = function() calls[#calls + 1] = "sync_event_log" end,
    },
  }
end

local function _new_game()
  return {
    dirty = { any = false, turn = false },
    consume_dirty = function(self)
      local d = self.dirty
      self.dirty = { any = false, turn = false }
      return d
    end,
    turn = { phase = "wait_landing_visual" },
  }
end

describe("tick_steps.refresh_tick_from_dirty event_log gate", function()
  it("syncs event_log even while landing_visual_hold is active", function()
    local calls = {}
    local game = _new_game()
    local state = {}
    runtime_state.set_landing_visual_hold_active(state, true)

    tick_steps.refresh_tick_from_dirty(game, state, _new_ports(calls), false)

    local saw_sync_event_log = false
    local saw_log_status = false
    for _, name in ipairs(calls) do
      if name == "sync_event_log" then saw_sync_event_log = true end
      if name == "log_status" then saw_log_status = true end
    end
    assert.is_true(saw_sync_event_log,
      "sync_event_log must fire during landing_visual_hold so debug log keeps up with gameplay")
    assert.is_false(saw_log_status,
      "log_status remains gated by HOLD: status snapshot stays frozen during landing animation")
  end)

  it("syncs event_log normally when no hold is active", function()
    local calls = {}
    local game = _new_game()
    local state = {}
    runtime_state.set_landing_visual_hold_active(state, false)

    tick_steps.refresh_tick_from_dirty(game, state, _new_ports(calls), false)

    local saw_sync_event_log = false
    for _, name in ipairs(calls) do
      if name == "sync_event_log" then saw_sync_event_log = true end
    end
    assert.is_true(saw_sync_event_log, "sync_event_log fires when hold is inactive")
  end)
end)
