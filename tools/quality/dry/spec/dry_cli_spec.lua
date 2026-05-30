---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/dry/spec/dry_cli_spec.lua") end

require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")

local function _write_fixture(root)
  local ok, err = common.ensure_dir(root)
  assert.is_true(ok, tostring(err))
  local content = table.concat({
    "local M = {}",
    "function M.first(value)",
    "  if value then",
    "    return value + 1",
    "  end",
    "  return 0",
    "end",
    "function M.second(value)",
    "  if value then",
    "    return value + 1",
    "  end",
    "  return 0",
    "end",
    "function M.third(value)",
    "  if value then",
    "    return value + 1",
    "  end",
    "  return 0",
    "end",
    "return M",
    "",
  }, "\n")
  ok, err = common.write_file(common.join_path(root, "duplicates.lua"), content)
  assert.is_true(ok, tostring(err))
end

local function _with_fixture(fn)
  local root = common.make_temp_path("dry_cli_spec", "")
  common.remove_path(root)
  _write_fixture(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  common.remove_path(root)
  if not ok then
    error(err)
  end
end

local function _duplicate_count(output)
  local count = 0
  for _ in tostring(output or ""):gmatch("DUPLICATE score=") do
    count = count + 1
  end
  return count
end

describe("dry.lua text output budget", function()
  it("limits text duplicate rows and reports the omitted count", function()
    _with_fixture(function(root)
      local result = common.run_command({
        "lua",
        "tools/quality/dry.lua",
        "--threshold", "1",
        "--min-lines", "1",
        "--min-nodes", "1",
        "--limit", "1",
        root,
      })

      assert.is_true(result.ok, result.output)
      assert.are.equal(1, _duplicate_count(result.output))
      assert.is_truthy(result.output:find("Showing 1 of", 1, true), result.output)
      assert.is_truthy(result.output:find("--limit 0", 1, true), result.output)
    end)
  end)

  it("prints all text duplicate rows when limit is zero", function()
    _with_fixture(function(root)
      local result = common.run_command({
        "lua",
        "tools/quality/dry.lua",
        "--threshold", "1",
        "--min-lines", "1",
        "--min-nodes", "1",
        "--limit", "0",
        root,
      })

      assert.is_true(result.ok, result.output)
      assert.is_true(_duplicate_count(result.output) > 1, result.output)
      assert.is_nil(result.output:find("Showing", 1, true))
    end)
  end)
end)
