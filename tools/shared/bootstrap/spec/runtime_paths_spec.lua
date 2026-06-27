---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/shared/bootstrap/spec/runtime_paths_spec.lua") end

require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")

local runtime_paths = dofile("tools/shared/runtime_paths.lua")

describe("shared.runtime_paths", function()
  it("resolves a repo root from the lockfile-based tool layout", function()
    local root = common.join_path(
      "tmp",
      "runtime_paths_spec_$__monopoly_runtime_paths_unset__ path"
    )
    common.remove_path(root)

    assert.is_true(common.ensure_dir(common.join_path(root, "src")))
    assert.is_true(common.ensure_dir(common.join_path(root, "spec")))
    assert.is_true(common.ensure_dir(common.join_path(root, "tools/shared")))
    assert.is_true(common.ensure_dir(common.join_path(root, "swarmforge")))
    assert.is_true(common.write_file(common.join_path(root, "swarmforge/tools.lock"), ""))

    local env = runtime_paths.resolve({
      cwd = root,
      source_path = "tools/shared/bootstrap.lua",
    })

    common.remove_path(root)

    assert.are.equal(common.normalize_path(root), env.repo_root)
    assert.are.equal(common.join_path(common.normalize_path(root), ".swarmforge/tools"), env.tool_cache_dir)
  end)
end)
