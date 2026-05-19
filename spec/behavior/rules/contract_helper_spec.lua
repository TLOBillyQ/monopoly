local contract_helper = require("src.rules.ports.contract_helper")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game(opts)
  local g = {}
  for k, v in pairs(opts or {}) do
    g[k] = v
  end
  return g
end

describe("domain contract helper coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("resolve_required_port returns port", function()
    local port = { do_thing = function() end }
    local game = _make_game({ my_port = port })
    local result = contract_helper.resolve_required_port(game, "my_port", "MyPort")
    _assert_eq(result, port, "should return the port table")
  end)

  it("resolve_required_port errors when game nil", function()
    local ok = pcall(function() contract_helper.resolve_required_port(nil, "port", "P") end)
    _assert_eq(ok, false, "nil game should error")
  end)

  it("resolve_required_port errors when field not table", function()
    local game = _make_game({ bad_port = "not_a_table" })
    local ok = pcall(function() contract_helper.resolve_required_port(game, "bad_port", "P") end)
    _assert_eq(ok, false, "non-table port should error")
  end)

  it("resolve_required_port errors when field nil", function()
    local game = _make_game()
    local ok = pcall(function() contract_helper.resolve_required_port(game, "missing_port", "P") end)
    _assert_eq(ok, false, "nil field should error")
  end)

  it("resolve_required_method returns function", function()
    local fn = function() return 42 end
    local game = _make_game({ my_port = { do_thing = fn } })
    local result = contract_helper.resolve_required_method(game, "my_port", "MyPort", "do_thing")
    _assert_eq(result, fn, "should return the method function")
  end)

  it("resolve_required_method errors when method not function", function()
    local game = _make_game({ my_port = { do_thing = "not_a_fn" } })
    local ok = pcall(function()
      contract_helper.resolve_required_method(game, "my_port", "MyPort", "do_thing")
    end)
    _assert_eq(ok, false, "non-function method should error")
  end)

  it("resolve_required_method errors when method missing", function()
    local game = _make_game({ my_port = {} })
    local ok = pcall(function()
      contract_helper.resolve_required_method(game, "my_port", "MyPort", "missing_fn")
    end)
    _assert_eq(ok, false, "missing method should error")
  end)

  it("resolve_method resolves using field_name as port_name", function()
    local fn = function() return 1 end
    local game = _make_game({ popup_port = { push = fn } })
    local result = contract_helper.resolve_method(game, "popup_port", "push")
    _assert_eq(result, fn, "resolve_method should use field_name as port_name")
  end)

  it("resolve_optional_port returns port when present", function()
    local port = { method = function() end }
    local game = _make_game({ opt_port = port })
    local result = contract_helper.resolve_optional_port(game, "opt_port", nil)
    _assert_eq(result, port, "should return the port when present")
  end)

  it("resolve_optional_port returns fallback when missing", function()
    local fallback = { fallback_method = function() end }
    local game = _make_game()
    local result = contract_helper.resolve_optional_port(game, "missing_port", fallback)
    _assert_eq(result, fallback, "should return fallback when port missing")
  end)

  it("resolve_optional_port returns nil when both missing", function()
    local game = _make_game()
    local result = contract_helper.resolve_optional_port(game, "missing_port", nil)
    _assert_eq(result, nil, "should return nil when both missing")
  end)

  it("resolve_optional_port returns nil when game nil", function()
    local fallback = nil
    local result = contract_helper.resolve_optional_port(nil, "port", fallback)
    _assert_eq(result, nil, "nil game without fallback should return nil")
  end)

  it("resolve_optional_port returns fallback when game nil", function()
    local fallback = { x = true }
    local result = contract_helper.resolve_optional_port(nil, "port", fallback)
    _assert_eq(result, fallback, "nil game should return fallback when provided")
  end)

  it("resolve_optional_port skips non-table field", function()
    local fallback = { x = true }
    local game = _make_game({ my_port = 42 })
    local result = contract_helper.resolve_optional_port(game, "my_port", fallback)
    _assert_eq(result, fallback, "non-table field should use fallback")
  end)

  it("resolve_optional_method returns function and port", function()
    local fn = function() return "result" end
    local port = { my_fn = fn }
    local game = _make_game({ my_port = port })
    local result_fn, result_port = contract_helper.resolve_optional_method(game, "my_port", "my_fn", nil)
    _assert_eq(result_fn, fn, "should return the function")
    _assert_eq(result_port, port, "should return the port")
  end)

  it("resolve_optional_method returns nil when method missing", function()
    local game = _make_game({ my_port = {} })
    local result = contract_helper.resolve_optional_method(game, "my_port", "missing_fn", nil)
    _assert_eq(result, nil, "missing method should return nil")
  end)

  it("resolve_optional_method returns nil when method not function", function()
    local game = _make_game({ my_port = { my_fn = "not_function" } })
    local result = contract_helper.resolve_optional_method(game, "my_port", "my_fn", nil)
    _assert_eq(result, nil, "non-function method should return nil")
  end)

  it("resolve_optional_method uses fallback port", function()
    local fn = function() return 99 end
    local fallback = { fallback_fn = fn }
    local game = _make_game()
    local result = contract_helper.resolve_optional_method(game, "missing_port", "fallback_fn", { fallback_port = fallback })
    _assert_eq(result, fn, "should use fallback_port when main port missing")
  end)

  it("call_required_method calls and returns", function()
    local received_args = nil
    local fn = function(x, y) received_args = {x, y}; return "ok" end
    local game = _make_game({ my_port = { do_it = fn } })
    local result = contract_helper.call_required_method(game, "my_port", "MyPort", "do_it", 1, 2)
    _assert_eq(result, "ok", "should return method result")
    assert(received_args ~= nil, "args should have been received")
    _assert_eq(received_args[1], 1, "should pass first arg")
    _assert_eq(received_args[2], 2, "should pass second arg")
  end)

  it("call_optional_method calls when present", function()
    local fn = function(x) return x * 2 end
    local game = _make_game({ my_port = { calc = fn } })
    local result = contract_helper.call_optional_method(game, "my_port", "calc", nil, 5)
    _assert_eq(result, 10, "should call method and return result")
  end)

  it("call_optional_method returns default when missing", function()
    local game = _make_game()
    local result = contract_helper.call_optional_method(game, "missing_port", "missing_fn", { default_result = "fallback" })
    _assert_eq(result, "fallback", "should return default_result when method missing")
  end)

  it("call_optional_method returns nil default when no opts", function()
    local game = _make_game()
    local result = contract_helper.call_optional_method(game, "missing_port", "missing_fn", nil)
    _assert_eq(result, nil, "should return nil when no opts and method missing")
  end)
end)
