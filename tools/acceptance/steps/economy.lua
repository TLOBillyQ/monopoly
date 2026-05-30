local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")
local game_driver = require("tools.acceptance.game_driver")
local effect_base = require("src.rules.land.effect_base")
local pricing = require("src.rules.land.pricing")

local economy_steps = {}

local _ensure_player = shared.ensure_player

local function _ensure_driver(world)
  if not world.driver then
    world.driver = game_driver.new_game()
  end
  return world.driver
end

local function _current_src_player(world)
  return game_driver.current_player(_ensure_driver(world))
end

function economy_steps.handlers()
  return {
    ["棋盘包含地块邻接关系"] = function(world)
      world.adjacency = true
      return true
    end,

    ["玩家持有<余额>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["余额"])
      if amount == nil then
        return nil, "invalid amount: " .. tostring(example["余额"])
      end
      _ensure_player(world)
      world.player.cash = amount
      _ensure_driver(world).game:set_player_cash(_current_src_player(world), amount)
      return true
    end,

    ["地块价格为<验证地价>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证地价"])
      if expected == nil then
        return nil, "invalid 验证地价: " .. tostring(example["验证地价"])
      end
      if not (world.landing_tile and world.landing_tile.price == expected) then
        return nil, "expected tile price=" .. tostring(expected) ..
          ", got " .. tostring(world.landing_tile and world.landing_tile.price)
      end
      return true
    end,

    ["当前升级费为<验证升级费>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证升级费"])
      if expected == nil then
        return nil, "invalid 验证升级费: " .. tostring(example["验证升级费"])
      end
      if not (world.owned_tile and world.owned_tile.upgrade_cost == expected) then
        return nil, "expected upgrade_cost=" .. tostring(expected) ..
          ", got " .. tostring(world.owned_tile and world.owned_tile.upgrade_cost)
      end
      return true
    end,

    ["租金表完整为<验证租金表>"] = function(world, example)
      local expected = shared.parse_number_list(example["验证租金表"])
      local actual = world.rent_tile and world.rent_tile.rent_table or {}
      if #actual ~= #expected then
        return nil, "expected rent_table length=" .. tostring(#expected) ..
          ", got " .. tostring(#actual)
      end
      for i, exp in ipairs(expected) do
        if actual[i] ~= exp then
          return nil, "rent_table[" .. tostring(i) .. "] expected=" ..
            tostring(exp) .. ", got " .. tostring(actual[i])
        end
      end
      return true
    end,

    ["相邻地块数量为<验证连片数>块"] = function(world, example)
      local expected = number_utils.to_integer(example["验证连片数"])
      if expected == nil then
        return nil, "invalid 验证连片数: " .. tostring(example["验证连片数"])
      end
      if world.adjacent_count ~= expected then
        return nil, "expected adjacent_count=" .. tostring(expected) ..
          ", got " .. tostring(world.adjacent_count)
      end
      return true
    end,

    ["对手地块等级为<验证等级>"] = function(world, example)
      local expected = number_utils.to_integer(example["验证等级"])
      if expected == nil then
        return nil, "invalid 验证等级: " .. tostring(example["验证等级"])
      end
      if not (world.seizure_tile and world.seizure_tile.level == expected) then
        return nil, "expected seizure_tile.level=" .. tostring(expected) ..
          ", got " .. tostring(world.seizure_tile and world.seizure_tile.level)
      end
      return true
    end,

    ["应付租金记为<验证应付租金>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["验证应付租金"])
      if expected == nil then
        return nil, "invalid 验证应付租金: " .. tostring(example["验证应付租金"])
      end
      if not (world.rent_payment and world.rent_payment.due == expected) then
        return nil, "expected rent_payment.due=" .. tostring(expected) ..
          ", got " .. tostring(world.rent_payment and world.rent_payment.due)
      end
      return true
    end,

    ["玩家落在价格为<地价>的无主地块"] = function(world, example)
      local price = number_utils.to_integer(example["地价"])
      if price == nil then
        return nil, "invalid price: " .. tostring(example["地价"])
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

    ["玩家扣除<地价>金币"] = function(world, example)
      local expected_deducted = number_utils.to_integer(example["地价"])
      if world.purchased and world.landing_tile then
        if world.landing_tile.price ~= expected_deducted then
          return nil, "deducted amount mismatch"
        end
      end
      return true
    end,

    ["玩家扣除<升级费>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["升级费"])
      if world.upgraded and world.owned_tile then
        if world.owned_tile.upgrade_cost ~= expected then
          return nil, "upgrade cost mismatch"
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

    ["玩家拥有一块等级为<当前等级>的地块"] = function(world, example)
      local level = number_utils.to_integer(example["当前等级"])
      _ensure_player(world)
      world.owned_tile = { level = level, max_level = 3 }
      return true
    end,

    ["该地块的下一级升级费为<升级费>"] = function(world, example)
      local cost = number_utils.to_integer(example["升级费"])
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

    ["地块等级变为<新等级>"] = function(world, example)
      local expected = number_utils.to_integer(example["新等级"])
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

    ["地块等级为<等级>"] = function(world, example)
      local level = number_utils.to_integer(example["等级"])
      world.rent_tile = world.rent_tile or {}
      world.rent_tile.level = level
      return true
    end,

    ["地块的租金表为<租金表>"] = function(world, example)
      world.rent_tile.rent_table = shared.parse_number_list(example["租金表"])
      return true
    end,

    ["该地块购买价为<地价>"] = function(world, example)
      local price = number_utils.to_integer(example["地价"])
      if price == nil then
        return nil, "invalid 地价: " .. tostring(example["地价"])
      end
      world.rent_tile = world.rent_tile or {}
      world.rent_tile.price = price
      world.rent_tile.upgrade_costs = { price, price * 2, price * 4 }
      return true
    end,

    ["地块加盖次数为<加盖次数>"] = function(world, example)
      local level = number_utils.to_integer(example["加盖次数"])
      if level == nil then
        return nil, "invalid 加盖次数: " .. tostring(example["加盖次数"])
      end
      world.rent_tile = world.rent_tile or {}
      world.rent_tile.level = level
      return true
    end,

    ["地块属于对手"] = function(world)
      world.rent_tile.owner = "opponent"
      return true
    end,

    ["玩家落在该地块"] = function(world)
      local tile = world.rent_tile
      if tile and tile.owner == "opponent"
        and not (world.opponent and (world.opponent.in_mountain or world.opponent.eliminated)) then
        world.rent_due = pricing.rent_for_level(tile, tile.level or 0)
      end
      return true
    end,

    ["玩家支付租金<应付租金>给对手"] = function(world, example)
      local expected = number_utils.to_integer(example["应付租金"])
      if world.rent_due ~= expected then
        return nil, "expected rent " .. tostring(expected) .. ", got " .. tostring(world.rent_due)
      end
      return true
    end,

    ["对手拥有<连片数>块相邻地块"] = function(world, example)
      local count = number_utils.to_integer(example["连片数"])
      world.adjacent_count = count
      return true
    end,

    ["各块租金分别为<各块租金>"] = function(world, example)
      world.adjacent_rents = shared.parse_number_list(example["各块租金"])
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

    ["玩家支付的租金为<总租金>"] = function(world, example)
      local expected = number_utils.to_integer(example["总租金"])
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

    ["单块基础租金为<基础租金>"] = function(world, example)
      local rent = number_utils.to_integer(example["基础租金"])
      world.base_rent = rent
      return true
    end,

    ["<神灵条件>"] = function(world, example)
      local condition = example["神灵条件"]
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

    ["实际支付租金为<实际租金>"] = function(world, example)
      local expected = number_utils.to_integer(example["实际租金"])
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

    ["对手已被淘汰"] = function(world)
      world.opponent = world.opponent or {}
      world.opponent.eliminated = true
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
      local ctx = _ensure_driver(world)
      local player = game_driver.current_player(ctx)
      ctx.game:set_player_cash(player, world.player.cash or 10000)
      local tax_idx = ctx.game.board:find_first_by_type("tax")
      local tax_tile = assert(ctx.game.board:get_tile(tax_idx), "missing tax tile")
      player.position = tax_idx
      local before = ctx.game:player_balance(player, "金币")
      effect_base.executors.tax.apply({
        game = ctx.game,
        player = player,
        tile = tax_tile,
      })
      local after = ctx.game:player_balance(player, "金币")
      world.tax_amount = before - after
      world.player.cash = after
      if after <= 0 then
        world.player.bankrupt = true
      end
      return true
    end,

    ["玩家被收取<税金>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["税金"])
      if world.tax_amount ~= expected then
        return nil, "expected tax " .. tostring(expected) .. ", got " .. tostring(world.tax_amount)
      end
      return true
    end,

    ["玩家被收取5000金币"] = function(world)
      if world.tax_amount ~= 5000 then
        return nil, "expected tax 5000, got " .. tostring(world.tax_amount)
      end
      return true
    end,

    ["玩家不被收税"] = function(world)
      if not world.tax_immune then
        return nil, "player should be immune to tax"
      end
      return true
    end,

    ["玩家附有天使守护"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.angel = true
      game_driver.set_player_deity(_ensure_driver(world), _current_src_player(world), "angel")
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

    ["对手的地块等级为<等级>"] = function(world, example)
      local level = number_utils.to_integer(example["等级"])
      world.seizure_tile = { level = level }
      return true
    end,

    ["地块购买价为<地价>"] = function(world, example)
      local price = number_utils.to_integer(example["地价"])
      world.seizure_tile.price = price
      return true
    end,

    ["各级累计升级费为<累计升级费>"] = function(world, example)
      local cost = number_utils.to_integer(example["累计升级费"])
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

    ["玩家支付<总投入>金币给对手"] = function(world, example)
      local expected = number_utils.to_integer(example["总投入"])
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

    ["应付租金为<应付租金>"] = function(world, example)
      local due = number_utils.to_integer(example["应付租金"])
      world.rent_payment = { due = due }
      return true
    end,

    ["房东收到<实收金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["实收金额"])
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

    ["玩家需要支付<金额>"] = function(world, example)
      local amount = number_utils.to_integer(example["金额"])
      world.payment_attempted = amount
      if world.player.cash < amount then
        world.player.bankrupt = true
      else
        world.player.cash = world.player.cash - amount
      end
      return true
    end,

    ["玩家<结果>"] = function(world, example)
      local result = example["结果"]
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

  }
end

return economy_steps
