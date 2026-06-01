local property = require("spec.support.property")
local share_task = require("src.app.host_integrations.share_task")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed")
    .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local function _gen_task(rng)
  return rng:pick(share_task.tasks)
end

describe("share_task config properties", function()
  it("lookup round trips every configured task identity", function()
    property.for_all(_gen_task, function(task)
      local found = share_task.find_task(task.period, task.name)

      _assert_eq(found, task, "configured task should resolve by period/name")
      _assert_eq(share_task.reward_for(task.period, task.name), task.reward_amount,
        "reward_for should mirror task reward")
    end)
  end)

  it("host-managed claims never mutate supplied player cash", function()
    property.for_all(function(rng)
      return {
        task = _gen_task(rng),
        cash = rng:int(0, 1000000),
      }
    end, function(case)
      local player = { id = 1, cash = case.cash }
      local result = share_task.claim(nil, player, case.task)

      _assert_eq(result.ok, false, "claim should stay host-managed")
      _assert_eq(result.reason, "host_managed", "claim should explain host ownership")
      _assert_eq(player.cash, case.cash, "claim should not mutate player cash")
    end)
  end)
end)
