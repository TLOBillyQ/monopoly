---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_aps_forwarders.lua") end
require("test.bootstrap").install_package_paths()

-- APS 转发器「正文」真源(packages.acceptance.aps_forwarders)的 spec。
--
-- 观测面:登记表点名哪三件、各自指向哪个真实入口;正文烘进了什么(解释器、$root 相对
-- 入口、APS 契约行、禁走 ensure 的告示);gherkin-mutator 的差分钳制;以及真跑 bash
-- 转发器时参数到底怎么递到入口。落盘与幂等在 test_provision.lua,根解析在
-- test_swarm_root.lua。
local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local property = require("test.support.property")
local probe = require("test.support.aps_forwarder_probe")
local forwarders = require("packages.acceptance.aps_forwarders")

local TOOL_NAMES = { "gherkin-parser", "ir-dry-checker", "gherkin-mutator" }

TestApsForwarders = {}

function TestApsForwarders:test_registry_names_the_three_aps_tools_on_real_project_entrypoints()
  local names = {}
  for _, tool in ipairs(forwarders.TOOLS) do
    names[#names + 1] = tool.name
    lu.assertIsString(tool.entrypoint, tool.name .. " 缺 entrypoint")
    lu.assertIsString(tool.contract, tool.name .. " 缺 APS 契约行")
    lu.assertEvalToTrue(fs_lib.path_exists(tool.entrypoint),
      "入口文件不存在: " .. tostring(tool.entrypoint))
  end
  lu.assertEquals(names, TOOL_NAMES)
end

function TestApsForwarders:test_forwarder_body_bakes_bash_probed_interpreter_and_lua_entrypoint()
  local lua_bin = "/opt/homebrew/opt/lua@5.4/bin/lua5.4"
  local body = forwarders.forwarder_body("gherkin-parser", lua_bin)

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

-- 逐个显式喂,不用 ipairs({nil, ...}):表里的前导 nil 会让 ipairs 零次迭代,
-- 断言整段变空转,绿得毫无意义。
function TestApsForwarders:test_forwarder_body_falls_back_to_path_lua_when_the_interpreter_is_blank()
  local expected = "exec 'lua' \"$root/"
  local cases = {
    { "nil", forwarders.forwarder_body("gherkin-parser", nil) },
    { "空串", forwarders.forwarder_body("gherkin-parser", "") },
    { "纯空白", forwarders.forwarder_body("gherkin-parser", "   ") },
  }
  lu.assertEquals(#cases, 3)
  for _, case in ipairs(cases) do
    lu.assertTrue(case[2]:find(expected, 1, true) ~= nil,
      case[1] .. " 解释器要退回 PATH 上的 lua,别烘出打不开的 exec 目标: " .. case[2])
  end

  local pinned = forwarders.forwarder_body("gherkin-parser", "/pin/lua5.4")
  lu.assertTrue(pinned:find("exec '/pin/lua5.4' \"$root/", 1, true) ~= nil, pinned)
end

function TestApsForwarders:test_mutator_forwarder_clamps_to_differential_defaults()
  local body = forwarders.forwarder_body("gherkin-mutator", "lua")

  lu.assertTrue(body:find("--level hard", 1, true) ~= nil, "APS 契约:--level full 钳到 hard")
  lu.assertTrue(body:find("full", 1, true) ~= nil, "钳制分支要显式识别 --level full")
  lu.assertTrue(body:find("args+=(--workers 4)", 1, true) ~= nil, "worker 上限按章程钉死 4")
  lu.assertEquals(forwarders.TOOLS[3].entrypoint, "tools/packages/acceptance_mutate/mutator.lua")
end

function TestApsForwarders:test_desired_bodies_cover_every_registered_tool_keyed_by_name()
  local bodies = forwarders.desired_bodies("lua")
  local keys = {}
  for name in pairs(bodies) do
    keys[#keys + 1] = name
  end
  table.sort(keys)
  lu.assertEquals(keys, { "gherkin-mutator", "gherkin-parser", "ir-dry-checker" })
  lu.assertIs(bodies["ir-dry-checker"], forwarders.forwarder_body("ir-dry-checker", "lua"))
end

function TestApsForwarders:test_bin_dir_is_the_swarmforge_bin_relative_to_the_root()
  lu.assertIs(forwarders.bin_dir("/repo"), "/repo/.swarmforge/bin")
end

function TestApsForwarders:test_provisioned_parser_forwarder_reaches_the_entrypoint_with_the_two_args()
  probe.require_bash_and_lua()
  probe.with_sandbox("forwarder_parser_e2e", function(root)
    local parser = forwarders.tool("gherkin-parser")
    local record = path_lib.join_path(root, "parser_argv.txt")
    probe.write_recording_stub(path_lib.join_path(root, parser.entrypoint), record)
    lu.assertNotNil(probe.sandbox_provision(root, { parser }))

    local result = proc_lib.run_command({
      probe.tool_path(root, parser),
      "features/game/deities.feature",
      "./tmp/deities.json",
    })
    lu.assertEquals(result.code, 0, "转发器非零退出: " .. tostring(result.output))
    lu.assertEquals(probe.recorded_argv(record),
      { "features/game/deities.feature", "./tmp/deities.json" })
  end)
end

-- 转发器 + 打桩入口的共用夹具:被测物是正文里那段 case,所以用例只关心「喂进去的
-- argv」与「入口实际收到的 argv」。沙箱、落盘、读回三件事只写一次,否则每多一个
-- 钳制用例就多一份复制源。
local function _with_mutator_forwarder(name, fn)
  probe.require_bash_and_lua()
  probe.with_sandbox(name, function(root)
    local mutator = forwarders.tool("gherkin-mutator")
    local record = path_lib.join_path(root, "mutator_argv.txt")
    probe.write_recording_stub(path_lib.join_path(root, mutator.entrypoint), record)
    lu.assertNotNil(probe.sandbox_provision(root, { mutator }))
    local forwarder = probe.tool_path(root, mutator)

    fn(function(args)
      local command = { forwarder }
      for _, value in ipairs(args) do
        command[#command + 1] = value
      end
      local result = proc_lib.run_command(command)
      lu.assertEquals(result.code, 0, "转发器非零退出: " .. tostring(result.output))
      return probe.recorded_argv(record)
    end)
  end)
end

function TestApsForwarders:test_provisioned_mutator_forwarder_clamps_level_and_workers_before_exec()
  _with_mutator_forwarder("forwarder_mutator_e2e", function(run)
    local argv = run({
      "--feature", "features/a-feature.feature",
      "--level", "full",
      "--workers", "9",
      "--runner-worker", "lua runner_worker.lua",
    })
    probe.assert_pair(argv, "--level", "hard", "--level full 必须钳成 hard")
    probe.assert_no_pair(argv, "--level", "full")
    probe.assert_pair(argv, "--workers", "4", "调用方 --workers 必须换成 4")
    probe.assert_no_pair(argv, "--workers", "9")
    probe.assert_pair(argv, "--feature", "features/a-feature.feature", "--feature 要原样透传")
    probe.assert_pair(argv, "--runner-worker", "lua runner_worker.lua", "带空格的值要作为一个 argv 元素透传")
  end)
end

-- 性质钉(转发器正文是「下次启动可用」的载体,输入面却是任意解释器字符串与任意
-- 参数向量)。解释器 alphabet 里特意放了空格、单引号、`$( )`、反引号与反斜杠:
-- 正文把这串字符烘成 shell 词,它就得在真 bash 的解析里活下来。
local _LAUNCHER_ALPHABET = {
  "lua", "", "   ", "/pin/lua5.4", "with space", "quote'd", 'dq"uote',
  "$(cmd)", "`back`", "\\", "/opt/homebrew/opt/lua@5.4/bin/lua5.4",
}

local function _generate_launcher(rng)
  return rng:pick(_LAUNCHER_ALPHABET)
end

-- 「没给」判定的第二实现:测试侧独立写一遍,免得与 aps_forwarders.is_blank_launcher
-- 同错——那种情况下性质律会一起漂绿。
local function _expected_bin(launcher)
  if launcher == nil or launcher == "" or launcher:match("^%s+$") ~= nil then
    return "lua"
  end
  return launcher
end

TestApsForwarderLaws = {}

function TestApsForwarderLaws:test_body_derivation_is_stable_for_repeated_identical_input()
  property.for_all(_generate_launcher, function(launcher)
    local first = forwarders.forwarder_body("gherkin-parser", launcher)
    lu.assertIs(first, forwarders.forwarder_body("gherkin-parser", launcher),
      "同一解释器两次演算必须逐字节相同(落盘幂等的前提)")
  end, { cases = 60 })
end

-- 用真 bash 当 oracle:把正文那条 exec 换成 printf(逐 argv 元素打一行),脚本落在沙箱
-- 的 .swarmforge/bin 下让 $root 的反推成立。引号没闭合 → argv 多出元素或脚本解析失败;
-- 烘错解释器 → 第一行不等于预期;`$( )`/反引号被求值 → 第一行变成执行结果。
-- 比在测试里重抄一遍 shell 转义规则强,因为它测的是转发器交付的那份真实 argv。
-- 替换串里的 %% 是 gsub 的转义写法,落进脚本要正好是 printf '%s\n'(反斜杠 + n)。
function TestApsForwarderLaws:test_baked_interpreter_survives_bash_parsing_as_one_argv_element()
  probe.require_bash_and_lua()
  probe.with_sandbox("forwarder_interpreter_law", function(root)
    local script = path_lib.join_path(root, ".swarmforge", "bin", "argv-probe")
    local entry = forwarders.tool("ir-dry-checker").entrypoint
    property.for_all(_generate_launcher, function(launcher)
      local body = assert(forwarders.forwarder_body("ir-dry-checker", launcher))
      lu.assertNotNil(body:find("exec ", 1, true), "正文得有一条 exec: " .. body)
      lu.assertTrue(fs_lib.write_file(script, body:gsub("exec ", "printf '%%s\\n' ", 1)),
        "探针脚本落盘失败")

      local result = proc_lib.run_command({ "bash", script })
      lu.assertEquals(result.code, 0, "探针脚本非零退出: " .. tostring(result.output))

      local words = {}
      for line in tostring(result.output or ""):gmatch("([^\n]*)\n") do
        words[#words + 1] = line
      end
      lu.assertEquals(words, { _expected_bin(launcher), root .. "/" .. entry },
        "解释器没作为单一 argv 元素抵达入口(引号或转义被破): 入参 " .. property.describe(launcher)
        .. " 实得 " .. table.concat(words, " | "))
    end, { cases = 30 })
  end)
end

function TestApsForwarderLaws:test_every_registered_tool_bakes_a_body_for_any_launcher()
  property.for_all(_generate_launcher, function(launcher)
    for _, tool in ipairs(forwarders.TOOLS) do
      local body = forwarders.forwarder_body(tool.name, launcher)
      lu.assertIsString(body, tool.name .. " 演算不出正文")
      lu.assertTrue(body:find('"' .. "$root/" .. tool.entrypoint .. '"', 1, true) ~= nil,
        tool.name .. " 的 exec 得指向登记入口: " .. body)
    end
  end, { cases = 20 })
end

-- 真跑 bash 的钳制守恒:入口实得的 argv 必须逐元素等于一份独立模型(正文那段 case 的
-- 第二实现)——钳制只许动 --level / --workers 两族,其余按原序整批透传。
--
-- 生成器只造「钳制旗标恒带值」的向量:正文是按位置吃 token 的(--workers 连值一起吃掉,
-- --level full 换成 hard 后吃掉两个),值缺位时转发器与模型的推进规则不再同构,
-- 那种输入改由下面两条字面量例子单独钉住。
local _PASSTHROUGH_FLAGS = { "--feature", "--work-dir", "--timeout", "--status-interval" }
local _LEVEL_VALUES = { "full", "hard", "soft" }
local _WORKER_VALUES = { "1", "4", "9", "16" }

local function _generate_mutator_args(rng)
  local args = { "--feature", "features/probe.feature" }
  if rng:bool() then
    args[#args + 1] = "--level"
    args[#args + 1] = rng:pick(_LEVEL_VALUES)
  end
  if rng:bool() then
    args[#args + 1] = "--workers"
    args[#args + 1] = rng:pick(_WORKER_VALUES)
  end
  for _ = 1, rng:int(0, 2) do
    args[#args + 1] = rng:pick(_PASSTHROUGH_FLAGS)
    args[#args + 1] = "value" .. tostring(rng:int(0, 9))
  end
  return args
end

local function _model_clamp(args)
  local kept = {}
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--workers" then
      index = index + 2
    elseif token == "--level" and args[index + 1] == "full" then
      kept[#kept + 1] = "--level"
      kept[#kept + 1] = "hard"
      index = index + 2
    else
      kept[#kept + 1] = token
      index = index + 1
    end
  end
  kept[#kept + 1] = "--workers"
  kept[#kept + 1] = "4"
  return kept
end

local function _count_token(argv, token)
  local hits = 0
  for _, value in ipairs(argv) do
    if value == token then
      hits = hits + 1
    end
  end
  return hits
end

TestApsForwarderClampLaws = {}

function TestApsForwarderClampLaws:test_clamped_forwarder_keeps_every_unclamped_argument_in_order()
  _with_mutator_forwarder("forwarder_clamp_law", function(run)
    property.for_all(_generate_mutator_args, function(args)
      local argv = run(args)
      lu.assertEquals(argv, _model_clamp(args),
        "非钳制参数被改动或换序: 入参 [" .. table.concat(args, " ") .. "] 实得 ["
        .. table.concat(argv, " ") .. "]")
      -- 模型与正文同错时,下面三条独立不变量仍然兜得住:full 绝不在成对位置、
      -- --workers 只许有一条、那条的值恒是 4。
      probe.assert_no_pair(argv, "--level", "full")
      lu.assertEquals(_count_token(argv, "--workers"), 1,
        "--workers 只该剩转发器补的那一条: " .. table.concat(argv, " "))
      probe.assert_pair(argv, "--workers", "4", "worker 上限按章程钉死 4")
    end, { cases = 18 })
  end)
end

-- 缺值支:正文不留 `[ ... ] && shift` 这类假条件(它在 set -e 下会让转发器带非零码
-- 退场),每个分支自己收完 token。--level 缺值只透传旗标,缺值交入口判用量错;
-- --workers 缺值照样吃掉旗标再补上钉死的 4。
function TestApsForwarderClampLaws:test_a_level_flag_without_its_value_is_passed_through_unchanged()
  _with_mutator_forwarder("forwarder_level_missing_value", function(run)
    lu.assertEquals(run({ "--level" }), { "--level", "--workers", "4" })
  end)
end

function TestApsForwarderClampLaws:test_a_workers_flag_without_its_value_leaves_only_the_clamped_default()
  _with_mutator_forwarder("forwarder_workers_missing_value", function(run)
    lu.assertEquals(run({ "--workers" }), { "--workers", "4" })
  end)
end
