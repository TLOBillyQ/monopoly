local lu = require("luaunit")
local choice_registry = require("src.rules.choice.registry")

local function _new()
  return choice_registry:new()
end

TestChoiceRegistry = {}

function TestChoiceRegistry:test_register_plain_function_wraps_as_execute()
  local reg = _new()
  local fn = function() return "done" end
  reg:register("my_kind", fn)
  local desc = reg:descriptor_for("my_kind")
  lu.assertEvalToTrue(type(desc) == "table", "descriptor is table")
  lu.assertEvalToTrue(desc.execute == fn, "execute is the registered function")
end

function TestChoiceRegistry:test_register_table_handler_copies_fields()
  local reg = _new()
  local exec = function() end
  reg:register("my_kind", { execute = exec, required_meta = { "field" } })
  local desc = reg:descriptor_for("my_kind")
  lu.assertEvalToTrue(desc.execute == exec, "execute preserved")
  lu.assertEvalToTrue(type(desc.required_meta) == "table", "required_meta preserved")
end

function TestChoiceRegistry:test_register_table_handler_invalid_optional_field_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", { execute = function() end, required_meta = "not_a_table" })
  end)
  lu.assertEvalToTrue(ok == false, "should raise on invalid required_meta type")
  lu.assertEvalToTrue(tostring(err):find("must be table"), "error mentions expected type: " .. tostring(err))
end

function TestChoiceRegistry:test_register_table_handler_invalid_function_field_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", { execute = function() end, normalize_meta = "not_a_function" })
  end)
  lu.assertEvalToTrue(ok == false, "should raise on invalid normalize_meta type")
  lu.assertEvalToTrue(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
end

function TestChoiceRegistry:test_register_table_missing_execute_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", { normalize_meta = function() end })
  end)
  lu.assertEvalToTrue(ok == false, "missing execute should raise")
  lu.assertEvalToTrue(tostring(err):find("missing execute"), "error mentions missing execute: " .. tostring(err))
end

function TestChoiceRegistry:test_descriptor_for_unknown_kind_returns_nil()
  local reg = _new()
  lu.assertEvalToTrue(reg:descriptor_for("nonexistent") == nil, "unknown kind returns nil")
end

function TestChoiceRegistry:test_register_defaults_iterates_all_groups()
  local reg = _new()
  local fn_a = function() end
  local fn_b = function() end
  reg:register_defaults({
    { kind_a = fn_a },
    { kind_b = fn_b },
  })
  lu.assertEvalToTrue(reg:descriptor_for("kind_a").execute == fn_a, "kind_a registered")
  lu.assertEvalToTrue(reg:descriptor_for("kind_b").execute == fn_b, "kind_b registered")
end

function TestChoiceRegistry:test_register_defaults_nil_groups_no_error()
  local reg = _new()
  local ok = pcall(function() reg:register_defaults(nil) end)
  lu.assertEvalToTrue(ok, "nil groups should not error")
end

function TestChoiceRegistry:test_valid_normalize_meta_function_passes_validation()
  local reg = _new()
  local ok = pcall(function()
    reg:register("k", { execute = function() end, normalize_meta = function() end })
  end)
  lu.assertEvalToTrue(ok, "valid normalize_meta function should not raise")
  lu.assertEvalToTrue(reg:descriptor_for("k").normalize_meta ~= nil, "normalize_meta preserved")
end

function TestChoiceRegistry:test_valid_meta_validator_function_passes_validation()
  local reg = _new()
  local ok = pcall(function()
    reg:register("k", { execute = function() end, meta_validator = function() end })
  end)
  lu.assertEvalToTrue(ok, "valid meta_validator function should not raise")
  lu.assertEvalToTrue(reg:descriptor_for("k").meta_validator ~= nil, "meta_validator preserved")
end

function TestChoiceRegistry:test_invalid_meta_validator_type_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("k", { execute = function() end, meta_validator = "bad" })
  end)
  lu.assertEvalToTrue(ok == false, "non-function meta_validator should raise")
  lu.assertEvalToTrue(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
end

function TestChoiceRegistry:test_invalid_normalize_action_type_raises()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("k", { execute = function() end, normalize_action = 42 })
  end)
  lu.assertEvalToTrue(ok == false, "non-function normalize_action should raise")
  lu.assertEvalToTrue(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
end

function TestChoiceRegistry:test_class_name_is_choice_registry()
  -- #293:类名字面量(ChoiceRegistry→nil 变异)未测。
  lu.assertEvalToTrue(_new().__name == "ChoiceRegistry",
    "registry instances should carry the ChoiceRegistry class name")
end

function TestChoiceRegistry:test_register_rejects_non_table_handler_with_message()
  -- #293:register 的 handler 类型断言消息未测,消息→nil 变异存活。
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", "not_a_table")
  end)
  lu.assertEvalToTrue(ok == false, "non-table handler should raise")
  lu.assertEvalToTrue(tostring(err):find("choice handler must be function or table", 1, true) ~= nil,
    "error should carry the handler message: " .. tostring(err))
end


return TestChoiceRegistry
