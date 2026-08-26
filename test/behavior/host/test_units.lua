local lu = require("luaunit")
local unit_lifecycle = require("src.host.units")
local support = require("test.support.shared_support")
local with_patches = support.with_patches

TestUnits = {}

function TestUnits:test_create_unit_group_returns_nil_when_gameapi_missing()
  local result, err = unit_lifecycle.create_unit_group(1, {}, {})
  lu.assertEvalToTrue(result == nil, "expected nil without GameAPI")
  lu.assertEvalToTrue(type(err) == "string", "expected error string")
  lu.assertEvalToTrue(err == "missing GameAPI.create_unit_group",
    "error should name the missing create_unit_group method, got " .. tostring(err))
end

function TestUnits:test_create_unit_with_scale_returns_nil_when_gameapi_missing()
  local result, err = unit_lifecycle.create_unit_with_scale(1, {}, {}, 1.0)
  lu.assertEvalToTrue(result == nil, "expected nil without GameAPI")
  lu.assertEvalToTrue(type(err) == "string", "expected error string")
  lu.assertEvalToTrue(err == "missing GameAPI.create_unit_with_scale",
    "error should name the missing create_unit_with_scale method, got " .. tostring(err))
end

function TestUnits:test_destroy_unit_with_children_returns_false_when_gameapi_missing()
  local result = unit_lifecycle.destroy_unit_with_children({})
  lu.assertEvalToTrue(result == false, "expected false without GameAPI")
end

function TestUnits:test_destroy_unit_returns_false_when_gameapi_missing()
  local result = unit_lifecycle.destroy_unit({})
  lu.assertEvalToTrue(result == false, "expected false without GameAPI")
end

function TestUnits:test_treats_a_non_function_gameapi_member_as_missing()
  with_patches({
    { key = "GameAPI", value = { create_unit_group = 42, destroy_unit = "not a fn" } },
  }, function()
    local result, err = unit_lifecycle.create_unit_group(1, {}, {})
    lu.assertEvalToTrue(result == nil, "non-function member should be treated as missing")
    lu.assertEvalToTrue(err == "missing GameAPI.create_unit_group", "non-function member should still report missing")
    lu.assertEvalToTrue(unit_lifecycle.destroy_unit({}) == false,
      "non-function destroy member should be treated as missing")
  end)
end

function TestUnits:test_create_unit_group_forwards_group_id_pos_rotation_and_returns_host_handle()
  local seen
  with_patches({
    { key = "GameAPI", value = {
      create_unit_group = function(group_id, pos, rotation)
        seen = { group_id = group_id, pos = pos, rotation = rotation }
        return "group_handle"
      end,
      create_unit_with_scale = function() return "wrong_scale_handle" end,
    } },
  }, function()
    local pos = { x = 1 }
    local rotation = { y = 2 }
    local result, err = unit_lifecycle.create_unit_group("grp7", pos, rotation)
    lu.assertEvalToTrue(result == "group_handle", "should return the host create_unit_group handle")
    lu.assertEvalToTrue(err == nil, "successful create should not return an error")
    lu.assertEvalToTrue(seen.group_id == "grp7", "group_id should be forwarded verbatim")
    lu.assertEvalToTrue(seen.pos == pos, "pos should be forwarded verbatim")
    lu.assertEvalToTrue(seen.rotation == rotation, "rotation should be forwarded verbatim")
  end)
end

function TestUnits:test_create_unit_with_scale_forwards_unit_id_pos_rotation_scale_and_returns_host_handle()
  local seen
  with_patches({
    { key = "GameAPI", value = {
      create_unit_with_scale = function(unit_id, pos, rotation, scale)
        seen = { unit_id = unit_id, pos = pos, rotation = rotation, scale = scale }
        return "scale_handle"
      end,
      create_unit_group = function() return "wrong_group_handle" end,
    } },
  }, function()
    local pos = { x = 3 }
    local rotation = { y = 4 }
    local result = unit_lifecycle.create_unit_with_scale("unit9", pos, rotation, 2.5)
    lu.assertEvalToTrue(result == "scale_handle", "should return the host create_unit_with_scale handle")
    lu.assertEvalToTrue(seen.unit_id == "unit9", "unit_id should be forwarded verbatim")
    lu.assertEvalToTrue(seen.pos == pos, "pos should be forwarded verbatim")
    lu.assertEvalToTrue(seen.rotation == rotation, "rotation should be forwarded verbatim")
    lu.assertEvalToTrue(seen.scale == 2.5, "scale should be forwarded verbatim")
  end)
end

function TestUnits:test_destroy_unit_forwards_the_handle_and_returns_true()
  local seen
  with_patches({
    { key = "GameAPI", value = {
      destroy_unit = function(handle)
        seen = handle
        return "ignored"
      end,
    } },
  }, function()
    local handle = { id = "h1" }
    local result = unit_lifecycle.destroy_unit(handle)
    lu.assertEvalToTrue(result == true, "destroy_unit should report success as true, not the host return value")
    lu.assertEvalToTrue(seen == handle, "destroy_unit should forward the handle verbatim")
  end)
end

function TestUnits:test_destroy_unit_with_children_coerces_include_children_to_a_boolean_and_returns_true()
  local seen = {}
  with_patches({
    { key = "GameAPI", value = {
      destroy_unit_with_children = function(handle, include_children)
        seen[#seen + 1] = { handle = handle, include_children = include_children }
        return "ignored"
      end,
    } },
  }, function()
    local handle = { id = "h2" }

    lu.assertEvalToTrue(unit_lifecycle.destroy_unit_with_children(handle, true) == true,
      "destroy_unit_with_children should return true on success")
    lu.assertEvalToTrue(seen[1].handle == handle, "handle should be forwarded verbatim")
    lu.assertEvalToTrue(seen[1].include_children == true, "include_children=true should stay true")

    lu.assertEvalToTrue(unit_lifecycle.destroy_unit_with_children(handle, "yes") == true,
      "truthy-but-not-true include_children should still succeed")
    lu.assertEvalToTrue(seen[2].include_children == false,
      "non-boolean include_children should be coerced to false via == true")

    lu.assertEvalToTrue(unit_lifecycle.destroy_unit_with_children(handle) == true,
      "omitted include_children should still succeed")
    lu.assertEvalToTrue(seen[3].include_children == false, "nil include_children should be coerced to false")
  end)
end


return TestUnits
