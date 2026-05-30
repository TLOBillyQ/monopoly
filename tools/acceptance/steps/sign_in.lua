local number_utils = require("src.foundation.number")
local sign_in = require("src.app.host_integrations.sign_in")

local sign_in_steps = {}

-- Minimal game/player whose add_player_cash mirrors the production cash add.
local function _ensure(world)
  if not world.si then
    local player = { id = 1, cash = 0 }
    world.si = {
      player = player,
      game = {
        add_player_cash = function(_, target, amount)
          target.cash = (target.cash or 0) + amount
        end,
      },
    }
  end
  return world.si
end

function sign_in_steps.handlers()
  return {
    ["玩家当前金币为<之前金币>"] = function(world, example)
      _ensure(world).player.cash = number_utils.to_integer(example["之前金币"])
      return true
    end,

    ["玩家领取第<签到天数>天签到奖励"] = function(world, example)
      local si = _ensure(world)
      local day = number_utils.to_integer(example["签到天数"])
      sign_in.grant(si.game, si.player, day)
      return true
    end,

    ["玩家当前金币为<之后金币>"] = function(world, example)
      local expected = number_utils.to_integer(example["之后金币"])
      local actual = _ensure(world).player.cash
      if actual ~= expected then
        return nil, "expected cash " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家当前金币为 500"] = function(world)
      _ensure(world).player.cash = 500
      return true
    end,

    ["触发一个未配置奖励的签到事件"] = function(world)
      local si = _ensure(world)
      -- RewardDay99 is a well-formed sign-in event whose day has no reward.
      sign_in.claim(si.game, "RewardDay99", si.player)
      return true
    end,

    ["玩家当前金币保持 500 不变"] = function(world)
      local actual = _ensure(world).player.cash
      if actual ~= 500 then
        return nil, "expected cash to stay 500, got " .. tostring(actual)
      end
      return true
    end,
  }
end

return sign_in_steps
