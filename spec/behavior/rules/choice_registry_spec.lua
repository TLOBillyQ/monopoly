require "vendor.third_party.ClassUtils"
local choice_registry = require("src.rules.choice.registry")

local function _new()
  return choice_registry:new()
end

describe("choice_registry", function()
  it("_test_register_plain_function_wraps_as_execute", function()
    local reg = _new()
    local fn = function() return "done" end
    reg:register("my_kind", fn)
    local desc = reg:descriptor_for("my_kind")
    assert(type(desc) == "table", "descriptor is table")
    assert(desc.execute == fn, "execute is the registered function")
  end)

  it("_test_register_table_handler_copies_fields", function()
    local reg = _new()
    local exec = function() end
    reg:register("my_kind", { execute = exec, required_meta = { "field" } })
    local desc = reg:descriptor_for("my_kind")
    assert(desc.execute == exec, "execute preserved")
    assert(type(desc.required_meta) == "table", "required_meta preserved")
  end)

  it("_test_register_table_handler_invalid_optional_field_raises", function()
    local reg = _new()
    local ok, err = pcall(function()
      reg:register("bad_kind", { execute = function() end, required_meta = "not_a_table" })
    end)
    assert(ok == false, "should raise on invalid required_meta type")
    assert(tostring(err):find("must be table"), "error mentions expected type: " .. tostring(err))
  end)

  it("_test_register_table_handler_invalid_function_field_raises", function()
    local reg = _new()
    local ok, err = pcall(function()
      reg:register("bad_kind", { execute = function() end, normalize_meta = "not_a_function" })
    end)
    assert(ok == false, "should raise on invalid normalize_meta type")
    assert(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
  end)

  it("_test_register_table_missing_execute_raises", function()
    local reg = _new()
    local ok, err = pcall(function()
      reg:register("bad_kind", { normalize_meta = function() end })
    end)
    assert(ok == false, "missing execute should raise")
    assert(tostring(err):find("missing execute"), "error mentions missing execute: " .. tostring(err))
  end)

  it("_test_descriptor_for_unknown_kind_returns_nil", function()
    local reg = _new()
    assert(reg:descriptor_for("nonexistent") == nil, "unknown kind returns nil")
  end)

  it("_test_register_defaults_iterates_all_groups", function()
    local reg = _new()
    local fn_a = function() end
    local fn_b = function() end
    reg:register_defaults({
      { kind_a = fn_a },
      { kind_b = fn_b },
    })
    assert(reg:descriptor_for("kind_a").execute == fn_a, "kind_a registered")
    assert(reg:descriptor_for("kind_b").execute == fn_b, "kind_b registered")
  end)

  it("_test_register_defaults_nil_groups_no_error", function()
    local reg = _new()
    local ok = pcall(function() reg:register_defaults(nil) end)
    assert(ok, "nil groups should not error")
  end)

  it("_test_valid_normalize_meta_function_passes_validation", function()
    local reg = _new()
    local ok = pcall(function()
      reg:register("k", { execute = function() end, normalize_meta = function() end })
    end)
    assert(ok, "valid normalize_meta function should not raise")
    assert(reg:descriptor_for("k").normalize_meta ~= nil, "normalize_meta preserved")
  end)

  it("_test_valid_meta_validator_function_passes_validation", function()
    local reg = _new()
    local ok = pcall(function()
      reg:register("k", { execute = function() end, meta_validator = function() end })
    end)
    assert(ok, "valid meta_validator function should not raise")
    assert(reg:descriptor_for("k").meta_validator ~= nil, "meta_validator preserved")
  end)

  it("_test_invalid_meta_validator_type_raises", function()
    local reg = _new()
    local ok, err = pcall(function()
      reg:register("k", { execute = function() end, meta_validator = "bad" })
    end)
    assert(ok == false, "non-function meta_validator should raise")
    assert(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
  end)

  it("_test_invalid_normalize_action_type_raises", function()
    local reg = _new()
    local ok, err = pcall(function()
      reg:register("k", { execute = function() end, normalize_action = 42 })
    end)
    assert(ok == false, "non-function normalize_action should raise")
    assert(tostring(err):find("must be function"), "error mentions expected type: " .. tostring(err))
  end)
end)
