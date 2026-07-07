-- 角色属性金币深模块（src/player/actions/balance.lua）的边界行为规约。
-- 曾经直接打内部拆分文件（coin_validation / coin_store）；合并为深模块后，
-- 同样的校验与存储行为改为通过 balance 公开接口观察。
local support = require("spec.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local balance = require("src.player.actions.balance")

local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local ATTR = balance.COIN_COUNT_ATTR_ID

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

describe("coin error labels", function()
  local function _assert_label(player, label)
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function() return nil end },
    }, function()
      _assert_error_contains(function()
        balance.player_balance(nil, player, "金币")
      end, { label .. " " .. ATTR .. " 缺少Role" })
    end)
  end

  it("labels players by available identity fields", function()
    _assert_label(nil, "玩家?")
    _assert_label({ id = 5, name = "Bob" }, "玩家5(Bob)")
    _assert_label({ id = 5 }, "玩家5")
    _assert_label({ id = 5, name = "" }, "玩家5")
    _assert_label({ name = "Bob" }, "Bob")
    _assert_label({ name = "" }, "玩家?")
    _assert_label({}, "玩家?")
  end)
end)

describe("coin amount and delta validation", function()
  it("returns validated non-negative integers on writes", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_eq(balance.seed_player_coins(player, 100), 100, "valid amount")
    _assert_eq(balance.seed_player_coins(player, 0), 0, "zero is valid")
  end)

  it("rejects non-finite and non-integer amounts", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_error_contains(function()
      balance.seed_player_coins(player, {})
    end, { ATTR, "必须是有限整数" })
    _assert_error_contains(function()
      balance.seed_player_coins(player, 12.5)
    end, { ATTR, "必须是有限整数" })
  end)

  it("rejects negative amounts at the write boundary", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_error_contains(function()
      balance.seed_player_coins(player, -5)
    end, { ATTR, "写入值", "不能为负数" })
  end)

  it("allows negative deltas but still rejects non-integers", function()
    local player = _player_with_role(balance.new_memory_coin_role(10))
    _assert_eq(balance.add_player_cash(nil, player, -5), 5, "negative delta allowed")
    _assert_error_contains(function()
      balance.add_player_cash(nil, player, 2.5)
    end, { "金币变化量", "必须是有限整数" })
  end)
end)

describe("coin role resolution and storage", function()
  it("reads and writes through an in-memory role", function()
    local role = balance.new_memory_coin_role(500)
    local player = _player_with_role(role)
    _assert_eq(balance.player_balance(nil, player, "金币"), 500, "seeded value")
    _assert_eq(balance.initialize_player_coins(player, 100), 500, "existing raw value wins over init amount")

    _assert_eq(balance.set_player_cash(nil, player, 750), 750, "write returns amount")
    _assert_eq(role:get_attr_raw_fixed(ATTR), 750, "role attr updated")

    -- 内存角色同时支持 Eggy 冒号签名：role:set(attr, value) / role:get(attr)。
    role:set_attr_raw_fixed(ATTR, 123)
    _assert_eq(role:get_attr_raw_fixed(ATTR), 123, "colon-signature set stores the value")
    _assert_eq(balance.player_balance(nil, player, "金币"), 123, "colon write is visible through balance")
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

    _assert_eq(balance.player_balance(nil, player, "金币"), 100, "dot-signature read")
    _assert_eq(balance.set_player_cash(nil, player, 250), 250, "write returns amount")
    _assert_eq(calls[1].attr_id, ATTR, "getter receives attr id as first arg")
    _assert_eq(calls[2].attr_id, ATTR, "setter receives attr id as first arg")
    _assert_eq(calls[2].value, 250, "setter receives value as second arg")
  end)

  it("seeds an uninitialized role on init but fails reads before that", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_error_contains(function()
      balance.player_balance(nil, player, "金币")
    end, { ATTR, "未初始化" })
    _assert_eq(balance.initialize_player_coins(player, 100), 100, "uninitialized role gets the init amount")
  end)

  it("reports a non-true setter result as a write failure", function()
    local role = {
      get_attr_raw_fixed = function() return 0 end,
      set_attr_raw_fixed = function() return false end,
    }
    _assert_error_contains(function()
      balance.set_player_cash(nil, _player_with_role(role), 10)
    end, { ATTR, "写入失败", "set_attr_raw_fixed返回" })
  end)

  it("surfaces getter errors as read failures", function()
    local role = {
      get_attr_raw_fixed = function() error("boom") end,
      set_attr_raw_fixed = function() return true end,
    }
    _assert_error_contains(function()
      balance.player_balance(nil, _player_with_role(role), "金币")
    end, { ATTR, "读取失败" })
  end)

  it("fails when no role is available", function()
    _assert_error_contains(function()
      balance.player_balance(nil, {}, "金币")
    end, { ATTR, "缺少Role" })
  end)

  it("fails when the role lacks coin attribute methods", function()
    _assert_error_contains(function()
      balance.player_balance(nil, _player_with_role({}), "金币")
    end, { ATTR, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("fails when the role exposes only a getter without a setter", function()
    _assert_error_contains(function()
      balance.player_balance(nil, _player_with_role({ get_attr_raw_fixed = function() return 5 end }), "金币")
    end, { ATTR, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("reports a throwing setter as a write failure", function()
    local role = {
      get_attr_raw_fixed = function() return 0 end,
      set_attr_raw_fixed = function() error("boom") end,
    }
    _assert_error_contains(function()
      balance.set_player_cash(nil, _player_with_role(role), 10)
    end, { ATTR, "写入失败", "boom" })
  end)

  it("resolves the runtime role for players with an id", function()
    local role = balance.new_memory_coin_role(1234)
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        return player_id == 9 and role or nil
      end },
    }, function()
      _assert_eq(balance.player_balance(nil, { id = 9 }, "金币"), 1234, "runtime role value")
    end)
  end)
end)
