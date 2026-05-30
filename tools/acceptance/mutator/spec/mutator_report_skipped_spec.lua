local json = require("acceptance4lua.json")
local mutator = require("acceptance4lua.mutator")

local function _summary(overrides)
  local base = {
    total = 0,
    killed = 0,
    survived = 0,
    errors = 0,
  }
  for key, value in pairs(overrides or {}) do
    base[key] = value
  end
  return base
end

describe("acceptance4lua.mutator.format_text_report skipped section", function()
  it("omits the skipped line when no scenarios or mutations were skipped", function()
    local report = { summary = _summary(), results = {} }
    local text = mutator.format_text_report(report)
    assert.is_truthy(text:find("total=0", 1, true))
    assert.is_nil(text:find("skipped_scenarios", 1, true))
    assert.is_nil(text:find("skipped_mutations", 1, true))
  end)

  it("emits the skipped line when skipped_scenarios is positive", function()
    local report = {
      summary = _summary({ skipped_scenarios = 3, skipped_mutations = 0 }),
      results = {},
    }
    local text = mutator.format_text_report(report)
    assert.is_truthy(text:find("skipped_scenarios=3 skipped_mutations=0", 1, true))
  end)

  it("emits the skipped line when only skipped_mutations is positive", function()
    local report = {
      summary = _summary({ skipped_scenarios = 0, skipped_mutations = 7 }),
      results = {},
    }
    local text = mutator.format_text_report(report)
    assert.is_truthy(text:find("skipped_scenarios=0 skipped_mutations=7", 1, true))
  end)

  it("places the skipped line immediately after the summary line", function()
    local report = {
      summary = _summary({ killed = 2, skipped_scenarios = 1, skipped_mutations = 4 }),
      results = {},
    }
    local text = mutator.format_text_report(report)
    local lines = {}
    for line in text:gmatch("([^\n]+)") do
      lines[#lines + 1] = line
    end
    assert.is_truthy(lines[1]:find("total="))
    assert.is_truthy(lines[2]:find("skipped_scenarios="))
  end)
end)

describe("acceptance4lua.mutator.format_text_report success output budget", function()
  it("omits killed mutation rows by default", function()
    local report = {
      summary = _summary({ total = 2, killed = 2 }),
      results = {
        {
          status = "killed",
          mutation = { description = "first noisy killed detail" },
          output = "",
          error = "",
        },
        {
          status = "killed",
          mutation = { description = "second noisy killed detail" },
          output = "",
          error = "",
        },
      },
    }

    local text = mutator.format_text_report(report)

    assert.is_truthy(text:find("total=2 killed=2 survived=0 errors=0", 1, true))
    assert.is_nil(text:find("first noisy killed detail", 1, true))
    assert.is_nil(text:find("second noisy killed detail", 1, true))
  end)

  it("keeps killed mutation rows when verbose is requested", function()
    local report = {
      summary = _summary({ total = 1, killed = 1 }),
      results = {
        {
          status = "killed",
          mutation = { description = "verbose killed detail" },
          output = "",
          error = "",
        },
      },
    }

    local text = mutator.format_text_report(report, { verbose = true })

    assert.is_truthy(text:find("verbose killed detail", 1, true))
  end)

  it("preserves survived diagnostics without verbose", function()
    local report = {
      summary = _summary({ total = 1, survived = 1 }),
      results = {
        {
          status = "survived",
          mutation = { description = "important survivor" },
          output = "runner output",
          error = "survivor error",
        },
      },
    }

    local text = mutator.format_text_report(report)

    assert.is_truthy(text:find("important survivor", 1, true))
    assert.is_truthy(text:find("survivor error", 1, true))
    assert.is_truthy(text:find("runner output", 1, true))
  end)
end)

describe("acceptance4lua.mutator.format_json_report skipped fields", function()
  it("omits SkippedScenarios and SkippedMutations when no skips occurred", function()
    local report = { summary = _summary(), results = {} }
    local decoded = json.decode(mutator.format_json_report(report))
    assert.is_nil(decoded.summary.SkippedScenarios)
    assert.is_nil(decoded.summary.SkippedMutations)
  end)

  it("includes SkippedScenarios and SkippedMutations when skips are present", function()
    local report = {
      summary = _summary({ skipped_scenarios = 2, skipped_mutations = 5 }),
      results = {},
    }
    local decoded = json.decode(mutator.format_json_report(report))
    assert.are.equal(2, decoded.summary.SkippedScenarios)
    assert.are.equal(5, decoded.summary.SkippedMutations)
  end)

  it("preserves the existing summary key casing alongside the new fields", function()
    local report = {
      summary = _summary({
        total = 3,
        killed = 3,
        skipped_scenarios = 1,
        skipped_mutations = 2,
      }),
      results = {},
    }
    local decoded = json.decode(mutator.format_json_report(report))
    assert.are.equal(3, decoded.summary.Total)
    assert.are.equal(3, decoded.summary.Killed)
    assert.are.equal(0, decoded.summary.Survived)
    assert.are.equal(0, decoded.summary.Errors)
    assert.are.equal(1, decoded.summary.SkippedScenarios)
    assert.are.equal(2, decoded.summary.SkippedMutations)
  end)
end)
