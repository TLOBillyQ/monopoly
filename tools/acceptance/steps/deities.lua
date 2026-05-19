local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local event_kinds = require("src.config.gameplay.event_kinds")
local angel_feedback = require("src.rules.items.angel_feedback")

local deities_steps = {}

local DEITY_NAME_MAP = {
  ["财神"] = "rich",
  ["穷神"] = "poor",
  ["天使"] = "angel",
}

local ITEM_NAME_MAP = {
  ["均富卡"] = 2011,
  ["偷窃卡"] = 2007,
  ["查税卡"] = 2014,
}

local function _game(world) return world.driver.game end
local function _ctx(world) return world.driver end

function deities_steps.handlers()
  return {
    ["玩家1附体<p1>持续<p2>回合"] = function(world, example)
      local deity_name = DEITY_NAME_MAP[example.p1]
      if deity_name == nil then
        return nil, "unknown deity: " .. tostring(example.p1)
      end
      local duration = number_utils.to_integer(example.p2)
      if duration == nil then
        return nil, "invalid duration: " .. tostring(example.p2)
      end
      local game = _game(world)
      local player1 = game.players[1]
      game:set_player_deity(player1, deity_name, duration)
      game:tick_player_deity(player1)
      return true
    end,

    ["玩家1的回合结束<p2>次"] = function(world, example)
      local times = number_utils.to_integer(example.p2)
      if times == nil then
        return nil, "invalid times: " .. tostring(example.p2)
      end
      local game = _game(world)
      local player1 = game.players[1]
      for _ = 1, times do
        game:tick_player_deity(player1)
      end
      return true
    end,

    ["玩家1不再持有任何神灵"] = function(world)
      local game = _game(world)
      local player1 = game.players[1]
      if game:player_has_any_deity(player1) then
        local d = player1.status and player1.status.deity
        return nil, "player1 still has deity: type=" .. tostring(d and d.type) .. " remaining=" .. tostring(d and d.remaining)
      end
      return true
    end,

    ["玩家2附体穷神持续3回合"] = function(world)
      local game = _game(world)
      local player2 = game.players[2]
      game:set_player_deity(player2, "poor", 3)
      game:tick_player_deity(player2)
      return true
    end,

    ["游戏进行一个完整回合"] = function(world)
      local game = _game(world)
      for _, player in ipairs(game.players) do
        game:tick_player_deity(player)
      end
      return true
    end,

    ["玩家2的神灵剩余回合仍为3"] = function(world)
      local player2 = _game(world).players[2]
      local deity = player2.status and player2.status.deity
      local remaining = deity and deity.remaining or 0
      if remaining ~= 3 then
        return nil, "expected remaining 3, got " .. tostring(remaining)
      end
      return true
    end,

    ["玩家2附体天使"] = function(world)
      local game = _game(world)
      local player2 = game.players[2]
      game:set_player_deity(player2, "angel", 5)
      game:tick_player_deity(player2)
      return true
    end,

    ["玩家1对玩家2使用<p3>"] = function(world, example)
      local item_name = example.p3
      local item_id = ITEM_NAME_MAP[item_name]
      if item_id == nil then
        return nil, "unknown item: " .. tostring(item_name)
      end
      local game = _game(world)
      local player2 = game.players[2]
      local is_blocked = game:angel_immune_to_item(player2, item_id)
      world.item_effect_blocked = is_blocked
      if is_blocked then
        angel_feedback.publish(game, player2, item_name)
      end
      return true
    end,

    ["道具效果被阻断"] = function(world)
      if not world.item_effect_blocked then
        return nil, "item effect should be blocked by angel immunity"
      end
      return true
    end,

    ["系统记录天使保护事件"] = function(world)
      local events = game_driver.events(_ctx(world))
      for _, event in ipairs(events) do
        if event.kind == event_kinds.item_immune then
          return true
        end
      end
      return nil, "no item_immune event in event log"
    end,

    ["当前棋盘存在地雷"] = function(world)
      local game = _game(world)
      local player2 = game.players[2]
      game:place_mine(player2.position, {})
      return true
    end,

    ["玩家2落在地雷格"] = function(world)
      local ctx = _ctx(world)
      local player2 = _game(world).players[2]
      world.mine_result = game_driver.try_trigger_mine(ctx, player2)
      return true
    end,

    ["玩家2不进医院"] = function(world)
      local player2 = _game(world).players[2]
      local status = player2.status
      if status and status.pending_location_effect == "hospital" then
        return nil, "player2 should not be sent to hospital"
      end
      return true
    end,
  }
end

return deities_steps
