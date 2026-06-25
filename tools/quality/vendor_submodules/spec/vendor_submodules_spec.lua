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

local function _make_tool_repo(root)
  local source = common.join_path(root, "mutate4lua-source")
  assert.is_true(common.ensure_dir(common.join_path(source, "lib/mutate4lua")))
  _git(source, { "init" })
  _configure_repo(source)
  _git(source, { "checkout", "-b", "main" })
  assert.is_true(common.write_file(common.join_path(source, "lib/mutate4lua/cli.lua"), "return {}\n"))
  _commit_all(source, "initial tool")
  local hash = _git(source, { "rev-parse", "HEAD" }):gsub("%s+$", "")
  local bare = common.join_path(root, "mutate4lua.git")
  _git(root, { "clone", "--bare", source, bare })
  return bare, hash
end

local function _make_project(root, repo, hash)
  local project = common.join_path(root, "repo")
  assert.is_true(common.ensure_dir(common.join_path(project, "swarmforge")))
  assert.is_true(common.write_file(common.join_path(project, "swarmforge/tools.lock"), table.concat({
    "mutate4lua " .. repo .. " " .. hash,
    "",
  }, "\n")))
  return project
end

local function _with_fixture(fn)
  local root = common.make_temp_path("tool_cache_health_spec", "")
  common.remove_path(root)
  assert.is_true(common.ensure_dir(root))
  local repo, hash = _make_tool_repo(root)
  local project = _make_project(root, repo, hash)
  local ok, err = xpcall(function()
    fn(project, hash)
  end, debug.traceback)
  common.remove_path(root)
  if not ok then
    error(err)
  end
end

describe("vendor_submodules.check", function()
  it("can ensure and validate the lockfile-pinned tool cache", function()
    _with_fixture(function(project)
      local result = vendor_submodules.check({ root = project, ensure = true })

      assert.is_true(result.ok)
      assert.are.equal(1, result.tool_count)
      assert.are.equal(0, #result.issues)
      assert.is_true(result.rows[1].cached)
    end)
  end)

  it("fails when a locked tool is missing from cache", function()
    _with_fixture(function(project)
      local result = vendor_submodules.check({ root = project, ensure = false })

      assert.is_false(result.ok)
      assert.is_truthy(result.issues[1].message:find("cache missing", 1, true))
    end)
  end)
end)
