---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_provision.lua") end
require("test.bootstrap").install_package_paths()

-- APS 三件转发器的幂等 provision(#606)单测。
--
-- 观测面 = provision 这一层唯一负责的事:给定 bin_dir 与解释器,正文一致就不动、
-- 缺失或漂移才重写并留 755;点名子集只碰子集;目录建不出来就失败;报告要说出真正
-- 烘进正文的那个解释器;命令面退出码与 tools/cli.lua 同一约定。
-- 转发器正文本身在 test_aps_forwarders.lua,SwarmForge 根解析在 test_swarm_root.lua,
-- bootstrap.ensure_tool 的 luarocks 本体不在此重测(那是 foundation 既有契约,且要联网)。
local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local property = require("test.support.property")
local probe = require("test.support.aps_forwarder_probe")
local forwarders = require("packages.acceptance.aps_forwarders")
local provision = require("packages.acceptance.provision")

local TOOL_NAMES = { "gherkin-parser", "ir-dry-checker", "gherkin-mutator" }
local SCRIPT = "tools/packages/acceptance/provision.lua"

local function _name_set(names)
  local set = {}
  for _, name in ipairs(names) do
    set[name] = (set[name] or 0) + 1
  end
  return set
end

local function _key_count(set)
  local keys = 0
  for _ in pairs(set) do
    keys = keys + 1
  end
  return keys
end

-- provision 按登记表顺序遍历被点名的工具,而不是按入参顺序——报告里的名单因此恒为
-- 登记表序。断言侧独立重排一遍,免得「按入参序」与「按登记表序」两种实现都算绿。
local function _in_registry_order(names)
  local wanted = _name_set(names)
  local ordered = {}
  for _, tool in ipairs(forwarders.TOOLS) do
    if wanted[tool.name] ~= nil then
      ordered[#ordered + 1] = tool.name
    end
  end
  return ordered
end

-- 命令面直跑真脚本(用与车道同口径的 lua5.4),退出码与输出都从子进程拿。
local function _run_command(args)
  local command = { provision.detect_lua_bin(), SCRIPT }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return proc_lib.run_command(command)
end

TestApsProvision = {}

function TestApsProvision:test_provision_writes_the_three_forwarders_executable()
  probe.with_sandbox("write", function(root)
    local report, err = probe.sandbox_provision(root)
    lu.assertNotNil(report, tostring(err))
    lu.assertEquals(report.written, TOOL_NAMES)
    lu.assertEquals(report.unchanged, {})
    lu.assertEquals(report.bin_dir, forwarders.bin_dir(root))
    lu.assertIs(report.lua_bin, "lua", "报告里的解释器必须等于真正烘进正文的那个词")

    local desired = forwarders.desired_bodies("lua")
    for _, tool in ipairs(forwarders.TOOLS) do
      local path = probe.tool_path(root, tool)
      lu.assertEvalToTrue(fs_lib.path_exists(path), "未落盘: " .. tool.name)
      lu.assertIs(fs_lib.read_raw(path), desired[tool.name])
      local executable = proc_lib.run_command({ "test", "-x", path })
      lu.assertTrue(executable.ok, tool.name .. " 不可执行(mode 非 755?): " .. executable.output)
    end
  end)
end

function TestApsProvision:test_provision_is_idempotent_and_repairs_drifted_or_missing_forwarders()
  probe.with_sandbox("idempotent", function(root)
    lu.assertNotNil(probe.sandbox_provision(root))

    local again = probe.sandbox_provision(root)
    lu.assertEquals(again.written, {}, "内容一致时不得重写(幂等要求)")
    lu.assertEquals(again.unchanged, TOOL_NAMES)

    local stale = forwarders.tool("ir-dry-checker")
    local stale_path = probe.tool_path(root, stale)
    fs_lib.write_file(stale_path, "#!/bin/sh\necho babashka\n")
    local parser_path = probe.tool_path(root, forwarders.tool("gherkin-parser"))
    fs_lib.remove_path(parser_path)

    local repaired = probe.sandbox_provision(root)
    lu.assertEquals(repaired.written, { "gherkin-parser", "ir-dry-checker" })
    lu.assertEquals(repaired.unchanged, { "gherkin-mutator" })
    lu.assertIs(fs_lib.read_raw(stale_path), forwarders.desired_bodies("lua")[stale.name])
  end)
end

function TestApsProvision:test_provision_accepts_a_single_tool_subset_without_touching_the_others()
  probe.with_sandbox("subset", function(root)
    local report = probe.sandbox_provision(root, { forwarders.tool("gherkin-parser") })
    lu.assertEquals(report.written, { "gherkin-parser" })
    lu.assertEvalToTrue(fs_lib.path_exists(probe.tool_path(root, forwarders.tool("gherkin-parser"))))
    lu.assertEvalToTrue(not fs_lib.path_exists(probe.tool_path(root, forwarders.tool("gherkin-mutator"))))
  end)
end

function TestApsProvision:test_provision_reports_failure_when_the_bin_dir_cannot_be_created()
  probe.with_sandbox("mkdir_fail", function(root)
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

-- 「没给解释器」与「给了空串/纯空白」都算没给:这种值烘出的 exec 目标打不开,而报告
-- 又必须说出真正烘进去的那个词,否则下次排障就被报告带偏。
-- 三个定点逐个显式喂:ipairs({nil, ...}) 的前导 nil 会让整圈零次迭代,断言全空转。
function TestApsProvision:test_provision_detects_the_interpreter_when_none_was_supplied()
  local parser = forwarders.tool("gherkin-parser")
  local blanks = {
    { label = "缺省", value = "unset" },
    { label = "nil", value = nil },
    { label = "空串", value = "" },
    { label = "纯空白", value = "   " },
  }
  lu.assertEquals(#blanks, 4)
  probe.with_sandbox("detect", function(root)
    for _, case in ipairs(blanks) do
      local options = {
        bin_dir = forwarders.bin_dir(root),
        tools = { parser },
      }
      if case.value ~= "unset" then
        options.lua_bin = case.value
      end

      local report, err = provision.provision(options)
      lu.assertNotNil(report, case.label .. " 解释器应当能供给: " .. tostring(err))
      lu.assertIs(report.lua_bin, provision.detect_lua_bin(),
        case.label .. " 得走探测口径,而不是烘出打不开的解释器")
      local body = fs_lib.read_raw(probe.tool_path(root, parser))
      lu.assertTrue(body:find("exec " .. shell_lib.shell_quote(report.lua_bin), 1, true) ~= nil,
        case.label .. " 报告词与实际烘进正文的词必须同一个: " .. tostring(body))
    end
  end)
end

function TestApsProvision:test_report_lines_name_the_root_interpreter_rock_and_both_lists()
  local report = {
    bin_dir = "/swarm/.swarmforge/bin",
    lua_bin = "/pin/lua5.4",
    written = { "gherkin-mutator" },
    unchanged = { "gherkin-parser", "ir-dry-checker" },
  }
  lu.assertEquals(provision.report_lines(report, "https://example/acceptance4lua.rockspec"), {
    "APS 转发器根目录: /swarm/.swarmforge/bin",
    "解释器: /pin/lua5.4",
    "rock: https://example/acceptance4lua.rockspec",
    "重建 1 件: gherkin-mutator",
    "保留 2 件: gherkin-parser, ir-dry-checker",
  })
  lu.assertEquals(provision.report_lines(report, nil)[3], "rock: nil",
    "rock 没 url 也要占一行,不能把整份报告挤歪")
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

local _SUBSETS = {
  {},
  { "gherkin-parser" },
  { "gherkin-mutator" },
  { "gherkin-parser", "ir-dry-checker" },
  TOOL_NAMES,
}

local function _tools_for(names)
  local tools = {}
  for _, name in ipairs(names) do
    tools[#tools + 1] = forwarders.tool(name)
  end
  return tools
end

TestApsProvisionLaws = {}

-- 性质钉:provision 恒把每个被点名的工具恰好归进「重建」或「保留」一侧,两侧都不重名、
-- 不越界,且第二次跑同一定点时一个都不该重写——幂等就是这条不变量的特例。
function TestApsProvisionLaws:test_every_named_tool_lands_on_exactly_one_side_and_reprovision_writes_nothing()
  probe.with_sandbox("one_side_law", function(root)
    local bin_dir = forwarders.bin_dir(root)

    local function run(names)
      local report, err = provision.provision({
        bin_dir = bin_dir,
        lua_bin = "lua",
        tools = _tools_for(names),
      })
      lu.assertNotNil(report, tostring(err))
      local written = _name_set(report.written)
      local kept = _name_set(report.unchanged)
      lu.assertEquals(_key_count(written), #report.written, "重建名单里有重名")
      lu.assertEquals(_key_count(kept), #report.unchanged, "保留名单里有重名")
      lu.assertEquals(#report.written + #report.unchanged, #names,
        "被点名的工具漏了或多了: " .. property.describe(names))
      local requested = _name_set(names)
      for _, name in ipairs(report.written) do
        lu.assertNil(kept[name], name .. " 既被重建又被保留")
      end
      for _, list in ipairs({ report.written, report.unchanged }) do
        for _, name in ipairs(list) do
          lu.assertTrue(requested[name] ~= nil,
            name .. " 不在被点名的子集里: " .. property.describe(names))
        end
      end
      return report
    end

    property.for_all(function(rng)
      return rng:pick(_SUBSETS)
    end, function(names)
      run(names)
      local again = run(names)
      lu.assertEquals(again.written, {}, "内容一致时不得重写(幂等要求)")
      lu.assertEquals(again.unchanged, _in_registry_order(names),
        "保留名单应按登记表序点名整个子集: " .. property.describe(names))
    end, { cases = 25 })
  end)
end

-- 正文可重放:同一解释器下,任意子集重写出来的文件必须逐字节等于 forwarders 的演算,
-- 而换解释器(含空白)后旧的落盘就全算漂移。
function TestApsProvisionLaws:test_written_bodies_always_equal_the_derived_bodies_for_the_reported_interpreter()
  probe.with_sandbox("replay_law", function(root)
    local bin_dir = forwarders.bin_dir(root)
    property.for_all(function(rng)
      return { names = rng:pick(_SUBSETS), lua_bin = rng:pick({ "lua", "/pin/lua5.4" }) }
    end, function(case)
      local report, err = provision.provision({
        bin_dir = bin_dir,
        lua_bin = case.lua_bin,
        tools = _tools_for(case.names),
      })
      lu.assertNotNil(report, tostring(err))
      lu.assertIs(report.lua_bin, case.lua_bin)

      local desired = forwarders.desired_bodies(case.lua_bin)
      for _, tool in ipairs(forwarders.TOOLS) do
        local body = fs_lib.read_raw(probe.tool_path(root, tool))
        if _name_set(case.names)[tool.name] ~= nil then
          lu.assertIs(body, desired[tool.name], tool.name .. " 落盘正文与演算不符")
        end
      end
    end, { cases = 20 })
  end)
end
