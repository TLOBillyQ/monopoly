-- APS 三件转发器 specs 的共享探针(工具测试 support,不是 spec,故不叫 test_*)。
--
-- 为什么抽出来:转发器正文、幂等落盘、根解析现在分住三个模块,三份 spec 都要
-- 「起沙箱 + 写打桩入口 + 真跑 bash 转发器 + 读回 argv」。这四件事本身没有断言,
-- 只有观察形状;留在某个 spec 里就会变成另外两个 spec 的复制源。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local provision = require("packages.acceptance.provision")

local probe = {}

-- 沙箱根:一次性临时目录,进出都清。fn 抛错也要清完再把错抛出去(带 traceback)。
function probe.with_sandbox(name, fn)
  local root = env_lib.make_temp_path("aps_" .. name .. "_", "")
  fs_lib.remove_path(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

function probe.tool_path(root, tool)
  return path_lib.join_path(root, ".swarmforge", "bin", tool.name)
end

-- 沙箱内落盘:解释器钉死成 "lua",免得探测结果随机器漂——断言要的是正文形状。
function probe.sandbox_provision(root, tools)
  return provision.provision({
    bin_dir = path_lib.join_path(root, ".swarmforge", "bin"),
    lua_bin = "lua",
    tools = tools,
  })
end

-- 打桩入口:把收到的 argv 逐行写进 record 后退 0。转发器是否真把参数递到本仓 Lua 入口,
-- 只看这份记录,不看转发器的自我声明。
function probe.write_recording_stub(stub_path, record_path)
  local ok, err = fs_lib.write_file(stub_path, table.concat({
    "local file = io.open(" .. string.format("%q", record_path) .. ", \"w\")",
    "file:write(table.concat(arg or {}, \"\\n\") .. \"\\n\")",
    "file:close()",
    "os.exit(0)",
    "",
  }, "\n"))
  lu.assertTrue(ok, "打桩入口写入失败: " .. tostring(err))
end

function probe.recorded_argv(record_path)
  local content = fs_lib.read_raw(record_path) or ""
  local argv = {}
  -- 逐行只认「行尾真有换行」的元素:记录体自带收尾换行,再拼一次会多出一个空 argv。
  for line in content:gmatch("([^\n]*)\n") do
    argv[#argv + 1] = line
  end
  return argv
end

-- argv 里 --flag value 只认「紧邻成对」这一种真实形状。
function probe.pair_index(argv, flag, value)
  for index = 1, #argv - 1 do
    if argv[index] == flag and argv[index + 1] == value then
      return index
    end
  end
  return nil
end

function probe.assert_pair(argv, flag, value, message)
  lu.assertNotNil(probe.pair_index(argv, flag, value),
    message .. "(实得: " .. table.concat(argv, " ") .. ")")
end

function probe.assert_no_pair(argv, flag, value)
  lu.assertNil(probe.pair_index(argv, flag, value),
    flag .. " " .. value .. " 不该再出现在 argv 里: " .. table.concat(argv, " "))
end

function probe.require_bash_and_lua()
  lu.assertTrue(proc_lib.command_exists("bash") and proc_lib.command_exists("lua"),
    "需要 bash 与 lua 才能真跑转发器")
end

return probe
