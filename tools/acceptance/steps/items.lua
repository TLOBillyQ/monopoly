local number_utils = require("src.foundation.number")

local items_steps = {}

function items_steps.handlers()
  return {
    ["玩家背包上限为5格"] = function(world)
      if not world.player then
        world.player = { cash = 0, tiles = {}, items = {}, deities = {} }
      end
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
      if not world.player then
        world.player = { cash = 0, tiles = {}, items = {}, deities = {} }
      end
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

    ["可选范围为前后各<p1>格"] = function(world, example)
      local dist = number_utils.to_integer(example.p1)
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

    ["玩家位于格子<p2>"] = function(world, example)
      local pos = number_utils.to_integer(example.p2)
      if not world.player then
        world.player = { cash = 0, tiles = {}, items = {}, deities = {} }
      end
      world.player.position = pos
      return true
    end,

    ["玩家使用地雷卡"] = function(world)
      local pos = world.player.position
      world.mine = { position = pos, active = true, placer = "player", placed_turn = world.current_turn or 1 }
      world.mine_card_consumed = true
      return true
    end,

    ["地雷埋设在格子<p2>"] = function(world, example)
      local expected_pos = number_utils.to_integer(example.p2)
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

    ["玩家选择点数<p3>"] = function(world, example)
      local val = number_utils.to_integer(example.p3)
      world.remote_dice_value = val
      return true
    end,

    ["下次掷骰每颗骰子固定为<p3>"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
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

    ["玩家对目标使用偷窃卡"] = function(world)
      world.using_theft = true
      world.target = world.target or { bag = {}, deities = {} }
      return true
    end,

    ["目标持有<p4>张道具"] = function(world, example)
      local count = number_utils.to_integer(example.p4)
      world.target = world.target or { bag = {}, deities = {} }
      world.target.bag = {}
      for i = 1, count do
        world.target.bag[i] = { name = "target_item_" .. i }
      end
      return true
    end,

    ["效果执行"] = function(world)
      if world.using_theft then
        local target_bag = world.target.bag or {}
        if #target_bag > 0 then
          local stolen = table.remove(target_bag, 1)
          world.player.bag = world.player.bag or {}
          world.player.bag[#world.player.bag + 1] = stolen
          world.theft_success = true
        else
          world.theft_failed = true
        end
      elseif world.using_exile then
        if world.target.deities and world.target.deities.angel then
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
      if not world.using_theft then
        return nil, "theft card should be consumed"
      end
      return true
    end,

    ["目标持有0张道具"] = function(world)
      world.target = world.target or { bag = {}, deities = {} }
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

    ["玩家持有<p5>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p5)
      if not world.player then
        world.player = { cash = 0, tiles = {}, items = {}, deities = {} }
      end
      world.player.cash = amount
      return true
    end,

    ["目标持有<p6>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p6)
      world.target = world.target or { bag = {}, deities = {} }
      world.target.cash = amount
      return true
    end,

    ["玩家对目标使用均富卡"] = function(world)
      local total = world.player.cash + world.target.cash
      local half = math.floor(total / 2)
      world.player.cash = half
      world.target.cash = half
      world.equalize_done = true
      return true
    end,

    ["双方各持有<p7>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p7)
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
      world.target = world.target or { bag = {}, deities = {} }
      if world.target.deities and world.target.deities.angel then
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

    ["目标需停留<p8>回合"] = function(world, example)
      local expected = number_utils.to_integer(example.p8)
      if world.target.detained_turns ~= expected then
        return nil, "expected " .. tostring(expected) .. " turns, got " .. tostring(world.target.detained_turns)
      end
      return true
    end,

    ["目标拥有天使守护"] = function(world)
      world.target = world.target or { bag = {}, deities = {} }
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

    ["天使守护抵消提示"] = function(world)
      if not world.angel_protection_triggered then
        return nil, "angel protection prompt should appear"
      end
      return true
    end,

    ["目标持有<p9>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p9)
      world.target = world.target or { bag = {}, deities = {} }
      world.target.cash = amount
      return true
    end,

    ["玩家对目标使用查税卡"] = function(world)
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

    ["目标被收取<p10>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p10)
      if world.target_tax_amount ~= expected then
        return nil, "expected tax " .. tostring(expected) .. ", got " .. tostring(world.target_tax_amount)
      end
      return true
    end,

    ["目标持有免税卡"] = function(world)
      world.target = world.target or { bag = {}, deities = {} }
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

    ["对手在范围<p1>格内有等级大于0的地块"] = function(world, example)
      local range = number_utils.to_integer(example.p1)
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

    ["地块等级重置为0"] = function(world)
      if world.monster_target then
        if world.monster_target.level ~= 0 then
          return nil, "tile level should be 0"
        end
      elseif world.missile_target then
        if world.missile_target.level ~= 0 then
          return nil, "tile level should be 0"
        end
      elseif world.typhoon_path then
        for _, tile in ipairs(world.typhoon_path) do
          if tile.level ~= 0 then
            return nil, "path tile level should be 0"
          end
        end
      end
      return true
    end,

    ["怪兽卡被消耗"] = function(world)
      if not world.monster_card_consumed then
        return nil, "monster card should be consumed"
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

    ["玩家使用导弹卡轰炸该地块"] = function(world)
      if world.missile_target then
        world.missile_target.level = 0
        if world.missile_target.has_opponent then
          world.opponent_sent_to_hospital = true
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

    ["目标身上附有<p11>"] = function(world, example)
      local deity_type = example.p11
      world.target = world.target or { bag = {}, deities = {} }
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

    ["<p11>转移到玩家身上"] = function(world, example)
      local deity = example.p11
      if world.deity_transferred ~= deity then
        return nil, deity .. " should transfer to player"
      end
      return true
    end,

    ["玩家身上附有穷神"] = function(world)
      if not world.player then
        world.player = { cash = 0, tiles = {}, items = {}, deities = {} }
      end
      world.player.deities = world.player.deities or {}
      world.player.deities["穷神"] = true
      return true
    end,

    ["玩家对目标使用送神卡"] = function(world)
      world.player.deities["穷神"] = nil
      world.target = world.target or { bag = {}, deities = {} }
      world.target.deities = world.target.deities or {}
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

    ["玩家使用<p12>"] = function(world, example)
      local card_name = example.p12
      world.using_deity_card = true
      if card_name == "财神卡" then
        world.deity_card_type = "财神"
      elseif card_name == "天使卡" then
        world.deity_card_type = "天使"
      end
      world.deity_card_duration = 10
      return true
    end,

    ["玩家获得<p11>守护"] = function(world, example)
      local deity = example.p11
      if not world.player.deities or not world.player.deities[deity] then
        return nil, "player should have " .. deity .. " protection"
      end
      return true
    end,

    ["持续<p13>回合"] = function(world, example)
      local expected = number_utils.to_integer(example.p13)
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

    ["玩家使用清障卡"] = function(world)
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

    ["清障卡被消耗"] = function(world)
      if not world.clear_card_consumed then
        return nil, "clear card should be consumed"
      end
      return true
    end,
  }
end

return items_steps
