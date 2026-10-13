require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- ui_role_globals.lua 直测：install 的守卫(非表→空表)、双全局注册、返回值契约。
-- 宿主无关(纯模块,写 _G.ALLROLES / _G.all_roles),setUp/tearDown 清理全局防串味。

local role_globals = require("src.state.ui_role_globals")

describe("TestUIRoleGlobals", function()

  before_each(function()
    _G.ALLROLES = nil
    _G.all_roles = nil
  end)

  after_each(function()
    _G.ALLROLES = nil
    _G.all_roles = nil
  end)

  it("test_install_registers_the_same_table_under_both_globals", function()
    local roles = { "r1", "r2" }
    local resolved = role_globals.install(roles)

    luassert.truthy(resolved == roles, "should return the caller table unchanged")
    luassert.truthy(_G.ALLROLES == roles, "ALLROLES should point at the caller table")
    luassert.truthy(_G.all_roles == roles, "all_roles should point at the caller table")
  end)

  it("test_install_treats_nil_as_an_empty_roles_table", function()
    local resolved = role_globals.install(nil)

    luassert.truthy(type(resolved) == "table" and next(resolved) == nil, "nil should resolve to an empty table")
    luassert.truthy(_G.ALLROLES == resolved, "ALLROLES should mirror the resolved table")
    luassert.truthy(_G.all_roles == resolved, "all_roles should mirror the resolved table")
  end)

  it("test_install_rejects_non_table_input_with_an_empty_table", function()
    local resolved = role_globals.install("not-a-table")

    luassert.truthy(type(resolved) == "table" and next(resolved) == nil, "a non-table should resolve to an empty table")
    luassert.truthy(_G.ALLROLES == resolved and _G.all_roles == resolved, "both globals should share the resolved table")
  end)

end)
