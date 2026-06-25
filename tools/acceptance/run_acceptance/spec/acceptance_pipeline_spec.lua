local common = require("shared.lib.common")
local parser = require("acceptance4lua.gherkin_parser")
local generator = require("acceptance4lua.generator")
local json = require("acceptance4lua.json")
local mutator = require("acceptance4lua.mutator")
local normalizer = require("acceptance4lua.chinese_normalizer")
local runner = require("acceptance4lua.runner")
local runtime = require("acceptance4lua.runtime")

local project_root = common.normalize_path(common.current_dir())

local function _cleanup_tmp(tmp_root)
  local ok, err = common.remove_path(tmp_root)
  if ok == nil then
    error(err)
  end
end

local function _with_tmp(tag, fn)
  local tmp_root = common.make_temp_path("acceptance_pipeline_" .. tostring(tag or "tmp"), "")
  _cleanup_tmp(tmp_root)
  local ok, err = xpcall(function()
    fn(tmp_root)
  end, debug.traceback)
  _cleanup_tmp(tmp_root)
  if not ok then
    error(err)
  end
end

local function _sample_feature()
  return table.concat({
    "Feature: Foundation integer parsing",
    "",
    "Background:",
    "  Given project acceptance step handlers are loaded",
    "",
    "Scenario Outline: Parse integer text",
    "  Given a text value <raw>",
    "  When the project converts it to an integer",
    "  Then the integer result is <result>",
    "",
    "Examples:",
    "  | raw | result |",
    "  | 12  | 12     |",
    "  | -7  | -7     |",
    "",
  }, "\n")
end

local function _chinese_feature()
  return table.concat({
    "# language: zh-CN",
    "",
    "功能: 基础整数解析",
    "",
    "背景:",
    "  假如 项目验收步骤已加载",
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
end

local function _write_file(path, content)
  local ok, err = common.ensure_dir(common.parent_dir(path))
  if not ok then
    error(err)
  end
  ok, err = common.write_file(path, content)
  if not ok then
    error(err)
  end
end

describe("acceptance pipeline", function()
  it("loads the portable framework directly from acceptance4lua", function()
    assert.is_truthy(parser.parse_text)
    assert.is_truthy(package.path:find(".swarmforge/tools/acceptance4lua@", 1, true))
    assert.is_truthy(package.path:find("/lib/?.lua", 1, true))
  end)

  it("parses the supported gherkin subset into canonical IR", function()
    local ir, err = parser.parse_text(_sample_feature())

    assert.is_nil(err)
    assert.are.equal("Foundation integer parsing", ir.name)
    assert.are.equal(1, #ir.background)
    assert.are.equal("project acceptance step handlers are loaded", ir.background[1].text)
    assert.are.equal(1, #ir.scenarios)
    assert.are.equal("Parse integer text", ir.scenarios[1].name)
    assert.are.equal(3, #ir.scenarios[1].steps)
    assert.same({ "raw" }, ir.scenarios[1].steps[1].parameters)
    assert.same({ "result" }, ir.scenarios[1].steps[3].parameters)
    assert.same({ raw = "12", result = "12" }, ir.scenarios[1].examples[1])
    assert.same({ raw = "-7", result = "-7" }, ir.scenarios[1].examples[2])
  end)

  it("rejects malformed feature files with useful parser errors", function()
    local ir, err = parser.parse_text(table.concat({
      "Feature: Broken",
      "Scenario Outline: Bad examples",
      "  Given a text value <raw>",
      "Examples:",
      "  | raw | result |",
      "  | 12  |",
    }, "\n"))

    assert.is_nil(ir)
    assert.is_true(tostring(err):find("examples row has 1 cells, expected 2", 1, true) ~= nil)
  end)

  it("rejects unsupported non-empty feature lines instead of dropping them", function()
    local ir, err = parser.parse_text(table.concat({
      "Feature: Broken",
      "Scenario: Unsupported line",
      "  Given project acceptance step handlers are loaded",
      "  Eventually this line should not be ignored",
    }, "\n"))

    assert.is_nil(ir)
    assert.is_true(tostring(err):find("unsupported line: Eventually this line should not be ignored", 1, true) ~= nil)
  end)

  it("round-trips JSON IR with deterministic array fields", function()
    local ir = assert(parser.parse_text(_sample_feature()))
    local encoded = json.encode(ir)
    local decoded = json.decode(encoded)

    assert.are.equal(ir.name, decoded.name)
    assert.are.equal(1, #decoded.background)
    assert.are.equal(1, #decoded.scenarios)
    assert.are.equal(2, #decoded.scenarios[1].examples)
    assert.is_true(encoded:find('"background": [', 1, true) ~= nil)
    assert.is_true(encoded:find('"scenarios": [', 1, true) ~= nil)
  end)

  it("executes parsed scenarios through exact step handlers", function()
    local ir = assert(parser.parse_text(_sample_feature()))
    local handlers = {
      ["project acceptance step handlers are loaded"] = function(world)
        world.loaded = true
      end,
      ["a text value <raw>"] = function(world, example)
        world.raw = example.raw
      end,
      ["the project converts it to an integer"] = function(world)
        world.result = tonumber(world.raw)
      end,
      ["the integer result is <result>"] = function(world, example)
        if world.loaded ~= true then
          return nil, "background did not run"
        end
        if world.result ~= tonumber(example.result) then
          return nil, "unexpected integer result"
        end
        return true
      end,
    }

    local result = runtime.run_feature(ir, handlers)

    assert.is_true(result.ok, runtime.format_failures(result))
  end)

  it("reports unsupported steps and missing example values as runtime failures", function()
    local ir = assert(parser.parse_text(table.concat({
      "Feature: Runtime failures",
      "Scenario Outline: Missing value",
      "  Then the integer result is <result>",
      "",
      "Examples:",
      "  | raw |",
      "  | 12  |",
      "",
      "Scenario: Unsupported step",
      "  Then no handler exists",
      "",
    }, "\n")))

    local handlers = {
      ["the integer result is <result>"] = function()
        return true
      end,
    }
    local result = runtime.run_feature(ir, handlers)
    local failures = runtime.format_failures(result)

    assert.is_false(result.ok)
    assert.is_true(failures:find("missing example value: result", 1, true) ~= nil)
    assert.is_true(failures:find("unsupported step: no handler exists", 1, true) ~= nil)
  end)

  it("generates deterministic busted specs from JSON IR without reading gherkin", function()
    local ir = assert(parser.parse_text(_sample_feature()))
    local first = generator.generate(ir)
    local second = generator.generate(ir)

    assert.are.equal(first, second)
    assert.is_true(first:find('require("acceptance4lua.runtime")', 1, true) ~= nil)
    assert.is_true(first:find('require("acceptance4lua.json")', 1, true) ~= nil)
    assert.is_true(first:find('os.getenv("ACCEPTANCE_FEATURE_JSON")', 1, true) ~= nil)
    assert.is_true(first:find("Feature:", 1, true) == nil)
    assert.is_true(first:find(".feature", 1, true) == nil)
  end)

  it("writes APS generator metadata using generated files only", function()
    _with_tmp("generator_metadata", function(tmp_root)
      local feature_path = common.join_path(tmp_root, "sample.feature")
      local json_path = common.join_path(tmp_root, "build/sample.json")
      local generated_path = common.join_path(tmp_root, "generated/sample_acceptance_spec.lua")
      _write_file(feature_path, _sample_feature())
      assert(parser.write_json_file(feature_path, json_path))
      assert(generator.generate_file(json_path, generated_path))

      local metadata_path = generator.metadata_path_for(generated_path, feature_path)
      local metadata = json.decode(assert(common.read_file(metadata_path)))
      assert.are.equal(1, metadata.schema_version)
      assert.are.equal(feature_path, metadata.feature_path)
      assert.are.equal(json_path, metadata.ir_path)
      assert.are.equal("generated_files", metadata.hash_scope)
      assert.are.equal(generated_path, metadata.generated_files[1])
      assert.is_truthy(metadata.implementation_hash:match("^sha256:[0-9a-f]+$"))
    end)
  end)

  it("builds deterministic example-value mutations", function()
    local ir = assert(parser.parse_text(_sample_feature()))
    local mutations = mutator.build_mutations(ir)

    assert.are.equal(4, #mutations)
    assert.are.equal("m1", mutations[1].id)
    assert.are.equal("$.scenarios[0].examples[0].raw", mutations[1].path)
    assert.are.equal("12", mutations[1].original)
    assert.are_not.equal("12", mutations[1].mutated)
    assert.are.equal("m4", mutations[4].id)
    assert.are.equal("$.scenarios[0].examples[1].result", mutations[4].path)
  end)

  it("mutates portable value shapes without changing mutation identity rules", function()
    assert.are.equal("false", mutator.mutate_value("true", "$.flag"))
    assert.are.equal("value", mutator.mutate_value("nil", "$.none"))
    assert.are_not.equal("3.14", mutator.mutate_value("3.14", "$.float"))
    assert.are_not.equal("2026-05-13", mutator.mutate_value("2026-05-13", "$.date"))
    assert.are_not.equal("2, 5, 8", mutator.mutate_value("2, 5, 8", "$.list"))
  end)

  it("runs the normal acceptance script against the sample project feature", function()
    _with_tmp("normal_run", function(tmp_root)
      local json_path = common.join_path(tmp_root, "a-feature.json")
      local generated_path = common.join_path(tmp_root, "generated/a-feature_acceptance_spec.lua")
      local result = common.run_command({
        "lua",
        "tools/acceptance/run_acceptance.lua",
        "--feature",
        "features/a-feature.feature",
        "--json",
        json_path,
        "--generated",
        generated_path,
      }, {
        cwd = project_root,
      })

      assert.is_true(result.ok, result.output)
      assert.is_true(common.path_exists(json_path))
      assert.is_true(common.path_exists(generated_path))
    end)
  end)

  it("normalizes Chinese Gherkin keywords and stable parameter names before parsing", function()
    local normalized = assert(normalizer.normalize_text(_chinese_feature(), {
      path = "features/a-feature.feature",
    }))

    assert.is_true(normalized.text:find("Feature: 基础整数解析", 1, true) ~= nil)
    assert.is_true(normalized.text:find("Scenario Outline: 解析整数文本", 1, true) ~= nil)
    assert.is_true(normalized.text:find("Given 文本值为<原始文本>", 1, true) ~= nil)
    assert.is_true(normalized.text:find("| 原始文本 | 整数结果 |", 1, true) ~= nil)
    assert.same({
      ["原始文本"] = "原始文本",
      ["整数结果"] = "整数结果",
    }, normalized.source_map.field_names)
  end)

  it("parses Chinese feature files into APS IR with Chinese source metadata", function()
    _with_tmp("parse_chinese", function(tmp_root)
      local feature_path = common.join_path(tmp_root, "features/a-feature.feature")
      _write_file(feature_path, _chinese_feature())

      local ir = assert(parser.parse_file(feature_path))

      assert.are.equal("基础整数解析", ir.name)
      assert.are.equal("Given", ir.background[1].keyword)
      assert.are.equal("项目验收步骤已加载", ir.background[1].text)
      assert.are.equal("文本值为<原始文本>", ir.scenarios[1].steps[1].text)
      assert.same({ "原始文本" }, ir.scenarios[1].steps[1].parameters)
      assert.same({ ["原始文本"] = "12", ["整数结果"] = "12" }, ir.scenarios[1].examples[1])
      assert.are.equal("原始文本", ir.metadata.field_names["原始文本"])
      assert.are.equal("整数结果", ir.metadata.field_names["整数结果"])
      assert.are.equal(14, ir.scenarios[1].metadata.example_field_lines["原始文本"])
    end)
  end)

  it("reports Chinese parser diagnostics with source file line and field names", function()
    _with_tmp("chinese_diagnostic", function(tmp_root)
      local feature_path = common.join_path(tmp_root, "features/broken.feature")
      _write_file(feature_path, table.concat({
        "# language: zh-CN",
        "功能: 损坏规格",
        "场景大纲: 表格错误",
        "  假如 玩家<玩家>已有<已有道具数>张道具",
        "例子:",
        "  | 玩家 | 已有道具数 |",
        "  | 小明 |",
      }, "\n"))

      local ir, err = parser.parse_file(feature_path)

      assert.is_nil(ir)
      assert.is_true(tostring(err):find(feature_path, 1, true) ~= nil)
      assert.is_true(tostring(err):find("第7行", 1, true) ~= nil)
      assert.is_true(tostring(err):find("已有道具数", 1, true) ~= nil)
      assert.is_true(tostring(err):find("p2", 1, true) == nil)
    end)
  end)

  it("rejects English structure keywords in Chinese business feature files", function()
    _with_tmp("english_keyword", function(tmp_root)
      local feature_path = common.join_path(tmp_root, "features/english.feature")
      _write_file(feature_path, table.concat({
        "# language: zh-CN",
        "Feature: Broken",
      }, "\n"))

      local ir, err = parser.parse_file(feature_path)

      assert.is_nil(ir)
      assert.is_true(tostring(err):find("英文结构关键字", 1, true) ~= nil)
      assert.is_true(tostring(err):find("Feature", 1, true) ~= nil)
    end)
  end)

  it("formats runtime missing-value diagnostics with original Chinese field names", function()
    local ir = assert(parser.parse_text(table.concat({
      "Feature: 中文诊断",
      "Scenario Outline: 缺少值",
      "  Given 玩家<p1>已有<p2>张道具",
      "Examples:",
      "  | p1 |",
      "  | 小明 |",
    }, "\n"), {
      source_map = {
        path = "features/broken.feature",
        field_names = {
          p1 = "玩家",
          p2 = "已有道具数",
        },
        line_by_normalized_line = {
          [3] = 10,
        },
      },
    }))

    local result = runtime.run_feature(ir, {
      ["玩家<p1>已有<p2>张道具"] = function()
        return true
      end,
    })

    assert.is_false(result.ok)
    local text = runtime.format_failures(result)
    assert.is_true(text:find("features/broken.feature", 1, true) ~= nil)
    assert.is_true(text:find("第10行", 1, true) ~= nil)
    assert.is_true(text:find("已有道具数", 1, true) ~= nil)
    assert.is_true(text:find("p2", 1, true) == nil)
  end)

  it("formats mutation reports with original Chinese source fields", function()
    _with_tmp("chinese_mutation_report", function(tmp_root)
      local feature_path = common.join_path(tmp_root, "features/a-feature.feature")
      _write_file(feature_path, _chinese_feature())
      local ir = assert(parser.parse_file(feature_path))

      local mutations = mutator.build_mutations(ir)
      local report = {
        summary = {
          total = 1,
          killed = 1,
          survived = 0,
          errors = 0,
        },
        results = {
          {
            mutation = mutations[1],
            status = "killed",
            output = "",
            error = "",
            duration = 0,
          },
        },
      }

      local text = mutator.format_text_report(report, { verbose = true })

      assert.is_true(text:find(feature_path, 1, true) ~= nil)
      assert.is_true(text:find("第14行", 1, true) ~= nil)
      assert.is_true(text:find("原始文本:", 1, true) ~= nil)
      assert.is_true(text:find("p1:", 1, true) == nil)
    end)
  end)

  describe("runner.is_infrastructure_error", function()
    it("flags exit code 127 as infrastructure failure", function()
      assert.is_true(runner.is_infrastructure_error(127, ""))
      assert.is_true(runner.is_infrastructure_error(127, "anything"))
    end)

    it("flags 'not found' anywhere in output", function()
      assert.is_true(runner.is_infrastructure_error(1, "busted: command not found"))
      assert.is_true(runner.is_infrastructure_error(0, "helper not found in spec/helper.lua"))
    end)

    it("treats normal pass/fail exit codes as non-infrastructure", function()
      assert.is_false(runner.is_infrastructure_error(0, "ok 1 - passing"))
      assert.is_false(runner.is_infrastructure_error(1, "not ok 1 - failing assertion"))
    end)

    it("tolerates nil output", function()
      assert.is_false(runner.is_infrastructure_error(0, nil))
      assert.is_true(runner.is_infrastructure_error(127, nil))
    end)
  end)
end)
