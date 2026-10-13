require("test.bootstrap").install_package_paths()

local luassert = assert
local guard = require("test.guards.lib.debug_flags_guard")

-- 每一条都喂合成的配置内容,断言 guard 对「联调开关被翻成 true」真的会红、
-- 对合规内容放行——门禁的价值全在能变红。

local _PATH = "src/config/gameplay/debug_flags.lua"

local function _reader(files)
  return function(path)
    return files[path]
  end
end

local function _check(files)
  local paths = {}
  for path in pairs(files) do
    paths[#paths + 1] = path
  end
  return guard.check(paths, _reader(files))
end

local _OFF = "return resettable_defaults.build({\n  debug_auto_all_roles = false,\n})\n"

describe("TestDebugFlagsGuard", function()
  it("test_passes_when_debug_auto_all_roles_is_false", function()
    local violations = _check({ [_PATH] = _OFF })
    luassert.is.equal(0, #violations)
  end)

  it("test_flags_debug_auto_all_roles_true_as_a_release_leak", function()
    local violations = _check({
      [_PATH] = "return resettable_defaults.build({\n  debug_auto_all_roles = true,\n})\n",
    })
    luassert.is.equal(1, #violations)
    local message = violations[1]
    luassert.truthy(message:find(_PATH, 1, true))
    luassert.truthy(message:find("必须为 false", 1, true))
  end)

  it("test_reports_the_line_number_of_the_offending_assignment", function()
    local violations = _check({
      [_PATH] = "-- header\ndebug_auto_all_roles = true\n",
    })
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find(_PATH .. ":2", 1, true))
  end)

  it("test_ignores_the_flag_name_inside_comments", function()
    local violations = _check({
      [_PATH] = "-- 联调时临时改:debug_auto_all_roles = true\ndebug_auto_all_roles = false\n",
    })
    luassert.is.equal(0, #violations)
  end)

  it("test_ignores_unrelated_tracked_files", function()
    local violations = _check({
      ["src/config/gameplay/timing.lua"] = "debug_auto_all_roles = true\n",
    })
    luassert.is.equal(0, #violations)
  end)

  it("test_flags_an_unreadable_flags_file_instead_of_silently_skipping_it", function()
    local violations = guard.check({ _PATH }, function()
      return nil
    end)
    luassert.is.equal(1, #violations)
    luassert.truthy(violations[1]:find("读不到", 1, true))
  end)
end)
