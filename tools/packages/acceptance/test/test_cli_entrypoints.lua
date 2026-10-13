---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_cli_entrypoints.lua") end
require("test.bootstrap").install_package_paths()

-- 项目显式入口(parser / generator / ir_dry / mutator)的公共 CLI 回归。
-- 中文 Gherkin 能在项目入口上解析出 IR、IR 能生成入口件、IR-DRY 能出 findings、
-- 用量错误按 APS 契约退 2、真失败退 1。全部以子进程真跑入口脚本,不测私有函数。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local json = require("acceptance4lua.json")
local lua54 = require("packages.luaunit_runner.lua54")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")

local PARSER = "tools/packages/acceptance/cli/parser.lua"
local GENERATOR = "tools/packages/acceptance/cli/generator.lua"
local IR_DRY = "tools/packages/acceptance/cli/ir_dry.lua"
local MUTATOR = "tools/packages/acceptance_mutate/mutator.lua"

-- 与 mutate_lane 同用 Lua 5.4 解释器。
local APS_LUA = lua54.lua54_bin()

local ZH_FEATURE = table.concat({
  "# language: zh-CN",
  "功能: 中文入口探针",
  "",
  "场景大纲: 解析整数文本",
  "  假如 文本值为<原始文本>",
  "  当 项目将文本转换为整数",
  "  那么 整数结果为<整数结果>",
  "",
  "例子:",
  "  | 原始文本 | 整数结果 |",
  "  | 12       | 12       |",
  "  | -7       | -7       |",
  "",
}, "\n")

local function _with_sandbox(name, fn)
  local root = env_lib.make_temp_path("aps_cli_entrypoints_" .. name .. "_", "")
  fs_lib.remove_path(root)
  fs_lib.ensure_dir(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

local function _write(path, content)
  local ok, err = fs_lib.write_file(path, content)
  lu.assertTrue(ok, "夹具写入失败: " .. tostring(path) .. " " .. tostring(err))
end

local function _run(entry, args)
  local command = { APS_LUA, entry }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return proc_lib.run_command(command)
end

local function _sandbox_feature(root)
  local feature_path = path_lib.join_path(root, "probe.feature")
  _write(feature_path, ZH_FEATURE)
  return feature_path
end

local function _sandbox_ir(root, feature_path)
  local ir_path = path_lib.join_path(root, "probe.json")
  local result = _run(PARSER, { feature_path, ir_path })
  lu.assertEquals(result.code, 0, "parser 应能解析中文 feature: " .. tostring(result.output))
  return ir_path
end

local function _decoded(path)
  local content = fs_lib.read_raw(path)
  lu.assertNotNil(content, "没有产物: " .. tostring(path))
  local ok, decoded = pcall(json.decode, content)
  lu.assertTrue(ok, "产物不是合法 JSON: " .. tostring(path))
  return decoded
end

TestApsCliEntrypoints = {}

function TestApsCliEntrypoints:test_direct_mutator_actual_request_is_unavailable_before_work_is_created()
  _with_sandbox("mutator_unavailable", function(root)
    local work = path_lib.join_path(root, "must_not_exist")
    local result = _run(MUTATOR, { "--feature", _sandbox_feature(root), "--work-dir", work })
    lu.assertEquals(result.code, 3, result.output)
    lu.assertStrContains(result.output, "status=unavailable")
    lu.assertFalse(fs_lib.path_exists(work))
  end)
end

function TestApsCliEntrypoints:test_public_mutator_status_steps_accept_captured_protocol()
  local handlers = require("packages.acceptance.steps").handlers()
  local world = {
    mutator_status_result = { ok = true, code = 0 },
    mutator_status_stderr_text = "status total=4 completed=4 running=0 skipped_scenarios=1 skipped_mutations=2 elapsed=0.5s\n",
    mutator_status_stdout_text = '{"summary":{"Total":4,"Killed":4,"Survived":0,"Errors":0}}',
  }
  local example = { ["变异总数"] = "4", ["跳过场景数"] = "1", ["跳过变异数"] = "2", ["报告格式"] = "JSON" }
  for _, step in ipairs({ "mutator 命令成功完成", "标准错误输出包含状态行",
    "状态行包含总数<变异总数>和完成数<变异总数>",
    "状态行包含跳过场景数<跳过场景数>和跳过变异数<跳过变异数>",
    "状态行包含已耗时", "标准输出保持为<报告格式>报告", "标准输出不包含状态行" }) do
    local ok, err = handlers[step](world, example)
    lu.assertTrue(ok, tostring(err))
  end
end

function TestApsCliEntrypoints:test_public_mutator_status_steps_reject_invalid_protocol()
  local handlers = require("packages.acceptance.steps").handlers()
  local samples = {
    { "mutator 命令成功完成", { mutator_status_result = { ok = false, code = 3 } } },
    { "标准错误输出包含状态行", { mutator_status_stderr_text = "unavailable\n" } },
    { "状态行包含总数<变异总数>和完成数<变异总数>", { last_status_line = "status total=40 completed=40 running=0" } },
    { "状态行包含已耗时", { last_status_line = "status elapsed=unknown" } },
    { "标准输出保持为<报告格式>报告", { mutator_status_stdout_text = "{}" } },
    { "标准输出不包含状态行", { mutator_status_stdout_text = "{}\nstatus total=4\n" } },
  }
  for _, sample in ipairs(samples) do
    local ok, err = handlers[sample[1]](sample[2], { ["变异总数"] = "4", ["报告格式"] = "JSON" })
    lu.assertNil(ok, sample[1])
    lu.assertIsString(err)
  end
end

function TestApsCliEntrypoints:test_acceptance_capabilities_reconciles_retained_mutator_feature()
  local result = _run("tools/cli.lua", { "acceptance", "--capabilities" })
  lu.assertEquals(result.code, 0, result.output)
  lu.assertStrContains(result.output, "features/tooling/acceptance_mutator_status.feature")
  lu.assertStrContains(result.output, "test_acceptance_mutator_status_acceptance.lua")
  lu.assertStrContains(result.output, "status=unavailable")
  lu.assertStrContains(result.output, "capability=acceptance-mutate")
  lu.assertStrContains(result.output, "registered=35 selected=34 excluded=1")
  local explicit = _run("tools/cli.lua", { "acceptance", "--feature", "features/tooling/acceptance_mutator_status.feature" })
  lu.assertEquals(explicit.code, 3, explicit.output)
  lu.assertStrContains(explicit.output, "status=unavailable")
end

function TestApsCliEntrypoints:test_parser_translates_a_zh_cn_feature_into_json_ir()
  _with_sandbox("parser", function(root)
    local ir_path = path_lib.join_path(root, "probe.json")
    local result = _run(PARSER, { _sandbox_feature(root), ir_path })
    lu.assertEquals(result.code, 0, tostring(result.output))

    local ir = _decoded(ir_path)
    lu.assertIs(ir.name, "中文入口探针", "中文功能名要进 IR")
    lu.assertEquals(#ir.scenarios, 1)
    local first_step = ir.scenarios[1].steps[1]
    lu.assertIs(first_step.text, "文本值为<原始文本>")
    lu.assertIs(first_step.metadata.original_text, "文本值为<原始文本>",
      "IR 要留住中文原文,别只留归一化后的英文关键字")
  end)
end

function TestApsCliEntrypoints:test_parser_exits_2_on_usage_and_1_when_the_feature_cannot_be_read()
  local usage = _run(PARSER, {})
  lu.assertEquals(usage.code, 2, usage.output)
  lu.assertTrue(usage.output:find("usage", 1, true) ~= nil, usage.output)

  _with_sandbox("parser_missing", function(root)
    local missing = path_lib.join_path(root, "nope.feature")
    local failure = _run(PARSER, { missing, path_lib.join_path(root, "out.json") })
    lu.assertEquals(failure.code, 1, failure.output)
    lu.assertEvalToTrue(not fs_lib.path_exists(path_lib.join_path(root, "out.json")),
      "解析失败不该留下半成品 IR")
  end)
end

function TestApsCliEntrypoints:test_generator_binds_the_ir_into_a_runnable_entrypoint_module()
  _with_sandbox("generator", function(root)
    local feature_path = path_lib.join_path(root, "中文 空格完整身份_" .. string.rep("full_identity_", 4) .. ".feature")
    _write(feature_path, ZH_FEATURE)
    local ir_path = _sandbox_ir(root, feature_path)
    local spec_path = path_lib.join_path(root, "test_probe_acceptance.lua")
    lu.assertTrue(#require("acceptance4lua.generator").metadata_path_for(spec_path, feature_path) > 270,
      "fixture must retain the full absolute identity that exceeds native metadata path limits")
    local result = _run(GENERATOR, { ir_path, spec_path })
    lu.assertEquals(result.code, 0, tostring(result.output))

    local metadata = _decoded(require("packages.acceptance.entrypoint").metadata_path_for(
      spec_path, feature_path))
    lu.assertEquals(metadata.feature_path, feature_path)
    lu.assertEquals(metadata.ir_path, ir_path)
    lu.assertEquals(metadata.generated_files, { spec_path })
    lu.assertEquals(metadata.implementation_hash,
      require("acceptance4lua.spec_hash").compute_generated_files_hash({ spec_path }))
    local generated = fs_lib.read_raw(spec_path)
    lu.assertNotNil(generated)
    lu.assertTrue(generated:find('require("packages.acceptance.runtime")', 1, true) ~= nil,
      "生成件要绑本仓 runtime,而不是自带平行实现")
    lu.assertTrue(generated:find("中文入口探针", 1, true) ~= nil,
      "生成件内嵌 IR,可独立执行")
    local metadata_path = require("packages.acceptance.entrypoint").metadata_path_for(spec_path, feature_path)
    local before = fs_lib.read_raw(metadata_path)
    local again = _run(GENERATOR, { ir_path, spec_path })
    lu.assertEquals(again.code, 0, again.output)
    lu.assertEquals(fs_lib.read_raw(spec_path), generated)
    lu.assertEquals(fs_lib.read_raw(metadata_path), before)
  end)
end

function TestApsCliEntrypoints:test_generator_rejects_metadata_identity_conflict_without_overwriting_entry()
  _with_sandbox("generator_conflict", function(root)
    local feature = _sandbox_feature(root)
    local ir = _sandbox_ir(root, feature)
    local output = path_lib.join_path(root, "entry.lua")
    local metadata = require("packages.acceptance.entrypoint").metadata_path_for(output, feature)
    _write(output, "original entry")
    _write(metadata, json.encode({ feature_path = "different/full/identity.feature" }))
    local result = _run(GENERATOR, { ir, output })
    lu.assertEquals(result.code, 1, result.output)
    lu.assertStrContains(result.output, "metadata identity conflict")
    lu.assertEquals(fs_lib.read_raw(output), "original entry")
  end)
end

function TestApsCliEntrypoints:test_generator_exits_2_without_arguments()
  local usage = _run(GENERATOR, {})
  lu.assertEquals(usage.code, 2, usage.output)
  lu.assertTrue(usage.output:find("usage", 1, true) ~= nil, usage.output)
end

function TestApsCliEntrypoints:test_ir_dry_reports_findings_for_repeated_step_shapes()
  _with_sandbox("ir_dry", function(root)
    local ir_path = _sandbox_ir(root, _sandbox_feature(root))
    local report_path = path_lib.join_path(root, "dry.json")
    local result = _run(IR_DRY, { ir_path, report_path })
    lu.assertEquals(result.code, 0, tostring(result.output))

    local report = _decoded(report_path)
    lu.assertNotNil(report.findings, "findings 字段必须存在(可以为空数组)")
    lu.assertIs(report.feature_name, "中文入口探针")
  end)
end

function TestApsCliEntrypoints:test_ir_dry_exits_2_without_arguments_and_1_on_a_missing_ir()
  local usage = _run(IR_DRY, {})
  lu.assertEquals(usage.code, 2, usage.output)

  _with_sandbox("ir_dry_missing", function(root)
    local failure = _run(IR_DRY, { path_lib.join_path(root, "nope.json"),
      path_lib.join_path(root, "dry.json") })
    lu.assertNotEquals(failure.code, 0, failure.output)
  end)
end

-- mutator 只做「必填校验 + usage」这一段契约:真变异跑属 acceptance-mutate 软车道,
-- 由 status 行为用例与车道覆盖,coder 不在此发起变异跑(#606 验收同口径)。
function TestApsCliEntrypoints:test_mutator_exits_2_and_prints_the_aps_flags_without_a_feature()
  local help = _run(MUTATOR, { "--help" })
  lu.assertEquals(help.code, 0, help.output)
  lu.assertStrContains(help.output, "--status-interval")
  local usage = _run(MUTATOR, {})
  lu.assertEquals(usage.code, 2, usage.output)
  lu.assertTrue(usage.output:find("--feature", 1, true) ~= nil, usage.output)
  lu.assertTrue(usage.output:find("--runner-worker", 1, true) ~= nil, usage.output)
end
