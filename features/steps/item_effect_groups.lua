-- #70：世界只保存真实 driver 与观察值，结算和准入均由 src 计算。
local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local item_ids = require("src.config.gameplay.item_ids")
local cards = { ["骰子加倍卡"] = item_ids.dice_multiplier, ["遥控骰子卡"] = item_ids.remote_dice }
local modes = { ["真人"] = true, ["补位电脑"] = true, ["手动托管"] = true, ["AFK托管"] = true }
local phases = { ["投骰前"] = "pre_action", ["投骰后"] = "pre_move" }

local function subject(w)
  return w.effect_groups, turn_driver.current_player(w.effect_groups)
end

local function select_card(ctx, item_id)
  local choice = assert(turn_driver.pending_choice(ctx), "未打开道具窗口")
  assert(choice.kind == "item_phase_passive", "应进入道具窗口")
  local result = turn_driver.resolve_pending_choice(ctx, item_id)
  assert(result.status ~= "rejected", "选卡被拒绝")
  choice = turn_driver.pending_choice(ctx)
  if choice and choice.kind == "remote_dice_value" then
    result = turn_driver.resolve_pending_choice(ctx, 3)
    assert(result.status ~= "rejected", "点数选择被拒绝")
  end
end

return dsl.steps({
  ["同组回归以{控制方式}开局，槽位1和2各放一张{卡名}"] = function(w, a)
    assert(modes[a["控制方式"]], "未知控制方式")
    local item_id = assert(cards[a["卡名"]], "未知同组卡")
    local ctx = game_driver.new_game({ ai = a["控制方式"] == "补位电脑" and { [1] = true } or {} })
    local player = turn_driver.current_player(ctx)
    turn_driver.set_item_control_mode(ctx, player, a["控制方式"])
    game_driver.clear_items(ctx, player)
    game_driver.give_item(ctx, player, item_id)
    game_driver.give_item(ctx, player, item_id)
    w.effect_groups, w.group_card = ctx, item_id
    return true
  end,
  ["同组回归从{窗口}完成首次用卡"] = function(w, a)
    local ctx, player = subject(w)
    turn_driver.run_item_phase(ctx, player, assert(phases[a["窗口"]], "未知窗口"))
    if not turn_driver.is_computer_controlled(ctx, player) then select_card(ctx, w.group_card) end
    w.first_remote_value = turn_driver.pending_remote_dice(ctx, player)
    return true
  end,
  ["同组回归只消耗槽位1，槽位2仍保留原卡"] = function(w)
    local ctx, player = subject(w)
    local ok, err = dsl.eq(game_driver.item_in_slot(ctx, player, 1), nil, "槽位1")
    if not ok then return nil, err end
    ok, err = dsl.eq(game_driver.item_in_slot(ctx, player, 2), w.group_card, "槽位2")
    if not ok then return nil, err end
    return dsl.eq(#game_driver.items_of(ctx, player), 1, "剩余卡数")
  end,
  ["同组回归骰子倍率为{倍率:int}"] = function(w, a)
    local ctx, player = subject(w)
    return dsl.eq(turn_driver.dice_multiplier(ctx, player), a["倍率"], "骰子倍率")
  end,
  ["同组回归效果组已登记，{窗口}的剩余卡不可用"] = function(w, a)
    local ctx, player = subject(w)
    local allowed, reason = game_driver.item_offer_allowed(ctx, player, w.group_card, phases[a["窗口"]])
    local ok, err = dsl.eq(allowed, false, "同组准入")
    if not ok then return nil, err end
    return dsl.eq(reason, "effect_group_used", "拒绝原因")
  end,
  ["同组回归在{窗口}尝试以第二张覆盖效果"] = function(w, a)
    local ctx, player = subject(w)
    local result = turn_driver.attempt_item_use(ctx, player, w.group_card, phases[a["窗口"]])
    local ok, err = dsl.eq(result.status, "rejected", "重复用卡结果")
    if not ok then return nil, err end
    return dsl.eq(result.reason, "effect_group_used", "重复用卡拒绝原因")
  end,
  ["同组回归遥控点数保留首次结果"] = function(w)
    local ctx, player = subject(w)
    local value = turn_driver.pending_remote_dice(ctx, player)
    local ok, err = dsl.truthy(value ~= nil, "首次遥控点数")
    if not ok then return nil, err end
    if not turn_driver.is_computer_controlled(ctx, player) then
      for _, point in ipairs(value) do
        ok, err = dsl.eq(point, 3, "真人选择的点数")
        if not ok then return nil, err end
      end
    end
    ok, err = dsl.eq(#value, #w.first_remote_value, "遥控骰子数")
    if not ok then return nil, err end
    for index, point in ipairs(value) do
      ok, err = dsl.eq(point, w.first_remote_value[index], "遥控点数不可覆盖")
      if not ok then return nil, err end
    end
    return true
  end,
  ["同组回归真人取消{取消位置}"] = function(w, a)
    local ctx, player = subject(w)
    turn_driver.run_item_phase(ctx, player, "pre_action")
    if a["取消位置"] == "点数选择" then
      turn_driver.resolve_pending_choice(ctx, w.group_card)
      assert(turn_driver.pending_choice(ctx).kind == "remote_dice_value", "应进入点数选择")
    else
      assert(a["取消位置"] == "道具窗口", "未知取消位置")
    end
    turn_driver.cancel_pending_choice(ctx)
    -- 道具窗口取消会结束本阶段，重入一次消费已完成标记；后续开窗仍由 phase.run。
    if a["取消位置"] == "道具窗口" then turn_driver.run_item_phase(ctx, player, "pre_action") end
    return true
  end,
  ["同组回归在非法窗口尝试用卡"] = function(w)
    local ctx, player = subject(w)
    local result = turn_driver.attempt_item_use(ctx, player, w.group_card, "post_action")
    return dsl.eq(result.status, "rejected", "非法阶段用卡")
  end,
  ["同组回归两张卡保留且效果组未登记，{窗口}仍可用"] = function(w, a)
    local ctx, player = subject(w)
    for slot = 1, 2 do
      local ok, err = dsl.eq(game_driver.item_in_slot(ctx, player, slot), w.group_card, "保留槽位" .. slot)
      if not ok then return nil, err end
    end
    return dsl.eq(game_driver.item_offer_allowed(ctx, player, w.group_card, phases[a["窗口"]]), true, "合法阶段可用")
  end,
  ["同组回归槽位3另有骰子加倍卡"] = function(w)
    local ctx, player = subject(w)
    game_driver.give_item(ctx, player, item_ids.dice_multiplier)
    return true
  end,
  ["同组回归继续在投骰后使用不同组加倍卡"] = function(w)
    local ctx, player = subject(w)
    turn_driver.run_item_phase(ctx, player, "pre_move")
    if not turn_driver.is_computer_controlled(ctx, player) then select_card(ctx, item_ids.dice_multiplier) end
    return dsl.eq(game_driver.item_in_slot(ctx, player, 3), nil, "不同组卡已消耗")
  end,
  ["同组回归经真实回合推进到自己的下一回合"] = function(w)
    local ctx, player = subject(w)
    turn_driver.rotate_to_next_own_turn(ctx, player)
    return true
  end,
  ["同组回归槽位2原卡在{窗口}恢复可用"] = function(w, a)
    local ctx, player = subject(w)
    local ok, err = dsl.eq(game_driver.item_in_slot(ctx, player, 2), w.group_card, "跨回合保留槽位")
    if not ok then return nil, err end
    return dsl.eq(game_driver.item_offer_allowed(ctx, player, w.group_card, phases[a["窗口"]]), true, "新回合可用")
  end,
}, { name = "item_effect_groups" })
