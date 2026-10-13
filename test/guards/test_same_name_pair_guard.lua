require("test.bootstrap").install_package_paths()

local luassert = assert
local guard = require("test.guards.lib.same_name_pair_guard")

-- #298 的发现式包结构 guard：禁止新增 foo.lua + foo/test/
-- 同名对,存量同名对白名单豁免(只许减不许增)。下面每一条都喂合成的路径表,
-- 断言它真的会红/会绿——门禁的价值全在能变红。

-- 合成白名单:让本 spec 语料无关(项目白名单快照为空时判定分支照样被验)。
local _SYNTHETIC_WHITELIST = {
  ["tools/packages/arch_view"] = true,
  ["test/support/behavior_parallel"] = true,
}

local function _check(paths, whitelist)
  return guard.check(paths, whitelist or _SYNTHETIC_WHITELIST)
end

local function _joined(violations)
  return table.concat(violations, "\n")
end

describe("TestSameNamePairGuard", function()
  -- 新同名对(白名单外)必须被拦:foo.lua + foo/test/ 并存。
  it("test_new_same_name_pair_is_blocked", function()
    local violations = _check({
      "tools/packages/foo.lua",
      "tools/packages/foo/test/test_foo.lua",
    })
    luassert.is.equal(1, #violations, _joined(violations))
    luassert.truthy(violations[1]:find("同名对", 1, true))
  end)

  -- 目录即包形态(<pkg>/test/ 无同名 .lua)不违规——新测试的正规落点。
  it("test_pkg_test_without_peer_lua_is_allowed", function()
    local violations = _check({
      "tools/packages/verify/test/test_verify.lua",
      "tools/packages/verify/cli.lua",
    })
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  -- 白名单内存量同名对豁免(迁移期并存,由迁移工单销账)。
  it("test_whitelisted_pair_is_allowed", function()
    local violations = _check({
      "tools/packages/arch_view.lua",
      "tools/packages/arch_view/test/test_arch_view.lua",
      "test/support/behavior_parallel.lua",
      "test/support/behavior_parallel/test/test_behavior_parallel.lua",
    })
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  -- 同一白名单条目在多层深度(test/support/foo/test/... 嵌套)也生效。
  it("test_deeply_nested_test_dir_detected", function()
    local violations = _check({
      "test/support/bar.lua",
      "test/support/bar/test/sub/deep.lua",
    })
    luassert.is.equal(1, #violations, _joined(violations))
    luassert.truthy(violations[1]:find("test/support/bar.lua", 1, true))
  end)

  -- 只有 test/ 目录而没有同名 .lua 文件 → 不是同名对,不违规。
  it("test_test_dir_without_peer_lua_is_allowed", function()
    local violations = _check({
      "tools/packages/luaunit_runner/test/test_events.lua",
    })
    luassert.is.equal(0, #violations, _joined(violations))
  end)

  -- 同名 .lua 存在但没有 test/ 目录 → 不是同名对,不违规。
  it("test_peer_lua_without_test_dir_is_allowed", function()
    local violations = _check({
      "tools/packages/coverage/coverage_config.lua",
    })
    luassert.is.equal(0, #violations, _joined(violations))
  end)
end)
