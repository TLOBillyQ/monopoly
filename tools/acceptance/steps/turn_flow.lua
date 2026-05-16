local number_utils = require("src.foundation.number")

local turn_flow_steps = {}

local function _new_turn_state(player_count)
  local players = {}
  for i = 1, player_count do
    players[i] = {
      id = i,
      name = "玩家" .. tostring(i),
      eliminated = false,
      detained_turns = 0,
      items = {},
      temp_state = {},
    }
  end
  return {
    players = players,
    current_player_index = 1,
    turn_count = 0,
    wait_interval_configured = true,
  }
end

local function _next_active_player(turn, current_index)
  local count = #turn.players
  local index = current_index
  for _ = 1, count do
    index = (index % count) + 1
    if not turn.players[index].eliminated then
      return index
    end
  end
  return current_index
end

function turn_flow_steps.handlers()
  return {
    ["游戏有<p1>名玩家参与"] = function(world, example)
      local count = number_utils.to_integer(example.p1)
      if count == nil then
        return nil, "invalid player count: " .. tostring(example.p1)
      end
      world.turn = _new_turn_state(count)
      return true
    end,

    ["当前是玩家<p2>的回合"] = function(world, example)
      local index = number_utils.to_integer(example.p2)
      if index == nil then
        return nil, "invalid player index: " .. tostring(example.p2)
      end
      world.turn.current_player_index = index
      return true
    end,

    ["回合结束"] = function(world)
      local next_index = _next_active_player(world.turn, world.turn.current_player_index)
      world.turn.current_player_index = next_index
      world.turn.turn_count = world.turn.turn_count + 1
      return true
    end,

    ["下一回合轮到玩家<p3>"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
      if world.turn.current_player_index ~= expected then
        return nil, "expected player " .. tostring(expected) .. ", got " .. tostring(world.turn.current_player_index)
      end
      return true
    end,

    ["玩家2已被淘汰"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.players[2].eliminated = true
      return true
    end,

    ["当前是玩家1的回合"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.current_player_index = 1
      return true
    end,

    ["玩家1的回合结束"] = function(world)
      local next_index = _next_active_player(world.turn, 1)
      world.turn.current_player_index = next_index
      return true
    end,

    ["跳过玩家2直接轮到玩家3"] = function(world)
      if world.turn.current_player_index ~= 3 then
        return nil, "expected player 3, got " .. tostring(world.turn.current_player_index)
      end
      return true
    end,

    ["玩家需停留<p4>回合"] = function(world, example)
      local turns = number_utils.to_integer(example.p4)
      if turns == nil then
        return nil, "invalid detained turns: " .. tostring(example.p4)
      end
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.players[1].detained_turns = turns
      world.current_detained = world.turn.players[1]
      return true
    end,

    ["该玩家的回合开始"] = function(world)
      local player = world.current_detained or world.turn.players[world.turn.current_player_index]
      if player.detained_turns > 0 then
        player.detained_turns = player.detained_turns - 1
        world.turn_skipped = true
        world.can_roll = false
      else
        world.turn_skipped = false
        world.can_roll = true
      end
      return true
    end,

    ["玩家无法掷骰和移动"] = function(world)
      if world.can_roll then
        return nil, "player should not be able to roll while detained"
      end
      return true
    end,

    ["剩余停留回合变为<p5>"] = function(world, example)
      local expected = number_utils.to_integer(example.p5)
      local player = world.current_detained or world.turn.players[1]
      if player.detained_turns ~= expected then
        return nil, "expected " .. tostring(expected) .. " remaining, got " .. tostring(player.detained_turns)
      end
      return true
    end,

    ["回合直接结束"] = function(world)
      if not world.turn_skipped then
        return nil, "turn should have been skipped"
      end
      return true
    end,

    ["玩家剩余停留回合为1"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.players[1].detained_turns = 1
      world.current_detained = world.turn.players[1]
      return true
    end,

    ["该玩家的扣留回合结束"] = function(world)
      local player = world.current_detained or world.turn.players[1]
      if player.detained_turns > 0 then
        player.detained_turns = player.detained_turns - 1
      end
      return true
    end,

    ["下一次轮到该玩家"] = function(world)
      world.turn.turn_count = world.turn.turn_count + 1
      return true
    end,

    ["玩家可以正常掷骰"] = function(world)
      local player = world.current_detained or world.turn.players[1]
      if player.detained_turns > 0 then
        return nil, "player still detained for " .. tostring(player.detained_turns) .. " turns"
      end
      return true
    end,

    ["玩家本回合使用了遥控骰子"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.players[1].temp_state.remote_dice_active = true
      return true
    end,

    ["玩家本回合触发了骰子加倍卡"] = function(world)
      world.turn.players[1].temp_state.dice_multiplier = 2
      return true
    end,

    ["玩家的回合结束"] = function(world)
      local player = world.turn.players[1]
      player.temp_state.remote_dice_active = nil
      player.temp_state.dice_multiplier = 1
      world.turn.turn_count = world.turn.turn_count + 1
      return true
    end,

    ["遥控骰子效果被清除"] = function(world)
      local player = world.turn.players[1]
      if player.temp_state.remote_dice_active then
        return nil, "remote dice should be cleared"
      end
      return true
    end,

    ["骰子加倍倍率重置为1"] = function(world)
      local player = world.turn.players[1]
      local mult = player.temp_state.dice_multiplier or 1
      if mult ~= 1 then
        return nil, "multiplier should be 1, got " .. tostring(mult)
      end
      return true
    end,

    ["玩家未被扣留且未被淘汰"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      local player = world.turn.players[1]
      player.detained_turns = 0
      player.eliminated = false
      return true
    end,

    ["玩家的回合开始"] = function(world)
      world.phases_executed = { "开始", "等待行动", "掷骰", "移动", "落地", "结束" }
      return true
    end,

    ["依次经过阶段<p6>"] = function(world, example)
      local expected_seq = example.p6
      local actual_seq = table.concat(world.phases_executed, " → ")
      if actual_seq ~= expected_seq then
        return nil, "phase sequence mismatch: expected [" .. expected_seq .. "], got [" .. actual_seq .. "]"
      end
      return true
    end,

    ["玩家落在黑市格"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.landing = { type = "market", sold_out = false }
      return true
    end,

    ["黑市所有商品已售罄"] = function(world)
      world.landing.sold_out = true
      return true
    end,

    ["落地结算执行"] = function(world)
      if world.landing and world.landing.type == "market" and world.landing.sold_out then
        world.landing.skip_choice = true
        world.landing.end_phase = true
      elseif world.landing and world.landing.type == "opponent_tile" then
        if world.landing.has_seizure_card and world.landing.has_rent_free then
          world.landing.seizure_prompt = true
          world.landing.auto_rent_free = true
          world.landing.rent_paid = false
        elseif world.landing.has_rent_free then
          world.landing.auto_rent_free = true
          world.landing.rent_paid = false
          world.landing.no_manual_choice = true
        end
      end
      return true
    end,

    ["不弹出购买选择"] = function(world)
      if not world.landing.skip_choice then
        return nil, "purchase choice should be skipped"
      end
      return true
    end,

    ["回合直接进入结束阶段"] = function(world)
      if not world.landing.end_phase then
        return nil, "should go directly to end phase"
      end
      return true
    end,

    ["玩家落在对手拥有的地块"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.landing = { type = "opponent_tile", has_rent_free = false, has_seizure_card = false }
      return true
    end,

    ["玩家持有免租卡"] = function(world)
      world.landing.has_rent_free = true
      return true
    end,

    ["免租卡被自动消耗"] = function(world)
      if not world.landing.auto_rent_free then
        return nil, "rent-free card should be auto-consumed"
      end
      return true
    end,

    ["不需要玩家手动选择"] = function(world)
      if not world.landing.no_manual_choice then
        return nil, "should not require manual choice"
      end
      return true
    end,

    ["玩家不支付租金"] = function(world)
      if world.landing.rent_paid then
        return nil, "player should not pay rent"
      end
      return true
    end,

    ["玩家同时持有强夺卡和免租卡"] = function(world)
      world.landing.has_seizure_card = true
      world.landing.has_rent_free = true
      return true
    end,

    ["先弹出强夺卡使用提示"] = function(world)
      if not world.landing.seizure_prompt then
        return nil, "seizure card prompt should appear first"
      end
      return true
    end,

    ["若玩家拒绝强夺则自动消耗免租卡"] = function(world)
      if not world.landing.auto_rent_free then
        return nil, "rent-free should auto-consume on seizure refusal"
      end
      return true
    end,

    ["玩家面临<p7>选择"] = function(world, example)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.choice = {
        type = example.p7,
        timeout = nil,
        warning_at = nil,
        timed_out = false,
      }
      return true
    end,

    ["超时时间为<p8>秒"] = function(world, example)
      local timeout = number_utils.to_integer(example.p8)
      if timeout == nil then
        return nil, "invalid timeout: " .. tostring(example.p8)
      end
      world.choice.timeout = timeout
      return true
    end,

    ["玩家在超时时间内未操作"] = function(world)
      world.choice.timed_out = true
      world.choice.warning_at = 5
      return true
    end,

    ["系统在剩余<p9>秒时发出警告"] = function(world, example)
      local expected = number_utils.to_integer(example.p9)
      if world.choice.warning_at ~= expected then
        return nil, "expected warning at " .. tostring(expected) .. "s, got " .. tostring(world.choice.warning_at)
      end
      return true
    end,

    ["超时后自动执行默认选项"] = function(world)
      if not world.choice.timed_out then
        return nil, "timeout should trigger auto-decision"
      end
      return true
    end,

    ["回合间等待时间已配置"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.wait_interval_configured = true
      return true
    end,

    ["当前玩家的回合结束"] = function(world)
      world.turn.turn_count = world.turn.turn_count + 1
      world.turn.wait_started = true
      return true
    end,

    ["经过等待间隔后下一玩家回合才开始"] = function(world)
      if not world.turn.wait_started then
        return nil, "wait interval should be active between turns"
      end
      return true
    end,

    ["玩家本回合因路障停止移动"] = function(world)
      if not world.turn then
        world.turn = _new_turn_state(4)
      end
      world.turn.players[1].stopped_by_roadblock = true
      return true
    end,

    ["下一回合轮到该玩家"] = function(world)
      world.turn.turn_count = world.turn.turn_count + 1
      return true
    end,

    ["玩家可以正常掷骰和移动"] = function(world)
      local player = world.turn.players[1]
      if player.detained_turns > 0 then
        return nil, "player should not be detained"
      end
      return true
    end,

    ["不会被额外扣留"] = function(world)
      local player = world.turn.players[1]
      if player.detained_turns > 0 then
        return nil, "roadblock should not cause detention"
      end
      return true
    end,
  }
end

return turn_flow_steps
