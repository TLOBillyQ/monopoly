local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local runtime_state = require("src.state.runtime")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local logger = require("src.foundation.log")
local control = require("src.player.control")

local afk_signal = {}

local function _counts(state)
  if type(state) ~= "table" then
    return nil
  end
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  if type(turn_runtime.afk_timeout_counts) ~= "table" then
    turn_runtime.afk_timeout_counts = {}
  end
  return turn_runtime.afk_timeout_counts
end

local function _resolve_player(game, role_id)
  if not (game and type(game.find_player_by_id) == "function") then
    return nil
  end
  local ok, player = pcall(game.find_player_by_id, game, role_id)
  if ok then
    return player
  end
  return nil
end

local function _threshold()
  local value = number_utils.to_integer(timing.afk.consecutive_timeout_count)
  if value and value > 0 then
    return value
  end
  return 2
end

function afk_signal.is_timeout_eligible(player)
  return player ~= nil
    and not control.is_delegated(player)
    and not control.is_replacement_computer(player)
    and player.eliminated ~= true
end

local function _eligible(game, player)
  return game ~= nil
    and game.finished ~= true
    and player ~= nil
    and not control.is_replacement_computer(player)
    and player.eliminated ~= true
end

local function _clear_count(counts, player, role_id)
  local key = player and player.id or role_id
  if key ~= nil then
    counts[key] = nil
  end
end

local function _resolve_counted_player(game, counts, role_id)
  local player = _resolve_player(game, role_id)
  if not _eligible(game, player) or control.is_delegated(player) then
    _clear_count(counts, player, role_id)
    return nil
  end
  return player
end

local function _publish_afk_placement(game, player, count, window_kind)
  event_feed.publish(game, {
    kind = event_kinds.afk_auto_enabled,
    text = tostring(player.name) .. " 已进入托管",
    tip = true,
    source = "afk",
    role_id = player.id,
    consecutive_timeout_count = count,
    window_kind = window_kind,
  })
end

function afk_signal.reset(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  turn_runtime.afk_timeout_counts = {}
end

-- 连续超时计数自增(CRAP 门禁):缺省 0 的兜底收敛到本函数,
-- on_timeout_fallback 只留阈值判定与托管切换。
local function _bump_count(counts, key)
  local count = (counts[key] or 0) + 1
  counts[key] = count
  return count
end

function afk_signal.on_timeout_fallback(game, state, role_id, window_kind)
  local counts = _counts(state)
  if counts == nil then
    return false
  end
  local player = _resolve_counted_player(game, counts, role_id)
  if player == nil then
    return false
  end

  local count = _bump_count(counts, player.id)
  if count < _threshold() then
    return false
  end

  counts[player.id] = nil
  if not control.enable_afk_delegation(player).changed then
    return false
  end
  logger.info_unlimited(
    "[AFK]",
    "role_id=" .. tostring(player.id),
    "source=afk",
    "count=" .. tostring(count),
    "window=" .. tostring(window_kind)
  )
  _publish_afk_placement(game, player, count, window_kind)
  return true
end

function afk_signal.on_real_input(game, state, role_id)
  local counts = _counts(state)
  if counts == nil then
    return false
  end
  local player = _resolve_player(game, role_id)
  _clear_count(counts, player, role_id)
  return player ~= nil
end

function afk_signal.prune(game, state)
  local counts = _counts(state)
  if counts == nil then
    return
  end
  for role_id in pairs(counts) do
    local player = _resolve_player(game, role_id)
    if not _eligible(game, player) or control.is_delegated(player) then
      counts[role_id] = nil
    end
  end
end

return afk_signal

--[[ mutate4lua-manifest
version=4
projectHash=c297f5f3f1d1448b
scope.0.id=chunk:src/turn/policies/afk_signal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=469b5f1996827f02
scope.1.id=function:_counts
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=20
scope.1.semanticHash=e07a15fd8758ed8c
scope.2.id=function:_resolve_player
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=31
scope.2.semanticHash=986888a074868acc
scope.3.id=function:_threshold
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=39
scope.3.semanticHash=d15414c3ed4b3422
scope.4.id=function:afk_signal.is_timeout_eligible
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=46
scope.4.semanticHash=f233e8b79a47d9f4
scope.5.id=function:_eligible
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=54
scope.5.semanticHash=8f4a5daac94bd0be
scope.6.id=function:_clear_count
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=61
scope.6.semanticHash=4d72805c5705f5be
scope.7.id=function:_resolve_counted_player
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=70
scope.7.semanticHash=090b10e188a43918
scope.8.id=function:_publish_afk_placement
scope.8.kind=function
scope.8.startLine=72
scope.8.endLine=82
scope.8.semanticHash=55fc29bd80fafefd
scope.9.id=function:afk_signal.reset
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=87
scope.9.semanticHash=40fc4358b3a67263
scope.10.id=function:_bump_count
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=95
scope.10.semanticHash=69ee0ad267023aaa
scope.11.id=function:afk_signal.on_timeout_fallback
scope.11.kind=function
scope.11.startLine=97
scope.11.endLine=125
scope.11.semanticHash=823156ffe3ade374
scope.12.id=function:afk_signal.on_real_input
scope.12.kind=function
scope.12.startLine=127
scope.12.endLine=135
scope.12.semanticHash=3695804026e0a5b0
scope.13.id=function:afk_signal.prune
scope.13.kind=function
scope.13.startLine=137
scope.13.endLine=148
scope.13.semanticHash=fab048c79b250d47
]]
