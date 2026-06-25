local property = require("spec.support.property")
local coin_validation = require("src.player.actions.coin_validation")
local coin_store = require("src.player.actions.coin_store")

-- The coin balance layer stores an integer coin_count on a role attribute and
-- validates every value crossing that boundary. The properties below pin the
-- round-trip, conservation, and idempotence guarantees that the balance
-- operations rely on: validation must never alter a legal value, and a write
-- must always be observable by the next read.

local AMOUNT_MAX = 1000000
local PLAYER = { id = 1, name = "P" }

local function _gen_amount(rng)
  return rng:int(0, AMOUNT_MAX)
end

local function _gen_delta(rng)
  return rng:int(-AMOUNT_MAX, AMOUNT_MAX)
end

local function _stored_player(initial)
  return { _coin_role = coin_store.new_memory_coin_role(initial) }
end

describe("coin validation properties", function()
  it("returns any non-negative integer amount unchanged", function()
    property.for_all(_gen_amount, function(amount)
      assert(coin_validation.validate_amount(PLAYER, amount) == amount,
        "validate_amount must be the identity on legal amounts")
    end)
  end)

  it("returns any integer delta unchanged regardless of sign", function()
    property.for_all(_gen_delta, function(delta)
      assert(coin_validation.validate_delta(PLAYER, delta) == delta,
        "validate_delta must be the identity on integer deltas")
    end)
  end)

  it("rejects every negative amount", function()
    property.for_all(function(rng) return rng:int(-AMOUNT_MAX, -1) end, function(amount)
      local ok = pcall(coin_validation.validate_amount, PLAYER, amount)
      assert(ok == false, "validate_amount must reject negative amounts")
    end)
  end)
end)

describe("coin store properties", function()
  it("reads back exactly what was written (write/read round trip)", function()
    property.for_all(_gen_amount, function(amount)
      local player = _stored_player(nil)
      local ok = coin_store.try_write(player, amount)
      assert(ok == true, "write of a legal amount must succeed")
      assert(coin_store.read_count(player) == amount, "read must return the written amount")
    end)
  end)

  it("is last-write-wins across two writes", function()
    property.for_all(function(rng)
      return { first = _gen_amount(rng), second = _gen_amount(rng) }
    end, function(case)
      local player = _stored_player(case.first)
      coin_store.try_write(player, case.first)
      coin_store.try_write(player, case.second)
      assert(coin_store.read_count(player) == case.second, "the latest write must win")
    end)
  end)

  it("is idempotent when the same amount is written twice", function()
    property.for_all(_gen_amount, function(amount)
      local player = _stored_player(nil)
      coin_store.try_write(player, amount)
      local after_first = coin_store.read_count(player)
      coin_store.try_write(player, amount)
      assert(coin_store.read_count(player) == after_first,
        "rewriting the same amount must not change the stored value")
    end)
  end)
end)
