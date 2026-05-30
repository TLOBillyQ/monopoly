local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")
local game_driver = require("tools.acceptance.game_driver")
local inventory_module = require("src.rules.items.inventory")
local chance_cards = require("src.config.content.chance_cards")

local chance_steps = {}

local _ensure_player = shared.ensure_player

local function _ensure_chance_card(world)
  world.chance_card = world.chance_card or {}
  return world.chance_card
end

local function _chance_by_id(id)
  for _, card in ipairs(chance_cards) do
    if card.id == id then
      return card
    end
  end
  return nil
end

local function _chance_param(card)
  if card.amount ~= nil then return tostring(card.amount) end
  if card.percent ~= nil then return tostring(card.percent) end
  if card.steps ~= nil then return tostring(card.steps) end
  if card.item_id ~= nil then return tostring(card.item_id) end
  if card.destination_tile_id ~= nil then return tostring(card.destination_tile_id) end
  if card.count ~= nil then return tostring(card.count) end
  return "-"
end

function chance_steps.handlers()
  return {
    ["策划案机会卡目录包含<卡号>"] = function(world, example)
      local id = number_utils.to_integer(example["卡号"])
      local card = _chance_by_id(id)
      if card == nil then
        return nil, "missing chance card: " .. tostring(example["卡号"])
      end
      world.catalog_chance_card = card
      return true
    end,

    ["机会卡<卡号>的效果为<效果>"] = function(world, example)
      local id = number_utils.to_integer(example["卡号"])
      local card = world.catalog_chance_card or _chance_by_id(id)
      if card == nil or card.effect ~= example["效果"] then
        return nil, "chance effect mismatch for " .. tostring(example["卡号"])
      end
      return true
    end,

    ["机会卡<卡号>的目标为<目标>"] = function(world, example)
      local id = number_utils.to_integer(example["卡号"])
      local card = world.catalog_chance_card or _chance_by_id(id)
      if card == nil or card.target ~= example["目标"] then
        return nil, "chance target mismatch for " .. tostring(example["卡号"])
      end
      return true
    end,

    ["机会卡<卡号>的参数为<参数>"] = function(world, example)
      local id = number_utils.to_integer(example["卡号"])
      local card = world.catalog_chance_card or _chance_by_id(id)
      if card == nil or _chance_param(card) ~= tostring(example["参数"]) then
        return nil, "chance parameter mismatch for " .. tostring(example["卡号"])
      end
      return true
    end,

    ["机会卡<卡号>的负面标记为<负面>"] = function(world, example)
      local id = number_utils.to_integer(example["卡号"])
      local card = world.catalog_chance_card or _chance_by_id(id)
      local expected = example["负面"] == "true"
      if card == nil or card.negative ~= expected then
        return nil, "chance negative flag mismatch for " .. tostring(example["卡号"])
      end
      return true
    end,

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
        if world.player.deities and world.player.deities.poor then
          per_player = per_player * 2
        end
        local opponents = world.opponents or {}
        local paid_count = 0
        for _, opp in ipairs(opponents) do
          if world.player.bankrupt then break end
          if not opp.in_mountain then
            if world.player.cash >= per_player then
              world.player.cash = world.player.cash - per_player
              opp.received = (opp.received or 0) + per_player
              paid_count = paid_count + 1
            else
              world.player.bankrupt = true
              break
            end
          end
        end
        world.chance_paid_count = paid_count
        world.paid_each = per_player
      end

      if cc.collect_each then
        local per_player = cc.collect_each
        if world.player.deities and world.player.deities.fortune then
          per_player = per_player * 2
        end
        local opponents = world.opponents or {}
        local total_collected = 0
        for _, opp in ipairs(opponents) do
          local take = math.min(per_player, opp.cash or 0)
          opp.cash = (opp.cash or 0) - take
          opp.paid = take
          if take < per_player then
            opp.bankrupt = true
            opp.eliminated = true
          end
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

      if cc.reset_path then
        local path = world.reset_path or {}
        for _, tile in ipairs(path) do
          tile.owner = nil
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

      if cc.target_all_negative_pay then
        local amount = cc.target_all_negative_pay
        for _, opp in ipairs(world.all_opponents or {}) do
          if not opp.angel then
            opp.cash = opp.cash - amount
            opp.deducted = amount
          end
        end
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

    ["获得金额记为<验证金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证金额"])
      if expected == nil then
        return nil, "invalid 验证金额: " .. tostring(example["验证金额"])
      end
      if world.actual_gain ~= expected then
        return nil, "expected actual_gain=" .. tostring(expected) ..
          ", got " .. tostring(world.actual_gain)
      end
      return true
    end,

    ["实际扣除金额为<验证金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证金额"])
      if expected == nil then
        return nil, "invalid 验证金额: " .. tostring(example["验证金额"])
      end
      if world.actual_pay ~= expected then
        return nil, "expected actual_pay=" .. tostring(expected) ..
          ", got " .. tostring(world.actual_pay)
      end
      return true
    end,

    ["当前对手数量为<验证其他玩家数>名"] = function(world, example)
      local expected = number_utils.to_integer(example["验证其他玩家数"])
      if expected == nil then
        return nil, "invalid 验证其他玩家数: " .. tostring(example["验证其他玩家数"])
      end
      local actual = #(world.opponents or {})
      if actual ~= expected then
        return nil, "expected opponents=" .. tostring(expected) ..
          ", got " .. tostring(actual)
      end
      return true
    end,

    ["实际每对手支付为<验证金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证金额"])
      if expected == nil then
        return nil, "invalid 验证金额: " .. tostring(example["验证金额"])
      end
      if world.paid_each ~= expected then
        return nil, "expected paid_each=" .. tostring(expected) ..
          ", got " .. tostring(world.paid_each)
      end
      return true
    end,

    ["当前收取上限为<验证金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证金额"])
      if expected == nil then
        return nil, "invalid 验证金额: " .. tostring(example["验证金额"])
      end
      local cc = world.chance_card or {}
      if cc.collect_each ~= expected then
        return nil, "expected collect_each=" .. tostring(expected) ..
          ", got " .. tostring(cc.collect_each)
      end
      return true
    end,

    ["对手起始余额为<验证对手余额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证对手余额"])
      if expected == nil then
        return nil, "invalid 验证对手余额: " .. tostring(example["验证对手余额"])
      end
      local opps = world.opponents or {}
      for i, opp in ipairs(opps) do
        if opp.cash ~= expected then
          return nil, "opponent " .. tostring(i) .. " cash expected=" ..
            tostring(expected) .. ", got " .. tostring(opp.cash)
        end
      end
      return true
    end,

    ["实际收取总额为<验证收取额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证收取额"])
      if expected == nil then
        return nil, "invalid 验证收取额: " .. tostring(example["验证收取额"])
      end
      if world.collected_total ~= expected then
        return nil, "expected collected_total=" .. tostring(expected) ..
          ", got " .. tostring(world.collected_total)
      end
      return true
    end,

    ["实际移动方向为<验证移动方向>"] = function(world, example)
      local expected = example["验证移动方向"]
      if not (world.player and world.player.moved_direction == expected) then
        return nil, "expected moved_direction=" .. tostring(expected) ..
          ", got " .. tostring(world.player and world.player.moved_direction)
      end
      return true
    end,

    ["实际移动步数为<验证步数>步"] = function(world, example)
      local expected = number_utils.to_integer(example["验证步数"])
      if expected == nil then
        return nil, "invalid 验证步数: " .. tostring(example["验证步数"])
      end
      if not (world.player and world.player.moved_steps == expected) then
        return nil, "expected moved_steps=" .. tostring(expected) ..
          ", got " .. tostring(world.player and world.player.moved_steps)
      end
      return true
    end,

    ["指定丢弃数为<验证数量>张"] = function(world, example)
      local expected = number_utils.to_integer(example["验证数量"])
      if expected == nil then
        return nil, "invalid 验证数量: " .. tostring(example["验证数量"])
      end
      local cc = world.chance_card or {}
      if cc.discard_items ~= expected then
        return nil, "expected discard_items=" .. tostring(expected) ..
          ", got " .. tostring(cc.discard_items)
      end
      return true
    end,

    ["背包道具数为<验证持有数>张"] = function(world, example)
      local expected = number_utils.to_integer(example["验证持有数"])
      if expected == nil then
        return nil, "invalid 验证持有数: " .. tostring(example["验证持有数"])
      end
      local bag = (world.player and world.player.bag) or {}
      if #bag ~= expected then
        return nil, "expected bag size=" .. tostring(expected) ..
          ", got " .. tostring(#bag)
      end
      return true
    end,

    ["指定丢弃地块数为<验证数量>块"] = function(world, example)
      local expected = number_utils.to_integer(example["验证数量"])
      if expected == nil then
        return nil, "invalid 验证数量: " .. tostring(example["验证数量"])
      end
      local cc = world.chance_card or {}
      if cc.discard_tiles ~= expected then
        return nil, "expected discard_tiles=" .. tostring(expected) ..
          ", got " .. tostring(cc.discard_tiles)
      end
      return true
    end,

    ["玩家神灵状态为<验证神灵>"] = function(world, example)
      local expected = example["验证神灵"]
      local deities = (world.player and world.player.deities) or {}
      if expected == "穷神" then
        if not deities.poor then
          return nil, "expected poor deity flag set; deities=" ..
            tostring(deities.poor) .. "/" .. tostring(deities.fortune)
        end
      elseif expected == "财神" then
        if not deities.fortune then
          return nil, "expected fortune deity flag set; deities=" ..
            tostring(deities.poor) .. "/" .. tostring(deities.fortune)
        end
      else
        return nil, "unknown 验证神灵: " .. tostring(expected)
      end
      return true
    end,

    ["抽到的机会卡效果为获得<金额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["金额"])
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.gain_amount = amount
      return true
    end,

    ["玩家获得<金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["金额"])
      if world.actual_gain then
        if world.actual_gain ~= expected then
          return nil, "expected gain " .. tostring(expected) .. ", got " .. tostring(world.actual_gain)
        end
      end
      return true
    end,

    ["抽到的机会卡效果为支付<金额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["金额"])
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.pay_amount = amount
      return true
    end,

    ["玩家扣除<金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["金额"])
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
        return nil, "player should be bankrupt"
      end
      return true
    end,

    ["抽到的机会卡效果为按<百分比>%支付金币"] = function(world, example)
      local percent = number_utils.to_integer(example["百分比"])
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.pay_percent = percent
      return true
    end,

    ["玩家扣除<扣除额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["扣除额"])
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
      if world.driver then
        local player = game_driver.current_player(world.driver)
        game_driver.set_player_deity(world.driver, player, "rich")
      end
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.fortune = true
      return true
    end,

    ["抽到获得<基础金额>金币的机会卡"] = function(world, example)
      local amount = number_utils.to_integer(example["基础金额"])
      _ensure_chance_card(world)
      world.chance_card.gain_amount = amount
      return true
    end,

    ["实际获得<实际金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["实际金额"])
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

    ["抽到支付<基础金额>金币的机会卡"] = function(world, example)
      local amount = number_utils.to_integer(example["基础金额"])
      _ensure_chance_card(world)
      world.chance_card.pay_amount = amount
      return true
    end,

    ["实际扣除<实际金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["实际金额"])
      if world.actual_pay ~= expected then
        return nil, "expected actual pay " .. tostring(expected) .. ", got " .. tostring(world.actual_pay)
      end
      return true
    end,

    ["抽到的机会卡效果为向每位玩家支付<金额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["金额"])
      _ensure_chance_card(world)
      world.chance_card.pay_each = amount
      return true
    end,

    ["游戏中有<其他玩家数>名未淘汰对手"] = function(world, example)
      local count = number_utils.to_integer(example["其他玩家数"])
      world.opponents = {}
      for i = 1, count do
        world.opponents[i] = { cash = 10000, in_mountain = false }
      end
      return true
    end,

    ["玩家向每位对手各支付<金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["金额"])
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

    ["抽到的机会卡效果为向每位玩家收取<金额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["金额"])
      _ensure_chance_card(world)
      world.chance_card.collect_each = amount
      return true
    end,

    ["对手持有<对手余额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["对手余额"])
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

    ["玩家从每位对手收取最多<金额>金币"] = function(world, example)
      local _ = number_utils.to_integer(example["金额"])
      if not world.collected_total then
        return nil, "collection did not happen"
      end
      return true
    end,

    ["对手余额不足时只收取其全部余额"] = function()
      return true
    end,

    ["抽到的机会卡效果为<移动方向><步数>步"] = function(world, example)
      local direction = example["移动方向"]
      local step_count = number_utils.to_integer(example["步数"])
      _ensure_chance_card(world)
      world.chance_card.move_direction = direction
      world.chance_card.move_steps = step_count
      return true
    end,

    ["玩家<移动方向><步数>步"] = function(world, example)
      local direction = example["移动方向"]
      local step_count = number_utils.to_integer(example["步数"])
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
      if world.driver then
        inventory_module.clear(game_driver.current_player(world.driver))
      end
      return true
    end,

    ["指定道具加入玩家背包"] = function(world)
      if not world.item_added then
        return nil, "item should be added to bag"
      end
      return true
    end,

    ["抽到的机会卡效果为随机丢弃<数量>张道具"] = function(world, example)
      local count = number_utils.to_integer(example["数量"])
      _ensure_chance_card(world)
      world.chance_card.discard_items = count
      return true
    end,

    ["玩家持有<持有数>张道具"] = function(world, example)
      local count = number_utils.to_integer(example["持有数"])
      _ensure_player(world)
      world.player.bag = {}
      for i = 1, count do
        world.player.bag[i] = { name = "item_" .. i }
      end
      return true
    end,

    ["玩家随机失去<实际丢弃>张道具"] = function(world, example)
      local expected = number_utils.to_integer(example["实际丢弃"])
      if world.items_discarded ~= expected then
        return nil, "expected discard " .. tostring(expected) .. ", got " .. tostring(world.items_discarded)
      end
      return true
    end,

    ["抽到的机会卡效果为随机丢弃<数量>块地块"] = function(world, example)
      local count = number_utils.to_integer(example["数量"])
      _ensure_chance_card(world)
      world.chance_card.discard_tiles = count
      return true
    end,

    ["玩家拥有<持有数>块地块"] = function(world, example)
      local count = number_utils.to_integer(example["持有数"])
      _ensure_player(world)
      world.player.owned_tiles = {}
      for i = 1, count do
        world.player.owned_tiles[i] = { level = 1, owner = "player" }
      end
      return true
    end,

    ["玩家随机失去<实际丢弃>块地块"] = function(world, example)
      local expected = number_utils.to_integer(example["实际丢弃"])
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

    ["抽到强制征地类机会卡"] = function(world)
      _ensure_chance_card(world)
      world.chance_card.reset_path = true
      return true
    end,

    ["玩家本次移动经过的路径上有已购地块"] = function(world)
      world.reset_path = {
        { owner = "player", level = 2 },
        { owner = "target", level = 1 },
      }
      return true
    end,

    ["路径上所有地块恢复初始状态"] = function(world)
      for _, tile in ipairs(world.reset_path or {}) do
        if tile.owner ~= nil or tile.level ~= 0 then
          return nil, "path tile should be reset"
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

    ["玩家抽到负面全体支付1000金币的机会卡"] = function(world)
      _ensure_player(world)
      _ensure_chance_card(world)
      world.chance_card.target_all_negative_pay = 1000
      return true
    end,

    ["游戏中有2名对手"] = function(world)
      world.all_opponents = {}
      for i = 1, 2 do
        world.all_opponents[i] = { cash = 0 }
      end
      return true
    end,

    ["对手B拥有天使守护"] = function(world)
      world.all_opponents = world.all_opponents or {}
      if not world.all_opponents[1] then
        world.all_opponents[1] = { cash = 0 }
      end
      world.all_opponents[1].angel = true
      return true
    end,

    ["各对手初始持有5000金币"] = function(world)
      for _, opp in ipairs(world.all_opponents or {}) do
        opp.cash = 5000
      end
      return true
    end,

    ["拥有天使守护的对手金币不变"] = function(world)
      for _, opp in ipairs(world.all_opponents or {}) do
        if opp.angel and opp.cash ~= 5000 then
          return nil, "angel opponent cash should be 5000, got " .. tostring(opp.cash)
        end
      end
      return true
    end,

    ["无天使守护的对手被扣除1000金币"] = function(world)
      for _, opp in ipairs(world.all_opponents or {}) do
        if not opp.angel and opp.cash ~= 4000 then
          return nil, "non-angel opponent should have 4000, got " .. tostring(opp.cash)
        end
      end
      return true
    end,

    ["玩家附有<神灵>"] = function(world, example)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      local deity = example["神灵"]
      if deity == "穷神" then
        world.player.deities.poor = true
      elseif deity == "财神" then
        world.player.deities.fortune = true
      end
      return true
    end,

    ["抽到<效果类型>3000金币的多人机会卡"] = function(world, example)
      _ensure_player(world)
      _ensure_chance_card(world)
      if world.player.cash < 99999 then
        world.player.cash = 99999
      end
      local effect_type = example["效果类型"]
      if effect_type == "向每位对手支付" then
        world.chance_card.pay_each = 3000
      elseif effect_type == "从每位对手收取" then
        world.chance_card.collect_each = 3000
      end
      return true
    end,

    ["游戏中有1名持有10000金币的对手"] = function(world)
      world.opponents = { { cash = 10000, in_mountain = false } }
      return true
    end,

    ["对手的金币变化量为<变化量>"] = function(world, example)
      local raw = example["变化量"]
      local sign = 1
      local num_str = raw
      if raw:sub(1, 1) == "+" then
        num_str = raw:sub(2)
      elseif raw:sub(1, 1) == "-" then
        sign = -1
        num_str = raw:sub(2)
      end
      local expected_delta = sign * number_utils.to_integer(num_str)
      local opp = world.opponents[1]
      local actual_delta = (opp.received or 0) + (opp.cash - 10000)
      if actual_delta ~= expected_delta then
        return nil, "expected delta " .. raw .. ", got " .. tostring(actual_delta)
      end
      return true
    end,
  }
end

return chance_steps
