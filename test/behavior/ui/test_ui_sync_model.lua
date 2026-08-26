local lu = require("luaunit")
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

TestUiSyncModel = {}

function TestUiSyncModel:test_refresh_feeds_the_seeded_model_to_view_update()
  -- L32 `runtime_state.get_ui_model(state)` 换 nil:已播种的模型必须原样
  -- 交给 view_model.update,变异体传 nil 走 build 全新建模。
  local state = { ui = {} }
  local game = _game()
  runtime_state.set_ui_dirty(state, true)
  -- update 被桩:prev 只做恒等比对,种子模型无需完备。
  local seeded = { seeded_marker = true }
  runtime_state.set_ui_model(state, seeded)
  local captured_prev = "unset"
  local dirty = { any = true, ui = false }

  _with_patches({
    { landing_visual_hold, "sync_state_from_game", function() end },
    { landing_visual_hold, "should_defer", function() return false end },
    { turn_ui_sync_shared, "build_ui_env", function()
      return {}
    end },
    { turn_ui_sync_shared, "is_only_turn_countdown", function()
      return false
    end },
    { view_model, "update", function(prev, _, update_env, update_dirty)
      captured_prev = prev
      return { panel = {} }
    end },
    { main_view, "render", function() end },
    { modal, "open_choice_modal", function() end },
    { modal, "close_choice_modal", function() end },
  }, function()
    local result = model_sync.refresh_from_dirty(game, state, dirty, _common())
    lu.assertEquals(result, true, "dirty refresh should render")
    lu.assertEquals(captured_prev, seeded, "view update must receive the seeded model as prev")
  end)
end

function TestUiSyncModel:test_turn_label_falls_back_to_empty_string()
  -- L45 `panel and panel.turn_label or ""` 的 `""` 换 nil:无 turn_label 时
  -- 刷新标签必须传空串,不能传 nil。
  local state = { ui = {} }
  local game = _game()
  runtime_state.set_ui_dirty(state, true)
  local captured_label = "unset"
  local dirty = { any = true, ui = false }

  _with_patches({
    { landing_visual_hold, "sync_state_from_game", function() end },
    { landing_visual_hold, "should_defer", function() return false end },
    { turn_ui_sync_shared, "build_ui_env", function()
      return {}
    end },
    { turn_ui_sync_shared, "is_only_turn_countdown", function()
      return true
    end },
    { view_model, "update", function()
      return { panel = { countdown_visible = false } }
    end },
    { main_view, "refresh_turn_label", function(_, label, countdown_visible)
      captured_label = label
      lu.assertEquals(countdown_visible, false, "countdown visibility should pass through")
    end },
  }, function()
    local result = model_sync.refresh_from_dirty(game, state, dirty, _common())
    lu.assertEquals(result, false, "only-countdown refresh should not render full UI")
    lu.assertEquals(captured_label, "", "missing turn label must fall back to empty string")
  end)
end


function TestUiSyncModel:test_refreshes_when_runtime_ui_dirty_marks_the_dirty_bucket()
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
      lu.assertEquals(update_env, env, "refresh should pass the built env to view model")
      lu.assertEquals(update_dirty.ui, true, "runtime UI dirty should mark dirty.ui")
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

    lu.assertEquals(result, true, "dirty UI refresh should render full UI")
    lu.assertEquals(dirty.ui, true, "dirty bucket should retain the UI mark for this refresh")
    lu.assertEquals(runtime_state.is_ui_dirty(state), false, "runtime UI dirty flag should be cleared")
    lu.assertNotNil(rendered_model, "refresh should render the new model")
  end)
end

function TestUiSyncModel:test_defers_refresh_while_landing_visual_hold_is_active()
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

    lu.assertEquals(result, false, "deferred refresh should report no render")
    lu.assertEquals(frozen, true, "active UI should be frozen")
    lu.assertEquals(deferred_dirty, dirty, "dirty bucket should be deferred")
  end)
end

function TestUiSyncModel:test_opens_inline_choices_only_outside_input_blocked_phases()
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
    lu.assertEquals(model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true }, _common()), true)
    lu.assertEquals(opened, 1, "inline choice should open when input is allowed")
    lu.assertEquals(model_sync.refresh_from_dirty(_game("wait_move_anim"), state, { any = true }, _common()), true)
    lu.assertEquals(opened, 1, "input-blocked phase should not open inline choice")
  end)
end

function TestUiSyncModel:test_opens_passive_item_choices_as_inline_choices()
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

    lu.assertEquals(result, true, "passive choice refresh should render")
    lu.assertEquals(opened, 1, "item_phase_passive should open through inline modal handler")
  end)
end

function TestUiSyncModel:test_does_not_open_market_choice_without_market_payload()
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
    lu.assertEquals(model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true, market = true }, _common()), true)
  end)
end

function TestUiSyncModel:test_opens_non_inline_choices_when_reconcile_requires_it()
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

    lu.assertEquals(result, true, "target choice refresh should render")
    lu.assertEquals(opened, 1, "reconciled target choice should open")
  end)
end

function TestUiSyncModel:test_build_model_forwards_the_ui_env_to_view_model_build()
  local state = { ui = {} }
  local game = _game()
  local env = { source = "build-env" }
  local built_model = { panel = {} }

  _with_patches({
    { turn_ui_sync_shared, "build_ui_env", function(build_state, build_game)
      lu.assertEquals(build_state, state, "build_model should pass state to env builder")
      lu.assertEquals(build_game, game, "build_model should pass game to env builder")
      return env
    end },
    { view_model, "build", function(build_game, build_env)
      lu.assertEquals(build_game, game, "build_model should pass game to view model")
      lu.assertEquals(build_env, env, "build_model should pass env to view model")
      return built_model
    end },
  }, function()
    lu.assertEquals(model_sync.build_model(state, game), built_model)
  end)
end

function TestUiSyncModel:test_closes_stale_choice_modal_when_the_refreshed_model_has_no_choice()
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

    lu.assertEquals(result, true, "full refresh should still report a render")
    lu.assertEquals(closed, 1, "stale active choice should be closed")
  end)
end

function TestUiSyncModel:test_reopens_a_pending_choice_from_the_cached_model_without_rebuilding()
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
      lu.assertEquals(choice, pending, "cached choice should be reopened")
      lu.assertEquals(market.id, "market", "cached market payload should be reused")
      opened = opened + 1
    end },
  }, function()
    local result = model_sync.reopen_choice_modal_if_needed(_game(), state, pending)

    lu.assertEquals(result, true, "reconciled pending choice should reopen")
    lu.assertEquals(opened, 1, "modal should open once")
  end)
end

function TestUiSyncModel:test_does_not_reopen_when_reconcile_says_the_ui_is_already_current()
  local state = { ui = {} }

  _with_patches({
    { choice_ui_state, "should_reconcile", function()
      return false
    end },
    { modal, "open_choice_modal", function()
      error("already-current UI should not reopen")
    end },
  }, function()
    lu.assertEquals(model_sync.reopen_choice_modal_if_needed(_game(), state, { id = "pending" }), false)
  end)
end

function TestUiSyncModel:test_does_not_reopen_when_rebuilt_model_has_no_choice()
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
    lu.assertEquals(model_sync.reopen_choice_modal_if_needed(_game(), state, { id = "pending" }), false)
  end)
end

function TestUiSyncModel:test_release_frame_opens_choice_modal_before_render()
  -- #525 时序 pin:阻塞期创建的窗口在放行帧首开。若 render 先跑,读到陈旧
  -- choice_active=false,post-action 可选窗口会把基础「结束」按钮点得与弹窗
  -- 同屏亮。开屏必须先于 main_view.render,让渲染读到开屏后的门控。
  local state = { ui = { choice_active = false } }
  local order = {}

  _with_patches({
    { landing_visual_hold, "sync_state_from_game", function() end },
    { landing_visual_hold, "should_defer", function() return false end },
    { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
    { view_model, "update", function()
      return {
        panel = {},
        choice = { id = "landing", route_key = "secondary_confirm" },
      }
    end },
    { choice_ui_state, "should_reconcile", function()
      return true
    end },
    { modal, "open_choice_modal", function()
      state.ui.choice_active = true -- 真实开屏会置门控为 true
      table.insert(order, "open")
    end },
    { main_view, "render", function()
      table.insert(order, "render")
      lu.assertEquals(state.ui.choice_active, true,
        "render must observe choice_active after the modal opened")
    end },
  }, function()
    local result = model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true }, _common())

    lu.assertEquals(result, true, "release frame refresh should render")
    lu.assertEquals(order, { "open", "render" }, "modal open must precede render")
  end)
end

function TestUiSyncModel:test_release_frame_closes_choice_modal_before_render()
  -- #525 时序 pin(收屏侧):窗口 resolve 后模型无 choice,收屏必须先于
  -- main_view.render,否则渲染读到陈旧 choice_active=true,基础按钮整门
  -- 持续落下,答完弹窗后行动/结束按钮不回。
  local state = { ui = { choice_active = true, active_choice_screen_key = "secondary_confirm" } }
  local order = {}

  _with_patches({
    { landing_visual_hold, "sync_state_from_game", function() end },
    { landing_visual_hold, "should_defer", function() return false end },
    { turn_ui_sync_shared, "is_only_turn_countdown", function() return false end },
    { view_model, "update", function()
      return { panel = {} }
    end },
    { modal, "close_choice_modal", function()
      state.ui.choice_active = false -- 真实收屏会置门控为 false
      table.insert(order, "close")
    end },
    { main_view, "render", function()
      table.insert(order, "render")
      lu.assertEquals(state.ui.choice_active, false,
        "render must observe choice_active after the modal closed")
    end },
  }, function()
    local result = model_sync.refresh_from_dirty(_game("wait_choice"), state, { any = true }, _common())

    lu.assertEquals(result, true, "release frame refresh should render")
    lu.assertEquals(order, { "close", "render" }, "modal close must precede render")
  end)
end

function TestUiSyncModel:test_does_not_close_a_choice_modal_when_ui_state_is_absent()
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
    lu.assertEquals(model_sync.refresh_from_dirty(_game(), state, { any = true }, _common()), true)
  end)
end


return TestUiSyncModel
