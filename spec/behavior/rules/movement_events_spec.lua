local events = require("src.rules.movement_events")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")

local function _assert_eq(actual, expected, label)
  assert(actual == expected, tostring(label) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _make_game(opts)
  opts = opts or {}
  local game = {
    emitted = {},
    feed = {},
    queued = {},
    cash = {},
    schedules = {},
    turn = { turn_count = opts.turn_count },
    anim_gate_port = { wait_action_anim = opts.wait_action_anim == true },
  }
  function game:queue_action_anim(payload)
    self.queued[#self.queued + 1] = payload
  end
  game.event_feed_port = {
    publish = function(_, _, event)
      game.feed[#game.feed + 1] = event
      return true
    end,
  }
  function game:player_has_deity(_, deity)
    return opts.rich == true and deity == "rich"
  end
  function game:add_player_cash(player, amount)
    self.cash[#self.cash + 1] = { player = player, amount = amount }
  end
  return game
end

local function _configure_runtime(game)
  runtime_ports.configure({
    emit_event = function(kind, payload, opts)
      game.emitted[#game.emitted + 1] = {
        kind = kind,
        payload = payload,
        opts = opts,
      }
      return true
    end,
    schedule = function(delay, fn)
      game.schedules[#game.schedules + 1] = { delay = delay, fn = fn }
    end,
  })
end

local function _player()
  return { id = 7, name = "P7" }
end

local function _move_ctx(game, opts)
  opts = opts or {}
  return {
    game = game,
    player = opts.player or _player(),
    start_tile = opts.start_tile or { id = 1, name = "起点" },
    steps = opts.steps or 3,
    pass_start = opts.pass_start or 0,
    pass_start_at_steps = opts.pass_start_at_steps or {},
    opts = opts.move_opts or {},
  }
end

describe("rules.movement_events", function()
  before_each(function()
    runtime_ports.reset_for_tests()
  end)

  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("emits roadblock action animation and visible feed event", function()
    local game = _make_game({ wait_action_anim = true })
    _configure_runtime(game)
    local player = _player()
    events.emit_roadblock_hit(game, player, 4, { id = 4, name = "路障格" })
    _assert_eq(#game.queued, 1, "roadblock action animation queued")
    _assert_eq(game.queued[1].kind, "roadblock_trigger", "roadblock animation kind")
    _assert_eq(game.queued[1].player_id, player.id, "roadblock player id")
    _assert_eq(game.queued[1].tile_index, 4, "roadblock tile index")
    _assert_eq(game.queued[1].duration, timing.action_anim_default_seconds, "roadblock duration")
    _assert_eq(#game.emitted, 1, "monopoly event emitted")
    _assert_eq(game.emitted[1].payload.prompt_text, "玩家正在行动", "prompt text set")
    _assert_eq(#game.feed, 1, "feed event published")
    _assert_eq(game.feed[1].tip, nil, "roadblock feed shows tip")
  end)

  it("emits market interrupt feed with default non-tip behavior", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_market_interrupt({
      game = game,
      player = _player(),
    }, 5)
    _assert_eq(#game.emitted, 1, "market monopoly event emitted")
    _assert_eq(game.emitted[1].payload.remaining_steps, 5, "remaining steps emitted")
    _assert_eq(game.emitted[1].payload.prompt_text, "玩家正在行动", "market prompt text set")
    _assert_eq(#game.feed, 1, "market feed published")
    _assert_eq(game.feed[1].tip, false, "market feed suppresses tip by default")
  end)

  it("emits move completion without pass-start reward when pass_start is zero", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, { pass_start = 0 }), { id = 8, name = "终点" })
    _assert_eq(#game.emitted, 1, "only move completion event emitted")
    _assert_eq(#game.feed, 1, "only move completion feed emitted")
    _assert_eq(#game.cash, 0, "no pass-start cash awarded")
    _assert_eq(#game.schedules, 0, "no pass-start schedule")
  end)

  it("emits immediate pass-start reward with deity multiplier and turn dedupe key", function()
    local game = _make_game({ rich = true, turn_count = 12 })
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, {
      pass_start = 2,
      move_opts = { pass_start_hold_seconds = 0 },
    }), { id = 8, name = "终点" })
    _assert_eq(#game.cash, 1, "pass-start cash awarded once")
    _assert_eq(game.cash[1].amount, 2 * constants.pass_start_bonus * 2, "rich deity doubles pass-start bonus")
    _assert_eq(#game.feed, 2, "move completion and pass-start feeds emitted")
    _assert_eq(game.feed[2].tip_dedupe_key, "passed_start:7:12", "pass-start dedupe key includes turn count")
  end)

  it("pass-start reward falls back to turn zero when no turn count is present", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, {
      pass_start = 1,
      move_opts = { pass_start_hold_seconds = 0 },
    }), { id = 8, name = "终点" })
    _assert_eq(game.feed[2].tip_dedupe_key, "passed_start:7:0", "missing turn count falls back to zero")
  end)

  it("pass-start reward is immediate when no pass-start step was recorded", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, {
      pass_start = 1,
      pass_start_at_steps = {},
    }), { id = 8, name = "终点" })
    _assert_eq(#game.schedules, 0, "missing first pass step should not schedule")
    _assert_eq(#game.cash, 1, "missing first pass step should reward immediately")
  end)

  it("clamps negative pass-start hold override to immediate reward", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, {
      pass_start = 1,
      move_opts = { pass_start_hold_seconds = -3 },
    }), { id = 8, name = "终点" })
    _assert_eq(#game.schedules, 0, "negative hold should not schedule")
    _assert_eq(#game.cash, 1, "negative hold should reward immediately")
  end)

  it("schedules default pass-start reward using first pass step, tail, and cap", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, {
      pass_start = 1,
      pass_start_at_steps = { 2 },
    }), { id = 8, name = "终点" })
    _assert_eq(#game.schedules, 1, "default hold should schedule reward")
    _assert_eq(game.schedules[1].delay,
      2 * timing.pass_start_hold_seconds_per_step + timing.pass_start_hold_tail_seconds,
      "default hold uses first step and tail")
    _assert_eq(#game.cash, 0, "scheduled reward is deferred")
    game.schedules[1].fn()
    _assert_eq(#game.cash, 1, "scheduled callback awards cash")
  end)

  it("caps default pass-start hold at configured maximum before adding tail", function()
    local game = _make_game()
    _configure_runtime(game)
    events.emit_move_completed(_move_ctx(game, {
      pass_start = 1,
      pass_start_at_steps = { 100 },
    }), { id = 8, name = "终点" })
    _assert_eq(game.schedules[1].delay,
      timing.pass_start_hold_max_seconds + timing.pass_start_hold_tail_seconds,
      "default hold is capped before tail")
  end)

  it("defaults missing pass-start timing values to zero", function()
    local saved_per = timing.pass_start_hold_seconds_per_step
    local saved_tail = timing.pass_start_hold_tail_seconds
    timing.pass_start_hold_seconds_per_step = nil
    timing.pass_start_hold_tail_seconds = nil
    local ok, err = pcall(function()
      local game = _make_game()
      _configure_runtime(game)
      events.emit_move_completed(_move_ctx(game, {
        pass_start = 1,
        pass_start_at_steps = { 3 },
      }), { id = 8, name = "终点" })
      _assert_eq(#game.schedules, 0, "missing timing values should produce immediate reward")
      _assert_eq(#game.cash, 1, "missing timing values should reward immediately")
    end)
    timing.pass_start_hold_seconds_per_step = saved_per
    timing.pass_start_hold_tail_seconds = saved_tail
    if not ok then
      error(err)
    end
  end)
end)
