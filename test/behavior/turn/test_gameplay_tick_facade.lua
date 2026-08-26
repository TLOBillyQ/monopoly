local lu = require("luaunit")
local support = require("test.support.shared_support")
local fixtures = require("test.support.gameplay_fixtures")
local gameplay_loop = require("src.turn.loop.init")
local runtime_state = require("src.state.runtime")

TestGameplayTickFacade = {}

local function _new_subject()
  local game = support.new_game({ players = { "P1", "P2" }, ai = {} })
  local state = fixtures.build_loop_state()
  state.auto_runner.next_action = function() return nil end
  state._resolved_gameplay_loop_ports = nil
  return game, state
end

function TestGameplayTickFacade:test_release_pulse_marks_turn_dirty_and_syncs_status_during_visual_hold()
  local game, state = _new_subject()
  local refreshed_dirty
  local status_syncs = 0
  runtime_state.set_landing_visual_hold_active(state, true)
  runtime_state.mark_landing_visual_release_pulse(state)
  state.gameplay_loop_ports.ui_sync.refresh_from_dirty = function(_, _, dirty)
    refreshed_dirty = dirty
    return false
  end
  state.gameplay_loop_ports.anim.sync_status_3d = function()
    status_syncs = status_syncs + 1
  end

  gameplay_loop.tick(game, state, 0)

  lu.assertTrue(refreshed_dirty.any)
  lu.assertTrue(refreshed_dirty.turn)
  lu.assertEquals(status_syncs, 1)
end

function TestGameplayTickFacade:test_visual_hold_skips_status_sync_but_keeps_event_log_flowing()
  local game, state = _new_subject()
  local status_syncs = 0
  local event_log_syncs = 0
  runtime_state.set_landing_visual_hold_active(state, true)
  state.gameplay_loop_ports.anim.sync_status_3d = function()
    status_syncs = status_syncs + 1
  end
  state.gameplay_loop_ports.debug.sync_event_log = function()
    event_log_syncs = event_log_syncs + 1
  end

  gameplay_loop.tick(game, state, 0)

  lu.assertEquals(status_syncs, 0)
  lu.assertEquals(event_log_syncs, 1)
end

function TestGameplayTickFacade:test_blocked_refreshed_ui_reapplies_input_lock()
  local game, state = _new_subject()
  local lock_applications = 0
  local ui_sync = state.gameplay_loop_ports.ui_sync
  ui_sync.get_ui_state = function() return {} end
  ui_sync.set_input_blocked = function() return false end
  ui_sync.is_input_blocked = function() return true end
  ui_sync.refresh_from_dirty = function() return true end
  ui_sync.apply_input_lock = function()
    lock_applications = lock_applications + 1
  end

  gameplay_loop.tick(game, state, 0)

  lu.assertEquals(lock_applications, 1)
end

function TestGameplayTickFacade:test_missing_ui_probe_samples_after_the_dirty_refresh()
  -- #523 时序 pin：缺屏探针必须在 refresh_from_dirty 之后采样——同帧
  -- 「先探后开」的误报（阻塞期创建、放行帧首开的窗口）不得回归。
  local game, state = _new_subject()
  local order = {}
  state.gameplay_loop_ports.ui_sync.refresh_from_dirty = function()
    order[#order + 1] = "refresh"
    return false
  end
  state.gameplay_loop_ports.ui_sync.probe_choice_ui_missing = function()
    order[#order + 1] = "probe"
  end

  gameplay_loop.tick(game, state, 0)

  local refresh_at, probe_at
  for index, tag in ipairs(order) do
    if tag == "refresh" then refresh_at = index end
    if tag == "probe" then probe_at = index end
  end
  lu.assertNotNil(refresh_at, "the dirty refresh runs in the tick")
  lu.assertNotNil(probe_at, "the missing-ui probe runs in the tick")
  lu.assertTrue(probe_at > refresh_at, "the probe samples after the dirty refresh")
end

function TestGameplayTickFacade:test_pending_choice_opened_in_the_same_frame_does_not_warn()
  -- #523 复现路径回归 pin（验收第 1 条）：窗口在 dirty 刷新内首开
  --（refresh 落 choice_active/screen_key 模拟 open_choice_modal 的门控
  -- 副作用），同帧探针必须看到 open=true 不告警；探针若被移回刷新之前
  --（先探后开），本 pin 立即转红。
  local game, state = _new_subject()
  local ui_sync_ports = require("src.ui.ports.ui_sync")
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local logger = require("src.foundation.log")
  local choice = {
    id = 51,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    owner_role_id = game.players[1].id,
    options = { { id = "buy_land", label = "购买地块" } },
  }
  game.turn.phase = "wait_choice"
  game.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
  local ui_sync = state.gameplay_loop_ports.ui_sync
  ui_sync.probe_choice_ui_missing = ui_sync_ports.build({
    get_ui_state = function() return state.ui end,
  }).probe_choice_ui_missing
  ui_sync.refresh_from_dirty = function()
    state.ui.choice_active = true
    state.ui.active_choice_screen_key = "secondary_confirm"
    return true
  end
  local warned = {}
  support.with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function()
      return { { get_roleid = function() return game.players[1].id end } }
    end },
    { target = logger, key = "warn", value = function(...)
      warned[#warned + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    gameplay_loop.tick(game, state, 0)
  end)
  lu.assertEquals(#warned, 0, "a choice opened in the same frame's refresh never warns")
end

function TestGameplayTickFacade:test_auto_runner_receives_tick_context_from_the_public_tick()
  local game, state = _new_subject()
  local captured
  support.with_patches({
    {
      target = gameplay_loop,
      key = "step_auto_runner",
      value = function(received_game, received_state, dt, context)
        captured = { game = received_game, state = received_state, dt = dt, context = context }
      end,
    },
  }, function()
    gameplay_loop.tick(game, state, 0.25)
  end)

  lu.assertIs(captured.game, game)
  lu.assertIs(captured.state, state)
  lu.assertEquals(captured.dt, 0.25)
  lu.assertIs(captured.context.game, game)
  lu.assertIs(captured.context.state, state)
  lu.assertEquals(captured.context.current_player_id, game:current_player().id)
end

return TestGameplayTickFacade
