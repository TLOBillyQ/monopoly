local support = require("spec.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local coin_validation = require("src.player.actions.coin_validation")
local coin_store = require("src.player.actions.coin_store")

local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local ATTR = coin_validation.COIN_COUNT_ATTR_ID

local function _assert_error_contains(fn, fragments)
  local ok, err = pcall(fn)
  assert(ok == false, "expected call to fail")
  local text = tostring(err)
  for _, fragment in ipairs(fragments) do
    assert(string.find(text, fragment, 1, true) ~= nil,
      "expected error to contain " .. tostring(fragment) .. ", got: " .. text)
  end
  return text
end

local function _player_with_role(role)
  return { _coin_role = role }
end

describe("coin_validation labels", function()
  it("labels players by available identity fields", function()
    _assert_eq(coin_validation.coin_error(nil, "x"), "玩家? " .. ATTR .. " x", "nil player")
    _assert_eq(coin_validation.coin_error({ id = 5, name = "Bob" }, "x"),
      "玩家5(Bob) " .. ATTR .. " x", "id and name")
    _assert_eq(coin_validation.coin_error({ id = 5 }, "x"), "玩家5 " .. ATTR .. " x", "id only")
    _assert_eq(coin_validation.coin_error({ id = 5, name = "" }, "x"),
      "玩家5 " .. ATTR .. " x", "empty name falls back to id")
    _assert_eq(coin_validation.coin_error({ name = "Bob" }, "x"), "Bob " .. ATTR .. " x", "name only")
    _assert_eq(coin_validation.coin_error({ name = "" }, "x"), "玩家? " .. ATTR .. " x", "empty name only falls back")
    _assert_eq(coin_validation.coin_error({}, "x"), "玩家? " .. ATTR .. " x", "no identity")
  end)
end)

describe("coin_validation amount and delta", function()
  it("returns validated non-negative integers", function()
    _assert_eq(coin_validation.validate_amount({ id = 1 }, 100), 100, "valid amount")
    _assert_eq(coin_validation.validate_amount({ id = 1 }, 0), 0, "zero is valid")
  end)

  it("rejects non-finite and non-integer amounts", function()
    _assert_error_contains(function()
      coin_validation.validate_amount({ id = 1 }, {})
    end, { ATTR, "必须是有限整数" })
    _assert_error_contains(function()
      coin_validation.validate_amount({ id = 1 }, 12.5)
    end, { ATTR, "必须是有限整数" })
  end)

  it("rejects negative amounts using the default label", function()
    _assert_error_contains(function()
      coin_validation.validate_amount({ id = 1 }, -5)
    end, { ATTR, "金币值", "不能为负数" })
  end)

  it("allows negative deltas but still rejects non-integers", function()
    _assert_eq(coin_validation.validate_delta({ id = 1 }, -5), -5, "negative delta allowed")
    _assert_error_contains(function()
      coin_validation.validate_delta({ id = 1 }, 2.5)
    end, { "金币变化量", "必须是有限整数" })
  end)
end)

describe("coin_store role resolution", function()
  it("reads and writes through an in-memory role", function()
    local role = coin_store.new_memory_coin_role(500)
    local player = _player_with_role(role)
    _assert_eq(coin_store.read_raw(player), 500, "seeded value")
    _assert_eq(coin_store.read_count(player), 500, "validated value")

    local ok, written = coin_store.try_write(player, 750)
    assert(ok == true, "write should succeed")
    _assert_eq(written, 750, "write returns amount")
    _assert_eq(role:get_attr_raw_fixed(ATTR), 750, "role attr updated")
  end)

  it("calls role attr functions with the Eggy raw attr signature", function()
    local calls = {}
    local attrs = { [ATTR] = 100 }
    local role = {
      get_attr_raw_fixed = function(attr_id)
        calls[#calls + 1] = { op = "get", attr_id = attr_id }
        return attrs[attr_id]
      end,
      set_attr_raw_fixed = function(attr_id, value)
        calls[#calls + 1] = { op = "set", attr_id = attr_id, value = value }
        attrs[attr_id] = value
        return true
      end,
    }
    local player = _player_with_role(role)

    _assert_eq(coin_store.read_count(player), 100, "dot-signature read")
    local ok, written = coin_store.try_write(player, 250)

    assert(ok == true, "write should succeed")
    _assert_eq(written, 250, "write returns amount")
    _assert_eq(calls[1].attr_id, ATTR, "getter receives attr id as first arg")
    _assert_eq(calls[2].attr_id, ATTR, "setter receives attr id as first arg")
    _assert_eq(calls[2].value, 250, "setter receives value as second arg")
  end)

  it("returns nil raw and fails read_count when uninitialized", function()
    local player = _player_with_role(coin_store.new_memory_coin_role(nil))
    _assert_eq(coin_store.read_raw(player), nil, "uninitialized raw is nil")
    _assert_error_contains(function()
      coin_store.read_count(player)
    end, { ATTR, "未初始化" })
  end)

  it("reports a non-true setter result as a write failure", function()
    local role = {
      get_attr_raw_fixed = function() return 0 end,
      set_attr_raw_fixed = function() return false end,
    }
    local ok, err = coin_store.try_write(_player_with_role(role), 10)
    assert(ok == false, "write should fail")
    assert(string.find(tostring(err), "set_attr_raw_fixed返回", 1, true) ~= nil, "failure reason")
  end)

  it("surfaces getter errors as read failures", function()
    local role = {
      get_attr_raw_fixed = function() error("boom") end,
      set_attr_raw_fixed = function() return true end,
    }
    _assert_error_contains(function()
      coin_store.read_raw(_player_with_role(role))
    end, { ATTR, "读取失败" })
  end)

  it("fails when no role is available", function()
    _assert_error_contains(function()
      coin_store.read_raw({})
    end, { ATTR, "缺少Role" })
  end)

  it("fails when the role lacks coin attribute methods", function()
    _assert_error_contains(function()
      coin_store.read_raw(_player_with_role({}))
    end, { ATTR, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("fails when the role exposes only a getter without a setter", function()
    _assert_error_contains(function()
      coin_store.read_raw(_player_with_role({ get_attr_raw_fixed = function() return 5 end }))
    end, { ATTR, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("reports a throwing setter as a write failure", function()
    local role = {
      get_attr_raw_fixed = function() return 0 end,
      set_attr_raw_fixed = function() error("boom") end,
    }
    local ok, err = coin_store.try_write(_player_with_role(role), 10)
    assert(ok == false, "write should fail")
    assert(string.find(tostring(err), "boom", 1, true) ~= nil, "failure should surface the setter error")
  end)

  it("resolves the runtime role for players with an id", function()
    local role = coin_store.new_memory_coin_role(1234)
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        return player_id == 9 and role or nil
      end },
    }, function()
      _assert_eq(coin_store.read_count({ id = 9 }), 1234, "runtime role value")
    end)
  end)
end)
