local common = require("shared.lib.common")
local parser = require("acceptance.gherkin_parser")
local generator = require("acceptance.generator")
local json = require("acceptance.json")
local mutator = require("acceptance.mutator")
local runtime = require("acceptance.runtime")

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

describe("acceptance pipeline", function()
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
    assert.is_true(first:find('require("acceptance.runtime")', 1, true) ~= nil)
    assert.is_true(first:find("Feature:", 1, true) == nil)
    assert.is_true(first:find(".feature", 1, true) == nil)
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
end)
