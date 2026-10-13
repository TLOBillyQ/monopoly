---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/acceptance/test/test_cli_entrypoints.lua") end
require("test.bootstrap").install_package_paths()

-- 项目显式入口(parser / generator / ir_dry / mutator)的公共 CLI 回归。
-- 中文 Gherkin 能在项目入口上解析出 IR、IR 能生成入口件、IR-DRY 能出 findings、
-- 用量错误按 APS 契约退 2、真失败退 1。全部以子进程真跑入口脚本,不测私有函数。
local check = require("luassert")
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
  check.is_true(ok, "夹具写入失败: " .. tostring(path) .. " " .. tostring(err))
end

local function _run(entry, args)
  local root = require("foundation.bootstrap").resolve("tools/packages/acceptance/cli/parser.lua").repo_root
  entry = (root .. "/" .. entry):gsub("/", "\\")
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
  check.same(0, result.code, "parser 应能解析中文 feature: " .. tostring(result.output))
  return ir_path
end

local function _decoded(path)
  local content = fs_lib.read_raw(path)
  check.is_not_nil(content, "没有产物: " .. tostring(path))
  local ok, decoded = pcall(json.decode, content)
  check.is_true(ok, "产物不是合法 JSON: " .. tostring(path))
  return decoded
end

describe("acceptance public CLI entrypoints", function()

it("direct_mutator_actual_request_is_unavailable_before_work_is_created", function()
  _with_sandbox("mutator_unavailable", function(root)
    local work = path_lib.join_path(root, "must_not_exist")
    local result = _run(MUTATOR, { "--feature", _sandbox_feature(root), "--work-dir", work })
    check.same(3, result.code, result.output)
    check.matches("status=unavailable", result.output, 1, true)
    check.is_false(fs_lib.path_exists(work))
  end)
end)

it("public_mutator_status_steps_accept_captured_protocol", function()
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
    check.is_true(ok, tostring(err))
  end
end)

it("public_mutator_status_steps_reject_invalid_protocol", function()
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
    check.is_nil(ok, sample[1])
    check.is_string(err)
  end
end)

it("acceptance_capabilities_reconciles_retained_mutator_feature", function()
  local result = _run("tools/cli.lua", { "acceptance", "--capabilities" })
  check.same(0, result.code, result.output)
  check.matches("features/tooling/acceptance_mutator_status.feature", result.output, 1, true)
  check.matches("test_acceptance_mutator_status_acceptance.lua", result.output, 1, true)
  check.matches("status=unavailable", result.output, 1, true)
  check.matches("capability=acceptance-mutate", result.output, 1, true)
  check.matches("registered=35 selected=34 excluded=1", result.output, 1, true)
  local explicit = _run("tools/cli.lua", { "acceptance", "--feature", "features/tooling/acceptance_mutator_status.feature" })
  check.same(3, explicit.code, explicit.output)
  check.matches("status=unavailable", explicit.output, 1, true)
end)

it("parser_translates_a_zh_cn_feature_into_json_ir", function()
  _with_sandbox("parser", function(root)
    local ir_path = path_lib.join_path(root, "probe.json")
    local result = _run(PARSER, { _sandbox_feature(root), ir_path })
    check.same(0, result.code, tostring(result.output))

    local ir = _decoded(ir_path)
    check.equal("中文入口探针", ir.name, "中文功能名要进 IR")
    check.same(1, #ir.scenarios)
    local first_step = ir.scenarios[1].steps[1]
    check.equal("文本值为<原始文本>", first_step.text)
    check.equal("文本值为<原始文本>", first_step.metadata.original_text,
      "IR 要留住中文原文,别只留归一化后的英文关键字")
  end)
end)

it("parser_exits_2_on_usage_and_1_when_the_feature_cannot_be_read", function()
  local usage = _run(PARSER, {})
  check.same(2, usage.code, usage.output)
  check.is_true(usage.output:find("usage", 1, true) ~= nil, usage.output)

  _with_sandbox("parser_missing", function(root)
    local missing = path_lib.join_path(root, "nope.feature")
    local failure = _run(PARSER, { missing, path_lib.join_path(root, "out.json") })
    check.same(1, failure.code, failure.output)
    check.truthy(not fs_lib.path_exists(path_lib.join_path(root, "out.json")),
      "解析失败不该留下半成品 IR")
  end)
end)

it("generator_binds_the_ir_into_a_runnable_entrypoint_module", function()
  _with_sandbox("generator", function(root)
    local feature_path = path_lib.join_path(root, "中文 空格完整身份_" .. string.rep("full_identity_", 4) .. ".feature")
    _write(feature_path, ZH_FEATURE)
    local ir_path = _sandbox_ir(root, feature_path)
    local spec_path = path_lib.join_path(root, "test_probe_acceptance.lua")
    check.is_true(#require("acceptance4lua.generator").metadata_path_for(spec_path, feature_path) > 270,
      "fixture must retain the full absolute identity that exceeds native metadata path limits")
    local result = _run(GENERATOR, { ir_path, spec_path })
    check.same(0, result.code, tostring(result.output))

    local metadata = _decoded(require("packages.acceptance.entrypoint").metadata_path_for(
      spec_path, feature_path))
    check.same(feature_path, metadata.feature_path)
    check.same(ir_path, metadata.ir_path)
    check.same({ spec_path }, metadata.generated_files)
    check.same(require("acceptance4lua.spec_hash").compute_generated_files_hash({ spec_path }),
      metadata.implementation_hash)
    local generated = fs_lib.read_raw(spec_path)
    check.is_not_nil(generated)
    check.is_true(generated:find('require("packages.acceptance.runtime")', 1, true) ~= nil,
      "生成件要绑本仓 runtime,而不是自带平行实现")
    check.is_true(generated:find("中文入口探针", 1, true) ~= nil,
      "生成件内嵌 IR,可独立执行")
    local metadata_path = require("packages.acceptance.entrypoint").metadata_path_for(spec_path, feature_path)
    local before = fs_lib.read_raw(metadata_path)
    local again = _run(GENERATOR, { ir_path, spec_path })
    check.same(0, again.code, again.output)
    check.same(generated, fs_lib.read_raw(spec_path))
    check.same(before, fs_lib.read_raw(metadata_path))
  end)
end)

it("generator_rejects_metadata_identity_conflict_without_overwriting_entry", function()
  _with_sandbox("generator_conflict", function(root)
    local feature = _sandbox_feature(root)
    local ir = _sandbox_ir(root, feature)
    local output = path_lib.join_path(root, "entry.lua")
    local metadata = require("packages.acceptance.entrypoint").metadata_path_for(output, feature)
    _write(output, "original entry")
    _write(metadata, json.encode({ feature_path = "different/full/identity.feature" }))
    local result = _run(GENERATOR, { ir, output })
    check.same(1, result.code, result.output)
    check.matches("metadata identity conflict", result.output, 1, true)
    check.same("original entry", fs_lib.read_raw(output))
  end)
end)

it("generated_chinese_examples_execute_in_genuine_busted", function()
  _with_sandbox("busted", function(root)
    local feature = path_lib.join_path(root, "probe.feature")
    _write(feature, ZH_FEATURE:gsub("场景大纲:", "背景:\n  假如 项目验收步骤已加载\n\n场景大纲:", 1))
    local ir = _sandbox_ir(root, feature)
    local output = path_lib.join_path(root, "test_probe_acceptance.lua")
    local generated_result = _run(GENERATOR, { ir, output })
    check.same(0, generated_result.code, generated_result.output)
    local result = _run("tools/packages/acceptance/execute.lua", { output, ir })
    check.same(0, result.code, result.output)
    local response = json.decode(result.output)
    check.same("busted", response.backend)
    check.same(2, response.counts.cases)
    check.same(2, response.counts.passed)
    check.same(0, response.counts.failed)
    check.same(0, response.counts.errors)
    check.same({
      { scenario = 1, example = 1, name = "解析整数文本/example_1", status = "success" },
      { scenario = 1, example = 2, name = "解析整数文本/example_2", status = "success" },
    }, response.executions)
    local ir_doc = _decoded(ir)
    ir_doc.scenarios[1].examples[1]["整数结果"] = "999"
    local bad_ir = path_lib.join_path(root, "bad.json")
    _write(bad_ir, json.encode(ir_doc))
    local bad = _run("tools/packages/acceptance/execute.lua", { output, bad_ir })
    check.same(1, bad.code, bad.output)
    local bad_response = json.decode(bad.output)
    check.same("test_failure", bad_response.outcome)
    check.same(1, bad_response.counts.failed)
    check.same(0, bad_response.counts.errors)
    local broken = path_lib.join_path(root, "broken.lua")
    _write(broken, 'error("故意加载失败")')
    local infra = _run("tools/packages/acceptance/execute.lua", { broken, ir })
    check.same(1, infra.code, infra.output)
    check.same("infrastructure_error", json.decode(infra.output).outcome)
    local worker_spec = path_lib.join_path(root, "test_feature_acceptance.lua")
    _write(worker_spec, assert(fs_lib.read_raw(output)))
    local jobs = path_lib.join_path(root, "jobs.jsonl")
    local function job(id, feature_json) return json.encode_compact({ id = id, generated_dir = root, feature_json = feature_json }) end
    _write(jobs, job("bad", bad_ir) .. "\nnull\n" .. job("good", ir) .. "\n")
    local worker = proc_lib.run_command({ APS_LUA, "tools/packages/acceptance/runner_worker.lua" }, { stdin_path = jobs })
    check.same(0, worker.code, worker.output)
    local responses = {}
    for line in worker.output:gmatch("[^\r\n]+") do responses[#responses + 1] = json.decode(line) end
    check.same(3, #responses, worker.output)
    check.same("bad", responses[1].id)
    check.same("test_failure", responses[1].outcome)
    check.same("infrastructure_error", responses[2].outcome)
    check.same("good", responses[3].id)
    check.same("test_success", responses[3].outcome)
    local metadata = require("packages.acceptance.entrypoint").metadata_path_for(output, feature)
    local original_metadata = assert(fs_lib.read_raw(metadata))
    local metadata_doc = json.decode(original_metadata)
    metadata_doc.implementation_hash = "wrong"
    _write(metadata, json.encode(metadata_doc))
    local hash_failure = _run("tools/packages/acceptance/execute.lua", { output, ir, feature })
    check.same(1, hash_failure.code, hash_failure.output)
    check.same("infrastructure_error", json.decode(hash_failure.output).outcome)
    _write(metadata, original_metadata)
    local incomplete = path_lib.join_path(root, "incomplete.lua")
    _write(incomplete, 'describe("漏场景", function() it("unrelated", function() end) end)')
    local missing = _run("tools/packages/acceptance/execute.lua", { incomplete, ir })
    check.same(1, missing.code, missing.output)
    check.same("infrastructure_error", json.decode(missing.output).outcome)
  end)
end)

it("executor_distinguishes_errors_and_restores_example_lifecycle", function()
  _with_sandbox("executor_lifecycle", function(root)
    local function execute(name, text)
      local spec = path_lib.join_path(root, name .. ".lua")
      _write(spec, text)
      local result = _run("tools/packages/acceptance/execute.lua", { spec })
      return result, json.decode(result.output)
    end
    local negatives = {
      throw = [[local runtime=require("packages.acceptance.runtime")
        describe("异常",function() runtime.define_specs({scenarios={{name="例子",steps={{text="异常"}}}}},
          {["异常"]=function() error("ordinary handler exception") end},it) end)]],
      hook = [[describe("钩子",function() before_each(function() error("hook exception") end)
        it("例子",function() end) end)]],
      leak = [[describe("泄漏",function() it("例子",function()
        require("src.rules.ports.paid_purchase").reset_for_tests() end) end)]],
    }
    for name, text in pairs(negatives) do
      local result, response = execute(name, text)
      check.same(1, result.code, result.output)
      check.same("infrastructure_error", response.outcome, result.output)
      check.same(0, response.counts.failed, result.output)
      check.same(1, response.counts.errors, result.output)
    end
    local result, response = execute("assertion", [[local runtime=require("packages.acceptance.runtime")
      describe("断言",function() runtime.define_specs({scenarios={{name="例子",steps={{text="断言"}}}}},
        {["断言"]=function() require("luassert").equal(1,2) end},it) end)]])
    check.same(1, result.code, result.output)
    check.same("test_failure", response.outcome, result.output)
    check.same(1, response.counts.failed, result.output)
    check.same(0, response.counts.errors, result.output)
    check.same("failure", response.executions[1].status, result.output)
    result, response = execute("cleanup", [[local runtime=require("packages.acceptance.runtime")
      describe("清理",function() runtime.define_specs({scenarios={{name="例子",steps={{text="清理"}}}}},
        {["清理"]=function(world) world.defer(function() error("cleanup exception") end); return true end},it) end)]])
    check.same(1, result.code, result.output)
    check.same(1, response.counts.errors, result.output)
    check.same("error", response.executions[1].status, result.output)
    result, response = execute("rng", [[
      local assert=require("luassert")
      describe("每例随机基线",function()
        local first
        before_each(function()
          local value=math.random()
          if first then assert.equal(first,value) else first=value end
        end)
        it("扰动随机状态",function() for _=1,10 do math.random() end end)
        it("下一例在钩子前恢复",function() end)
      end)]])
    check.same(0, result.code, result.output)
    check.same(2, response.counts.cases, result.output)
    check.same(2, response.counts.passed, result.output)
  end)
end)

it("generator_exits_2_without_arguments", function()
  local usage = _run(GENERATOR, {})
  check.same(2, usage.code, usage.output)
  check.is_true(usage.output:find("usage", 1, true) ~= nil, usage.output)
end)

it("ir_dry_reports_findings_for_repeated_step_shapes", function()
  _with_sandbox("ir_dry", function(root)
    local ir_path = _sandbox_ir(root, _sandbox_feature(root))
    local report_path = path_lib.join_path(root, "dry.json")
    local result = _run(IR_DRY, { ir_path, report_path })
    check.same(0, result.code, tostring(result.output))

    local report = _decoded(report_path)
    check.is_not_nil(report.findings, "findings 字段必须存在(可以为空数组)")
    check.equal("中文入口探针", report.feature_name)
  end)
end)

it("ir_dry_exits_2_without_arguments_and_1_on_a_missing_ir", function()
  local usage = _run(IR_DRY, {})
  check.same(2, usage.code, usage.output)

  _with_sandbox("ir_dry_missing", function(root)
    local failure = _run(IR_DRY, { path_lib.join_path(root, "nope.json"),
      path_lib.join_path(root, "dry.json") })
    check.is_not.equal(0, failure.code, failure.output)
  end)
end)

-- mutator 只做「必填校验 + usage」这一段契约:真变异跑属 acceptance-mutate 软车道,
-- 由 status 行为用例与车道覆盖,coder 不在此发起变异跑(#606 验收同口径)。
it("mutator_exits_2_and_prints_the_aps_flags_without_a_feature", function()
  local help = _run(MUTATOR, { "--help" })
  check.same(0, help.code, help.output)
  check.matches("--status-interval", help.output, 1, true)
  local usage = _run(MUTATOR, {})
  check.same(2, usage.code, usage.output)
  check.is_true(usage.output:find("--feature", 1, true) ~= nil, usage.output)
  check.is_true(usage.output:find("--runner-worker", 1, true) ~= nil, usage.output)
end)
end)
