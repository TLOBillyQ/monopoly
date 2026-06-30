local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local event_kinds = require("src.config.gameplay.event_kinds")
local angel_feedback = require("src.rules.items.angel_feedback")
local item_ids = require("src.config.gameplay.item_ids")
local post_effects = require("src.rules.items.post_effects")

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

local function _deity_code(raw_name)
  return DEITY_NAME_MAP[raw_name]
end

local function _set_player_deity(game, player, raw_name, duration)
  local deity_name = _deity_code(raw_name)
  if deity_name == nil then
    return nil, "unknown deity: " .. tostring(raw_name)
  end
  game:set_player_deity(player, deity_name, duration)
  game:tick_player_deity(player)
  return true
end

local function _assert_player_deity(game, player, raw_name)
  local deity_name = _deity_code(raw_name)
  if deity_name == nil then
    return nil, "unknown deity: " .. tostring(raw_name)
  end
  if not game:player_has_deity(player, deity_name) then
    local deity = player.status and player.status.deity
    return nil, "expected " .. tostring(player.name) .. " to have " .. tostring(raw_name) ..
      ", got type=" .. tostring(deity and deity.type) .. " remaining=" .. tostring(deity and deity.remaining)
  end
  return true
end

local function _end_player1_turns(world, times)
  local game = _game(world)
  local player1 = game.players[1]
  for _ = 1, times do
    game:tick_player_deity(player1)
  end
  return true
end

function deities_steps.handlers()
  return {
    ["玩家1附体<神灵>持续<持续回合>回合"] = function(world, example)
      local duration = number_utils.to_integer(example["持续回合"])
      if duration == nil then
        return nil, "invalid duration: " .. tostring(example["持续回合"])
      end
      local game = _game(world)
      local player1 = game.players[1]
      return _set_player_deity(game, player1, example["神灵"], duration)
    end,

    ["玩家2附体<神灵>持续<持续回合>回合"] = function(world, example)
      local duration = number_utils.to_integer(example["持续回合"])
      if duration == nil then
        return nil, "invalid duration: " .. tostring(example["持续回合"])
      end
      local game = _game(world)
      return _set_player_deity(game, game.players[2], example["神灵"], duration)
    end,

    ["玩家1附体穷神持续3回合"] = function(world)
      local game = _game(world)
      return _set_player_deity(game, game.players[1], "穷神", 3)
    end,

    ["玩家1附体财神持续3回合"] = function(world)
      local game = _game(world)
      return _set_player_deity(game, game.players[1], "财神", 3)
    end,

    ["玩家1神灵剩余回合为<验证持续回合>"] = function(world, example)
      local expected = number_utils.to_integer(example["验证持续回合"])
      if expected == nil then
        return nil, "invalid 验证持续回合: " .. tostring(example["验证持续回合"])
      end
      local player1 = _game(world).players[1]
      local deity = player1.status and player1.status.deity
      local remaining = deity and deity.remaining or 0
      if remaining ~= expected then
        return nil, "expected remaining=" .. tostring(expected) ..
          ", got " .. tostring(remaining)
      end
      return true
    end,

    ["玩家1的回合结束<持续回合>次"] = function(world, example)
      local times = number_utils.to_integer(example["持续回合"])
      if times == nil then
        return nil, "invalid times: " .. tostring(example["持续回合"])
      end
      return _end_player1_turns(world, times)
    end,

    ["玩家1的回合结束<已结束回合>次"] = function(world, example)
      local times = number_utils.to_integer(example["已结束回合"])
      if times == nil then
        return nil, "invalid times: " .. tostring(example["已结束回合"])
      end
      return _end_player1_turns(world, times)
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
      return _set_player_deity(game, player2, "穷神", 3)
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

    ["玩家1对玩家2使用<道具>"] = function(world, example)
      local item_name = example["道具"]
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

    ["玩家1对玩家2使用请神卡"] = function(world)
      local game = _game(world)
      local ok = post_effects.apply_target(game, game.players[1], item_ids.invite_deity, game.players[2], {})
      if ok ~= true then
        return nil, "invite deity should apply"
      end
      return true
    end,

    ["<神灵>转移到玩家1身上"] = function(world, example)
      return _assert_player_deity(_game(world), _game(world).players[1], example["神灵"])
    end,

    ["玩家2不再持有任何神灵"] = function(world)
      local game = _game(world)
      local player2 = game.players[2]
      if game:player_has_any_deity(player2) then
        local deity = player2.status and player2.status.deity
        return nil, "player2 still has deity: type=" .. tostring(deity and deity.type) ..
          " remaining=" .. tostring(deity and deity.remaining)
      end
      return true
    end,

    ["玩家1对玩家2使用送神卡"] = function(world)
      local game = _game(world)
      local ok = post_effects.apply_target(game, game.players[1], item_ids.send_poor, game.players[2], {})
      if ok ~= true then
        return nil, "send poor should apply"
      end
      return true
    end,

    ["穷神转移到玩家2身上"] = function(world)
      return _assert_player_deity(_game(world), _game(world).players[2], "穷神")
    end,
  }
end

return deities_steps
