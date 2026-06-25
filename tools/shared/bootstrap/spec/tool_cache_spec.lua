---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/shared/bootstrap/spec/tool_cache_spec.lua") end

require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local tool_cache = require("shared.tool_cache")

describe("shared.tool_cache", function()
  it("parses the lockfile format", function()
    local lock, err = tool_cache.parse_lock_contents([[
# comment
mutate4lua https://example.invalid/mutate4lua.git 0123456789abcdef
dry4lua https://example.invalid/dry4lua.git fedcba9876543210
]])

    assert.is_nil(err)
    assert.is_not_nil(lock)
    assert.are.equal("https://example.invalid/mutate4lua.git", lock.tools.mutate4lua.repo)
    assert.are.equal("0123456789abcdef", lock.tools.mutate4lua.commit)
    assert.are.same({ "mutate4lua", "dry4lua" }, lock.ordered)
  end)

  it("rejects unknown tools", function()
    local lock, err = tool_cache.parse_lock_contents(
      "unknown https://example.invalid/tool.git 0123456789abcdef\n"
    )

    assert.is_nil(lock)
    assert.is_truthy(tostring(err):find("unknown tool", 1, true))
  end)

  it("installs cache package paths without cloning", function()
    local root = common.make_temp_path("tool_cache_spec", "")
    common.remove_path(root)
    assert.is_true(common.ensure_dir(common.join_path(root, "swarmforge")))
    assert.is_true(common.write_file(common.join_path(root, "swarmforge/tools.lock"), table.concat({
      "acceptance4lua https://example.invalid/acceptance4lua.git 1111111111111111111111111111111111111111",
      "arch_view https://example.invalid/arch_view.git 2222222222222222222222222222222222222222",
      "",
    }, "\n")))

    local original = package.path
    package.path = "/sentinel/?.lua"
    local ok, err = tool_cache.install_locked_tool_paths({ repo_root = root })
    local path = package.path
    package.path = original
    common.remove_path(root)

    assert.is_true(ok, err)
    assert.is_truthy(path:find(".swarmforge/tools/acceptance4lua@1111111111111111111111111111111111111111/lib/%?%.lua"))
    assert.is_truthy(path:find(".swarmforge/tools/arch_view@2222222222222222222222222222222222222222/lib/%?/init%.lua"))
  end)
end)
