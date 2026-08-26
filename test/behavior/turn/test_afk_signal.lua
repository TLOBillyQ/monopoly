local lu = require("luaunit")
local support = require("test.support.shared_support")
local afk_signal = require("src.turn.policies.afk_signal")
local event_feed = require("src.rules.ports.event_feed")
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_log = require("src.state.event_log")
local logger = require("src.foundation.log")
local timing = require("src.config.gameplay.timing")
local control = require("src.player.control")

local function _player(opts)
  opts = opts or {}
  local player = {
    id = opts.id or 7,
    name = opts.name or "P7",
    is_ai = opts.is_ai,
    eliminated = opts.eliminated == true,
  }
  control.initialize(player)
  if opts.auto == true then
    if opts.auto_source == "afk" then
      control.enable_afk_delegation(player)
    else
      control.toggle_manual_delegation(player)
    end
  end
  return player
end

local function _game(player, finished)
  local game = {
    finished = finished == true,
    players = { player },
  }
  function game:find_player_by_id(role_id)
    if role_id == player.id then
      return player
    end
    return nil
  end
  return game
end

local function _capture(fn)
  local events = {}
  local logs = {}
  support.with_patches({
    {
      target = event_feed,
      key = "publish",
      value = function(_, event)
        events[#events + 1] = event
        return true
      end,
    },
    {
      target = logger,
      key = "info_unlimited",
      value = function(...)
        logs[#logs + 1] = table.concat({ ... }, "|")
      end,
    },
  }, function()
    fn(events, logs)
  end)
  return events, logs
end

TestAfkSignal = {}

function TestAfkSignal:test_default_threshold_places_a_live_human_after_two_timeouts()
  local player = _player()
  local game = _game(player)
  local state = {}

  local events, logs = _capture(function(captured_events, captured_logs)
    afk_signal.reset(state)
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
    lu.assertFalse(control.is_delegated(player))
    lu.assertTrue(afk_signal.on_timeout_fallback(game, state, player.id, "choice"))
    lu.assertTrue(control.is_delegated(player))
    lu.assertTrue(control.is_afk_delegated(player))
    lu.assertEquals(#captured_events, 1)
    lu.assertEquals(captured_events[1].kind, event_kinds.afk_auto_enabled)
    lu.assertEquals(captured_events[1].tip, true)
    lu.assertEquals(captured_events[1].text, "P7 已进入托管")
    lu.assertEquals(captured_events[1].role_id, player.id)
    lu.assertEquals(captured_events[1].source, "afk")
    lu.assertEquals(captured_events[1].consecutive_timeout_count, 2)
    lu.assertEquals(#captured_logs, 1)
    lu.assertStrContains(captured_logs[1], "role_id=7")
    lu.assertStrContains(captured_logs[1], "source=afk")
    lu.assertStrContains(captured_logs[1], "count=2")
  end)

  lu.assertEquals(#events, 1)
  lu.assertEquals(#logs, 1)
end

function TestAfkSignal:test_repeated_timeout_is_idempotent_after_afk_placement()
  local player = _player()
  local game = _game(player)
  local state = {}

  local events, logs = _capture(function(captured_events, captured_logs)
    afk_signal.reset(state)
    afk_signal.on_timeout_fallback(game, state, player.id, "action_button")
    afk_signal.on_timeout_fallback(game, state, player.id, "action_button")
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
    lu.assertEquals(#captured_events, 1)
    lu.assertEquals(#captured_logs, 1)
  end)

  lu.assertEquals(#events, 1)
  lu.assertEquals(#logs, 1)
end

function TestAfkSignal:test_afk_placement_uses_the_event_feed_tip_chain_as_one_global_tip()
  local player = _player()
  local game = _game(player)
  game.state = {}
  local tips = {}
  game.tip_output_port = {
    enqueue = function(_, intent)
      tips[#tips + 1] = intent
      return true
    end,
  }
  game.event_feed_port = event_feed_adapter.new(game)
  local state = {}

  support.with_patches({
    { target = logger, key = "info_unlimited", value = function() end },
  }, function()
    afk_signal.reset(state)
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
    lu.assertTrue(afk_signal.on_timeout_fallback(game, state, player.id, "choice"))
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
  end)

  lu.assertEquals(#tips, 1)
  lu.assertEquals(tips[1].text, "P7 已进入托管")
  lu.assertNil(tips[1].role_id)
  lu.assertEquals(tips[1].source, "afk")
  local entries = event_log.get_entries(game.state.event_log)
  lu.assertEquals(#entries, 1)
  lu.assertEquals(entries[1].kind, event_kinds.afk_auto_enabled)
  lu.assertEquals(entries[1].text, "P7 已进入托管")
end

function TestAfkSignal:test_real_input_breaks_the_consecutive_timeout_sequence()
  local player = _player()
  local game = _game(player)
  local state = {}

  _capture(function(events)
    afk_signal.reset(state)
    afk_signal.on_timeout_fallback(game, state, player.id, "action_button")
    afk_signal.on_real_input(game, state, player.id)
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "choice"))
    lu.assertFalse(control.is_delegated(player))
    lu.assertEquals(#events, 0)
  end)
end

function TestAfkSignal:test_configured_threshold_one_places_on_first_timeout()
  local player = _player()
  local game = _game(player)
  local state = {}

  support.with_patches({
    { target = timing, key = "afk", value = { consecutive_timeout_count = 1 } },
  }, function()
    _capture(function()
      afk_signal.reset(state)
      lu.assertTrue(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
      lu.assertTrue(control.is_delegated(player))
    end)
  end)
end

function TestAfkSignal:test_ai_eliminated_and_finished_players_are_not_eligible()
  local cases = {
    { player = _player({ is_ai = true }), game_finished = false },
    { player = _player({ eliminated = true }), game_finished = false },
    { player = _player(), game_finished = true },
  }

  for _, case in ipairs(cases) do
    local game = _game(case.player, case.game_finished)
    local state = {}
    _capture(function(events)
      afk_signal.reset(state)
      afk_signal.on_timeout_fallback(game, state, case.player.id, "action_button")
      afk_signal.on_timeout_fallback(game, state, case.player.id, "action_button")
      lu.assertFalse(control.is_delegated(case.player))
      lu.assertFalse(control.is_afk_delegated(case.player))
      lu.assertEquals(#events, 0)
    end)
  end
end

function TestAfkSignal:test_already_auto_player_does_not_count_or_rebroadcast()
  local player = _player({ auto = true, auto_source = "manual" })
  local game = _game(player)
  local state = {}

  _capture(function(events, logs)
    afk_signal.reset(state)
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
    lu.assertTrue(control.is_delegated(player))
    lu.assertFalse(control.is_afk_delegated(player))
    lu.assertEquals(#events, 0)
    lu.assertEquals(#logs, 0)
  end)
end

function TestAfkSignal:test_prune_removes_a_partial_sequence_for_an_eliminated_player()
  local player = _player()
  local game = _game(player)
  local state = {}

  _capture(function()
    afk_signal.reset(state)
    afk_signal.on_timeout_fallback(game, state, player.id, "action_button")
    player.eliminated = true
    afk_signal.prune(game, state)
    player.eliminated = false
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "choice"))
    lu.assertFalse(control.is_delegated(player))
  end)
end

-- _counts 的非 table state 早退:阈值判定之前就返回 false,不碰玩家。
function TestAfkSignal:test_non_table_state_is_ignored_without_placement()
  local player = _player()
  local game = _game(player)

  _capture(function(events, logs)
    lu.assertFalse(afk_signal.on_timeout_fallback(game, nil, player.id, "action_button"))
    lu.assertFalse(control.is_delegated(player))
    lu.assertEquals(#events, 0)
    lu.assertEquals(#logs, 0)
  end)
end

-- 达阈值但 enable_afk_delegation 未改动(如控制模式非法)时不发事件、不留日志:
-- 计数已清,返回 false。
function TestAfkSignal:test_threshold_without_a_control_change_publishes_nothing()
  local player = _player()
  local game = _game(player)
  local state = {}

  _capture(function(events, logs)
    afk_signal.reset(state)
    support.with_patches({
      { target = control, key = "enable_afk_delegation", value = function()
        return { changed = false, enabled = false }
      end },
    }, function()
      lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
      lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "choice"))
    end)
    lu.assertEquals(#events, 0)
    lu.assertEquals(#logs, 0)
  end)
end

return TestAfkSignal
