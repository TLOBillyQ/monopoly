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

-- resolve_required_port

local function test_resolve_required_port_returns_port()
  local port = { do_thing = function() end }
  local game = _make_game({ my_port = port })
  local result = contract_helper.resolve_required_port(game, "my_port", "MyPort")
  _assert_eq(result, port, "should return the port table")
end

local function test_resolve_required_port_errors_when_game_nil()
  local ok = pcall(function() contract_helper.resolve_required_port(nil, "port", "P") end)
  _assert_eq(ok, false, "nil game should error")
end

local function test_resolve_required_port_errors_when_field_not_table()
  local game = _make_game({ bad_port = "not_a_table" })
  local ok = pcall(function() contract_helper.resolve_required_port(game, "bad_port", "P") end)
  _assert_eq(ok, false, "non-table port should error")
end

local function test_resolve_required_port_errors_when_field_nil()
  local game = _make_game()
  local ok = pcall(function() contract_helper.resolve_required_port(game, "missing_port", "P") end)
  _assert_eq(ok, false, "nil field should error")
end

-- resolve_required_method

local function test_resolve_required_method_returns_function()
  local fn = function() return 42 end
  local game = _make_game({ my_port = { do_thing = fn } })
  local result = contract_helper.resolve_required_method(game, "my_port", "MyPort", "do_thing")
  _assert_eq(result, fn, "should return the method function")
end

local function test_resolve_required_method_errors_when_method_not_function()
  local game = _make_game({ my_port = { do_thing = "not_a_fn" } })
  local ok = pcall(function()
    contract_helper.resolve_required_method(game, "my_port", "MyPort", "do_thing")
  end)
  _assert_eq(ok, false, "non-function method should error")
end

local function test_resolve_required_method_errors_when_method_missing()
  local game = _make_game({ my_port = {} })
  local ok = pcall(function()
    contract_helper.resolve_required_method(game, "my_port", "MyPort", "missing_fn")
  end)
  _assert_eq(ok, false, "missing method should error")
end

-- resolve_method

local function test_resolve_method_resolves_using_field_name_as_port_name()
  local fn = function() return 1 end
  local game = _make_game({ popup_port = { push = fn } })
  local result = contract_helper.resolve_method(game, "popup_port", "push")
  _assert_eq(result, fn, "resolve_method should use field_name as port_name")
end

-- resolve_optional_port

local function test_resolve_optional_port_returns_port_when_present()
  local port = { method = function() end }
  local game = _make_game({ opt_port = port })
  local result = contract_helper.resolve_optional_port(game, "opt_port", nil)
  _assert_eq(result, port, "should return the port when present")
end

local function test_resolve_optional_port_returns_fallback_when_missing()
  local fallback = { fallback_method = function() end }
  local game = _make_game()
  local result = contract_helper.resolve_optional_port(game, "missing_port", fallback)
  _assert_eq(result, fallback, "should return fallback when port missing")
end

local function test_resolve_optional_port_returns_nil_when_both_missing()
  local game = _make_game()
  local result = contract_helper.resolve_optional_port(game, "missing_port", nil)
  _assert_eq(result, nil, "should return nil when both missing")
end

local function test_resolve_optional_port_returns_nil_when_game_nil()
  local fallback = nil
  local result = contract_helper.resolve_optional_port(nil, "port", fallback)
  _assert_eq(result, nil, "nil game without fallback should return nil")
end

local function test_resolve_optional_port_returns_fallback_when_game_nil()
  local fallback = { x = true }
  local result = contract_helper.resolve_optional_port(nil, "port", fallback)
  _assert_eq(result, fallback, "nil game should return fallback when provided")
end

local function test_resolve_optional_port_skips_non_table_field()
  local fallback = { x = true }
  local game = _make_game({ my_port = 42 })
  local result = contract_helper.resolve_optional_port(game, "my_port", fallback)
  _assert_eq(result, fallback, "non-table field should use fallback")
end

-- resolve_optional_method

local function test_resolve_optional_method_returns_function_and_port()
  local fn = function() return "result" end
  local port = { my_fn = fn }
  local game = _make_game({ my_port = port })
  local result_fn, result_port = contract_helper.resolve_optional_method(game, "my_port", "my_fn", nil)
  _assert_eq(result_fn, fn, "should return the function")
  _assert_eq(result_port, port, "should return the port")
end

local function test_resolve_optional_method_returns_nil_when_method_missing()
  local game = _make_game({ my_port = {} })
  local result = contract_helper.resolve_optional_method(game, "my_port", "missing_fn", nil)
  _assert_eq(result, nil, "missing method should return nil")
end

local function test_resolve_optional_method_returns_nil_when_method_not_function()
  local game = _make_game({ my_port = { my_fn = "not_function" } })
  local result = contract_helper.resolve_optional_method(game, "my_port", "my_fn", nil)
  _assert_eq(result, nil, "non-function method should return nil")
end

local function test_resolve_optional_method_uses_fallback_port()
  local fn = function() return 99 end
  local fallback = { fallback_fn = fn }
  local game = _make_game()
  local result = contract_helper.resolve_optional_method(game, "missing_port", "fallback_fn", { fallback_port = fallback })
  _assert_eq(result, fn, "should use fallback_port when main port missing")
end

-- call_required_method

local function test_call_required_method_calls_and_returns()
  local received_args = nil
  local fn = function(x, y) received_args = {x, y}; return "ok" end
  local game = _make_game({ my_port = { do_it = fn } })
  local result = contract_helper.call_required_method(game, "my_port", "MyPort", "do_it", 1, 2)
  _assert_eq(result, "ok", "should return method result")
  assert(received_args ~= nil, "args should have been received")
  _assert_eq(received_args[1], 1, "should pass first arg")
  _assert_eq(received_args[2], 2, "should pass second arg")
end

-- call_optional_method

local function test_call_optional_method_calls_when_present()
  local fn = function(x) return x * 2 end
  local game = _make_game({ my_port = { calc = fn } })
  local result = contract_helper.call_optional_method(game, "my_port", "calc", nil, 5)
  _assert_eq(result, 10, "should call method and return result")
end

local function test_call_optional_method_returns_default_when_missing()
  local game = _make_game()
  local result = contract_helper.call_optional_method(game, "missing_port", "missing_fn", { default_result = "fallback" })
  _assert_eq(result, "fallback", "should return default_result when method missing")
end

local function test_call_optional_method_returns_nil_default_when_no_opts()
  local game = _make_game()
  local result = contract_helper.call_optional_method(game, "missing_port", "missing_fn", nil)
  _assert_eq(result, nil, "should return nil when no opts and method missing")
end

return {
  name = "domain contract helper coverage",
  tests = {
    { name = "resolve_required_port returns port", run = test_resolve_required_port_returns_port },
    { name = "resolve_required_port errors when game nil", run = test_resolve_required_port_errors_when_game_nil },
    { name = "resolve_required_port errors when field not table", run = test_resolve_required_port_errors_when_field_not_table },
    { name = "resolve_required_port errors when field nil", run = test_resolve_required_port_errors_when_field_nil },
    { name = "resolve_required_method returns function", run = test_resolve_required_method_returns_function },
    { name = "resolve_required_method errors when method not function", run = test_resolve_required_method_errors_when_method_not_function },
    { name = "resolve_required_method errors when method missing", run = test_resolve_required_method_errors_when_method_missing },
    { name = "resolve_method resolves using field_name as port_name", run = test_resolve_method_resolves_using_field_name_as_port_name },
    { name = "resolve_optional_port returns port when present", run = test_resolve_optional_port_returns_port_when_present },
    { name = "resolve_optional_port returns fallback when missing", run = test_resolve_optional_port_returns_fallback_when_missing },
    { name = "resolve_optional_port returns nil when both missing", run = test_resolve_optional_port_returns_nil_when_both_missing },
    { name = "resolve_optional_port returns nil when game nil", run = test_resolve_optional_port_returns_nil_when_game_nil },
    { name = "resolve_optional_port returns fallback when game nil", run = test_resolve_optional_port_returns_fallback_when_game_nil },
    { name = "resolve_optional_port skips non-table field", run = test_resolve_optional_port_skips_non_table_field },
    { name = "resolve_optional_method returns function and port", run = test_resolve_optional_method_returns_function_and_port },
    { name = "resolve_optional_method returns nil when method missing", run = test_resolve_optional_method_returns_nil_when_method_missing },
    { name = "resolve_optional_method returns nil when method not function", run = test_resolve_optional_method_returns_nil_when_method_not_function },
    { name = "resolve_optional_method uses fallback port", run = test_resolve_optional_method_uses_fallback_port },
    { name = "call_required_method calls and returns", run = test_call_required_method_calls_and_returns },
    { name = "call_optional_method calls when present", run = test_call_optional_method_calls_when_present },
    { name = "call_optional_method returns default when missing", run = test_call_optional_method_returns_default_when_missing },
    { name = "call_optional_method returns nil default when no opts", run = test_call_optional_method_returns_nil_default_when_no_opts },
  },
}
