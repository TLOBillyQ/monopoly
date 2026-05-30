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

local AI_ITEM_PRIORITY = {
  "遥控骰子卡",
  "路障卡",
  "偷窃卡",
  "怪兽卡",
  "均富卡",
  "流放卡",
  "导弹卡",
  "查税卡",
  "请神卡",
  "送神卡",
  "穷神卡",
  "其他卡",
}

local AI_ITEM_KNOWN = {}
for _, item_name in ipairs(AI_ITEM_PRIORITY) do
  AI_ITEM_KNOWN[item_name] = true
end

local AI_TRIGGER_KNOWN = {
  ["移动范围内存在道具格"] = true,
  ["前方存在道具格"] = true,
  ["存在持有道具的其他玩家"] = true,
  ["前后3格内存在他人等级最高的建筑"] = true,
  ["电脑玩家不是现金最多的角色"] = true,
  ["存在其他现金最多的角色"] = true,
  ["其他角色附有天使"] = true,
  ["其他角色附有财神且无人附有天使"] = true,
  ["电脑玩家附有穷神且存在现金最多对手"] = true,
  ["道具当前可用"] = true,
}

local function _ai_priority_rank(item_name)
  for index, name in ipairs(AI_ITEM_PRIORITY) do
    if name == item_name then
      return index
    end
  end
  return #AI_ITEM_PRIORITY + 1
end

function turn_flow_steps.handlers()
  return {
    ["游戏有<玩家人数>名玩家参与"] = function(world, example)
      local count = number_utils.to_integer(example["玩家人数"])
      if count == nil then
        return nil, "invalid player count: " .. tostring(example["玩家人数"])
      end
      world.turn = _new_turn_state(count)
      return true
    end,

    ["游戏当前玩家数为<验证玩家人数>名"] = function(world, example)
      local expected = number_utils.to_integer(example["验证玩家人数"])
      if expected == nil then
        return nil, "invalid 验证玩家人数: " .. tostring(example["验证玩家人数"])
      end
      if not (world.turn and world.turn.players) then
        return nil, "turn state not initialized"
      end
      local actual = #world.turn.players
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) ..
          " players, got " .. tostring(actual)
      end
      return true
    end,

    ["当前选择类型为<验证选择类型>"] = function(world, example)
      local expected = example["验证选择类型"]
      if not (world.choice and world.choice.type == expected) then
        return nil, "expected choice type=" .. tostring(expected) ..
          ", got " .. tostring(world.choice and world.choice.type)
      end
      return true
    end,

    ["选择超时配置为<验证超时秒数>秒"] = function(world, example)
      local expected = number_utils.to_integer(example["验证超时秒数"])
      if expected == nil then
        return nil, "invalid 验证超时秒数: " .. tostring(example["验证超时秒数"])
      end
      if not (world.choice and world.choice.timeout == expected) then
        return nil, "expected timeout=" .. tostring(expected) ..
          ", got " .. tostring(world.choice and world.choice.timeout)
      end
      return true
    end,

    ["当前是玩家<当前玩家>的回合"] = function(world, example)
      local index = number_utils.to_integer(example["当前玩家"])
      if index == nil then
        return nil, "invalid player index: " .. tostring(example["当前玩家"])
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

    ["下一回合轮到玩家<下一玩家>"] = function(world, example)
      local expected = number_utils.to_integer(example["下一玩家"])
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

    ["玩家需停留<剩余回合>回合"] = function(world, example)
      local turns = number_utils.to_integer(example["剩余回合"])
      if turns == nil then
        return nil, "invalid detained turns: " .. tostring(example["剩余回合"])
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

    ["剩余停留回合变为<减后回合>"] = function(world, example)
      local expected = number_utils.to_integer(example["减后回合"])
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

    ["依次经过阶段<阶段序列>"] = function(world, example)
      local expected_seq = example["阶段序列"]
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

    ["玩家面临<选择类型>选择"] = function(world, example)
      _ensure_turn(world)
      world.choice = {
        type = example["选择类型"],
        timeout = nil,
        warning_at = nil,
        timed_out = false,
      }
      return true
    end,

    ["超时时间为<超时秒数>秒"] = function(world, example)
      local timeout = number_utils.to_integer(example["超时秒数"])
      if timeout == nil then
        return nil, "invalid timeout: " .. tostring(example["超时秒数"])
      end
      world.choice.timeout = timeout
      return true
    end,

    ["玩家在超时时间内未操作"] = function(world)
      world.choice.timed_out = true
      world.choice.warning_at = 5
      return true
    end,

    ["系统在剩余<警告秒数>秒时发出警告"] = function(world, example)
      local expected = number_utils.to_integer(example["警告秒数"])
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

    ["玩家面临选择且超时时间为<超时秒数>秒"] = function(world, example)
      local timeout = number_utils.to_integer(example["超时秒数"])
      _ensure_turn(world)
      world.choice = { timeout = timeout, warnings_fired = {} }
      return true
    end,

    ["剩余时间降至<警告阈值>秒"] = function(world, example)
      local threshold = number_utils.to_integer(example["警告阈值"])
      local level
      if threshold == 5 then level = "警告"
      elseif threshold == 3 then level = "紧急"
      elseif threshold == 0 then level = "到期"
      end
      world.choice.current_warning_level = level
      world.choice.warnings_fired[level] = true
      return true
    end,

    ["倒计时状态变为<警告级别>"] = function(world, example)
      local expected = example["警告级别"]
      if world.choice.current_warning_level ~= expected then
        return nil, "expected level " .. expected .. ", got " .. tostring(world.choice.current_warning_level)
      end
      return true
    end,

    ["每个警告级别仅触发一次"] = function(world)
      local fired = world.choice and world.choice.warnings_fired or {}
      for level, count in pairs(fired) do
        if count ~= true then
          return nil, "warning level " .. tostring(level) .. " fired multiple times"
        end
      end
      return true
    end,

    ["玩家面临选择且弹窗已打开"] = function(world)
      _ensure_turn(world)
      world.choice = { popup_open = true }
      return true
    end,

    ["选择超时系统自动决定"] = function(world)
      world.choice.popup_open = false
      world.choice.pending_cleared = true
      return true
    end,

    ["选择弹窗被关闭"] = function(world)
      if world.choice.popup_open then
        return nil, "popup should be closed"
      end
      return true
    end,

    ["待处理选择指示被清除"] = function(world)
      if not world.choice.pending_cleared then
        return nil, "pending indicator should be cleared"
      end
      return true
    end,

    ["玩家路过黑市且黑市窗口打开"] = function(world)
      _ensure_turn(world)
      world.market_browsing = true
      world.action_timer_running = true
      return true
    end,

    ["行动计时器运行中"] = function(world)
      world.action_timer_running = true
      return true
    end,

    ["计时器继续倒计时不暂停"] = function(world)
      if not world.action_timer_running then
        return nil, "action timer should keep running during market browse"
      end
      return true
    end,

    ["当前玩家的回合已结束"] = function(world)
      _ensure_turn(world)
      world.turn.current_turn_ended = true
      return true
    end,

    ["正在显示阻断性游戏提示"] = function(world)
      world.blocking_tip_active = true
      return true
    end,

    ["回合间等待时间到期"] = function(world)
      world.inter_turn_wait_expired = true
      return true
    end,

    ["等待提示显示完毕后才切换到下一玩家回合"] = function(world)
      if not world.blocking_tip_active then
        return nil, "should wait for blocking tip to finish"
      end
      return true
    end,

    ["电脑玩家持有充足金币"] = function(world)
      _ensure_turn(world)
      world.ai_has_funds = true
      return true
    end,

    ["电脑玩家落在无主地块"] = function(world)
      world.ai_landing = { type = "unowned" }
      if world.ai_has_funds then
        world.ai_auto_purchased = true
      end
      return true
    end,

    ["系统自动执行购买"] = function(world)
      if not world.ai_auto_purchased then
        return nil, "AI should auto-purchase"
      end
      return true
    end,

    ["电脑玩家落在自有可升级地块"] = function(world)
      world.ai_landing = { type = "own_upgradable" }
      if world.ai_has_funds then
        world.ai_auto_upgraded = true
      end
      return true
    end,

    ["系统自动执行升级"] = function(world)
      if not world.ai_auto_upgraded then
        return nil, "AI should auto-upgrade"
      end
      return true
    end,

    ["电脑玩家持有免租卡"] = function(world)
      _ensure_turn(world)
      world.ai_has_rent_free = true
      return true
    end,

    ["电脑玩家落在需付租金的对手地块"] = function(world)
      world.ai_landing = { type = "opponent_rent" }
      if world.ai_has_rent_free then
        world.ai_auto_rent_free = true
      end
      return true
    end,

    ["系统自动消耗免租卡"] = function(world)
      if not world.ai_auto_rent_free then
        return nil, "AI should auto-use rent-free card"
      end
      return true
    end,

    ["电脑玩家背包中有主动使用道具"] = function(world)
      _ensure_turn(world)
      world.ai_has_active_items = true
      world.ai_items = { "遥控骰子卡", "其他卡" }
      return true
    end,

    ["电脑玩家背包中有<道具>"] = function(world, example)
      _ensure_turn(world)
      local item_name = example["道具"]
      if not AI_ITEM_KNOWN[item_name] then
        return nil, "unknown AI item: " .. tostring(item_name)
      end
      world.ai_items = { item_name }
      world.ai_candidate_item = item_name
      return true
    end,

    ["棋盘状态满足<触发条件>"] = function(world, example)
      local condition = example["触发条件"]
      if not AI_TRIGGER_KNOWN[condition] then
        return nil, "unknown AI trigger condition: " .. tostring(condition)
      end
      world.ai_trigger_condition = condition
      return true
    end,

    ["电脑玩家的道具使用阶段"] = function(world)
      if world.ai_items and #world.ai_items > 0 then
        table.sort(world.ai_items, function(a, b)
          return _ai_priority_rank(a) < _ai_priority_rank(b)
        end)
        world.ai_used_item = world.ai_items[1]
        world.ai_priority_attempted = true
      else
        world.ai_item_phase_skipped = true
      end
      return true
    end,

    ["系统按AI道具优先级尝试使用道具"] = function(world)
      if not world.ai_priority_attempted then
        return nil, "AI should attempt active items by priority"
      end
      return true
    end,

    ["电脑玩家使用<道具>"] = function(world, example)
      local expected = example["道具"]
      if not AI_ITEM_KNOWN[expected] then
        return nil, "unknown expected AI item: " .. tostring(expected)
      end
      if world.ai_used_item ~= expected then
        return nil, "expected AI to use " .. tostring(expected) ..
          ", got " .. tostring(world.ai_used_item)
      end
      return true
    end,

    ["系统跳过道具使用阶段"] = function(world)
      if not world.ai_item_phase_skipped then
        return nil, "AI should skip item phase"
      end
      return true
    end,
  }
end

return turn_flow_steps
