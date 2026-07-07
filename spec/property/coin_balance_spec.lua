local property = require("spec.support.property")
local balance = require("src.player.actions.balance")

-- 角色属性金币深模块 stores an integer coin_count on a role attribute and
-- validates every value crossing that boundary. The properties below pin the
-- round-trip, conservation, and idempotence guarantees that the balance
-- operations rely on: validation must never alter a legal value, and a write
-- must always be observable by the next read.

local AMOUNT_MAX = 1000000

local function _gen_amount(rng)
  return rng:int(0, AMOUNT_MAX)
end

local function _gen_delta(rng)
  return rng:int(-AMOUNT_MAX, AMOUNT_MAX)
end

local function _stored_player(initial)
  return { name = "P", _coin_role = balance.new_memory_coin_role(initial) }
end

local function _read(player)
  return balance.player_cash(nil, player)
end

describe("coin validation properties", function()
  it("returns any non-negative integer amount unchanged", function()
    property.for_all(_gen_amount, function(amount)
      assert(balance.seed_player_coins(_stored_player(nil), amount) == amount,
        "a legal amount must pass through the write boundary unchanged")
    end)
  end)

  it("applies any integer delta exactly regardless of sign", function()
    property.for_all(_gen_delta, function(delta)
      local player = _stored_player(AMOUNT_MAX)
      assert(balance.add_player_cash(nil, player, delta) == AMOUNT_MAX + delta,
        "an in-range delta must be applied without alteration")
    end)
  end)

  it("rejects every negative amount", function()
    property.for_all(function(rng) return rng:int(-AMOUNT_MAX, -1) end, function(amount)
      local ok = pcall(balance.seed_player_coins, _stored_player(nil), amount)
      assert(ok == false, "the write boundary must reject negative amounts")
    end)
  end)
end)

describe("coin store properties", function()
  it("reads back exactly what was written (write/read round trip)", function()
    property.for_all(_gen_amount, function(amount)
      local player = _stored_player(nil)
      assert(balance.set_player_cash(nil, player, amount) == amount,
        "write of a legal amount must succeed")
      assert(_read(player) == amount, "read must return the written amount")
    end)
  end)

  it("is last-write-wins across two writes", function()
    property.for_all(function(rng)
      return { first = _gen_amount(rng), second = _gen_amount(rng) }
    end, function(case)
      local player = _stored_player(case.first)
      balance.set_player_cash(nil, player, case.first)
      balance.set_player_cash(nil, player, case.second)
      assert(_read(player) == case.second, "the latest write must win")
    end)
  end)

  it("is idempotent when the same amount is written twice", function()
    property.for_all(_gen_amount, function(amount)
      local player = _stored_player(nil)
      balance.set_player_cash(nil, player, amount)
      local after_first = _read(player)
      balance.set_player_cash(nil, player, amount)
      assert(_read(player) == after_first,
        "rewriting the same amount must not change the stored value")
    end)
  end)
end)
