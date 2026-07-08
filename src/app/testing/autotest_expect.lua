local number_utils = require("src.foundation.number")

-- 评估 profile.expect 与真实对局状态的偏差。expect 镜像既有 behavior spec 的
-- 设计事实（见 spec/behavior/app/test_profiles_expect_spec.lua 的契约说明），
-- 这里只做"规则跑对了 vs 没跑"的最小充分判定，不做全量状态快照。
--
-- 支持的断言键（未知键直接报错，防止 expect 写错字段静默通过）：
--   tiles[id].level            地块建筑等级
--   players[idx].in_hospital   玩家在医院格且处于扣留中
--   players[idx].cash          玩家现金
--   events[n].kind             event_log 中出现过该 kind 的事件
local expect_eval = {}

local function _fail(failures, text)
  failures[#failures + 1] = text
end

local function _check_tile(game, raw_tile_id, tile_expect, failures)
  local tile_id = number_utils.to_integer(raw_tile_id)
  assert(tile_id ~= nil, "invalid expect tile id: " .. tostring(raw_tile_id))
  local tile = game.board:get_tile_by_id(tile_id)
  if tile == nil then
    _fail(failures, "tile " .. tile_id .. " missing from board")
    return
  end
  for key, expected in pairs(tile_expect) do
    if key == "level" then
      if tile.level ~= expected then
        _fail(failures, "tile " .. tile_id .. " level=" .. tostring(tile.level)
          .. " expected=" .. tostring(expected))
      end
    else
      error("unsupported expect tile key: " .. tostring(key))
    end
  end
end

local function _is_in_hospital(game, player)
  local hospital_index = game.board:find_first_by_type("hospital")
  if hospital_index == nil then
    return false
  end
  return player.position == hospital_index and game:detention_remaining(player) > 0
end

local function _check_player(game, raw_index, player_expect, failures)
  local index = number_utils.to_integer(raw_index)
  assert(index ~= nil, "invalid expect player index: " .. tostring(raw_index))
  local player = game.players[index]
  if player == nil then
    _fail(failures, "player " .. index .. " missing")
    return
  end
  for key, expected in pairs(player_expect) do
    if key == "in_hospital" then
      local actual = _is_in_hospital(game, player)
      if actual ~= expected then
        _fail(failures, "player " .. index .. " in_hospital=" .. tostring(actual)
          .. " expected=" .. tostring(expected))
      end
    elseif key == "cash" then
      local actual = game:player_cash(player)
      if actual ~= expected then
        _fail(failures, "player " .. index .. " cash=" .. tostring(actual)
          .. " expected=" .. tostring(expected))
      end
    else
      error("unsupported expect player key: " .. tostring(key))
    end
  end
end

local function _event_kind_seen(game, kind)
  local event_log = game.state and game.state.event_log or nil
  for _, entry in ipairs(event_log and event_log.entries or {}) do
    if entry.kind == kind then
      return true
    end
  end
  return false
end

local function _check_events(game, events_expect, failures)
  for _, event_expect in ipairs(events_expect) do
    assert(type(event_expect) == "table" and event_expect.kind ~= nil,
      "expect event entry needs kind")
    if not _event_kind_seen(game, event_expect.kind) then
      _fail(failures, "event kind=" .. tostring(event_expect.kind) .. " not published")
    end
  end
end

-- 返回 { ok = boolean, failures = string[] }。expect 为 nil 时视为无断言（ok）。
function expect_eval.evaluate(game, expect)
  assert(game ~= nil, "missing game")
  if expect == nil then
    return { ok = true, failures = {} }
  end
  assert(type(expect) == "table", "invalid expect payload")

  local failures = {}
  for raw_tile_id, tile_expect in pairs(expect.tiles or {}) do
    _check_tile(game, raw_tile_id, tile_expect, failures)
  end
  for raw_index, player_expect in pairs(expect.players or {}) do
    _check_player(game, raw_index, player_expect, failures)
  end
  _check_events(game, expect.events or {}, failures)
  return { ok = #failures == 0, failures = failures }
end

return expect_eval
