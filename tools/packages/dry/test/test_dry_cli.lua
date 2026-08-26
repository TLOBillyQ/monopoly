---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/dry/test/test_dry_cli.lua") end

require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")

local function _write_fixture(root)
  local ok, err = fs_lib.ensure_dir(root)
  lu.assertTrue(ok, tostring(err))
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
  ok, err = fs_lib.write_file(path_lib.join_path(root, "duplicates.lua"), content)
  lu.assertTrue(ok, tostring(err))
end

local function _with_fixture(fn)
  local root = env_lib.make_temp_path("dry_cli_spec", "")
  fs_lib.remove_path(root)
  _write_fixture(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
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

-- dry.lua text output budget
TestDryCli = {}

function TestDryCli:test_limits_text_duplicate_rows_and_reports_the_omitted_count()
  _with_fixture(function(root)
    local result = proc_lib.run_command({
      "lua",
      "tools/packages/dry/runner.lua",
      "--threshold", "1",
      "--min-lines", "1",
      "--min-nodes", "1",
      "--limit", "1",
      root,
    })

    lu.assertTrue(result.ok, result.output)
    lu.assertIs(_duplicate_count(result.output), 1)
    lu.assertEvalToTrue(result.output:find("Showing 1 of", 1, true), result.output)
    lu.assertEvalToTrue(result.output:find("--limit 0", 1, true), result.output)
  end)
end

function TestDryCli:test_prints_all_text_duplicate_rows_when_limit_is_zero()
  _with_fixture(function(root)
    local result = proc_lib.run_command({
      "lua",
      "tools/packages/dry/runner.lua",
      "--threshold", "1",
      "--min-lines", "1",
      "--min-nodes", "1",
      "--limit", "0",
      root,
    })

    lu.assertTrue(result.ok, result.output)
    lu.assertTrue(_duplicate_count(result.output) > 1, result.output)
    lu.assertNil(result.output:find("Showing", 1, true))
  end)
end


return TestDryCli
