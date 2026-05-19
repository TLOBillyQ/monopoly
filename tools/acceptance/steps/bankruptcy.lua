local shared = require("acceptance.steps.shared")

local bankruptcy_steps = {}

local _ensure_player = shared.ensure_player

function bankruptcy_steps.handlers()
  return {
    ["玩家持有800金币"] = function(world)
      _ensure_player(world)
      world.player.cash = 800
      return true
    end,

    ["抽到的机会卡效果为向每位玩家支付500金币"] = function(world)
      _ensure_player(world)
      world.chance_card = world.chance_card or {}
      world.chance_card.pay_each = 500
      return true
    end,

    ["游戏中有3名未淘汰对手"] = function(world)
      world.opponents = {
        { id = 1, cash = 10000, eliminated = false, received = 0 },
        { id = 2, cash = 10000, eliminated = false, received = 0 },
        { id = 3, cash = 10000, eliminated = false, received = 0 },
      }
      return true
    end,

    ["玩家向第一位对手支付500金币后破产"] = function(world)
      if not world.player.bankrupt then
        return nil, "player should be bankrupt"
      end
      local first = world.opponents[1]
      if first.received ~= 500 then
        return nil, "first opponent should receive 500, got " .. tostring(first.received)
      end
      return true
    end,

    ["后续对手不再收到支付"] = function(world)
      for i = 2, #(world.opponents or {}) do
        if (world.opponents[i].received or 0) ~= 0 then
          return nil, "opponent " .. tostring(i) .. " should not receive payment"
        end
      end
      return true
    end,

    ["抽到的机会卡效果为向每位玩家收取1000金币"] = function(world)
      _ensure_player(world)
      world.player.cash = world.player.cash or 10000
      world.chance_card = world.chance_card or {}
      world.chance_card.collect_each = 1000
      world.opponents = world.opponents or {
        { id = 1, cash = 10000, eliminated = false, received = 0 },
      }
      return true
    end,

    ["对手A持有500金币"] = function(world)
      world.opponents = world.opponents or {}
      if #world.opponents == 0 then
        world.opponents[1] = { id = 1, eliminated = false, received = 0 }
      end
      world.opponents[1].cash = 500
      return true
    end,

    ["对手A支付全部500金币后破产淘汰"] = function(world)
      local opp = world.opponents[1]
      if opp.cash ~= 0 then
        return nil, "opponent A should have 0 cash, got " .. tostring(opp.cash)
      end
      if not opp.eliminated then
        return nil, "opponent A should be eliminated"
      end
      return true
    end,

    ["玩家收到对手A的500金币"] = function(world)
      if world.player.cash < 500 then
        return nil, "player should have received at least 500 from opponent A"
      end
      return true
    end,

    ["玩家因效果被送往医院且需支付住院费"] = function(world)
      _ensure_player(world)
      local hospital_fee = 200
      if world.player.cash < hospital_fee then
        world.player.bankrupt = true
      else
        world.player.cash = world.player.cash - hospital_fee
      end
      world.player.in_hospital = true
      return true
    end,
  }
end

return bankruptcy_steps
