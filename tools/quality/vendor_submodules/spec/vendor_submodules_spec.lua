---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/vendor_submodules/spec/vendor_submodules_spec.lua") end

require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")
local vendor_submodules = require("tools.quality.vendor_submodules")

local function _run(cwd, args)
  local result = common.run_command(args, { cwd = cwd })
  assert.is_true(result.ok, result.output)
  return result.output
end

local function _git(cwd, args)
  local command = { "git" }
  for _, value in ipairs(args) do
    command[#command + 1] = value
  end
  return _run(cwd, command)
end

local function _configure_repo(path)
  _git(path, { "config", "user.email", "tooling@example.invalid" })
  _git(path, { "config", "user.name", "Tooling Spec" })
end

local function _commit_all(path, message)
  _git(path, { "add", "." })
  _git(path, { "commit", "-m", message })
end

local function _make_submodule_remote(root)
  local source = common.join_path(root, "remote-source")
  local bare = common.join_path(root, "remote.git")
  assert.is_true(common.ensure_dir(source))
  _git(source, { "init" })
  _configure_repo(source)
  _git(source, { "checkout", "-b", "main" })
  assert.is_true(common.write_file(common.join_path(source, "tool.lua"), "return true\n"))
  _commit_all(source, "initial")
  _git(root, { "clone", "--bare", source, bare })
  return bare
end

local function _make_superproject(root)
  local remote = _make_submodule_remote(root)
  local repo = common.join_path(root, "repo")
  assert.is_true(common.ensure_dir(repo))
  _git(repo, { "init" })
  _configure_repo(repo)
  _git(repo, { "checkout", "-b", "main" })
  _git(repo, {
    "-c",
    "protocol.file.allow=always",
    "submodule",
    "add",
    "-b",
    "main",
    remote,
    "vendor/tool",
  })
  _commit_all(repo, "add vendor submodule")
  return repo
end

local function _with_fixture(fn)
  local root = common.make_temp_path("vendor_submodules_spec", "")
  common.remove_path(root)
  assert.is_true(common.ensure_dir(root))
  local repo = _make_superproject(root)
  local ok, err = xpcall(function()
    fn(repo)
  end, debug.traceback)
  common.remove_path(root)
  if not ok then
    error(err)
  end
end

describe("vendor_submodules.check", function()
  it("passes when the recorded gitlink, checkout, and origin/main agree", function()
    _with_fixture(function(repo)
      local result = vendor_submodules.check({ root = repo, fetch = false })

      assert.is_true(result.ok)
      assert.are.equal(1, result.worktree_count)
      assert.are.equal(1, result.submodule_count)
      assert.are.equal(0, #result.issues)
    end)
  end)

  it("fails when a vendor submodule working tree is dirty", function()
    _with_fixture(function(repo)
      assert.is_true(common.write_file(common.join_path(repo, "vendor/tool/tool.lua"), "return false\n"))

      local result = vendor_submodules.check({ root = repo, fetch = false })

      assert.is_false(result.ok)
      assert.is_true(#result.issues >= 1)
      assert.is_truthy(result.issues[1].message:find("dirty", 1, true))
    end)
  end)
end)
