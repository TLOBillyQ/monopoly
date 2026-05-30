---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "spec/support/log_warns_handler/spec/log_warns_handler_spec.lua") end
require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")

local project_root = common.normalize_path(common.current_dir())

local function _cleanup_tmp(tmp_root)
  local ok, err = common.remove_path(tmp_root)
  if ok == nil then
    error(err)
  end
end

local function _with_tmp(tag, fn)
  local tmp_root = common.make_temp_path("log_warns_handler_" .. tostring(tag or "tmp"), "")
  _cleanup_tmp(tmp_root)
  local ok, err = xpcall(function()
    fn(tmp_root)
  end, debug.traceback)
  _cleanup_tmp(tmp_root)
  if not ok then
    error(err)
  end
end

local function _write_noisy_spec(path)
  local ok, err = common.write_file(path, table.concat({
    "describe('noisy output', function()",
    "  it('keeps failures readable', function()",
    "    print('0 [info] noisy info line')",
    "    print('plain diagnostic line')",
    "    print('0 [warn] custom warning line')",
    "    assert.is_true(false, 'boom failure')",
    "  end)",
    "end)",
    "",
  }, "\n"))
  assert.is_true(ok, tostring(err))
end

local function _run_with_handler(spec_path, extra_args)
  local args = {
    os.getenv("BUSTED_BIN") or "busted",
    "--helper=spec/helper.lua",
    "--output=spec/log_warns_handler.lua",
  }
  for _, value in ipairs(extra_args or {}) do
    args[#args + 1] = value
  end
  args[#args + 1] = spec_path
  return common.run_command(args, { cwd = project_root })
end

local function _run_verbose_drop_info(spec_path)
  local busted_bin = os.getenv("BUSTED_BIN") or "busted"
  local run_command = common.build_command({
    busted_bin,
    "--helper=spec/helper.lua",
    "--output=spec/log_warns_handler.lua",
    "-Xoutput",
    "drop-info",
    spec_path,
  })
  local command
  if common.is_windows() then
    command = 'set "MONO_TEST_VERBOSE=1" && ' .. run_command
  else
    command = "MONO_TEST_VERBOSE=1 " .. run_command
  end
  return common.run_command(command, { cwd = project_root })
end

describe("log_warns_handler drop-info output option", function()
  it("preserves captured info lines by default", function()
    _with_tmp("default", function(tmp_root)
      local spec_path = common.join_path(tmp_root, "noisy_spec.lua")
      _write_noisy_spec(spec_path)

      local result = _run_with_handler(spec_path)

      assert.is_false(result.ok)
      assert.is_truthy(result.output:find("0 %[info%] noisy info line"))
      assert.is_truthy(result.output:find("plain diagnostic line", 1, true))
      assert.is_truthy(result.output:find("# WARN 0 [warn] custom warning line", 1, true))
      assert.is_truthy(result.output:find("boom failure", 1, true))
    end)
  end)

  it("drops captured info lines when requested", function()
    _with_tmp("drop_info", function(tmp_root)
      local spec_path = common.join_path(tmp_root, "noisy_spec.lua")
      _write_noisy_spec(spec_path)

      local result = _run_with_handler(spec_path, { "-Xoutput", "drop-info" })

      assert.is_false(result.ok)
      assert.is_nil(result.output:find("0 %[info%] noisy info line"))
      assert.is_truthy(result.output:find("plain diagnostic line", 1, true))
      assert.is_truthy(result.output:find("# WARN 0 [warn] custom warning line", 1, true))
      assert.is_truthy(result.output:find("boom failure", 1, true))
      assert.is_truthy(result.output:find("1 FAIL", 1, true))
    end)
  end)

  it("does not drop info lines in verbose mode", function()
    _with_tmp("verbose_drop_info", function(tmp_root)
      local spec_path = common.join_path(tmp_root, "noisy_spec.lua")
      _write_noisy_spec(spec_path)

      local result = _run_verbose_drop_info(spec_path)

      assert.is_false(result.ok)
      assert.is_truthy(result.output:find("0 %[info%] noisy info line"))
      assert.is_truthy(result.output:find("not ok 1 -", 1, true))
    end)
  end)
end)
