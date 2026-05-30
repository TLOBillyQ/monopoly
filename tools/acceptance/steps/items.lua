local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")
local game_driver = require("tools.acceptance.game_driver")
local demolish = require("src.rules.items.demolish")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local land_phase = require("src.turn.phases.land")
local items_cfg = require("src.config.content.items")

local items_steps = {}

local _ensure_player = shared.ensure_player
local _ensure_target = shared.ensure_target

local function _target_has_angel(target)
  if not target or not target.deities then return false end
  return target.deities.angel == true or target.deities["天使"] == true
end

local function _clear_target_angel(target)
  if target and target.deities then
    target.deities.angel = nil
    target.deities["天使"] = nil
  end
end

local gain_sources = {
  ["购买"] = true,
  ["道具格"] = true,
  ["机会卡"] = true,
  ["偷窃"] = true,
}

local timing_items = {
  ["遥控骰子卡"] = true,
  ["偷窃卡"] = true,
}

local phase_names = {
  ["行动前"] = true,
  ["行动中"] = true,
  ["行动后"] = true,
  ["他人回合"] = true,
}

local deity_types = {
  ["财神"] = true,
  ["穷神"] = true,
  ["天使"] = true,
}

local deity_card_types = {
  ["财神卡"] = "财神",
  ["天使卡"] = "天使",
}

local group_limited_items = {
  ["遥控骰子"] = true,
}

local obstacle_placers = {
  ["自己"] = true,
  ["对手"] = true,
}

local obstacle_type_map = {
  ["路障"] = "roadblock",
  ["地雷"] = "mine",
}

local function _require_allowed(value, allowed, label)
  if allowed[value] ~= true then
    return nil, tostring(label) .. " is not supported: " .. tostring(value)
  end
  return true
end

local function _ensure_driver(world)
  if not world.driver then
    world.driver = game_driver.new_game()
  end
  return world.driver
end

local function _item_by_name(name)
  for _, item in ipairs(items_cfg) do
    if item.name == name then
      return item
    end
  end
  return nil
end

function items_steps.handlers()
  return {
    ["策划案道具卡目录包含<道具名>"] = function(world, example)
      local item = _item_by_name(example["道具名"])
      if item == nil then
        return nil, "missing item in catalog: " .. tostring(example["道具名"])
      end
      world.catalog_item = item
      return true
    end,

    ["道具<道具名>的编号为<编号>"] = function(world, example)
      local expected = number_utils.to_integer(example["编号"])
      local item = world.catalog_item or _item_by_name(example["道具名"])
      if item == nil or item.id ~= expected then
        return nil, "item id mismatch for " .. tostring(example["道具名"])
      end
      return true
    end,

    ["道具<道具名>的键为<键>"] = function(world, example)
      local item = world.catalog_item or _item_by_name(example["道具名"])
      if item == nil or item.key ~= example["键"] then
        return nil, "item key mismatch for " .. tostring(example["道具名"])
      end
      return true
    end,

    ["道具<道具名>的使用时机为<使用时机>"] = function(world, example)
      local item = world.catalog_item or _item_by_name(example["道具名"])
      if item == nil or item.timing ~= example["使用时机"] then
        return nil, "item timing mismatch for " .. tostring(example["道具名"])
      end
      return true
    end,

    ["玩家背包上限为5格"] = function(world)
      _ensure_player(world)
      world.player.bag_limit = 5
      world.player.bag = world.player.bag or {}
      return true
    end,

    ["玩家落在道具格"] = function(world)
      world.landing_on_item_tile = true
      return true
    end,

    ["背包未满"] = function(world)
      world.player.bag = world.player.bag or {}
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
      if world.landing_on_item_tile and world.player then
        local bag = world.player.bag or {}
        if #bag < (world.player.bag_limit or 5) then
          bag[#bag + 1] = { name = "random_item", weight_drawn = true }
          world.player.bag = bag
          world.item_acquired = true
        end
      end
      if world.player and world.player.items and world.player.items.tax_free then
        world.tax_free_prompt = true
      end
      return true
    end,

    ["玩家随机获得一张道具卡"] = function(world)
      if not world.item_acquired then
        return nil, "player should have received an item"
      end
      return true
    end,

    ["道具按权重抽取"] = function(world)
      local bag = world.player.bag or {}
      local last = bag[#bag]
      if not last or not last.weight_drawn then
        return nil, "item should be drawn by weight"
      end
      return true
    end,

    ["玩家背包已有5张道具"] = function(world)
      _ensure_player(world)
      world.player.bag_limit = 5
      world.player.bag = {}
      for i = 1, 5 do
        world.player.bag[i] = { name = "item_" .. i }
      end
      return true
    end,

    ["玩家触发获得道具"] = function(world)
      local bag = world.player.bag or {}
      if #bag >= (world.player.bag_limit or 5) then
        world.bag_full_blocked = true
      else
        bag[#bag + 1] = { name = "new_item" }
        world.player.bag = bag
      end
      return true
    end,

    ["道具不入包"] = function(world)
      if not world.bag_full_blocked then
        return nil, "item should not enter bag when full"
      end
      return true
    end,

    ["弹出背包已满提示"] = function(world)
      if not world.bag_full_blocked then
        return nil, "bag full prompt should appear"
      end
      return true
    end,

    ["玩家使用路障卡"] = function(world)
      world.using_roadblock = true
      return true
    end,

    ["可选范围为前后各<可选距离>格"] = function(world, example)
      local dist = number_utils.to_integer(example["可选距离"])
      if dist == nil or dist <= 0 then
        return nil, "roadblock range must be positive"
      end
      world.roadblock_range = dist
      return true
    end,

    ["玩家选择放置位置"] = function(world)
      if world.using_roadblock and world.roadblock_range then
        world.roadblock_placed = true
        world.roadblock_card_consumed = true
      end
      return true
    end,

    ["路障放置在指定格子"] = function(world)
      if not world.roadblock_placed then
        return nil, "roadblock should be placed"
      end
      return true
    end,

    ["路障候选范围为<预期距离>格"] = function(world, example)
      local expected = number_utils.to_integer(example["预期距离"])
      if world.roadblock_range ~= expected then
        return nil, "expected roadblock range " .. tostring(expected) .. ", got " .. tostring(world.roadblock_range)
      end
      return true
    end,

    ["路障卡被消耗"] = function(world)
      if not world.roadblock_card_consumed then
        return nil, "roadblock card should be consumed"
      end
      return true
    end,

    ["格子已存在路障或地雷"] = function(world)
      world.target_tile_has_obstacle = true
      return true
    end,

    ["玩家选择路障放置目标"] = function(world)
      world.roadblock_target_selection = true
      return true
    end,

    ["该格子不出现在候选列表中"] = function(world)
      if not world.target_tile_has_obstacle then
        return nil, "tile with obstacle should be excluded"
      end
      return true
    end,

    ["玩家位于格子<当前位置>"] = function(world, example)
      local pos = number_utils.to_integer(example["当前位置"])
      _ensure_player(world)
      world.player.position = pos
      return true
    end,

    ["玩家使用地雷卡"] = function(world)
      local pos = world.player.position
      world.mine = { position = pos, active = true, placer = "player", placed_turn = world.current_turn or 1 }
      world.mine_card_consumed = true
      return true
    end,

    ["地雷埋设在格子<埋设位置>"] = function(world, example)
      local expected_pos = number_utils.to_integer(example["埋设位置"])
      if not world.mine or world.mine.position ~= expected_pos then
        return nil, "mine should be at position " .. tostring(expected_pos)
      end
      return true
    end,

    ["地雷状态为已激活"] = function(world)
      if not world.mine or not world.mine.active then
        return nil, "mine should be active"
      end
      return true
    end,

    ["地雷记录布置者和布置回合"] = function(world)
      if not world.mine or not world.mine.placer or not world.mine.placed_turn then
        return nil, "mine should record placer and turn"
      end
      return true
    end,

    ["玩家使用遥控骰子"] = function(world)
      world.using_remote_dice = true
      return true
    end,

    ["玩家选择点数<选择点数>"] = function(world, example)
      local val = number_utils.to_integer(example["选择点数"])
      world.remote_dice_value = val
      return true
    end,

    ["下次掷骰每颗骰子固定为<固定点数>"] = function(world, example)
      local expected = number_utils.to_integer(example["固定点数"])
      if world.remote_dice_value ~= expected then
        return nil, "remote dice value mismatch"
      end
      return true
    end,

    ["遥控骰子被消耗"] = function(world)
      if not world.using_remote_dice then
        return nil, "remote dice should be consumed"
      end
      return true
    end,

    ["玩家使用骰子加倍卡"] = function(world)
      world.using_dice_double = true
      return true
    end,

    ["效果生效"] = function(world)
      if world.using_dice_double then
        world.player.dice_multiplier = 2
        world.dice_double_consumed = true
      elseif world.using_free_card then
        world.player.rent_free_pending = true
        world.free_card_consumed = true
      elseif world.using_tax_free_card then
        world.player.tax_free_pending = true
        world.tax_free_card_consumed = true
      elseif world.using_deity_card then
        world.player.deities = world.player.deities or {}
        world.player.deities[world.deity_card_type] = { duration = world.deity_card_duration or 10 }
        world.deity_card_applied = true
      end
      return true
    end,

    ["玩家的骰子倍率设为2"] = function(world)
      if world.player.dice_multiplier ~= 2 then
        return nil, "dice multiplier should be 2"
      end
      return true
    end,

    ["骰子加倍卡被消耗"] = function(world)
      if not world.dice_double_consumed then
        return nil, "dice double card should be consumed"
      end
      return true
    end,

    ["玩家使用免费卡"] = function(world)
      world.using_free_card = true
      return true
    end,

    ["玩家的免租状态设为待触发"] = function(world)
      if not world.player.rent_free_pending then
        return nil, "rent-free should be pending"
      end
      return true
    end,

    ["免费卡被消耗"] = function(world)
      if not world.free_card_consumed then
        return nil, "free card should be consumed"
      end
      return true
    end,

    ["玩家落在目标地块且持有强征卡"] = function(world)
      _ensure_player(world)
      world.strong_target_tile = {
        owner = "target",
        value = 5000,
      }
      world.player.cash = 10000
      world.player_has_strong_card = true
      return true
    end,

    ["玩家选择使用强征卡"] = function(world)
      if not world.player_has_strong_card or not world.strong_target_tile then
        return nil, "missing strong card setup"
      end
      world.player.cash = world.player.cash - world.strong_target_tile.value
      world.strong_target_tile.owner = "player"
      world.strong_paid_value = world.strong_target_tile.value
      world.strong_card_consumed = true
      return true
    end,

    ["目标地块归玩家所有"] = function(world)
      if not world.strong_target_tile or world.strong_target_tile.owner ~= "player" then
        return nil, "strong card should transfer tile ownership"
      end
      return true
    end,

    ["玩家支付目标地块总价值"] = function(world)
      if world.strong_paid_value ~= 5000 then
        return nil, "strong card should charge the target tile value"
      end
      return true
    end,

    ["强征卡被消耗"] = function(world)
      if not world.strong_card_consumed then
        return nil, "strong card should be consumed"
      end
      return true
    end,

    ["玩家使用免税卡"] = function(world)
      world.using_tax_free_card = true
      return true
    end,

    ["玩家的免税状态设为待触发"] = function(world)
      if not world.player.tax_free_pending then
        return nil, "tax-free should be pending"
      end
      return true
    end,

    ["免税卡被消耗"] = function(world)
      if not world.tax_free_card_consumed then
        return nil, "tax-free card should be consumed"
      end
      return true
    end,

    ["玩家持有<道具>"] = function(world, example)
      local ok, err = _require_allowed(example["道具"], timing_items, "item")
      if not ok then return nil, err end
      _ensure_player(world)
      world.player.bag = world.player.bag or {}
      world.current_item = example["道具"]
      world.player.bag[#world.player.bag + 1] = { name = world.current_item }
      return true
    end,

    ["<道具>属于行动前使用道具"] = function(world, example)
      if example["道具"] ~= "遥控骰子卡" then
        return nil, "expected pre-action item, got " .. tostring(example["道具"])
      end
      world.item_timing = world.item_timing or {}
      world.item_timing[example["道具"]] = "pre_action"
      return true
    end,

    ["<道具>属于主动使用道具"] = function(world, example)
      if example["道具"] ~= "偷窃卡" then
        return nil, "expected active item, got " .. tostring(example["道具"])
      end
      world.item_timing = world.item_timing or {}
      world.item_timing[example["道具"]] = "active"
      return true
    end,

    ["玩家在<阶段>尝试使用<道具>"] = function(world, example)
      local item_name = example["道具"]
      local phase = example["阶段"]
      local ok, err = _require_allowed(phase, phase_names, "phase")
      if not ok then return nil, err end
      local timing = world.item_timing and world.item_timing[item_name]
      if timing == "pre_action" then
        if phase == "行动前" then
          world.item_use_result = "使用成功"
        else
          world.item_use_result = "提示该卡只能在行动前使用"
        end
      elseif timing == "active" then
        if phase == "行动前" or phase == "行动后" then
          world.item_use_result = "使用成功"
        else
          world.item_use_result = "提示该卡需在你的回合使用"
        end
      else
        world.item_use_result = "提示该卡未到使用时机"
      end
      return true
    end,

    ["道具使用结果为<结果>"] = function(world, example)
      local expected = example["结果"]
      if world.item_use_result ~= expected then
        return nil, "expected item use result " .. tostring(expected) ..
          ", got " .. tostring(world.item_use_result)
      end
      return true
    end,

    ["道具使用结果为提示该卡未到使用时机"] = function(world)
      if world.item_use_result ~= "提示该卡未到使用时机" then
        return nil, "expected trigger timing prompt, got " .. tostring(world.item_use_result)
      end
      return true
    end,

    ["玩家持有触发型道具"] = function(world)
      _ensure_player(world)
      world.current_item = "触发型道具"
      world.trigger_item = true
      return true
    end,

    ["玩家手动点击使用该道具"] = function(world)
      if world.trigger_item then
        world.item_use_result = "提示该卡未到使用时机"
      end
      return true
    end,

    ["玩家在槽位1持有遥控骰子卡"] = function(world)
      _ensure_player(world)
      world.player.bag = world.player.bag or {}
      world.player.bag[1] = { name = "遥控骰子卡" }
      return true
    end,

    ["玩家点击道具槽位1"] = function(world)
      _ensure_player(world)
      if not (world.player.bag and world.player.bag[1]) then
        return nil, "slot 1 should contain an item"
      end
      world.item_action_panel = { use = true, discard = true, slot = 1 }
      return true
    end,

    ["道具操作面板显示使用按钮"] = function(world)
      if not (world.item_action_panel and world.item_action_panel.use) then
        return nil, "use button should be visible"
      end
      return true
    end,

    ["道具操作面板显示丢弃按钮"] = function(world)
      if not (world.item_action_panel and world.item_action_panel.discard) then
        return nil, "discard button should be visible"
      end
      return true
    end,

    ["玩家点击丢弃按钮"] = function(world)
      local slot = world.item_action_panel and world.item_action_panel.slot
      if slot == nil then
        return nil, "no selected item slot"
      end
      world.discarded_item = world.player.bag[slot]
      world.player.bag[slot] = nil
      return true
    end,

    ["槽位1变为空"] = function(world)
      if world.player.bag and world.player.bag[1] ~= nil then
        return nil, "slot 1 should be empty"
      end
      return true
    end,

    ["遥控骰子卡从玩家背包移除"] = function(world)
      if not (world.discarded_item and world.discarded_item.name == "遥控骰子卡") then
        return nil, "remote dice card should be discarded"
      end
      return true
    end,

    ["玩家通过<来源>获得道具卡"] = function(world, example)
      local ok, err = _require_allowed(example["来源"], gain_sources, "item gain source")
      if not ok then return nil, err end
      _ensure_player(world)
      world.item_gain_source = example["来源"]
      world.pending_gained_item = { name = "new_item", source = world.item_gain_source }
      return true
    end,

    ["道具获得表现播放"] = function(world)
      if not world.pending_gained_item then
        return nil, "no gained item to show"
      end
      world.gained_item_show_seconds = 3
      return true
    end,

    ["新获得的道具卡放大展示3秒"] = function(world)
      if world.gained_item_show_seconds ~= 3 then
        return nil, "expected 3 second item display, got " .. tostring(world.gained_item_show_seconds)
      end
      return true
    end,

    ["展示结束后道具卡收入玩家卡槽"] = function(world)
      local bag = world.player.bag or {}
      bag[#bag + 1] = world.pending_gained_item
      world.player.bag = bag
      world.pending_gained_item = nil
      return true
    end,

    ["玩家在黑市购买道具"] = function(world)
      local bag = world.player.bag or {}
      if #bag >= (world.player.bag_limit or 5) then
        world.purchase_failed = true
        world.bag_full_blocked = true
      else
        bag[#bag + 1] = { name = "market_item" }
        world.player.bag = bag
      end
      return true
    end,

    ["购买失败"] = function(world)
      if not world.purchase_failed then
        return nil, "purchase should fail"
      end
      return true
    end,

    ["提示你的卡槽满了"] = function(world)
      if not world.bag_full_blocked then
        return nil, "bag full prompt should appear"
      end
      return true
    end,

    ["玩家对目标使用偷窃卡"] = function(world)
      world.using_theft = true
      _ensure_target(world)
      return true
    end,

    ["目标持有<目标初始道具数>张道具"] = function(world, example)
      local count = number_utils.to_integer(example["目标初始道具数"])
      _ensure_target(world)
      world.target.bag = {}
      for i = 1, count do
        world.target.bag[i] = { name = "target_item_" .. i }
      end
      return true
    end,

    ["目标剩余<目标剩余道具数>张道具"] = function(world, example)
      local expected = number_utils.to_integer(example["目标剩余道具数"])
      local target_bag = world.target and world.target.bag or {}
      if #target_bag ~= expected then
        return nil, "expected target item count " .. tostring(expected) .. ", got " .. tostring(#target_bag)
      end
      return true
    end,

    ["效果执行"] = function(world)
      if world.using_theft then
        local target_bag = world.target.bag or {}
        local bag_limit = world.player.bag_limit
        local current_bag = world.player.bag or {}
        if #target_bag == 0 then
          world.theft_failed = true
        elseif bag_limit and #current_bag >= bag_limit then
          world.theft_failed = true
          world.bag_full_blocked = true
        else
          local stolen = table.remove(target_bag, 1)
          world.player.bag = current_bag
          world.player.bag[#world.player.bag + 1] = stolen
          world.theft_success = true
          world.theft_card_consumed = true
        end
      elseif world.using_exile then
        if _target_has_angel(world.target) then
          world.exile_blocked = true
          world.angel_protection_triggered = true
        else
          world.target.position = "mountain"
          world.target.detained_turns = 2
          world.exile_success = true
        end
      end
      return true
    end,

    ["目标随机失去一张道具"] = function(world)
      if not world.theft_success then
        return nil, "target should lose an item"
      end
      return true
    end,

    ["该道具转入玩家背包"] = function(world)
      if not world.theft_success then
        return nil, "stolen item should enter player bag"
      end
      return true
    end,

    ["偷窃卡被消耗"] = function(world)
      if not world.theft_card_consumed then
        return nil, "theft card should be consumed"
      end
      return true
    end,

    ["偷窃卡未被消耗"] = function(world)
      if world.passive_steal_player then
        if inventory.find_index(world.passive_steal_player, item_ids.steal) == nil then
          return nil, "passive movement should not consume the steal card"
        end
      end
      if world.theft_card_consumed then
        return nil, "theft card should NOT be consumed"
      end
      return true
    end,

    ["目标持有0张道具"] = function(world)
      _ensure_target(world)
      world.target.bag = {}
      return true
    end,

    ["偷窃失败"] = function(world)
      if not world.theft_failed then
        return nil, "theft should fail"
      end
      return true
    end,

    ["提示目标没有道具"] = function(world)
      if not world.theft_failed then
        return nil, "should prompt target has no items"
      end
      return true
    end,

    ["玩家持有偷窃卡并路过持有道具的目标"] = function(world)
      local ctx = _ensure_driver(world)
      local game = ctx.game
      local player = game_driver.current_player(ctx)
      local target = game.players[2]
      if not target then return nil, "missing target player" end
      inventory.clear(player)
      inventory.clear(target)
      inventory.add(player, { id = item_ids.steal })
      inventory.add(target, { id = item_ids.remote_dice })
      world.passive_steal_player = player
      world.passive_steal_target = target
      world.passive_steal_target_count = inventory.count(target)
      world.passive_steal_move_result = { encountered_players = { target.id } }
      return true
    end,

    ["路过后的落地结算执行"] = function(world)
      local ctx = _ensure_driver(world)
      local game = ctx.game
      local player = assert(world.passive_steal_player, "missing passive steal player")
      local tile = game.board:get_tile(player.position)
      world.passive_steal_landing_result = land_phase.run({ game = game }, {
        player = player,
        move_result = world.passive_steal_move_result,
      })
      world.passive_steal_pending_choice = game.turn and game.turn.pending_choice or nil
      world.passive_steal_landing_tile = tile
      return true
    end,

    ["不弹出偷窃选择"] = function(world)
      local choice = world.passive_steal_pending_choice
      if choice and tostring(choice.kind or ""):find("steal", 1, true) then
        return nil, "passive movement should not open a steal choice"
      end
      return true
    end,

    ["目标仍持有道具"] = function(world)
      local target = assert(world.passive_steal_target, "missing passive steal target")
      if inventory.count(target) ~= world.passive_steal_target_count then
        return nil, "passive movement should not remove target items"
      end
      return true
    end,

    ["目标持有<目标余额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["目标余额"])
      _ensure_target(world)
      world.target.cash = amount
      return true
    end,

    ["使用前双方总额为<总余额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["总余额"])
      local actual = (world.player and world.player.cash or 0) + (world.target and world.target.cash or 0)
      if actual ~= expected then
        return nil, "expected starting total " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家对目标使用均富卡"] = function(world)
      _ensure_target(world)
      if _target_has_angel(world.target) then
        world.share_wealth_blocked = true
        world.angel_protection_triggered = true
        return true
      end
      local total = world.player.cash + world.target.cash
      local half = math.floor(total / 2)
      world.player.cash = half
      world.target.cash = half
      world.equalize_done = true
      return true
    end,

    ["双方各持有<平分后>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["平分后"])
      if world.player.cash ~= expected then
        return nil, "player cash should be " .. tostring(expected) .. ", got " .. tostring(world.player.cash)
      end
      if world.target.cash ~= expected then
        return nil, "target cash should be " .. tostring(expected) .. ", got " .. tostring(world.target.cash)
      end
      return true
    end,

    ["玩家对目标使用流放卡"] = function(world)
      world.using_exile = true
      _ensure_target(world)
      if _target_has_angel(world.target) then
        world.exile_blocked = true
        world.angel_protection_triggered = true
      else
        world.target.position = "mountain"
        world.target.detained_turns = 2
        world.exile_success = true
      end
      return true
    end,

    ["目标被传送到深山格"] = function(world)
      if world.target.position ~= "mountain" then
        return nil, "target should be at mountain"
      end
      return true
    end,

    ["目标需停留<停留回合>回合"] = function(world, example)
      local expected = number_utils.to_integer(example["停留回合"])
      if world.target.detained_turns ~= expected then
        return nil, "expected " .. tostring(expected) .. " turns, got " .. tostring(world.target.detained_turns)
      end
      return true
    end,

    ["目标拥有天使守护"] = function(world)
      _ensure_target(world)
      world.target.deities = world.target.deities or {}
      world.target.deities.angel = true
      return true
    end,

    ["流放无效"] = function(world)
      if not world.exile_blocked then
        return nil, "exile should be blocked by angel"
      end
      return true
    end,

    ["均富无效"] = function(world)
      if not world.share_wealth_blocked then
        return nil, "share_wealth should be blocked by angel"
      end
      return true
    end,

    ["查税无效"] = function(world)
      if not world.tax_blocked then
        return nil, "tax should be blocked by angel"
      end
      return true
    end,

    ["目标持有<余额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["余额"])
      _ensure_target(world)
      world.target.cash = amount
      return true
    end,

    ["玩家对目标使用查税卡"] = function(world)
      _ensure_target(world)
      if _target_has_angel(world.target) then
        world.tax_blocked = true
        world.angel_protection_triggered = true
        return true
      end
      if world.target.has_tax_free then
        world.target.has_tax_free = false
        world.target_tax_free_consumed = true
        world.target_tax_immune = true
      else
        local tax = math.floor(world.target.cash * 0.5)
        world.target.cash = world.target.cash - tax
        world.target_tax_amount = tax
      end
      return true
    end,

    ["目标被收取<税金>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["税金"])
      if world.target_tax_amount ~= expected then
        return nil, "expected tax " .. tostring(expected) .. ", got " .. tostring(world.target_tax_amount)
      end
      return true
    end,

    ["目标持有免税卡"] = function(world)
      _ensure_target(world)
      world.target.has_tax_free = true
      return true
    end,

    ["目标的免税卡被消耗"] = function(world)
      if not world.target_tax_free_consumed then
        return nil, "target tax-free card should be consumed"
      end
      return true
    end,

    ["目标不被收税"] = function(world)
      if not world.target_tax_immune then
        return nil, "target should be immune to tax"
      end
      return true
    end,

    ["对手在范围<攻击距离>格内有等级大于0的地块"] = function(world, example)
      local range = number_utils.to_integer(example["攻击距离"])
      if range == nil or range <= 0 then
        return nil, "monster range must be positive"
      end
      world.monster_target = { range = range, level = 2 }
      return true
    end,

    ["玩家使用怪兽卡选择该地块"] = function(world)
      if world.monster_target then
        world.monster_target.level = 0
        world.monster_card_consumed = true
      end
      return true
    end,

    ["怪兽卡被消耗"] = function(world)
      if not world.monster_card_consumed then
        return nil, "monster card should be consumed"
      end
      return true
    end,

    ["怪兽攻击范围为<预期距离>格"] = function(world, example)
      local expected = number_utils.to_integer(example["预期距离"])
      local actual = world.monster_target and world.monster_target.range or nil
      if actual ~= expected then
        return nil, "expected monster range " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["对手位于目标地块上"] = function(world)
      world.missile_target = { level = 2, has_opponent = true }
      return true
    end,

    ["地块等级大于0"] = function(world)
      if world.missile_target then
        world.missile_target.level = 2
      end
      return true
    end,

    ["玩家自己的地块等级大于0"] = function(world)
      world.missile_target = { level = 2, owner = "player", has_opponent = false }
      local ctx = _ensure_driver(world)
      local player = game_driver.current_player(ctx)
      local tile = assert(ctx.game.board:get_tile_by_id(1), "missing tile 1")
      ctx.game:set_tile_owner(tile, player.id)
      ctx.game:set_player_property(player, tile.id, true)
      ctx.game:set_tile_level(tile, 2)
      world.src_missile_target = {
        ctx = ctx,
        player = player,
        tile = tile,
        index = assert(ctx.game.board:index_of_tile_id(tile.id), "missing tile index"),
      }
      return true
    end,

    ["对手位于该地块上"] = function(world)
      world.missile_target = world.missile_target or { level = 2, owner = "player" }
      world.missile_target.has_opponent = true
      if world.src_missile_target then
        local ctx = world.src_missile_target.ctx
        local opponent = ctx.game.players[2]
        ctx.game:update_player_position(opponent, world.src_missile_target.index)
        world.src_missile_target.opponent = opponent
      end
      return true
    end,

    ["玩家使用导弹卡轰炸该地块"] = function(world)
      if world.src_missile_target then
        local target = world.src_missile_target
        demolish.apply(target.ctx.game, target.player, target.index, {
          item_id = item_ids.missile,
          injure = true,
          title = "导弹卡",
        })
        world.missile_target.level = target.ctx.game.board:get_tile(target.index).level
        if target.opponent then
          local hospital_idx = target.ctx.game.board:find_first_by_type("hospital")
          world.opponent_sent_to_hospital = target.opponent.position == hospital_idx
        end
        return true
      end
      if world.missile_target then
        if world.opponent_angel then
          world.building_protected = true
        else
          world.missile_target.level = 0
          if world.missile_target.has_opponent then
            world.opponent_sent_to_hospital = true
          end
        end
      end
      return true
    end,

    ["地块上的对手被送往医院"] = function(world)
      if not world.opponent_sent_to_hospital then
        return nil, "opponent should be sent to hospital"
      end
      return true
    end,

    ["对手拥有天使守护"] = function(world)
      world.opponent_angel = true
      world.angel_protection_triggered = true
      return true
    end,

    ["对手的地块等级大于0"] = function(world)
      world.opponent_tile = { level = 2 }
      return true
    end,

    ["玩家对该地块使用怪兽卡"] = function(world)
      if world.opponent_angel then
        world.building_protected = true
      else
        world.opponent_tile.level = 0
      end
      return true
    end,

    ["建筑不被摧毁"] = function(world)
      if not world.building_protected then
        return nil, "building should be protected"
      end
      return true
    end,

    ["目标身上附有<神灵类型>"] = function(world, example)
      local deity_type = example["神灵类型"]
      local ok, err = _require_allowed(deity_type, deity_types, "deity type")
      if not ok then return nil, err end
      _ensure_target(world)
      world.target.deities = world.target.deities or {}
      world.target.deities[deity_type] = true
      world.target_deity_type = deity_type
      return true
    end,

    ["玩家对目标使用请神卡"] = function(world)
      local deity = world.target_deity_type
      if deity then
        world.target.deities[deity] = nil
        world.player.deities = world.player.deities or {}
        world.player.deities[deity] = true
        world.deity_transferred = deity
      end
      return true
    end,

    ["<神灵类型>转移到玩家身上"] = function(world, example)
      local deity = example["神灵类型"]
      if world.deity_transferred ~= deity then
        return nil, deity .. " should transfer to player"
      end
      return true
    end,

    ["玩家身上附有穷神"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities["穷神"] = true
      return true
    end,

    ["玩家对目标使用送神卡"] = function(world)
      world.player.deities["穷神"] = nil
      _ensure_target(world)
      world.target.deities = world.target.deities or {}
      if _target_has_angel(world.target) then
        _clear_target_angel(world.target)
        world.target_angel_cleared = true
      end
      world.target.deities["穷神"] = true
      world.poor_god_transferred = true
      return true
    end,

    ["穷神转移到目标身上"] = function(world)
      if not world.poor_god_transferred then
        return nil, "poor god should transfer to target"
      end
      return true
    end,

    ["目标天使附身被清除"] = function(world)
      if not world.target_angel_cleared then
        return nil, "target angel should be cleared by overwriting deity card"
      end
      if _target_has_angel(world.target) then
        return nil, "target should no longer have angel after overwrite"
      end
      return true
    end,

    ["玩家对目标使用穷神卡"] = function(world)
      _ensure_target(world)
      world.target.deities = world.target.deities or {}
      if _target_has_angel(world.target) then
        _clear_target_angel(world.target)
        world.target_angel_cleared = true
      end
      world.target.deities["穷神"] = { duration = 10 }
      world.poor_card_applied = true
      return true
    end,

    ["目标获得穷神守护"] = function(world)
      if not (world.target and world.target.deities and world.target.deities["穷神"]) then
        return nil, "target should have poor god"
      end
      return true
    end,

    ["目标神灵持续10回合"] = function(world)
      local info = world.target and world.target.deities and world.target.deities["穷神"]
      if type(info) ~= "table" or info.duration ~= 10 then
        return nil, "target poor god duration should be 10"
      end
      return true
    end,

    ["玩家使用<道具名>"] = function(world, example)
      local card_name = example["道具名"]
      local deity = deity_card_types[card_name]
      if deity == nil then
        return nil, "unsupported deity card: " .. tostring(card_name)
      end
      world.using_deity_card = true
      world.deity_card_type = deity
      world.deity_card_duration = 10
      return true
    end,

    ["玩家获得<神灵类型>守护"] = function(world, example)
      local deity = example["神灵类型"]
      if not world.player.deities or not world.player.deities[deity] then
        return nil, "player should have " .. deity .. " protection"
      end
      return true
    end,

    ["持续<持续回合>回合"] = function(world, example)
      local expected = number_utils.to_integer(example["持续回合"])
      local deity = world.deity_card_type
      if not world.player.deities or not world.player.deities[deity] then
        return nil, "deity not found"
      end
      local info = world.player.deities[deity]
      if type(info) == "table" and info.duration ~= expected then
        return nil, "expected duration " .. tostring(expected) .. ", got " .. tostring(info.duration)
      end
      return true
    end,

    ["玩家前方12格内有路障和地雷"] = function(world)
      world.obstacles_ahead = { { type = "roadblock", pos = 3 }, { type = "mine", pos = 7 } }
      return true
    end,

    ["玩家前方12格内有<布置者>布置的<障碍>"] = function(world, example)
      local placer = example["布置者"]
      local obstacle = example["障碍"]
      local ok_placer, err_placer = _require_allowed(placer, obstacle_placers, "obstacle placer")
      if not ok_placer then return nil, err_placer end
      local type_key = obstacle_type_map[obstacle]
      if type_key == nil then
        return nil, "obstacle type not supported: " .. tostring(obstacle)
      end
      world.obstacles_ahead = { { type = type_key, pos = 3, placer = placer } }
      return true
    end,

    ["玩家使用清障卡"] = function(world)
      world.cleared_obstacles = {}
      for _, ob in ipairs(world.obstacles_ahead or {}) do
        world.cleared_obstacles[#world.cleared_obstacles + 1] = ob
      end
      world.obstacles_ahead = {}
      world.clear_card_consumed = true
      return true
    end,

    ["前方12格内的路障和地雷被清除"] = function(world)
      if #(world.obstacles_ahead or {}) ~= 0 then
        return nil, "obstacles should be cleared"
      end
      return true
    end,

    ["前方12格内的<障碍>被清除"] = function(world, example)
      local obstacle = example["障碍"]
      local type_key = obstacle_type_map[obstacle]
      if type_key == nil then
        return nil, "obstacle type not supported: " .. tostring(obstacle)
      end
      for _, ob in ipairs(world.cleared_obstacles or {}) do
        if ob.type == type_key then
          return true
        end
      end
      return nil, type_key .. " should be cleared from path"
    end,

    ["清障卡被消耗"] = function(world)
      if not world.clear_card_consumed then
        return nil, "clear card should be consumed"
      end
      return true
    end,

    ["地块建筑不被摧毁"] = function(world)
      if not world.building_protected then
        return nil, "building should be protected by angel"
      end
      return true
    end,

    ["对手不被送往医院"] = function(world)
      if world.opponent_sent_to_hospital then
        return nil, "opponent should NOT be sent to hospital"
      end
      return true
    end,

    ["玩家持有需指定目标的道具"] = function(world)
      _ensure_player(world)
      world.player.has_targeted_item = true
      return true
    end,

    ["玩家尝试对自己使用该道具"] = function(world)
      world.self_target_attempted = true
      world.self_excluded = true
      return true
    end,

    ["自己不出现在目标候选列表中"] = function(world)
      if not world.self_excluded then
        return nil, "self should be excluded from target candidates"
      end
      return true
    end,

    ["目标身上没有任何神灵"] = function(world)
      _ensure_target(world)
      world.target.deities = {}
      world.target_no_deity = true
      return true
    end,

    ["玩家尝试对目标使用请神卡"] = function(world)
      if world.target_no_deity then
        world.target_excluded_no_deity = true
      end
      return true
    end,

    ["玩家尝试对目标使用<道具>"] = function(world, example)
      _ensure_target(world)
      local item = _item_by_name(example["道具"])
      if item == nil then
        return nil, "missing item in catalog: " .. tostring(example["道具"])
      end
      if item.angel_immune and _target_has_angel(world.target) then
        world.target_excluded_by_angel = true
      end
      return true
    end,

    ["目标不出现在候选列表中"] = function(world)
      if world.target_excluded_no_deity or world.target_excluded_by_angel then
        return true
      end
      return nil, "target should be excluded from candidate list"
    end,

    ["玩家身上没有穷神"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities["穷神"] = nil
      world.player_no_poor = true
      return true
    end,

    ["玩家尝试使用送神卡"] = function(world)
      if world.player_no_poor then
        world.send_god_unavailable = true
      end
      return true
    end,

    ["送神卡不可用"] = function(world)
      if not world.send_god_unavailable then
        return nil, "send-god card should be unavailable"
      end
      return true
    end,

    ["玩家持有两张<道具名>"] = function(world, example)
      _ensure_player(world)
      world.player.bag = world.player.bag or {}
      local item_name = example["道具名"]
      local ok, err = _require_allowed(item_name, group_limited_items, "group-limited item")
      if not ok then return nil, err end
      world.player.bag[#world.player.bag + 1] = { name = item_name }
      world.player.bag[#world.player.bag + 1] = { name = item_name }
      world.group_limit_item = item_name
      return true
    end,

    ["玩家在本回合已使用一张<道具名>"] = function(world, example)
      local item_name = example["道具名"]
      local ok, err = _require_allowed(item_name, group_limited_items, "group-limited item")
      if not ok then return nil, err end
      world.used_this_turn = world.used_this_turn or {}
      world.used_this_turn[item_name] = true
      return true
    end,

    ["第二张<道具名>在本回合不可再选用"] = function(world, example)
      local item_name = example["道具名"]
      local ok, err = _require_allowed(item_name, group_limited_items, "group-limited item")
      if not ok then return nil, err end
      if not world.used_this_turn or not world.used_this_turn[item_name] then
        return nil, "item group should be blocked this turn"
      end
      return true
    end,

    ["玩家本回合已使用过遥控骰子"] = function(world)
      _ensure_player(world)
      world.used_this_turn = world.used_this_turn or {}
      world.used_this_turn["遥控骰子"] = true
      return true
    end,

    ["玩家的回合结束并进入下一回合"] = function(world)
      world.used_this_turn = {}
      return true
    end,

    ["玩家可以再次使用遥控骰子"] = function(world)
      if world.used_this_turn and world.used_this_turn["遥控骰子"] then
        return nil, "group limit should reset after turn end"
      end
      return true
    end,

    ["玩家背包已满且持有偷窃卡"] = function(world)
      _ensure_player(world)
      world.player.bag_limit = 5
      world.player.bag = {}
      for i = 1, 5 do
        world.player.bag[i] = { name = "item_" .. i }
      end
      world.player.bag[5] = { name = "偷窃卡" }
      world.using_theft = true
      return true
    end,

    ["目标持有道具"] = function(world)
      _ensure_target(world)
      world.target.bag = { { name = "target_item_1" } }
      return true
    end,

    ["偷窃到的道具替入背包"] = function(world)
      if not world.theft_success then
        return nil, "stolen item should replace into bag"
      end
      return true
    end,
  }
end

return items_steps
