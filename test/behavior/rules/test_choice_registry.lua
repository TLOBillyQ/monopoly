require("test.bootstrap").install_package_paths()
local luassert = assert
local choice_registry = require("src.rules.choice.registry")

local function _new()
  return choice_registry:new()
end

describe("TestChoiceRegistry", function()
it("test_register_plain_function_wraps_as_execute", function()
  local reg = _new()
  local fn = function() return "done" end
  reg:register("my_kind", fn)
  local desc = reg:descriptor_for("my_kind")
  luassert.truthy(type(desc) == "table", "descriptor is table")
  luassert.truthy(desc.execute == fn, "execute is the registered function")
end)

it("test_register_table_handler_copies_fields", function()
  local reg = _new()
  local exec = function() end
  reg:register("my_kind", { execute = exec, required_meta = { "field" } })
  local desc = reg:descriptor_for("my_kind")
  luassert.truthy(desc.execute == exec, "execute preserved")
  luassert.truthy(type(desc.required_meta) == "table", "required_meta preserved")
end)

it("test_register_table_handler_invalid_optional_field_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", { execute = function() end, required_meta = "not_a_table" })
  end)
  luassert.truthy(ok == false, "should raise on invalid required_meta type")
  luassert.truthy(tostring(err):find("must be table"), "error mentions expected type: " .. tostring(err))
end)

it("test_register_table_handler_invalid_function_field_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", { execute = function() end, normalize_meta = "not_a_function" })
  end)
  luassert.truthy(ok == false, "should raise on invalid normalize_meta type")
  luassert.truthy(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
end)

it("test_register_table_missing_execute_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", { normalize_meta = function() end })
  end)
  luassert.truthy(ok == false, "missing execute should raise")
  luassert.truthy(tostring(err):find("missing execute"), "error mentions missing execute: " .. tostring(err))
end)

it("test_descriptor_for_unknown_kind_returns_nil", function()
  local reg = _new()
  luassert.truthy(reg:descriptor_for("nonexistent") == nil, "unknown kind returns nil")
end)

it("test_register_defaults_iterates_all_groups", function()
  local reg = _new()
  local fn_a = function() end
  local fn_b = function() end
  reg:register_defaults({
    { kind_a = fn_a },
    { kind_b = fn_b },
  })
  luassert.truthy(reg:descriptor_for("kind_a").execute == fn_a, "kind_a registered")
  luassert.truthy(reg:descriptor_for("kind_b").execute == fn_b, "kind_b registered")
end)

it("test_register_defaults_nil_groups_no_error", function()
  local reg = _new()
  local ok = pcall(function() reg:register_defaults(nil) end)
  luassert.truthy(ok, "nil groups should not error")
end)

it("test_valid_normalize_meta_function_passes_validation", function()
  local reg = _new()
  local ok = pcall(function()
    reg:register("k", { execute = function() end, normalize_meta = function() end })
  end)
  luassert.truthy(ok, "valid normalize_meta function should not raise")
  luassert.truthy(reg:descriptor_for("k").normalize_meta ~= nil, "normalize_meta preserved")
end)

it("test_valid_meta_validator_function_passes_validation", function()
  local reg = _new()
  local ok = pcall(function()
    reg:register("k", { execute = function() end, meta_validator = function() end })
  end)
  luassert.truthy(ok, "valid meta_validator function should not raise")
  luassert.truthy(reg:descriptor_for("k").meta_validator ~= nil, "meta_validator preserved")
end)

it("test_invalid_meta_validator_type_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("k", { execute = function() end, meta_validator = "bad" })
  end)
  luassert.truthy(ok == false, "non-function meta_validator should raise")
  luassert.truthy(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
end)

it("test_invalid_normalize_action_type_raises", function()
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("k", { execute = function() end, normalize_action = 42 })
  end)
  luassert.truthy(ok == false, "non-function normalize_action should raise")
  luassert.truthy(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
end)

it("test_class_name_is_choice_registry", function()
  -- #293:类名字面量(ChoiceRegistry→nil 变异)未测。
  luassert.truthy(_new().__name == "ChoiceRegistry",
    "registry instances should carry the ChoiceRegistry class name")
end)

it("test_register_rejects_non_table_handler_with_message", function()
  -- #293:register 的 handler 类型断言消息未测,消息→nil 变异存活。
  local reg = _new()
  local ok, err = pcall(function()
    reg:register("bad_kind", "not_a_table")
  end)
  luassert.truthy(ok == false, "non-table handler should raise")
  luassert.truthy(tostring(err):find("choice handler must be function or table", 1, true) ~= nil,
    "error should carry the handler message: " .. tostring(err))
end)


end)
