local common = require("shared.lib.common")
local registry = require("acceptance.acceptance_features")
local regenerate = require("acceptance.regenerate")

describe("acceptance feature registry", function()
  it("lists features with unique, well-formed generated spec names", function()
    assert.is_true(#registry.entries > 0)
    assert.is_string(registry.generated_dir)
    local seen = {}
    for _, entry in ipairs(registry.entries) do
      assert.is_string(entry.feature)
      assert.is_string(entry.generated)
      assert.is_truthy(entry.generated:match("_spec%.lua$"))
      assert.is_nil(seen[entry.generated], "duplicate generated name: " .. tostring(entry.generated))
      seen[entry.generated] = true
    end
  end)

  it("points every entry at a readable feature file", function()
    for _, entry in ipairs(registry.entries) do
      assert.is_truthy(common.path_exists(entry.feature), "missing feature: " .. entry.feature)
    end
  end)
end)

describe("acceptance regenerate", function()
  local tmp = common.join_path("build/acceptance", "regenerate_spec_tmp")

  after_each(function()
    common.remove_path(tmp)
  end)

  it("regenerates a feature's spec into the target dir, deterministically", function()
    local entry = registry.entries[1]
    local out = common.join_path(tmp, entry.generated)

    local ok = regenerate.run({ generated_dir = tmp, entries = { entry } })
    assert.is_true(ok)
    assert.is_truthy(common.path_exists(out), "expected regenerated spec at " .. out)

    -- Re-deriving the same feature must produce byte-identical output.
    local first = common.read_file(out)
    assert.is_true(regenerate.run({ generated_dir = tmp, entries = { entry } }))
    assert.are.equal(first, common.read_file(out))
  end)

  it("fails loudly when a feature path is missing", function()
    local ok, err = regenerate.run({
      generated_dir = tmp,
      entries = { { feature = "features/does-not-exist.feature", generated = "missing_spec.lua" } },
    })
    assert.is_nil(ok)
    assert.is_truthy(tostring(err):match("does%-not%-exist"))
  end)
end)
