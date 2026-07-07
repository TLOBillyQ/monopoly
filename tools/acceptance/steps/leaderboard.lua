local number_utils = require("src.foundation.number")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local leaderboard = require("src.app.host_integrations.leaderboard")

local leaderboard_steps = {}

local WIN = leaderboard.win_count_archive_key
local ASSETS = leaderboard.total_assets_archive_key

local function _slot(role_id, archive_key)
  return tostring(role_id) .. "|" .. tostring(archive_key)
end

-- Builds (once per scenario) an in-memory archive store wired through the
-- runtime ports, plus a lightweight game whose players settle() can read.
local function _ensure(world)
  if world.lb then
    return world.lb
  end
  local lb = {
    store = {},
    writes = 0,
    enabled = true,
    by_id = {},
    game = {
      players = {},
      winners = {},
      player_cash = function(_, player)
        return player.cash or 0
      end,
      board = { get_tile_by_id = function() return nil end },
    },
  }
  runtime_ports.configure({
    archives_enabled = function()
      return lb.enabled
    end,
    get_archive_int = function(role_id, archive_key)
      return lb.store[_slot(role_id, archive_key)] or 0
    end,
    set_archive_int = function(role_id, archive_key, value)
      lb.store[_slot(role_id, archive_key)] = value
      lb.writes = lb.writes + 1
    end,
  })
  world.lb = lb
  return lb
end

local function _ensure_player(world, id)
  local lb = _ensure(world)
  local player = lb.by_id[id]
  if player == nil then
    player = { id = id, name = "P" .. tostring(id), properties = {}, cash = 0 }
    lb.by_id[id] = player
    lb.game.players[#lb.game.players + 1] = player
  end
  return player
end

local function _seed(world, role_id, archive_key, value)
  local lb = _ensure(world)
  lb.store[_slot(role_id, archive_key)] = value
end

local function _stored(world, role_id, archive_key)
  return _ensure(world).store[_slot(role_id, archive_key)] or 0
end

function leaderboard_steps.handlers()
  return {
    ["玩家本局之前的胜利次数为<之前胜利次数>"] = function(world, example)
      _ensure_player(world, 1)
      _seed(world, 1, WIN, number_utils.to_integer(example["之前胜利次数"]))
      return true
    end,

    ["玩家本局<胜负结果>"] = function(world, example)
      local player = _ensure_player(world, 1)
      local result = example["胜负结果"]
      if result == "获胜" then
        world.lb.game.winners = { player }
      elseif result == "未获胜" then
        world.lb.game.winners = {}
      else
        return nil, "unknown 胜负结果: " .. tostring(result)
      end
      return true
    end,

    ["排行榜结算执行"] = function(world)
      leaderboard.settle(_ensure(world).game)
      return true
    end,

    ["玩家本局之后的胜利次数为<之后胜利次数>"] = function(world, example)
      local expected = number_utils.to_integer(example["之后胜利次数"])
      local actual = _stored(world, 1, WIN)
      if actual ~= expected then
        return nil, "expected win count " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家本局之前的累计资产为<之前累计资产>"] = function(world, example)
      _ensure_player(world, 1)
      _seed(world, 1, ASSETS, number_utils.to_integer(example["之前累计资产"]))
      return true
    end,

    ["玩家本局结束时仍在场"] = function(world)
      local player = _ensure_player(world, 1)
      player.quit_reason = nil
      return true
    end,

    ["玩家本局结束时的剩余总资产为<本局剩余资产>"] = function(world, example)
      local player = _ensure_player(world, 1)
      player.cash = number_utils.to_integer(example["本局剩余资产"])
      return true
    end,

    ["玩家本局之后的累计资产为<之后累计资产>"] = function(world, example)
      local expected = number_utils.to_integer(example["之后累计资产"])
      local actual = _stored(world, 1, ASSETS)
      if actual ~= expected then
        return nil, "expected cumulative assets " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家本局中途退出且退出时仍持有可观剩余资产"] = function(world)
      local player = _ensure_player(world, 1)
      player.cash = 99999
      player.quit_reason = "disconnect"
      return true
    end,

    ["本局两名玩家并列获胜"] = function(world)
      local one = _ensure_player(world, 1)
      local two = _ensure_player(world, 2)
      world.lb.game.winners = { one, two }
      return true
    end,

    ["每名获胜者本局之前的胜利次数为 2"] = function(world)
      _ensure_player(world, 1)
      _ensure_player(world, 2)
      _seed(world, 1, WIN, 2)
      _seed(world, 2, WIN, 2)
      return true
    end,

    ["每名获胜者本局之后的胜利次数为 3"] = function(world)
      for _, id in ipairs({ 1, 2 }) do
        local actual = _stored(world, id, WIN)
        if actual ~= 3 then
          return nil, "winner " .. tostring(id) .. " expected win count 3, got " .. tostring(actual)
        end
      end
      return true
    end,

    ["玩家本局已完成排行榜结算"] = function(world)
      local player = _ensure_player(world, 1)
      player.cash = 50000
      world.lb.game.winners = { player }
      leaderboard.settle(world.lb.game)
      world.lb_snapshot = {
        win = _stored(world, 1, WIN),
        assets = _stored(world, 1, ASSETS),
      }
      return true
    end,

    ["排行榜结算再次执行"] = function(world)
      leaderboard.settle(_ensure(world).game)
      return true
    end,

    ["玩家的胜利次数不再增加"] = function(world)
      local actual = _stored(world, 1, WIN)
      if actual ~= world.lb_snapshot.win then
        return nil, "win count changed on repeat settlement: " .. tostring(actual)
      end
      return true
    end,

    ["玩家的累计资产不再增加"] = function(world)
      local actual = _stored(world, 1, ASSETS)
      if actual ~= world.lb_snapshot.assets then
        return nil, "cumulative assets changed on repeat settlement: " .. tostring(actual)
      end
      return true
    end,

    ["宿主未开启自定义存档"] = function(world)
      local player = _ensure_player(world, 1)
      player.cash = 50000
      world.lb.game.winners = { player }
      world.lb.enabled = false
      return true
    end,

    ["不写入任何排行榜存档"] = function(world)
      if _ensure(world).writes ~= 0 then
        return nil, "expected no archive writes, got " .. tostring(world.lb.writes)
      end
      return true
    end,
  }
end

return leaderboard_steps
