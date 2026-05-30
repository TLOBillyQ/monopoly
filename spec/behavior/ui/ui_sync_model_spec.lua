local model_sync = require("src.ui.ports.ui_sync")._model
local runtime_state = require("src.ui.state.runtime")
local turn_ui_sync_shared = require("src.state.ui_sync_shared")
local landing_visual_hold = require("src.ui.visual_hold")
local main_view = require("src.ui.coord.ui_runtime")
local view_model = require("src.ui.view")
local modal = require("src.ui.coord.modal")
local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state

local function _with_patches(patches, fn)
  local old = {}
  for i, patch in ipairs(patches) do
    old[i] = patch[1][patch[2]]
    patch[1][patch[2]] = patch[3]
  end
  local ok, err = pcall(fn)
  for i = #patches, 1, -1 do
    patches[i][1][patches[i][2]] = old[i]
  end
  if not ok then
    error(err)
  end
end

local function _game(phase)
  return {
    turn = { phase = phase or "wait_choice", current_player_index = 1 },
    players = { { id = 1, name = "P1", cash = 100 } },
  }
end

local function _common()
  return {
    log_once = function() end,
    build_log_prefix = function() return "test" end,
  }
end

describe("ui_sync model behavior", function()
  it("refreshes when runtime UI dirty marks the dirty bucket", function()
    local state = { ui = {} }
    local dirty = { any = false, ui = false }
    local env = { source = "test-env" }
    local rendered_model = nil
    runtime_state.set_ui_dirty(state, true)

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "build_ui_env", function()
        return env
      end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function()
        return false
      end },
      { view_model, "update", function(_, _, update_env, update_dirty)
        assert.equals(env, update_env, "refresh should pass the built env to view model")
        assert.equals(true, update_dirty.ui, "runtime UI dirty should mark dirty.ui")
        return { panel = { turn_label = "P1", countdown_visible = true } }
      end },
      { main_view, "render", function(_, next_model)
        rendered_model = next_model
      end },
      { modal, "open_choice_modal", function()
        error("no choice should not open a modal")
      end },
      { modal, "close_choice_modal", function()
        error("no active choice should not close a modal")
      end },
    }, function()
      local result = model_sync.refresh_from_dirty(_game(), state, dirty, _common())

      assert.equals(true, result, "dirty UI refresh should render full UI")
      assert.equals(true, dirty.ui, "dirty bucket should retain the UI mark for this refresh")
      assert.equals(false, runtime_state.is_ui_dirty(state), "runtime UI dirty flag should be cleared")
      assert.is_not_nil(rendered_model, "refresh should render the new model")
    end)
  end)

  it("defers refresh while landing visual hold is active", function()
    local state = { ui = {} }
    local dirty = { any = true, ui = false, turn = true }
    local frozen = false
    local deferred_dirty = nil

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function()
        return true
      end },
      { landing_visual_hold, "freeze_active_ui", function()
        frozen = true
      end },
      { landing_visual_hold, "defer_dirty", function(_, next_dirty)
        deferred_dirty = next_dirty
      end },
      { view_model, "update", function()
        error("deferred refresh should not update the UI model")
      end },
      { main_view, "render", function()
        error("deferred refresh should not render")
      end },
    }, function()
      local result = model_sync.refresh_from_dirty(_game(), state, dirty, _common())

      assert.equals(false, result, "deferred refresh should report no render")
      assert.equals(true, frozen, "active UI should be frozen")
      assert.equals(dirty, deferred_dirty, "dirty bucket should be deferred")
    end)
  end)

  it("opens inline choices only outside input-blocked phases", function()
    local state = { ui = {} }
    local opened = 0

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
      { view_model, "update", function()
        return {
          panel = {},
          choice = { id = "inline", route_key = "base_inline" },
        }
      end },
      { main_view, "render", function() end },
      { modal, "open_choice_modal", function()
        opened = opened + 1
      end },
    }, function()
      assert.equals(true, model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true }, _common()))
      assert.equals(1, opened, "inline choice should open when input is allowed")
      assert.equals(true, model_sync.refresh_from_dirty(_game("wait_move_anim"), state, { any = true }, _common()))
      assert.equals(1, opened, "input-blocked phase should not open inline choice")
    end)
  end)

  it("opens passive item choices as inline choices", function()
    local state = { ui = {} }
    local opened = 0

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
      { view_model, "update", function()
        return {
          panel = {},
          choice = { id = "passive", route_key = "item_phase_passive" },
        }
      end },
      { main_view, "render", function() end },
      { modal, "open_choice_modal", function()
        opened = opened + 1
      end },
    }, function()
      local result = model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true }, _common())

      assert.equals(true, result, "passive choice refresh should render")
      assert.equals(1, opened, "item_phase_passive should open through inline modal handler")
    end)
  end)

  it("does not open market choice without market payload", function()
    local state = { ui = {} }

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
      { view_model, "update", function()
        return {
          panel = {},
          choice = { id = "market", route_key = "market" },
          market = nil,
        }
      end },
      { main_view, "render", function() end },
      { modal, "open_choice_modal", function()
        error("market choice without market payload should not open")
      end },
    }, function()
      assert.equals(true, model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true, market = true }, _common()))
    end)
  end)

  it("opens non-inline choices when reconcile requires it", function()
    local state = { ui = {} }
    local opened = 0

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
      { view_model, "update", function()
        return {
          panel = {},
          choice = { id = "target", route_key = "target" },
        }
      end },
      { choice_ui_state, "should_reconcile", function()
        return true
      end },
      { main_view, "render", function() end },
      { modal, "open_choice_modal", function()
        opened = opened + 1
      end },
    }, function()
      local result = model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true }, _common())

      assert.equals(true, result, "target choice refresh should render")
      assert.equals(1, opened, "reconciled target choice should open")
    end)
  end)

  it("build_model forwards the UI env to view model build", function()
    local state = { ui = {} }
    local game = _game()
    local env = { source = "build-env" }
    local built_model = { panel = {} }

    _with_patches({
      { turn_ui_sync_shared, "build_ui_env", function(build_state, build_game)
        assert.equals(state, build_state, "build_model should pass state to env builder")
        assert.equals(game, build_game, "build_model should pass game to env builder")
        return env
      end },
      { view_model, "build", function(build_game, build_env)
        assert.equals(game, build_game, "build_model should pass game to view model")
        assert.equals(env, build_env, "build_model should pass env to view model")
        return built_model
      end },
    }, function()
      assert.equals(built_model, model_sync.build_model(state, game))
    end)
  end)

  it("closes stale choice modal when the refreshed model has no choice", function()
    local state = { ui = { choice_active = true } }
    local closed = 0

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
      { view_model, "update", function()
        return { panel = {} }
      end },
      { main_view, "render", function() end },
      { modal, "close_choice_modal", function()
        closed = closed + 1
      end },
      { modal, "open_choice_modal", function()
        error("missing choice should not open modal")
      end },
    }, function()
      local result = model_sync.refresh_from_dirty(_game(), state, { any = true }, _common())

      assert.equals(true, result, "full refresh should still report a render")
      assert.equals(1, closed, "stale active choice should be closed")
    end)
  end)

  it("reopens a pending choice from the cached model without rebuilding", function()
    local state = { ui = {} }
    local pending = { id = "pending", route_key = "target" }
    local opened = 0
    runtime_state.set_ui_model(state, { choice = pending, market = { id = "market" } })

    _with_patches({
      { choice_ui_state, "should_reconcile", function()
        return true
      end },
      { view_model, "build", function()
        error("matching cached pending choice should not rebuild")
      end },
      { modal, "open_choice_modal", function(_, choice, market)
        assert.equals(pending, choice, "cached choice should be reopened")
        assert.equals("market", market.id, "cached market payload should be reused")
        opened = opened + 1
      end },
    }, function()
      local result = model_sync.reopen_choice_modal_if_needed(_game(), state, pending)

      assert.equals(true, result, "reconciled pending choice should reopen")
      assert.equals(1, opened, "modal should open once")
    end)
  end)

  it("does not reopen when reconcile says the UI is already current", function()
    local state = { ui = {} }

    _with_patches({
      { choice_ui_state, "should_reconcile", function()
        return false
      end },
      { modal, "open_choice_modal", function()
        error("already-current UI should not reopen")
      end },
    }, function()
      assert.equals(false, model_sync.reopen_choice_modal_if_needed(_game(), state, { id = "pending" }))
    end)
  end)

  it("does not reopen when rebuilt model has no choice", function()
    local state = { ui = {} }

    _with_patches({
      { choice_ui_state, "should_reconcile", function()
        return true
      end },
      { view_model, "build", function()
        return { market = { id = "market" } }
      end },
      { modal, "open_choice_modal", function()
        error("model without choice should not reopen")
      end },
    }, function()
      assert.equals(false, model_sync.reopen_choice_modal_if_needed(_game(), state, { id = "pending" }))
    end)
  end)

  it("does not close a choice modal when ui state is absent", function()
    local state = {}

    _with_patches({
      { landing_visual_hold, "sync_state_from_game", function() end },
      { landing_visual_hold, "should_defer", function() return false end },
      { turn_ui_sync_shared, "build_ui_env", function()
        return { source = "no-ui" }
      end },
      { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
      { view_model, "update", function()
        return { panel = {} }
      end },
      { main_view, "render", function() end },
      { modal, "close_choice_modal", function()
        error("absent ui state should not close a choice modal")
      end },
      { modal, "open_choice_modal", function()
        error("model without choice should not open a modal")
      end },
    }, function()
      assert.equals(true, model_sync.refresh_from_dirty(_game(), state, { any = true }, _common()))
    end)
  end)
end)
