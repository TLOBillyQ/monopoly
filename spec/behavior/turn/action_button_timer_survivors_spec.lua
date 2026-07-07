local support = require("spec.support.shared_support")

local action_button_timer = require("src.turn.policies.action_button_timer")
local constants = require("src.config.content.constants")

-- Build a ctx that drives update_action_button_timer down the tracking path:
-- ports.ui_sync is present but inert so is_action_button_wait_active returns true,
-- and the current player resolves from turn.current_player_index.
local function _timer_ctx(opts)
  opts = opts or {}
  local player = opts.player or { id = 1 }
  local state = opts.state or {}
  local dispatched = {}
  local game = {
    finished = false,
    turn = {
      current_player_index = 1,
      phase = opts.phase,
      pending_choice = nil,
    },
    players = { player },
    auto_play_port = opts.auto_play_port,
  }
  local ctx = {
    state = state,
    game = game,
    dt = opts.dt or 0,
    ports = { ui_sync = {} },
    dispatch_next = function(id, reason)
      dispatched[#dispatched + 1] = { id = id, reason = reason }
    end,
  }
  return ctx, state, game, dispatched
end

describe("action_button_timer.resolve_elapsed survivors", function()
  it("treats a nil elapsed as zero", function()
    assert.equals(3, action_button_timer.resolve_elapsed(nil, 3))
  end)

  it("treats a nil dt as zero", function()
    assert.equals(2, action_button_timer.resolve_elapsed(2, nil))
  end)
end)

describe("action_button_timer auto-player detection survivors", function()
  it("uses the auto_play_port verdict rather than player flags", function()
    -- Port reports auto; player flags are all falsy and the phase is not
    -- wait_action, so tracking can only stay active if the port branch runs.
    local ctx, state = _timer_ctx({
      phase = "idle",
      player = { id = 1 },
      auto_play_port = { is_auto_player = function() return true end },
    })

    action_button_timer.update_action_button_timer(ctx)

    assert.is_true(state.action_button_active)
  end)

  it("honors the player.ai flag in the fallback verdict", function()
    local ctx, state = _timer_ctx({ phase = "idle", player = { id = 1, ai = true } })

    action_button_timer.update_action_button_timer(ctx)

    assert.is_true(state.action_button_active)
  end)
end)

describe("action_button_timer.update_action_button_timer survivors", function()
  it("resets the elapsed timer and re-owns the button on a player switch", function()
    local ctx, state = _timer_ctx({ phase = "wait_action", dt = 0 })
    state.action_button_player_id = 999
    state.action_button_elapsed = 10

    action_button_timer.update_action_button_timer(ctx)

    assert.equals(1, state.action_button_player_id)
    assert.equals(0, state.action_button_elapsed)
    assert.is_true(state.action_button_active)
  end)

  it("stays within the window without firing a timeout while elapsed < timeout", function()
    local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 1 })

    action_button_timer.update_action_button_timer(ctx)

    assert.equals(0, #dispatched)
    assert.equals(1, state.action_button_elapsed)
  end)

  it("fires a timeout once elapsed reaches the timeout boundary", function()
    local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 0 })
    state.action_button_player_id = 1
    state.action_button_elapsed = 15

    action_button_timer.update_action_button_timer(ctx)

    assert.equals(1, #dispatched)
    assert.equals("timeout", dispatched[1].reason)
  end)

  it("clears the elapsed timer when a timeout is handled", function()
    local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 0 })
    state.action_button_player_id = 1
    state.action_button_elapsed = 20

    action_button_timer.update_action_button_timer(ctx)

    assert.equals(1, #dispatched)
    assert.equals(0, state.action_button_elapsed)
  end)

  it("stays inert when the configured timeout is unset", function()
    support.with_patches({
      { target = constants, key = "action_timeout_seconds", value = false },
    }, function()
      local ctx, state = _timer_ctx({ phase = "wait_action", dt = 0 })

      action_button_timer.update_action_button_timer(ctx)

      assert.is_false(state.action_button_active)
    end)
  end)

  it("stays inert when the configured timeout is zero", function()
    support.with_patches({
      { target = constants, key = "action_timeout_seconds", value = 0 },
    }, function()
      local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 0 })

      action_button_timer.update_action_button_timer(ctx)

      assert.equals(0, #dispatched)
      assert.is_false(state.action_button_active)
    end)
  end)
end)
