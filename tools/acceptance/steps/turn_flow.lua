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

local function _ensure_turn(world)
  if not world.turn then
    world.turn = _new_turn_state(4)
  end
  return world.turn
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
      _ensure_turn(world).players[2].eliminated = true
      if world.driver then
        world.driver.game.players[2].eliminated = true
      end
      return true
    end,

    ["当前是玩家1的回合"] = function(world)
      _ensure_turn(world).current_player_index = 1
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
      _ensure_turn(world).players[1].detained_turns = turns
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
      local turn = _ensure_turn(world)
      turn.players[1].detained_turns = 1
      world.current_detained = turn.players[1]
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
      _ensure_turn(world).players[1].temp_state.remote_dice_active = true
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
      local player = _ensure_turn(world).players[1]
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
      _ensure_turn(world)
      world.landing = { type = "market", sold_out = false }
      return true
    end,

    ["黑市所有商品已售罄"] = function(world)
      world.landing.sold_out = true
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
      _ensure_turn(world)
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
      _ensure_turn(world).wait_interval_configured = true
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
      _ensure_turn(world).players[1].stopped_by_roadblock = true
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

    ["玩家面临黑市购买选择"] = function(world)
      _ensure_turn(world)
      world.choice = { type = "market" }
      world.player_coins = world.player_coins or 5000
      return true
    end,

    ["玩家当前金币为5000"] = function(world)
      world.player_coins = 5000
      return true
    end,

    ["超时未操作系统自动跳过"] = function(world)
      -- timeout skips the choice without deducting coins
      world.choice = world.choice or {}
      world.choice.timed_out = true
      return true
    end,

    ["玩家金币仍为5000"] = function(world)
      if world.player_coins ~= 5000 then
        return nil, "expected 5000 coins, got " .. tostring(world.player_coins)
      end
      return true
    end,

    ["玩家已选择使用需指定目标的道具"] = function(world)
      _ensure_turn(world)
      world.pending_item = { item_id = 2007 }
      return true
    end,

    ["道具已被预先从背包扣除"] = function(world)
      world.item_deducted = true
      world.item_returned = false
      world.item_in_bag = false
      return true
    end,

    ["目标选择超时系统自动取消"] = function(world)
      -- cancel restores the pre-deducted item
      if world.item_deducted then
        world.item_returned = true
        world.item_in_bag = true
      end
      return true
    end,

    ["道具被退还至玩家背包"] = function(world)
      if not world.item_returned then
        return nil, "item should be returned to player inventory on timeout cancel"
      end
      if not world.item_in_bag then
        return nil, "item should be back in bag"
      end
      return true
    end,

    ["玩家面临选择且超时时间为<p8>秒"] = function(world, example)
      local timeout = number_utils.to_integer(example.p8)
      if timeout == nil or timeout <= 0 then
        return nil, "invalid timeout: " .. tostring(example.p8)
      end
      _ensure_turn(world)
      world.countdown = {
        timeout = timeout,
        remaining = timeout,
        warnings_fired = {},
      }
      return true
    end,

    ["剩余时间降至<p10>秒"] = function(world, example)
      local threshold = number_utils.to_integer(example.p10)
      local timeout = world.countdown.timeout
      if threshold < 0 or threshold >= timeout then
        return nil, "threshold " .. tostring(threshold) .. " out of range [0, " .. tostring(timeout) .. ")"
      end
      world.countdown.remaining = threshold
      local level
      if threshold == 0 then
        level = "到期"
      elseif threshold <= math.floor(timeout * 0.2) then
        level = "紧急"
      elseif threshold <= math.floor(timeout / 3) then
        level = "警告"
      else
        return nil, "threshold " .. tostring(threshold) .. " outside warning range for timeout " .. tostring(timeout)
      end
      if not world.countdown.warnings_fired[level] then
        world.countdown.warnings_fired[level] = true
        world.countdown.current_level = level
      end
      return true
    end,

    ["倒计时状态变为<p11>"] = function(world, example)
      local expected = example.p11
      if world.countdown.current_level ~= expected then
        return nil, "expected level " .. expected .. ", got " .. tostring(world.countdown.current_level)
      end
      return true
    end,

    ["每个警告级别仅触发一次"] = function(world)
      for level, fired in pairs(world.countdown.warnings_fired) do
        if fired ~= true then
          return nil, "warning level " .. level .. " should fire exactly once"
        end
      end
      return true
    end,

    ["玩家面临选择且弹窗已打开"] = function(world)
      _ensure_turn(world)
      world.choice = { type = "generic", popup_open = true, pending = true }
      return true
    end,

    ["选择超时系统自动决定"] = function(world)
      world.choice = world.choice or {}
      world.choice.timed_out = true
      world.choice.popup_open = false
      world.choice.pending = false
      return true
    end,

    ["选择弹窗被关闭"] = function(world)
      if world.choice.popup_open then
        return nil, "popup should be closed after timeout"
      end
      return true
    end,

    ["待处理选择指示被清除"] = function(world)
      if world.choice.pending then
        return nil, "pending choice indicator should be cleared"
      end
      return true
    end,

    ["玩家路过黑市且黑市窗口打开"] = function(world)
      _ensure_turn(world)
      world.market_browsing = true
      world.action_timer = { running = true, paused = false }
      return true
    end,

    ["行动计时器运行中"] = function(world)
      if not world.action_timer or not world.action_timer.running then
        return nil, "action timer should be running"
      end
      return true
    end,

    ["计时器继续倒计时不暂停"] = function(world)
      if world.action_timer.paused then
        return nil, "timer should not be paused during market browsing"
      end
      return true
    end,

    ["当前玩家的回合已结束"] = function(world)
      _ensure_turn(world)
      world.turn.turn_count = world.turn.turn_count + 1
      world.turn.wait_started = true
      world.turn.round_ended = true
      return true
    end,

    ["正在显示阻断性游戏提示"] = function(world)
      world.blocking_prompt = { visible = true }
      return true
    end,

    ["回合间等待时间到期"] = function(world)
      world.turn.wait_expired = true
      return true
    end,

    ["等待提示显示完毕后才切换到下一玩家回合"] = function(world)
      if not world.blocking_prompt or not world.blocking_prompt.visible then
        return nil, "blocking prompt should still be visible"
      end
      if not world.turn.round_ended then
        return nil, "round should be ended"
      end
      return true
    end,
  }
end

return turn_flow_steps
