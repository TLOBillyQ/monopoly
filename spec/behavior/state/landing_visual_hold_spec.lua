local landing_visual_hold = require("src.state.visual_hold")
local runtime_state = require("src.state.runtime")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game(opts)
  opts = opts or {}
  return {
    turn = opts.turn or {},
    dirty = opts.dirty or { any = false, turn = false },
  }
end

local function _make_state()
  return {}
end

describe("domain landing visual hold coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("is_active_game false when no hold", function()
    local game = _make_game()
    _assert_eq(landing_visual_hold.is_active_game(game), false, "no hold should return false")
  end)

  it("is_active_game true via game.turn", function()
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    _assert_eq(landing_visual_hold.is_active_game(game), true, "game.turn active=true should return true")
  end)

  it("is_active_game nil game returns false", function()
    _assert_eq(landing_visual_hold.is_active_game(nil), false, "nil game should return false")
  end)

  it("is_release_pending_game false when no flag", function()
    local game = _make_game()
    _assert_eq(landing_visual_hold.is_release_pending_game(game), false, "no pending flag should return false")
  end)

  it("is_release_pending_game true via game.turn", function()
    local game = _make_game({ turn = { landing_visual_release_pending = true } })
    _assert_eq(landing_visual_hold.is_release_pending_game(game), true, "release_pending=true should return true")
  end)

  it("mark_release_pending returns false when not active", function()
    local game = _make_game()
    local result = landing_visual_hold.mark_release_pending(game)
    _assert_eq(result, false, "not active should return false")
  end)

  it("mark_release_pending returns false when no turn", function()
    local game = { dirty = {} }
    local result = landing_visual_hold.mark_release_pending(game)
    _assert_eq(result, false, "no turn should return false")
  end)

  it("mark_release_pending sets flag when active", function()
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    local result = landing_visual_hold.mark_release_pending(game)
    _assert_eq(result, true, "active game should return true")
    _assert_eq(game.turn.landing_visual_release_pending, true, "release_pending should be set")
    _assert_eq(game.dirty.any, true, "dirty.any should be set")
  end)

  it("clear_game returns false when no turn", function()
    local game = { dirty = {} }
    local result = landing_visual_hold.clear_game(game)
    _assert_eq(result, false, "no turn should return false")
  end)

  it("clear_game returns false when nothing active", function()
    local game = _make_game()
    local result = landing_visual_hold.clear_game(game)
    _assert_eq(result, false, "nothing active should return false")
  end)

  it("clear_game clears active flag", function()
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    local result = landing_visual_hold.clear_game(game)
    _assert_eq(result, true, "clearing active hold should return true")
    _assert_eq(game.turn.landing_visual_hold_active, false, "active flag should be cleared")
    _assert_eq(game.dirty.any, true, "dirty.any should be set")
  end)

  it("clear_game clears release_pending", function()
    local game = _make_game({ turn = { landing_visual_release_pending = true } })
    local result = landing_visual_hold.clear_game(game)
    _assert_eq(result, true, "clearing release_pending should return true")
    _assert_eq(game.turn.landing_visual_release_pending, false, "release_pending should be cleared")
  end)

  it("hold_state_for_game delegates to start", function()
    local game = _make_game()
    local result = landing_visual_hold.hold_state_for_game(game, nil)
    -- Without active state, start should activate and return true
    _assert_eq(result, true, "hold_state_for_game should delegate to start")
  end)

  it("is_flushing_state false by default", function()
    local state = _make_state()
    _assert_eq(landing_visual_hold.is_flushing_state(state), false, "not flushing by default")
  end)

  it("with_flushing calls fn and returns result", function()
    local state = _make_state()
    local called = false
    local result = landing_visual_hold.with_flushing(state, function()
      called = true
      return 42
    end)
    _assert_eq(called, true, "fn should be called")
    _assert_eq(result, 42, "result should be returned")
  end)

  it("with_flushing restores flushing flag after fn", function()
    local state = _make_state()
    landing_visual_hold.with_flushing(state, function() end)
    _assert_eq(landing_visual_hold.is_flushing_state(state), false, "flushing should be false after fn")
  end)

  it("with_flushing propagates error", function()
    local state = _make_state()
    local ok = pcall(function()
      landing_visual_hold.with_flushing(state, function() error("test_error") end)
    end)
    _assert_eq(ok, false, "error in fn should propagate")
    _assert_eq(landing_visual_hold.is_flushing_state(state), false, "flushing should be restored after error")
  end)

  it("is_active_state false by default", function()
    local state = _make_state()
    _assert_eq(landing_visual_hold.is_active_state(state), false, "not active by default")
  end)

  it("should_defer false when state nil", function()
    local result = landing_visual_hold.should_defer(nil, nil)
    _assert_eq(result, false, "nil state should return false")
  end)

  it("should_defer false when not active", function()
    local state = _make_state()
    _assert_eq(landing_visual_hold.should_defer(state, nil), false, "inactive state should not defer")
  end)

  it("capture_frozen_ui_model returns nil when no ui_model", function()
    local state = _make_state()
    local result = landing_visual_hold.capture_frozen_ui_model(state)
    _assert_eq(result, nil, "should return nil when no ui_model set")
  end)

  it("capture_frozen_ui_model returns same on second call", function()
    local state = _make_state()
    runtime_state.set_ui_model(state, { model = true })
    local m1 = landing_visual_hold.capture_frozen_ui_model(state)
    local m2 = landing_visual_hold.capture_frozen_ui_model(state)
    _assert_eq(m1, m2, "second call should return same frozen model")
  end)

  it("freeze_active_ui returns nil when not active", function()
    local state = _make_state()
    local result = landing_visual_hold.freeze_active_ui(state)
    _assert_eq(result, nil, "not active should return nil")
  end)

  it("set_post_release_hook stores fn", function()
    landing_visual_hold.set_post_release_hook(function() end)
    landing_visual_hold.set_post_release_hook(nil)
  end)

  it("merge_dirty delegates to deferred_dirty", function()
    local target = { any = false, players = false, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory_ids = {} }
    local dirty = { any = true, players = true, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory_ids = {} }
    landing_visual_hold.merge_dirty(target, dirty)
    _assert_eq(target.any, true, "any should be merged")
    _assert_eq(target.players, true, "players should be merged")
  end)

  it("register_release_callback registers fn", function()
    local state = _make_state()
    local fn = function() return true end
    local returned = landing_visual_hold.register_release_callback(state, "popup", fn, nil)
    _assert_eq(returned, fn, "should return registered fn")
  end)

  it("run_or_defer calls fn when not deferred", function()
    local state = _make_state()
    local called = false
    landing_visual_hold.run_or_defer(state, nil, "popup", function()
      called = true
      return true
    end, nil)
    _assert_eq(called, true, "fn should be called when not deferred")
  end)

  it("defer_popup registers callback", function()
    local state = _make_state()
    local replay = function() return true end
    landing_visual_hold.defer_popup(state, { title = "hi" }, {}, replay)
  end)

  it("defer_runtime_event registers callback", function()
    local state = _make_state()
    local replay = function() return true end
    landing_visual_hold.defer_runtime_event(state, "some_event", { data = 1 }, replay)
  end)

  it("defer_board_visual_sync registers callback", function()
    local state = _make_state()
    local replay = function() return true end
    landing_visual_hold.defer_board_visual_sync(state, { tiles = {} }, replay)
  end)

  it("defer_tile_update registers callback", function()
    local state = _make_state()
    local replay = function() return true end
    landing_visual_hold.defer_tile_update(state, 5, 2, replay)
  end)

  it("defer_owner_change registers callback", function()
    local state = _make_state()
    local replay = function() return true end
    landing_visual_hold.defer_owner_change(state, 5, "player_1", replay)
  end)

  it("defer_bankruptcy_clear registers callback", function()
    local state = _make_state()
    local replay = function() return true end
    landing_visual_hold.defer_bankruptcy_clear(state, nil, nil, nil, replay)
  end)

  it("reset_state clears active and flushing", function()
    local state = _make_state()
    -- ensure hold is created first
    landing_visual_hold.is_flushing_state(state)
    local hold = landing_visual_hold.reset_state(state)
    _assert_eq(hold.active, false, "active should be false after reset")
    _assert_eq(hold.flushing, false, "flushing should be false after reset")
    _assert_eq(hold.release_pending, false, "release_pending should be false after reset")
    _assert_eq(hold.frozen_ui_model, nil, "frozen_ui_model should be nil after reset")
    _assert_eq(hold.source, nil, "source should be nil after reset")
  end)

  it("sync_state_from_game uses game turn active", function()
    local state = _make_state()
    local game = _make_game({ turn = { landing_visual_hold_active = true } })
    local hold = landing_visual_hold.sync_state_from_game(state, game)
    _assert_eq(landing_visual_hold.is_active_state(state), true, "state should reflect game turn active")
    assert(hold ~= nil, "hold should be returned")
  end)

  it("start returns false when no turn", function()
    local game = { dirty = {} }
    local result = landing_visual_hold.start(game, nil)
    _assert_eq(result, false, "no turn should return false")
  end)
end)
