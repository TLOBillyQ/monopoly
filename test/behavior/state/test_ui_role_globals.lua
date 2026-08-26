-- ui_role_globals.lua 直测：install 的守卫(非表→空表)、双全局注册、返回值契约。
-- 宿主无关(纯模块,写 _G.ALLROLES / _G.all_roles),setUp/tearDown 清理全局防串味。
local lu = require("luaunit")

local role_globals = require("src.state.ui_role_globals")

TestUIRoleGlobals = {}

function TestUIRoleGlobals:setUp()
  _G.ALLROLES = nil
  _G.all_roles = nil
end

function TestUIRoleGlobals:tearDown()
  _G.ALLROLES = nil
  _G.all_roles = nil
end

function TestUIRoleGlobals:test_install_registers_the_same_table_under_both_globals()
  local roles = { "r1", "r2" }
  local resolved = role_globals.install(roles)

  lu.assertEvalToTrue(resolved == roles, "should return the caller table unchanged")
  lu.assertEvalToTrue(_G.ALLROLES == roles, "ALLROLES should point at the caller table")
  lu.assertEvalToTrue(_G.all_roles == roles, "all_roles should point at the caller table")
end

function TestUIRoleGlobals:test_install_treats_nil_as_an_empty_roles_table()
  local resolved = role_globals.install(nil)

  lu.assertEvalToTrue(type(resolved) == "table" and next(resolved) == nil,
    "nil should resolve to an empty table")
  lu.assertEvalToTrue(_G.ALLROLES == resolved, "ALLROLES should mirror the resolved table")
  lu.assertEvalToTrue(_G.all_roles == resolved, "all_roles should mirror the resolved table")
end

function TestUIRoleGlobals:test_install_rejects_non_table_input_with_an_empty_table()
  local resolved = role_globals.install("not-a-table")

  lu.assertEvalToTrue(type(resolved) == "table" and next(resolved) == nil,
    "a non-table should resolve to an empty table")
  lu.assertEvalToTrue(_G.ALLROLES == resolved and _G.all_roles == resolved,
    "both globals should share the resolved table")
end

return TestUIRoleGlobals
