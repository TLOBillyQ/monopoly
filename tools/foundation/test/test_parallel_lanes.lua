---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()
local lu = require("luaunit")
local env = require("foundation.env")
local fs = require("foundation.fs")
local proc = require("foundation.proc")
local shell = require("foundation.shell")
local parallel = require("foundation.parallel_lanes")
local native_lua = assert(arg[-1], "native Lua interpreter identity required")

TestParallelLanes = {}

local function fixture(body)
  local root = env.make_temp_path("parallel_中文 space", "")
  assert(fs.ensure_dir(root))
  local ok, err = xpcall(function() body(root) end, debug.traceback)
  assert(fs.remove_path(root))
  assert(ok, err)
end

local function script(root, name, text)
  local file = root .. "/" .. name .. ".lua"
  assert(fs.write_file(file, text))
  return file
end

function TestParallelLanes:test_success_failure_missing_command_and_empty_output_are_distinct()
  fixture(function(root)
    local writer = script(root, "writer", 'local d=os.time()+2; while os.time()<d do end; print("中文 success")')
    local success = 'start "" /b lua "' .. writer:gsub("/", "\\") .. '"'
    local failure = script(root, "bad", 'print("out"); io.stderr:write("err\\n"); os.exit(4)')
    local silent = script(root, "empty", "os.exit(0)")
    local ok, results = parallel.run({
      { label = "ok", cmd = success },
      { label = "bad", cmd = shell.build_command({ "lua", failure }) },
      { label = "missing", cmd = shell.build_command({ root .. "/missing_91.exe" }) },
      { label = "empty", cmd = shell.build_command({ "lua", silent }) },
    }, { stream = false, timeout = 20 })
    lu.assertFalse(ok)
    lu.assertEquals(#results, 4)
    lu.assertEquals(results[1].label, "ok")
    lu.assertTrue(results[1].ok)
    lu.assertEquals(results[1].exit_code, 0)
    lu.assertNotEquals(results[1].owner_pid, nil)
    lu.assertNotEquals(results[1].child_pid, nil)
    lu.assertStrContains(results[1].output, "中文 success")
    lu.assertEquals(results[2].reason, "exit")
    lu.assertEquals(results[2].exit_code, 4)
    lu.assertStrContains(results[2].output, "err")
    lu.assertEquals(results[3].reason, "launch_failed")
    lu.assertEquals(results[3].exit_code, 9009)
    lu.assertNotEquals(results[3].output, "")
    lu.assertEquals(results[4].reason, "output_incomplete")
    lu.assertEquals(results[4].exit_code, 0)
    lu.assertNotEquals(results[4].message, nil)
  end)
end

function TestParallelLanes:test_parallel_and_serial_preserve_order_results_and_chinese_arguments()
  fixture(function(root)
    local file = script(root, "echo args", 'for i=1,#arg do print(arg[i]) end; os.exit(tonumber(arg[1]))')
    local first = { "lua", file, "0", "", "中文 space", 'quote"and&pipe|', "%PATH%", "bang!caret^", "tail\\" }
    local second = { "lua", file, "5", "参数 空格" }
    local lanes = {
      { label = "first", cmd = first },
      { label = "second", cmd = second },
    }
    local ok, results = parallel.run(lanes, { stream = false, timeout = 20 })
    lu.assertFalse(ok)
    for index, lane in ipairs(lanes) do
      local serial = proc.run_command(lane.cmd)
      lu.assertEquals(results[index].label, lane.label)
      lu.assertEquals(results[index].ok, serial.ok)
      lu.assertEquals(results[index].exit_code, serial.code)
      lu.assertEquals(results[index].output, serial.output)
    end
  end)
end

function TestParallelLanes:test_lua_argv_exceeds_cmd_limit_and_lanes_overlap()
  fixture(function(root)
    local file = script(root, "wait", [[
local started=os.time()
local deadline=started+3
while os.time()<deadline do end
print('INTERVAL '..started..' '..os.time())
print(#arg)
print(arg[1])
]])
    local args = { "lua", file }
    for i = 1, 1000 do args[#args + 1] = "中文 argument space" end
    local ok, results = parallel.run({
      { label = "a", cmd = args }, { label = "b", cmd = args },
    }, { stream = false, timeout = 20 })
    lu.assertTrue(ok)
    local a_start, a_end = results[1].output:match("INTERVAL (%d+) (%d+)")
    local b_start, b_end = results[2].output:match("INTERVAL (%d+) (%d+)")
    lu.assertTrue(math.max(tonumber(a_start), tonumber(b_start)) < math.min(tonumber(a_end), tonumber(b_end)), "actual worker intervals must overlap")
    lu.assertStrContains(results[1].output, "1000")
    lu.assertStrContains(results[2].output, "中文 argument space")
  end)
end

function TestParallelLanes:test_timeout_stops_delayed_write_and_preserves_unowned_files()
  fixture(function(root)
    local marker = root .. "/late.txt"
    local file = script(root, "slow", [[
print("START")
io.stdout:flush()
local deadline=os.time()+8
while os.time()<deadline do end
local f=assert(io.open(arg[1],"wb")); f:write("LATE"); f:close()
]])
    assert(fs.write_file(root .. "/owned/sentinel.txt", "keep"))
    local ok, results = parallel.run({ { label = "slow", cmd = { native_lua, file, marker } } },
      { stream = false, timeout = 2, lane_dir = root .. "/owned" })
    lu.assertFalse(ok)
    lu.assertEquals(results[1].reason, "timeout")
    lu.assertStrContains(results[1].output, "START")
    lu.assertNil(results[1].artifact_dir, "termination and cleanup must succeed")
    proc.run_command({ "lua", "-e", "local d=os.time()+9; while os.time()<d do end; print('WAIT')" })
    lu.assertFalse(fs.path_exists(marker), "timed-out child must not perform its delayed write")
    lu.assertEquals(fs.read_raw(root .. "/owned/sentinel.txt"), "keep")
    lu.assertEquals(#assert(proc.collect_files(root .. "/owned")), 1)
  end)
end

function TestParallelLanes:test_builtin_windows_owner_requires_no_external_compiler()
  fixture(function(root)
    local file = script(root, "builtin", 'print("BUILTIN_ONLY")')
    local driver = script(root, "driver", 'require("test.bootstrap").install_package_paths(); local ok,r=require("foundation.parallel_lanes").run({{label="builtin",cmd={' .. string.format('%q', native_lua) .. ',' .. string.format('%q', file) .. '}}},{stream=false,timeout=20}); print(r[1].output); os.exit(ok and 0 or 1)')
    local system = assert(os.getenv("SystemRoot"))
    local command = 'set "PATH=' .. system .. '\\System32;' .. system .. '\\System32\\WindowsPowerShell\\v1.0" && "' .. native_lua .. '" "' .. driver:gsub("/", "\\") .. '"'
    local result = proc.run_command(command)
    lu.assertTrue(result.ok, result.output)
    lu.assertStrContains(result.output, "BUILTIN_ONLY")
  end)
end

function TestParallelLanes:test_timeout_stops_detached_writer_after_command_parent_exits()
  fixture(function(root)
    local marker = root .. "/detached_late.txt"
    local file = script(root, "detached", 'print("DETACHED_START"); io.stdout:flush(); local d=os.time()+6; while os.time()<d do end; local f=assert(io.open(arg[1],"wb")); f:write("LATE"); f:close()')
    local command = 'start "" /b "' .. native_lua .. '" "' .. file:gsub("/", "\\") .. '" "' .. marker:gsub("/", "\\") .. '"'
    local ok, results = parallel.run({{label="detached", cmd=command}}, {stream=false, timeout=2})
    lu.assertFalse(ok)
    lu.assertEquals(results[1].reason, "timeout")
    lu.assertStrContains(results[1].output, "DETACHED_START")
    lu.assertNil(results[1].artifact_dir)
    proc.run_command({native_lua, "-e", "local d=os.time()+7; while os.time()<d do end; print('WAIT')"})
    lu.assertFalse(fs.path_exists(marker), "detached owned writer must stop before timeout result returns")
  end)
end

return TestParallelLanes
