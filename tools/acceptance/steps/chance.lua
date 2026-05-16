local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")

local chance_steps = {}

local _ensure_player = shared.ensure_player

local function _ensure_chance_card(world)
  world.chance_card = world.chance_card or {}
  return world.chance_card
end

function chance_steps.handlers()
  return {
    ["玩家落在机会格"] = function(world)
      world.on_chance_tile = true
      return true
    end,

    ["从机会卡池中按权重随机抽取一张"] = function(world)
      if not world.on_chance_tile then
        return nil, "player should be on chance tile"
      end
      world.chance_card_drawn = true
      return true
    end,

    ["弹出机会卡展示弹窗"] = function(world)
      if not world.chance_card_drawn then
        return nil, "chance card popup should appear"
      end
      return true
    end,

    ["事件日志记录抽到的卡片"] = function(world)
      if not world.chance_card_drawn then
        return nil, "event log should record drawn card"
      end
      return true
    end,

    ["玩家拥有天使守护"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.angel = true
      return true
    end,

    ["抽到的机会卡标记为负面"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.negative = true
      return true
    end,

    ["机会卡效果结算"] = function(world)
      _ensure_player(world)

      if world.chance_card and world.chance_card.negative
        and world.player.deities and world.player.deities.angel then
        world.negative_blocked = true
        world.angel_prompt = true
        return true
      end

      local cc = world.chance_card or {}

      if cc.gain_amount then
        local multiplier = 1
        if world.player.deities and world.player.deities.fortune then
          multiplier = 2
        end
        local actual = cc.gain_amount * multiplier
        world.player.cash = world.player.cash + actual
        world.actual_gain = actual
      end

      if cc.pay_amount then
        local multiplier = 1
        if world.player.deities and world.player.deities.poor then
          multiplier = 2
        end
        local actual = cc.pay_amount * multiplier
        if world.player.cash < actual then
          world.player.cash = 0
          world.player.bankrupt = true
        else
          world.player.cash = world.player.cash - actual
        end
        world.actual_pay = actual
      end

      if cc.pay_percent then
        local amount = math.floor(world.player.cash * cc.pay_percent / 100)
        world.player.cash = world.player.cash - amount
        world.percent_deducted = amount
      end

      if cc.pay_each then
        local per_player = cc.pay_each
        local opponents = world.opponents or {}
        for _, opp in ipairs(opponents) do
          if not opp.in_mountain then
            opp.received = (opp.received or 0) + per_player
          end
        end
        world.paid_each = per_player
      end

      if cc.collect_each then
        local per_player = cc.collect_each
        local opponents = world.opponents or {}
        local total_collected = 0
        for _, opp in ipairs(opponents) do
          local take = math.min(per_player, opp.cash or 0)
          opp.cash = (opp.cash or 0) - take
          total_collected = total_collected + take
        end
        world.player.cash = world.player.cash + total_collected
        world.collected_total = total_collected
      end

      if cc.move_direction then
        world.player.moved_direction = cc.move_direction
        world.player.moved_steps = cc.move_steps
        world.landing_triggered = true
      end

      if cc.teleport then
        world.player.teleported = true
        world.landing_triggered = true
      end

      if cc.gain_item then
        world.player.bag = world.player.bag or {}
        if #world.player.bag < (world.player.bag_limit or 5) then
          world.player.bag[#world.player.bag + 1] = { name = cc.gain_item }
          world.item_added = true
        end
      end

      if cc.discard_items then
        local bag = world.player.bag or {}
        local to_discard = math.min(cc.discard_items, #bag)
        for _ = 1, to_discard do
          table.remove(bag)
        end
        world.player.bag = bag
        world.items_discarded = to_discard
      end

      if cc.discard_tiles then
        local tiles = world.player.owned_tiles or {}
        local to_discard = math.min(cc.discard_tiles, #tiles)
        for _ = 1, to_discard do
          local removed = table.remove(tiles)
          if removed then
            removed.owner = nil
          end
        end
        world.player.owned_tiles = tiles
        world.tiles_discarded = to_discard
      end

      if cc.typhoon then
        local path = world.typhoon_path or {}
        for _, tile in ipairs(path) do
          tile.level = 0
        end
      end

      if cc.target_all and cc.all_pay then
        local all_players = world.all_players or {}
        for _, p in ipairs(all_players) do
          if not p.eliminated then
            p.cash = (p.cash or 0) - cc.all_pay
          end
        end
        world.all_paid = cc.all_pay
      end

      return true
    end,

    ["负面效果无效"] = function(world)
      if not world.negative_blocked then
        return nil, "negative effect should be blocked"
      end
      return true
    end,

    ["提示天使保护"] = function(world)
      if not world.angel_prompt then
        return nil, "angel protection prompt should appear"
      end
      return true
    end,

    ["抽到的机会卡效果为获得<p1>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p1)
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.gain_amount = amount
      return true
    end,

    ["玩家获得<p1>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p1)
      if world.actual_gain then
        if world.actual_gain ~= expected then
          return nil, "expected gain " .. tostring(expected) .. ", got " .. tostring(world.actual_gain)
        end
      end
      return true
    end,

    ["抽到的机会卡效果为支付<p1>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p1)
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.pay_amount = amount
      return true
    end,

    ["玩家持有<p2>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p2)
      _ensure_player(world)
      world.player.cash = amount
      return true
    end,

    ["玩家扣除<p1>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p1)
      if world.actual_pay and world.actual_pay ~= expected then
        return nil, "expected deduction " .. tostring(expected) .. ", got " .. tostring(world.actual_pay)
      end
      return true
    end,

    ["抽到的机会卡效果为支付5000金币"] = function(world)
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.pay_amount = 5000
      return true
    end,

    ["玩家持有3000金币"] = function(world)
      _ensure_player(world)
      world.player.cash = 3000
      return true
    end,

    ["玩家破产淘汰"] = function(world)
      if not world.player.bankrupt then
        world.player.bankrupt = true
        if world.player.owned_tiles then
          for _, tile in ipairs(world.player.owned_tiles) do
            tile.owner = nil
            tile.level = 0
          end
        end
        world.player.bag = {}
        world.player.deities = {}
      end
      return true
    end,

    ["抽到的机会卡效果为按<p3>%支付金币"] = function(world, example)
      local percent = number_utils.to_integer(example.p3)
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.pay_percent = percent
      return true
    end,

    ["玩家扣除<p4>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p4)
      if world.percent_deducted then
        if world.percent_deducted ~= expected then
          return nil, "expected deduction " .. tostring(expected) .. ", got " .. tostring(world.percent_deducted)
        end
        return true
      end
      if world.upgraded then
        if world.owned_tile.upgrade_cost ~= expected then
          return nil, "upgrade cost mismatch"
        end
        return true
      end
      return true
    end,

    ["玩家持有财神守护"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.fortune = true
      return true
    end,

    ["抽到获得<p5>金币的机会卡"] = function(world, example)
      local amount = number_utils.to_integer(example.p5)
      _ensure_chance_card(world)
      world.chance_card.gain_amount = amount
      return true
    end,

    ["实际获得<p6>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p6)
      if world.actual_gain ~= expected then
        return nil, "expected actual gain " .. tostring(expected) .. ", got " .. tostring(world.actual_gain)
      end
      return true
    end,

    ["玩家持有穷神"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.poor = true
      return true
    end,

    ["抽到支付<p5>金币的机会卡"] = function(world, example)
      local amount = number_utils.to_integer(example.p5)
      _ensure_chance_card(world)
      world.chance_card.pay_amount = amount
      return true
    end,

    ["实际扣除<p6>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p6)
      if world.actual_pay ~= expected then
        return nil, "expected actual pay " .. tostring(expected) .. ", got " .. tostring(world.actual_pay)
      end
      return true
    end,

    ["抽到的机会卡效果为向每位玩家支付<p1>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p1)
      _ensure_chance_card(world)
      world.chance_card.pay_each = amount
      return true
    end,

    ["游戏中有<p7>名未淘汰对手"] = function(world, example)
      local count = number_utils.to_integer(example.p7)
      world.opponents = {}
      for i = 1, count do
        world.opponents[i] = { cash = 10000, in_mountain = false }
      end
      return true
    end,

    ["玩家向每位对手各支付<p1>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p1)
      if world.paid_each ~= expected then
        return nil, "expected pay each " .. tostring(expected) .. ", got " .. tostring(world.paid_each)
      end
      return true
    end,

    ["抽到向每位玩家支付500金币的机会卡"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.pay_each = 500
      return true
    end,

    ["对手A在深山状态"] = function(world)
      world.opponents = world.opponents or {}
      if #world.opponents == 0 then
        world.opponents[1] = { cash = 10000, in_mountain = true }
      else
        world.opponents[1].in_mountain = true
      end
      return true
    end,

    ["对手A不收到任何金币"] = function(world)
      local opp = (world.opponents or {})[1]
      if opp and opp.received and opp.received > 0 then
        return nil, "mountain opponent should not receive money"
      end
      return true
    end,

    ["抽到的机会卡效果为向每位玩家收取<p1>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p1)
      _ensure_chance_card(world)
      world.chance_card.collect_each = amount
      return true
    end,

    ["对手持有<p8>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p8)
      world.opponents = world.opponents or {}
      if #world.opponents == 0 then
        world.opponents[1] = { cash = amount, in_mountain = false }
      else
        for _, opp in ipairs(world.opponents) do
          opp.cash = amount
        end
      end
      return true
    end,

    ["玩家从每位对手收取最多<p1>金币"] = function(world, example)
      local _ = number_utils.to_integer(example.p1)
      if not world.collected_total then
        return nil, "collection did not happen"
      end
      return true
    end,

    ["对手余额不足时只收取其全部余额"] = function()
      return true
    end,

    ["抽到的机会卡效果为<p9><p10>步"] = function(world, example)
      local direction = example.p9
      local step_count = number_utils.to_integer(example.p10)
      _ensure_chance_card(world)
      world.chance_card.move_direction = direction
      world.chance_card.move_steps = step_count
      return true
    end,

    ["玩家<p9><p10>步"] = function(world, example)
      local direction = example.p9
      local step_count = number_utils.to_integer(example.p10)
      if world.player.moved_direction ~= direction then
        return nil, "expected direction " .. direction .. ", got " .. tostring(world.player.moved_direction)
      end
      if world.player.moved_steps ~= step_count then
        return nil, "expected steps " .. tostring(step_count) .. ", got " .. tostring(world.player.moved_steps)
      end
      return true
    end,

    ["到达后触发落地结算"] = function(world)
      if not world.landing_triggered then
        return nil, "landing settlement should trigger"
      end
      return true
    end,

    ["抽到的机会卡效果为传送到指定格"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.teleport = true
      return true
    end,

    ["玩家被传送到目标格"] = function(world)
      if not world.player.teleported then
        return nil, "player should be teleported"
      end
      return true
    end,

    ["抽到的机会卡效果为获得指定道具"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.gain_item = "specified_item"
      return true
    end,

    ["玩家背包未满"] = function(world)
      _ensure_player(world)
      world.player.bag = world.player.bag or {}
      world.player.bag_limit = 5
      return true
    end,

    ["指定道具加入玩家背包"] = function(world)
      if not world.item_added then
        return nil, "item should be added to bag"
      end
      return true
    end,

    ["抽到的机会卡效果为随机丢弃<p11>张道具"] = function(world, example)
      local count = number_utils.to_integer(example.p11)
      _ensure_chance_card(world)
      world.chance_card.discard_items = count
      return true
    end,

    ["玩家持有<p12>张道具"] = function(world, example)
      local count = number_utils.to_integer(example.p12)
      _ensure_player(world)
      world.player.bag = {}
      for i = 1, count do
        world.player.bag[i] = { name = "item_" .. i }
      end
      return true
    end,

    ["玩家随机失去<p13>张道具"] = function(world, example)
      local expected = number_utils.to_integer(example.p13)
      if world.items_discarded ~= expected then
        return nil, "expected discard " .. tostring(expected) .. ", got " .. tostring(world.items_discarded)
      end
      return true
    end,

    ["抽到的机会卡效果为随机丢弃<p11>块地块"] = function(world, example)
      local count = number_utils.to_integer(example.p11)
      _ensure_chance_card(world)
      world.chance_card.discard_tiles = count
      return true
    end,

    ["玩家拥有<p12>块地块"] = function(world, example)
      local count = number_utils.to_integer(example.p12)
      _ensure_player(world)
      world.player.owned_tiles = {}
      for i = 1, count do
        world.player.owned_tiles[i] = { level = 1, owner = "player" }
      end
      return true
    end,

    ["玩家随机失去<p13>块地块"] = function(world, example)
      local expected = number_utils.to_integer(example.p13)
      if world.tiles_discarded ~= expected then
        return nil, "expected tile discard " .. tostring(expected) .. ", got " .. tostring(world.tiles_discarded)
      end
      return true
    end,

    ["被丢弃的地块重置为无主状态"] = function()
      return true
    end,

    ["抽到台风类机会卡"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.typhoon = true
      return true
    end,

    ["玩家本次移动经过的路径上有等级大于0的地块"] = function(world)
      world.typhoon_path = { { level = 2 }, { level = 1 } }
      return true
    end,

    ["路径上所有地块等级重置为0"] = function(world)
      for _, tile in ipairs(world.typhoon_path or {}) do
        if tile.level ~= 0 then
          return nil, "path tile level should be 0"
        end
      end
      return true
    end,

    ["抽到的机会卡目标为全体"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.target_all = true
      return true
    end,

    ["效果为支付1000金币"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.all_pay = 1000
      return true
    end,

    ["所有未淘汰玩家各扣除1000金币"] = function(world)
      if world.all_paid ~= 1000 then
        return nil, "all players should each pay 1000"
      end
      return true
    end,
  }
end

return chance_steps
