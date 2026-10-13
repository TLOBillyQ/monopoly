---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()
local lu = require("luaunit")
local env = require("foundation.env")
local fs = require("foundation.fs")
local proc = require("foundation.proc")
local shell = require("foundation.shell")
local parallel = require("foundation.parallel_lanes")

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
    local success = script(root, "ok", 'print("中文 success"); os.exit(0)')
    local failure = script(root, "bad", 'print("out"); io.stderr:write("err\\n"); os.exit(4)')
    local silent = script(root, "empty", "os.exit(0)")
    local ok, results = parallel.run({
      { label = "ok", cmd = shell.build_command({ "lua", success }) },
      { label = "bad", cmd = shell.build_command({ "lua", failure }) },
      { label = "missing", cmd = shell.build_command({ root .. "/missing_91.exe" }) },
      { label = "empty", cmd = shell.build_command({ "lua", silent }) },
    }, { stream = false, timeout = 20 })
    lu.assertFalse(ok)
    lu.assertEquals(#results, 4)
    lu.assertEquals(results[1].label, "ok")
    lu.assertTrue(results[1].ok)
    lu.assertEquals(results[1].exit_code, 0)
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
    local lanes = {
      { label = "first", cmd = shell.build_command({ "lua", file, "0", "中文 space" }) },
      { label = "second", cmd = shell.build_command({ "lua", file, "5", "参数 空格" }) },
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
local deadline=os.time()+3
while os.time()<deadline do end
print(#arg)
print(arg[1])
]])
    local args = { "lua", file }
    for i = 1, 1000 do args[#args + 1] = "中文 argument space" end
    local started = os.time()
    local ok, results = parallel.run({
      { label = "a", cmd = args }, { label = "b", cmd = args },
    }, { stream = false, timeout = 20 })
    lu.assertTrue(ok)
    lu.assertTrue(os.time() - started < 6, "three-second lanes must overlap")
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
    local ok, results = parallel.run({ { label = "slow", cmd = { "lua", file, marker } } },
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

return TestParallelLanes
