---@diagnostic disable: redundant-parameter

local property = require("spec.support.property")
local sign_in = require("src.app.host_integrations.sign_in")
local rewards = require("src.config.content.sign_in_rewards")

local function _game()
  return {
    add_player_cash = function(_, player, amount)
      player.cash = (player.cash or 0) + amount
    end,
  }
end

describe("sign_in parsing and claim properties", function()
  it("round-trips any positive day through the RewardDay event name", function()
    property.for_all(function(rng)
      return rng:int(1, 10000000)
    end, function(day)
      assert(sign_in.day_from_event("RewardDay" .. day) == day,
        "RewardDay<day> must parse back to the same day, including beyond the configured range")
    end)
  end)

  it("rejects event names with a non-digit appended to the day", function()
    -- Guards the trailing `$` anchor: a well-formed prefix plus trailing junk
    -- must not be accepted as a reward event.
    local SUFFIXES = { "x", " ", "0x", "-", ".5", "!" }
    property.for_all(function(rng)
      return { day = rng:int(1, 10000), suffix = rng:pick(SUFFIXES) }
    end, function(case)
      assert(sign_in.day_from_event("RewardDay" .. case.day .. case.suffix) == nil,
        "a non-digit suffix must not parse as a reward event")
    end)
  end)

  it("claims grant exactly the configured coins for configured days and nothing otherwise", function()
    property.for_all(function(rng)
      return { day = rng:int(1, 12), cash = rng:int(0, 100000) }
    end, function(case)
      local player = { id = 1, cash = case.cash }
      local granted = sign_in.claim(_game(), "RewardDay" .. case.day, player)
      local configured = rewards[case.day]
      if configured == nil then
        assert(granted == false, "an unconfigured day must not grant")
        assert(player.cash == case.cash, "an unconfigured day must leave cash unchanged")
      else
        assert(granted == true, "a configured day must grant")
        assert(player.cash == case.cash + configured,
          "a configured claim must add exactly the configured coins to existing cash")
      end
    end)
  end)
end)
