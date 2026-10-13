require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local balance = require("src.player.actions.balance")

local _with_patches = support.with_patches
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end

local ATTR = balance.COIN_COUNT_ATTR_ID

local function _assert_error_contains(fn, fragments)
  local ok, err = pcall(fn)
  luassert.truthy(ok == false, "expected call to fail")
  local text = tostring(err)
  for _, fragment in ipairs(fragments) do
    luassert.truthy(string.find(text, fragment, 1, true) ~= nil, "expected error to contain " .. tostring(fragment) .. ", got: " .. text)
  end
  return text
end

local function _player_with_role(role)
  return { _coin_role = role }
end

local function _assert_label(player, label)
  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return nil end },
  }, function()
    _assert_error_contains(function()
      balance.player_cash(nil, player)
    end, { label .. " " .. ATTR .. " 缺少Role" })
  end)
end

describe("TestCoinModules", function()

  it("test_labels_players_by_available_identity_fields", function()
    _assert_label(nil, "玩家?")
    _assert_label({ id = 5, name = "Bob" }, "玩家5(Bob)")
    _assert_label({ id = 5 }, "玩家5")
    _assert_label({ id = 5, name = "" }, "玩家5")
    _assert_label({ name = "Bob" }, "Bob")
    _assert_label({ name = "" }, "玩家?")
    _assert_label({}, "玩家?")
  end)

  it("test_returns_validated_non_negative_integers_on_writes", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_eq(balance.seed_player_coins(player, 100), 100, "valid amount")
    _assert_eq(balance.seed_player_coins(player, 0), 0, "zero is valid")
  end)

  it("test_rejects_non_finite_and_non_integer_amounts", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_error_contains(function()
      balance.seed_player_coins(player, {})
    end, { ATTR, "必须是有限整数" })
    _assert_error_contains(function()
      balance.seed_player_coins(player, 12.5)
    end, { ATTR, "必须是有限整数" })
  end)

  it("test_rejects_negative_amounts_at_the_write_boundary", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_error_contains(function()
      balance.seed_player_coins(player, -5)
    end, { ATTR, "写入值", "不能为负数" })
  end)

  it("test_allows_negative_deltas_but_still_rejects_non_integers", function()
    local player = _player_with_role(balance.new_memory_coin_role(10))
    _assert_eq(balance.add_player_cash(nil, player, -5), 5, "negative delta allowed")
    _assert_error_contains(function()
      balance.add_player_cash(nil, player, 2.5)
    end, { "金币变化量", "必须是有限整数" })
  end)

  it("test_reads_and_writes_through_an_in_memory_role", function()
    local role = balance.new_memory_coin_role(500)
    local player = _player_with_role(role)
    _assert_eq(balance.player_cash(nil, player), 500, "seeded value")
    _assert_eq(balance.initialize_player_coins(player, 100), 500, "existing raw value wins over init amount")

    _assert_eq(balance.set_player_cash(nil, player, 750), 750, "write returns amount")
    _assert_eq(role:get_attr_raw_fixed(ATTR), 750, "role attr updated")

    -- 内存角色同时支持 Eggy 冒号签名：role:set(attr, value) / role:get(attr)。
    role:set_attr_raw_fixed(ATTR, 123)
    _assert_eq(role:get_attr_raw_fixed(ATTR), 123, "colon-signature set stores the value")
    _assert_eq(balance.player_cash(nil, player), 123, "colon write is visible through balance")
  end)

  it("test_calls_role_attr_functions_with_eggy_raw_attr_signature", function()
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

    _assert_eq(balance.player_cash(nil, player), 100, "dot-signature read")
    _assert_eq(balance.set_player_cash(nil, player, 250), 250, "write returns amount")
    _assert_eq(calls[1].attr_id, ATTR, "getter receives attr id as first arg")
    _assert_eq(calls[2].attr_id, ATTR, "setter receives attr id as first arg")
    _assert_eq(calls[2].value, 250, "setter receives value as second arg")
  end)

  it("test_seeds_uninitialized_role_on_init_but_fails_reads_before_that", function()
    local player = _player_with_role(balance.new_memory_coin_role(nil))
    _assert_error_contains(function()
      balance.player_cash(nil, player)
    end, { ATTR, "未初始化" })
    _assert_eq(balance.initialize_player_coins(player, 100), 100, "uninitialized role gets the init amount")
  end)

  it("test_reports_non_true_setter_result_as_write_failure", function()
    local role = {
      get_attr_raw_fixed = function() return 0 end,
      set_attr_raw_fixed = function() return false end,
    }
    _assert_error_contains(function()
      balance.set_player_cash(nil, _player_with_role(role), 10)
    end, { ATTR, "写入失败", "set_attr_raw_fixed返回" })
  end)

  it("test_surfaces_getter_errors_as_read_failures", function()
    local role = {
      get_attr_raw_fixed = function() error("boom") end,
      set_attr_raw_fixed = function() return true end,
    }
    _assert_error_contains(function()
      balance.player_cash(nil, _player_with_role(role))
    end, { ATTR, "读取失败" })
  end)

  it("test_fails_when_no_role_is_available", function()
    _assert_error_contains(function()
      balance.player_cash(nil, {})
    end, { ATTR, "缺少Role" })
  end)

  it("test_fails_when_role_lacks_coin_attribute_methods", function()
    _assert_error_contains(function()
      balance.player_cash(nil, _player_with_role({}))
    end, { ATTR, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("test_fails_when_role_exposes_only_getter_without_setter", function()
    _assert_error_contains(function()
      balance.player_cash(nil, _player_with_role({ get_attr_raw_fixed = function() return 5 end }))
    end, { ATTR, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("test_reports_throwing_setter_as_write_failure", function()
    local role = {
      get_attr_raw_fixed = function() return 0 end,
      set_attr_raw_fixed = function() error("boom") end,
    }
    _assert_error_contains(function()
      balance.set_player_cash(nil, _player_with_role(role), 10)
    end, { ATTR, "写入失败", "boom" })
  end)

  it("test_resolves_runtime_role_for_players_with_an_id", function()
    local role = balance.new_memory_coin_role(1234)
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        return player_id == 9 and role or nil
      end },
    }, function()
      _assert_eq(balance.player_cash(nil, { id = 9 }), 1234, "runtime role value")
    end)
  end)

  it("test_initialize_rejects_negative_existing_raw_value_with_label", function()
    -- #293:initialize_player_coins 走「已有值校验」分支时,label(读取值)进入
    -- 报错文案,label→nil 变异可分。
    local player = _player_with_role(balance.new_memory_coin_role(-5))
    _assert_error_contains(function()
      balance.initialize_player_coins(player, 100)
    end, { "读取值不能为负数" })
  end)


end)
