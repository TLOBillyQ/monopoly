local gameplay_loop = require("src.game.flow.turn.gameplay_loop")
local turn_dispatch = require("src.game.flow.turn.turn_dispatch")
local presentation_ports = require("src.presentation.adapter.presentation_ports")
local number_utils = require("src.core.utils.number_utils")
local runtime_constants = require("src.core.config.runtime_constants")

local M = {}

local function _resolve_fallback_tick_seconds(interval)
  local fps = runtime_constants.fps
  if not number_utils.is_numeric(fps) or fps <= 0 then
    fps = 30.0
  end
  return math.tofixed(interval) / fps
end

local function _normalize_positive_dt(value)
  if not number_utils.is_numeric(value) or value <= 0 then
    return nil
  end
  if value > 1.0 then
    return 1.0
  end
  return value
end

local function _is_integer_like_time(value)
  if not number_utils.is_numeric(value) then
    return false
  end
  local as_int = number_utils.to_integer(value)
  if as_int == nil then
    return false
  end
  return value == as_int
end

local function _resolve_tick_seconds(state, fallback_seconds)
  if not state then
    return fallback_seconds, "fallback:no_state", nil, nil, nil
  end
  local ports = state.gameplay_loop_ports
  local clock = ports and ports.clock or nil
  local wall_now_seconds = clock and clock.wall_now_seconds or nil
  local wall_diff_seconds = clock and clock.wall_diff_seconds or nil
  if type(wall_now_seconds) ~= "function" or type(wall_diff_seconds) ~= "function" then
    return fallback_seconds, "fallback:no_clock", nil, nil, nil
  end

  local ok_now, now = pcall(wall_now_seconds)
  if not ok_now or not number_utils.is_numeric(now) then
    return fallback_seconds, "fallback:now_invalid", nil, nil, nil
  end
  local previous = state.tick_wall_now_seconds
  state.tick_wall_now_seconds = now
  if not number_utils.is_numeric(previous) then
    return fallback_seconds, "fallback:no_previous", now, nil, nil
  end

  if _is_integer_like_time(now) and _is_integer_like_time(previous) then
    return fallback_seconds, "fallback:coarse_wall_clock", now, previous, nil
  end

  local ok_diff, diff = pcall(wall_diff_seconds, now, previous)
  local normalized_diff = _normalize_positive_dt(diff)
  if ok_diff and normalized_diff ~= nil then
    return normalized_diff, "wall:diff", now, previous, diff
  end

  local ok_reverse_diff, reverse_diff = pcall(wall_diff_seconds, previous, now)
  local normalized_reverse = _normalize_positive_dt(reverse_diff)
  if ok_reverse_diff and normalized_reverse ~= nil then
    return normalized_reverse, "wall:diff_reversed", now, previous, reverse_diff
  end

  local raw_diff = now - previous
  local normalized_raw = _normalize_positive_dt(raw_diff)
  if normalized_raw ~= nil then
    return normalized_raw, "wall:raw_diff", now, previous, raw_diff
  end

  local raw_reverse = previous - now
  local normalized_raw_reverse = _normalize_positive_dt(raw_reverse)
  if normalized_raw_reverse ~= nil then
    return normalized_raw_reverse, "wall:raw_diff_reversed", now, previous, raw_reverse
  end

  return fallback_seconds, "fallback:diff_invalid", now, previous, diff
end

local function _start_tick_loop(state, current_game_ref, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local fallback_tick_seconds = _resolve_fallback_tick_seconds(tick_interval)
  SetFrameOut(tick_interval, function()
    local tick_seconds = _resolve_tick_seconds(state, fallback_tick_seconds)
    gameplay_loop.tick(current_game_ref[1], state, tick_seconds)
  end, -1)
end

local function _build_gameplay_loop_ports()
  return presentation_ports.build()
end

local function _build_turn_action_port()
  return {
    dispatch_action = function(game, state, action, opts)
      return turn_dispatch.dispatch_action(game, state, action, opts)
    end,
    should_block_action = function(state, action_or_type)
      return turn_dispatch.should_block_action(state, action_or_type)
    end,
  }
end

function M.start(state, current_game_ref)
  assert(state ~= nil, "missing state")
  assert(type(current_game_ref) == "table", "missing current_game_ref")
  if current_game_ref[1] then
    return current_game_ref[1]
  end

  state.turn_action_port = _build_turn_action_port()
  state.gameplay_loop_ports = _build_gameplay_loop_ports()
  local current_game = gameplay_loop.new_game(state)
  current_game_ref[1] = current_game
  gameplay_loop.set_game(state, current_game)

  if not state.tick_started then
    state.tick_started = true
    _start_tick_loop(state, current_game_ref)
  end

  return current_game
end

return M
