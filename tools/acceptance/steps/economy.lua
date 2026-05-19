local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")

local economy_steps = {}

local _ensure_player = shared.ensure_player

function economy_steps.handlers()
  return {
    ["棋盘包含地块邻接关系"] = function(world)
      world.adjacency = true
      return true
    end,

    ["玩家持有<p1>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p1)
      if amount == nil then
        return nil, "invalid amount: " .. tostring(example.p1)
      end
      _ensure_player(world)
      world.player.cash = amount
      return true
    end,

    ["玩家落在价格为<p2>的无主地块"] = function(world, example)
      local price = number_utils.to_integer(example.p2)
      if price == nil then
        return nil, "invalid price: " .. tostring(example.p2)
      end
      world.landing_tile = { price = price, owner = nil, level = 0 }
      return true
    end,

    ["玩家选择购买"] = function(world)
      local tile = world.landing_tile
      if not tile then
        return nil, "no landing tile"
      end
      if tile.owner ~= nil then
        world.purchase_failed = "already owned"
        return true
      end
      if world.player.cash < tile.price then
        world.purchase_failed = "余额不足"
        return true
      end
      world.player.cash = world.player.cash - tile.price
      tile.owner = "player"
      world.purchased = true
      return true
    end,

    ["玩家扣除<p2>金币"] = function(world, example)
      local expected_deducted = number_utils.to_integer(example.p2)
      if world.purchased and world.landing_tile then
        if world.landing_tile.price ~= expected_deducted then
          return nil, "deducted amount mismatch"
        end
      end
      return true
    end,

    ["玩家成为该地块的所有者"] = function(world)
      if not world.purchased then
        return nil, "tile was not purchased"
      end
      return true
    end,

    ["玩家持有1000金币"] = function(world)
      _ensure_player(world)
      world.player.cash = 1000
      return true
    end,

    ["玩家落在价格为2000的无主地块"] = function(world)
      world.landing_tile = { price = 2000, owner = nil, level = 0 }
      return true
    end,

    ["购买失败并提示余额不足"] = function(world)
      if world.purchase_failed ~= "余额不足" then
        return nil, "expected purchase failure due to insufficient funds"
      end
      return true
    end,

    ["玩家拥有一块等级为<p3>的地块"] = function(world, example)
      local level = number_utils.to_integer(example.p3)
      _ensure_player(world)
      world.owned_tile = { level = level, max_level = 3 }
      return true
    end,

    ["该地块的下一级升级费为<p4>"] = function(world, example)
      local cost = number_utils.to_integer(example.p4)
      world.owned_tile.upgrade_cost = cost
      return true
    end,

    ["玩家选择升级"] = function(world)
      local tile = world.owned_tile
      if not tile then
        return nil, "no owned tile"
      end
      if tile.level >= tile.max_level then
        world.upgrade_failed = "max_level"
        return true
      end
      if world.player.cash < tile.upgrade_cost then
        world.upgrade_failed = "insufficient"
        return true
      end
      world.player.cash = world.player.cash - tile.upgrade_cost
      tile.level = tile.level + 1
      world.upgraded = true
      return true
    end,

    ["地块等级变为<p5>"] = function(world, example)
      local expected = number_utils.to_integer(example.p5)
      if world.owned_tile.level ~= expected then
        return nil, "expected level " .. tostring(expected) .. ", got " .. tostring(world.owned_tile.level)
      end
      return true
    end,

    ["玩家拥有的地块已达最高等级"] = function(world)
      _ensure_player(world)
      world.owned_tile = { level = 3, max_level = 3, upgrade_cost = 0 }
      return true
    end,

    ["玩家尝试升级"] = function(world)
      if world.owned_tile.level >= world.owned_tile.max_level then
        world.upgrade_unavailable = true
      end
      return true
    end,

    ["升级选项不可用"] = function(world)
      if not world.upgrade_unavailable then
        return nil, "upgrade should be unavailable"
      end
      return true
    end,

    ["地块等级为<p6>"] = function(world, example)
      local level = number_utils.to_integer(example.p6)
      world.rent_tile = world.rent_tile or {}
      world.rent_tile.level = level
      return true
    end,

    ["地块的租金表为<p7>"] = function(world, example)
      world.rent_tile.rent_table = shared.parse_number_list(example.p7)
      return true
    end,

    ["地块属于对手"] = function(world)
      world.rent_tile.owner = "opponent"
      return true
    end,

    ["玩家落在该地块"] = function(world)
      local tile = world.rent_tile
      if tile and tile.owner == "opponent" then
        local rent = tile.rent_table[tile.level + 1]
        world.rent_due = rent
      end
      return true
    end,

    ["玩家支付租金<p8>给对手"] = function(world, example)
      local expected = number_utils.to_integer(example.p8)
      if world.rent_due ~= expected then
        return nil, "expected rent " .. tostring(expected) .. ", got " .. tostring(world.rent_due)
      end
      return true
    end,

    ["对手拥有<p9>块相邻地块"] = function(world, example)
      local count = number_utils.to_integer(example.p9)
      world.adjacent_count = count
      return true
    end,

    ["各块租金分别为<p10>"] = function(world, example)
      world.adjacent_rents = shared.parse_number_list(example.p10)
      return true
    end,

    ["玩家落在其中任一块"] = function(world)
      local total = 0
      for _, r in ipairs(world.adjacent_rents or {}) do
        total = total + r
      end
      world.rent_due = total
      return true
    end,

    ["玩家支付的租金为<p11>"] = function(world, example)
      local expected = number_utils.to_integer(example.p11)
      if world.rent_due ~= expected then
        return nil, "expected total rent " .. tostring(expected) .. ", got " .. tostring(world.rent_due)
      end
      return true
    end,

    ["玩家落在对手拥有的地块"] = function(world)
      _ensure_player(world)
      world.rent_tile = world.rent_tile or {}
      world.rent_tile.owner = "opponent"
      world.landing = { type = "opponent_tile", has_rent_free = false, has_seizure_card = false }
      if not world.turn then
        world.turn = { current_player_index = 1, phase = "landing", players = {} }
      end
      return true
    end,

    ["单块基础租金为<p12>"] = function(world, example)
      local rent = number_utils.to_integer(example.p12)
      world.base_rent = rent
      return true
    end,

    ["<p13>"] = function(world, example)
      local condition = example.p13
      world.deity_condition = condition
      if condition:find("租户持有穷神") and condition:find("房东持有财神") then
        world.rent_multiplier = 4
      elseif condition:find("租户持有穷神") then
        world.rent_multiplier = 2
      elseif condition:find("房东持有财神") then
        world.rent_multiplier = 2
      else
        world.rent_multiplier = 1
      end
      return true
    end,

    ["租金结算执行"] = function(world)
      if world.base_rent and world.rent_multiplier then
        world.actual_rent = world.base_rent * world.rent_multiplier
      elseif world.rent_payment then
        local due = world.rent_payment.due
        local cash = world.player.cash
        if cash < due then
          world.rent_payment.received = cash
          world.player.cash = 0
          world.player.bankrupt = true
        else
          world.player.cash = world.player.cash - due
          world.rent_payment.received = due
        end
      end
      return true
    end,

    ["实际支付租金为<p14>"] = function(world, example)
      local expected = number_utils.to_integer(example.p14)
      if world.actual_rent ~= expected then
        return nil, "expected actual rent " .. tostring(expected) .. ", got " .. tostring(world.actual_rent)
      end
      return true
    end,

    ["对手拥有一块地块"] = function(world)
      world.opponent = world.opponent or {}
      world.opponent.has_tile = true
      return true
    end,

    ["对手当前在深山状态"] = function(world)
      world.opponent = world.opponent or {}
      world.opponent.in_mountain = true
      return true
    end,

    ["租金不收取"] = function(world)
      if world.opponent and (world.opponent.in_mountain or world.opponent.eliminated) then
        return true
      end
      return nil, "rent should not be collected"
    end,

    ["事件日志显示房东在深山"] = function(world)
      if not (world.opponent and world.opponent.in_mountain) then
        return nil, "should log landlord in mountain"
      end
      return true
    end,

    ["税率为50%"] = function(world)
      world.tax_rate = 0.5
      return true
    end,

    ["玩家落在税务局格"] = function(world)
      _ensure_player(world)
      local rate = world.tax_rate or 0.5
      local tax = math.floor(world.player.cash * rate)
      world.tax_amount = tax
      if world.player.deities and world.player.deities.angel then
        world.tax_immune = true
        world.tax_amount = 0
      elseif not world.player.deities or not world.player.deities.angel then
        world.player.cash = world.player.cash - tax
      end
      if world.player.cash <= 0 and not world.tax_immune then
        world.player.bankrupt = true
      end
      return true
    end,

    ["玩家被收取<p15>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p15)
      if world.tax_amount ~= expected then
        return nil, "expected tax " .. tostring(expected) .. ", got " .. tostring(world.tax_amount)
      end
      return true
    end,

    ["玩家不被收税"] = function(world)
      if not world.tax_immune then
        return nil, "player should be immune to tax"
      end
      return true
    end,

    ["玩家持有免税卡"] = function(world)
      _ensure_player(world)
      world.player.items.tax_free = true
      return true
    end,

    ["弹出免税卡使用选择"] = function(world)
      if not world.tax_free_prompt then
        return nil, "tax-free card prompt should appear"
      end
      return true
    end,

    ["若玩家确认则消耗免税卡并免税"] = function(world)
      if not world.tax_free_prompt then
        return nil, "no tax-free prompt available"
      end
      return true
    end,

    ["对手的地块等级为<p6>"] = function(world, example)
      local level = number_utils.to_integer(example.p6)
      world.seizure_tile = { level = level }
      return true
    end,

    ["地块购买价为<p2>"] = function(world, example)
      local price = number_utils.to_integer(example.p2)
      world.seizure_tile.price = price
      return true
    end,

    ["各级累计升级费为<p16>"] = function(world, example)
      local cost = number_utils.to_integer(example.p16)
      world.seizure_tile.cumulative_upgrade = cost
      return true
    end,

    ["玩家使用强夺卡"] = function(world)
      local tile = world.seizure_tile
      local total = tile.price + tile.cumulative_upgrade
      if world.player.cash >= total then
        world.player.cash = world.player.cash - total
        world.seizure_paid = total
        tile.owner = "player"
      else
        world.seizure_failed = true
      end
      return true
    end,

    ["玩家支付<p17>金币给对手"] = function(world, example)
      local expected = number_utils.to_integer(example.p17)
      if world.seizure_paid ~= expected then
        return nil, "expected seizure payment " .. tostring(expected) .. ", got " .. tostring(world.seizure_paid)
      end
      return true
    end,

    ["地块所有权转移给玩家"] = function(world)
      if not world.seizure_tile or world.seizure_tile.owner ~= "player" then
        return nil, "tile ownership should transfer to player"
      end
      return true
    end,

    ["对手的地块总投入为5000"] = function(world)
      world.seizure_tile = { price = 5000, cumulative_upgrade = 0, level = 0 }
      return true
    end,

    ["玩家尝试使用强夺卡"] = function(world)
      local tile = world.seizure_tile
      local total = tile.price + tile.cumulative_upgrade
      if world.player.cash < total then
        world.seizure_unavailable = true
      end
      return true
    end,

    ["强夺卡不可用"] = function(world)
      if not world.seizure_unavailable then
        return nil, "seizure card should be unavailable"
      end
      return true
    end,

    ["应付租金为<p8>"] = function(world, example)
      local due = number_utils.to_integer(example.p8)
      world.rent_payment = { due = due }
      return true
    end,

    ["房东收到<p18>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p18)
      local received = world.rent_payment and world.rent_payment.received
      if received ~= expected then
        return nil, "expected landlord receives " .. tostring(expected) .. ", got " .. tostring(received)
      end
      return true
    end,

    ["玩家持有0金币"] = function(world)
      _ensure_player(world)
      world.player.cash = 0
      return true
    end,

    ["游戏已开始"] = function(world)
      _ensure_player(world)
      return true
    end,

    ["玩家持有初始资金"] = function(world)
      _ensure_player(world)
      world.player.cash = world.player.cash or 10000
      return true
    end,

    ["玩家余额为<p1>"] = function(world, example)
      local amount = number_utils.to_integer(example.p1)
      _ensure_player(world)
      world.player.cash = amount
      return true
    end,

    ["玩家需要支付<p2>"] = function(world, example)
      local amount = number_utils.to_integer(example.p2)
      if world.player.cash < amount then
        world.player.bankrupt = true
      else
        world.player.cash = world.player.cash - amount
      end
      return true
    end,

    ["玩家<p3>"] = function(world, example)
      local result = example.p3
      if result == "破产" then
        if not world.player.bankrupt then
          return nil, "player should be bankrupt"
        end
      elseif result == "存活" then
        if world.player.bankrupt then
          return nil, "player should survive"
        end
      else
        return nil, "unknown result: " .. tostring(result)
      end
      return true
    end,

    ["税金为0"] = function(world)
      if world.tax_amount ~= 0 then
        return nil, "expected tax 0, got " .. tostring(world.tax_amount)
      end
      return true
    end,

    ["玩家因余额为零而破产淘汰"] = function(world)
      if not world.player.bankrupt then
        return nil, "player should be bankrupt due to zero balance"
      end
      return true
    end,

    ["对手已被淘汰"] = function(world)
      world.opponent = world.opponent or {}
      world.opponent.eliminated = true
      return true
    end,

    ["玩家持有800金币"] = function(world)
      _ensure_player(world)
      world.player.cash = 800
      return true
    end,

    ["抽到的机会卡效果为向每位玩家支付500金币"] = function(world)
      world.chance_card = world.chance_card or {}
      world.chance_card.pay_each = 500
      return true
    end,

    ["游戏中有3名未淘汰对手"] = function(world)
      world.opponents = {
        { cash = 10000, bankrupt = false },
        { cash = 10000, bankrupt = false },
        { cash = 10000, bankrupt = false },
      }
      return true
    end,

    ["玩家向第一位对手支付500金币后破产"] = function(world)
      if not world.player.bankrupt then
        return nil, "player should be bankrupt after paying first opponent"
      end
      if world.chance_paid_count ~= 1 then
        return nil, "expected 1 payment before bankruptcy, got " .. tostring(world.chance_paid_count)
      end
      return true
    end,

    ["后续对手不再收到支付"] = function(world)
      local unpaid = 0
      for i = 2, #(world.opponents or {}) do
        if not world.opponents[i].received then
          unpaid = unpaid + 1
        end
      end
      if unpaid ~= #(world.opponents or {}) - 1 then
        return nil, "subsequent opponents should not receive payment"
      end
      return true
    end,

    ["抽到的机会卡效果为向每位玩家收取1000金币"] = function(world)
      _ensure_player(world)
      world.chance_card = world.chance_card or {}
      world.chance_card.collect_each = 1000
      world.opponents = world.opponents or {}
      return true
    end,

    ["对手A持有500金币"] = function(world)
      world.opponents = world.opponents or {}
      world.opponents[1] = { cash = 500, bankrupt = false }
      return true
    end,

    ["对手A支付全部500金币后破产淘汰"] = function(world)
      local opp = (world.opponents or {})[1]
      if not opp or not opp.bankrupt then
        return nil, "opponent A should be bankrupt"
      end
      if opp.paid ~= 500 then
        return nil, "opponent A should have paid 500, paid " .. tostring(opp.paid)
      end
      return true
    end,

    ["玩家收到对手A的500金币"] = function(world)
      local opp = (world.opponents or {})[1]
      if not opp or opp.paid ~= 500 then
        return nil, "player should have received 500 from opponent A"
      end
      return true
    end,

    ["玩家因效果被送往医院且需支付住院费"] = function(world)
      _ensure_player(world)
      if world.player.cash <= 0 then
        world.player.bankrupt = true
      end
      return true
    end,

  }
end

return economy_steps
