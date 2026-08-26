require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.debug_flags_guard")

-- 每一条都喂合成的配置内容,断言 guard 对「联调开关被翻成 true」真的会红、
-- 对合规内容放行——门禁的价值全在能变红。
--
-- 原生 LuaUnit 试点(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 断言词汇从 luassert 兼容层切到 lu.assertXxx,用例数与改写前一一对应(6 例)。

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

TestDebugFlagsGuard = {}

function TestDebugFlagsGuard:test_passes_when_debug_auto_all_roles_is_false()
  local violations = _check({ [_PATH] = _OFF })
  lu.assertEquals(#violations, 0)
end

function TestDebugFlagsGuard:test_flags_debug_auto_all_roles_true_as_a_release_leak()
  local violations = _check({
    [_PATH] = "return resettable_defaults.build({\n  debug_auto_all_roles = true,\n})\n",
  })
  lu.assertEquals(#violations, 1)
  local message = violations[1]
  lu.assertEvalToTrue(message:find(_PATH, 1, true))
  lu.assertEvalToTrue(message:find("必须为 false", 1, true))
end

function TestDebugFlagsGuard:test_reports_the_line_number_of_the_offending_assignment()
  local violations = _check({
    [_PATH] = "-- header\ndebug_auto_all_roles = true\n",
  })
  lu.assertEquals(#violations, 1)
  lu.assertEvalToTrue(violations[1]:find(_PATH .. ":2", 1, true))
end

function TestDebugFlagsGuard:test_ignores_the_flag_name_inside_comments()
  local violations = _check({
    [_PATH] = "-- 联调时临时改:debug_auto_all_roles = true\ndebug_auto_all_roles = false\n",
  })
  lu.assertEquals(#violations, 0)
end

function TestDebugFlagsGuard:test_ignores_unrelated_tracked_files()
  local violations = _check({
    ["src/config/gameplay/timing.lua"] = "debug_auto_all_roles = true\n",
  })
  lu.assertEquals(#violations, 0)
end

function TestDebugFlagsGuard:test_flags_an_unreadable_flags_file_instead_of_silently_skipping_it()
  local violations = guard.check({ _PATH }, function()
    return nil
  end)
  lu.assertEquals(#violations, 1)
  lu.assertEvalToTrue(violations[1]:find("读不到", 1, true))
end


return TestDebugFlagsGuard
