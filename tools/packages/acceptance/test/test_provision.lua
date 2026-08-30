---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_provision.lua") end
require("test.bootstrap").install_package_paths()

-- APS 三件转发器的幂等 provision(#606)单测。
--
-- 观测面即该卡的语义:转发器正文(纯演算)、落盘与幂等(沙箱 fs)、转发契约与差分钳制
-- (真跑 bash 转发器 + 打桩入口)、SwarmForge 项目根候选(纯演算)、命令面退出码。
-- bootstrap.ensure_tool 的 luarocks 本体不在此重测(那是 foundation 既有契约,且要联网)。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local provision = require("packages.acceptance.provision")

local TOOL_NAMES = { "gherkin-parser", "ir-dry-checker", "gherkin-mutator" }
local SCRIPT = "tools/packages/acceptance/provision.lua"

local function _with_sandbox(name, fn)
  local root = env_lib.make_temp_path("aps_provision_" .. name .. "_", "")
  fs_lib.remove_path(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

-- argv 里 --flag value 只认「紧邻成对」这一种真实形状。
local function _pair_index(argv, flag, value)
  for index = 1, #argv - 1 do
    if argv[index] == flag and argv[index + 1] == value then
      return index
    end
  end
  return nil
end

local function _assert_pair(argv, flag, value, message)
  lu.assertNotNil(_pair_index(argv, flag, value),
    message .. "(实得: " .. table.concat(argv, " ") .. ")")
end

local function _assert_no_pair(argv, flag, value)
      lu.assertNil(_pair_index(argv, flag, value),
    flag .. " " .. value .. " 不该再出现在 argv 里: " .. table.concat(argv, " "))
end

-- 打桩入口:把收到的 argv 逐行写进 record 后退 0。转发器是否真把参数递到本仓 Lua 入口,
-- 只看这份记录,不看转发器的自我声明。
local function _recording_stub(stub_path, record_path)
  local ok, err = fs_lib.write_file(stub_path, table.concat({
    "local file = io.open(" .. string.format("%q", record_path) .. ", \"w\")",
    "file:write(table.concat(arg or {}, \"\\n\") .. \"\\n\")",
    "file:close()",
    "os.exit(0)",
    "",
  }, "\n"))
  lu.assertTrue(ok, "打桩入口写入失败: " .. tostring(err))
end

local function _recorded_argv(record_path)
  local content = fs_lib.read_raw(record_path) or ""
  local argv = {}
  -- 逐行只认「行尾真有换行」的元素:记录体自带收尾换行,再拼一次会多出一个空 argv。
  for line in content:gmatch("([^\n]*)\n") do
    argv[#argv + 1] = line
  end
  return argv
end

local function _tool_path(root, tool)
  return path_lib.join_path(root, ".swarmforge", "bin", tool.name)
end

local function _sandbox_provision(root, tools)
  return provision.provision({
    bin_dir = path_lib.join_path(root, ".swarmforge", "bin"),
    lua_bin = "lua",
    tools = tools,
  })
end

-- 命令面直跑真脚本(用与车道同口径的 lua5.4),退出码与输出都从子进程拿。
local function _run_command(args)
  local command = { provision.detect_lua_bin(), SCRIPT }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return proc_lib.run_command(command)
end

local function _require_bash_and_lua()
  lu.assertTrue(proc_lib.command_exists("bash") and proc_lib.command_exists("lua"),
    "需要 bash 与 lua 才能真跑转发器")
end

TestApsProvision = {}

function TestApsProvision:test_registry_names_the_three_aps_tools_on_real_project_entrypoints()
  local names = {}
  for _, tool in ipairs(provision.TOOLS) do
    names[#names + 1] = tool.name
    lu.assertIsString(tool.entrypoint, tool.name .. " 缺 entrypoint")
    lu.assertIsString(tool.contract, tool.name .. " 缺 APS 契约行")
    lu.assertEvalToTrue(fs_lib.path_exists(tool.entrypoint),
      "入口文件不存在: " .. tostring(tool.entrypoint))
  end
  lu.assertEquals(names, TOOL_NAMES)
end

function TestApsProvision:test_forwarder_body_bakes_bash_probed_interpreter_and_lua_entrypoint()
  local lua_bin = "/opt/homebrew/opt/lua@5.4/bin/lua5.4"
  local body = provision.forwarder_body("gherkin-parser", lua_bin)

  lu.assertIs(body:sub(1, 19), "#!/usr/bin/env bash", "转发器得是 bash 脚本(PATH 上那是可执行名)")
  lu.assertTrue(body:find("set -e", 1, true) ~= nil, "转发器要 set -e,失败即非零退出")
  lu.assertTrue(body:find("exec " .. shell_lib.shell_quote(lua_bin), 1, true) ~= nil,
    "探测到的解释器要烘进转发器:PATH 上的 lua 可能是 5.5,不是本仓钉定的 5.4")
  lu.assertTrue(
    body:find('"$root/tools/packages/acceptance/cli/parser.lua"', 1, true) ~= nil,
    "入口按 $root 相对定位,转发器才能随仓搬家")
  lu.assertTrue(body:find("# Contract: gherkin-parser", 1, true) ~= nil, "正文要写清 APS 调用契约")
  lu.assertTrue(body:find("swarm_tool.sh ensure gherkin-parser", 1, true) ~= nil,
    "正文要写明禁走 ensure(它会把上游 Clojure 克隆和 bb 包装器拖回来)")
  lu.assertNil(body:find("bb --config", 1, true), "Lua 后端不得回落到 Babashka 包装器")
  lu.assertNil(body:find("clojure", 1, true), "Lua 后端不得拖回 Clojure")
end

function TestApsProvision:test_mutator_forwarder_clamps_to_differential_defaults()
  local body = provision.forwarder_body("gherkin-mutator", "lua")

  lu.assertTrue(body:find("--level hard", 1, true) ~= nil, "APS 契约:--level full 钳到 hard")
  lu.assertTrue(body:find("full", 1, true) ~= nil, "钳制分支要显式识别 --level full")
  lu.assertTrue(body:find("args+=(--workers 4)", 1, true) ~= nil, "worker 上限按章程钉死 4")
  lu.assertEquals(provision.TOOLS[3].entrypoint, "tools/packages/acceptance_mutate/mutator.lua")
end

function TestApsProvision:test_desired_bodies_cover_every_registered_tool_keyed_by_name()
  local bodies = provision.desired_bodies("lua")
  local keys = {}
  for name in pairs(bodies) do
    keys[#keys + 1] = name
  end
  table.sort(keys)
  lu.assertEquals(keys, { "gherkin-mutator", "gherkin-parser", "ir-dry-checker" })
  lu.assertIs(bodies["ir-dry-checker"], provision.forwarder_body("ir-dry-checker", "lua"))
end

function TestApsProvision:test_provision_writes_the_three_forwarders_executable()
  _with_sandbox("write", function(root)
    local report, err = _sandbox_provision(root)
    lu.assertNotNil(report, tostring(err))
    lu.assertEquals(report.written, TOOL_NAMES)
    lu.assertEquals(report.unchanged, {})

    local desired = provision.desired_bodies("lua")
    for _, tool in ipairs(provision.TOOLS) do
      local path = _tool_path(root, tool)
      lu.assertEvalToTrue(fs_lib.path_exists(path), "未落盘: " .. tool.name)
      lu.assertIs(fs_lib.read_raw(path), desired[tool.name])
      local probe = proc_lib.run_command({ "test", "-x", path })
      lu.assertTrue(probe.ok, tool.name .. " 不可执行(mode 非 755?): " .. probe.output)
    end
  end)
end

function TestApsProvision:test_provision_is_idempotent_and_repairs_drifted_or_missing_forwarders()
  _with_sandbox("idempotent", function(root)
    lu.assertNotNil(_sandbox_provision(root))

    local again = _sandbox_provision(root)
    lu.assertEquals(again.written, {}, "内容一致时不得重写(幂等要求)")
    lu.assertEquals(again.unchanged, TOOL_NAMES)

    local stale = provision.tool("ir-dry-checker")
    local stale_path = _tool_path(root, stale)
    fs_lib.write_file(stale_path, "#!/bin/sh\necho babashka\n")
    local parser_path = _tool_path(root, provision.tool("gherkin-parser"))
    fs_lib.remove_path(parser_path)

    local repaired = _sandbox_provision(root)
    lu.assertEquals(repaired.written, { "gherkin-parser", "ir-dry-checker" })
    lu.assertEquals(repaired.unchanged, { "gherkin-mutator" })
    lu.assertIs(fs_lib.read_raw(stale_path), provision.desired_bodies("lua")[stale.name])
  end)
end

function TestApsProvision:test_provision_accepts_a_single_tool_subset_without_touching_the_others()
  _with_sandbox("subset", function(root)
    local report = _sandbox_provision(root, { provision.tool("gherkin-parser") })
    lu.assertEquals(report.written, { "gherkin-parser" })
    lu.assertEvalToTrue(fs_lib.path_exists(_tool_path(root, provision.tool("gherkin-parser"))))
    lu.assertEvalToTrue(not fs_lib.path_exists(_tool_path(root, provision.tool("gherkin-mutator"))))
  end)
end

function TestApsProvision:test_provision_reports_failure_when_the_bin_dir_cannot_be_created()
  _with_sandbox("mkdir_fail", function(root)
    local blocker = path_lib.join_path(root, "blocker")
    fs_lib.write_file(blocker, "not a directory")

    local report, err = provision.provision({
      bin_dir = path_lib.join_path(blocker, "bin"),
      lua_bin = "lua",
    })
    lu.assertNil(report)
    lu.assertIsString(err)
  end)
end

function TestApsProvision:test_provisioned_parser_forwarder_reaches_the_entrypoint_with_the_two_args()
  _require_bash_and_lua()
  _with_sandbox("parser_e2e", function(root)
    local parser = provision.tool("gherkin-parser")
    local record = path_lib.join_path(root, "parser_argv.txt")
    _recording_stub(path_lib.join_path(root, parser.entrypoint), record)
    lu.assertNotNil(_sandbox_provision(root, { parser }))

    local result = proc_lib.run_command({
      _tool_path(root, parser),
      "features/game/deities.feature",
      "./tmp/deities.json",
    })
    lu.assertEquals(result.code, 0, "转发器非零退出: " .. tostring(result.output))
    lu.assertEquals(_recorded_argv(record),
      { "features/game/deities.feature", "./tmp/deities.json" })
  end)
end

function TestApsProvision:test_provisioned_mutator_forwarder_clamps_level_and_workers_before_exec()
  _require_bash_and_lua()
  _with_sandbox("mutator_e2e", function(root)
    local mutator = provision.tool("gherkin-mutator")
    local record = path_lib.join_path(root, "mutator_argv.txt")
    _recording_stub(path_lib.join_path(root, mutator.entrypoint), record)
    lu.assertNotNil(_sandbox_provision(root, { mutator }))

    local result = proc_lib.run_command({
      _tool_path(root, mutator),
      "--feature", "features/a-feature.feature",
      "--level", "full",
      "--workers", "9",
      "--runner-worker", "lua runner_worker.lua",
    })
    lu.assertEquals(result.code, 0, "转发器非零退出: " .. tostring(result.output))

    local argv = _recorded_argv(record)
    _assert_pair(argv, "--level", "hard", "--level full 必须钳成 hard")
    _assert_no_pair(argv, "--level", "full")
    _assert_pair(argv, "--workers", "4", "调用方 --workers 必须换成 4")
    _assert_no_pair(argv, "--workers", "9")
    _assert_pair(argv, "--feature", "features/a-feature.feature", "--feature 要原样透传")
    _assert_pair(argv, "--runner-worker", "lua runner_worker.lua", "带空格的值要作为一个 argv 元素透传")
  end)
end

function TestApsProvision:test_swarm_root_candidates_order_common_dir_parent_first()
  local candidates = provision.swarm_root_candidates({
    git_common_dir = "/repo/.git",
    toplevel = "/repo/.worktrees/coder",
    cwd = "/repo/.worktrees/coder",
  })
  lu.assertEquals(candidates, { "/repo", "/repo/.worktrees/coder", "/repo/.worktrees/coder" })
end

function TestApsProvision:test_swarm_root_candidates_absolutize_a_relative_common_dir_against_cwd()
  local candidates = provision.swarm_root_candidates({
    git_common_dir = ".git",
    toplevel = "/repo",
    cwd = "/repo",
  })
  lu.assertEquals(candidates, { "/repo", "/repo", "/repo" })
end

function TestApsProvision:test_swarm_root_picks_the_first_candidate_owning_the_roles_file()
  local chosen = provision.select_swarm_root(
    { "/repo", "/repo/.worktrees/coder" },
    function(dir)
      return dir == "/repo"
    end)
  lu.assertIs(chosen, "/repo")

  local none = provision.select_swarm_root({ "/elsewhere" }, function()
    return false
  end)
  lu.assertNil(none)
end

function TestApsProvision:test_usage_documents_the_command_and_the_no_ensure_rule()
  local usage = provision.usage()
  lu.assertTrue(usage:find("provision.lua", 1, true) ~= nil, usage)
  lu.assertTrue(usage:find(".swarmforge/bin", 1, true) ~= nil, usage)
  lu.assertTrue(usage:find("swarm_tool.sh ensure", 1, true) ~= nil,
    "usage 要写明禁止 ensure(会把 Clojure 克隆和 bb 包装器拖回来)")
  lu.assertNil(usage:find("bb edn", 1, true))
end

function TestApsProvision:test_command_exits_zero_with_usage_on_help()
  local result = _run_command({ "--help" })
  lu.assertEquals(result.code, 0, result.output)
  lu.assertTrue(result.output:find("provision.lua", 1, true) ~= nil, result.output)
end

function TestApsProvision:test_command_rejects_arguments_with_usage_exit_2_without_touching_the_tree()
  local result = _run_command({ "--not-a-flag" })
  lu.assertEquals(result.code, 2, result.output)
  lu.assertTrue(result.output:find("不接受参数", 1, true) ~= nil, result.output)
end
