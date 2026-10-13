-- 验收注册表与生成入口的七个公开契约。
require("test.bootstrap").install_package_paths()
local check = require("luassert")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local registry = require("packages.acceptance.acceptance_features")
local regenerate = require("packages.acceptance.regenerate")

local tmp = path_lib.join_path("build/acceptance", "regenerate_spec_tmp")

describe("acceptance registry and regeneration", function()
  local saved_open, saved_dofile
  before_each(function()
    saved_open, saved_dofile = io.open, dofile
  end)
  after_each(function()
    rawset(io, "open", saved_open)
    _G.dofile = saved_dofile
    fs_lib.remove_path(tmp)
  end)

it("lists unique well formed generated spec names", function()
  check.is_true(#registry.entries > 0)
  check.is_string(registry.generated_dir)
  local seen = {}
  for _, entry in ipairs(registry.entries) do
    check.is_string(entry.feature)
    check.is_string(entry.generated)
    check.truthy(entry.generated:match("^test_.*_acceptance%.lua$"))
    check.is_nil(seen[entry.generated], "duplicate generated name: " .. tostring(entry.generated))
    seen[entry.generated] = true
  end
end)

it("empty explicit entries are infrastructure failure", function()
  local ok, err = regenerate.run({ entries = {} })
  check.is_nil(ok)
  check.matches("no acceptance entries", err, 1, true)
end)

it("missing or invalid manifest never becomes empty success", function()
  local original_open = io.open
  local original_dofile = dofile
  for _, value in ipairs({ false, { entries = {} } }) do
    _G.dofile = function(path)
      if tostring(path):match("features/manifest%.lua$") then return value end
      return original_dofile(path)
    end
    local ok, err = pcall(original_dofile, "tools/packages/acceptance/acceptance_features.lua")
    _G.dofile = original_dofile
    check.is_false(ok)
    check.matches("manifest invalid or empty", tostring(err), 1, true)
  end
  rawset(io, "open", function(path, mode)
    if tostring(path):match("features/manifest%.lua$") then return nil end
    return original_open(path, mode)
  end)
  local ok, err = pcall(original_dofile, "tools/packages/acceptance/acceptance_features.lua")
  rawset(io, "open", original_open)
  check.is_false(ok)
  check.matches("manifest unavailable", tostring(err), 1, true)
end)

it("native selection and exclusion partition complete manifest", function()
  local selected, excluded = registry.select()
  check.equal(#selected + #excluded, #registry.entries)
  local seen = {}
  for _, entries in ipairs({ selected, excluded }) do
    for _, entry in ipairs(entries) do
      check.is_nil(seen[entry.feature], "identity appears in both sets")
      seen[entry.feature] = entry.generated
    end
  end
  for _, entry in ipairs(registry.entries) do
    check.equal(seen[entry.feature], entry.generated)
  end
  check.equal(#excluded, 1)
  check.equal(excluded[1].feature, "features/tooling/acceptance_mutator_status.feature")
  check.equal(excluded[1].capability, "acceptance-mutate")
end)

it("points every entry at readable feature file", function()
  for _, entry in ipairs(registry.entries) do
    check.truthy(fs_lib.path_exists(entry.feature), "missing feature: " .. entry.feature)
  end
end)

it("regenerates feature spec deterministically", function()
  local entry = registry.entries[1]
  local out = path_lib.join_path(tmp, entry.generated)

  local ok = regenerate.run({ generated_dir = tmp, entries = { entry } })
  check.is_true(ok)
  check.truthy(fs_lib.path_exists(out), "expected regenerated spec at " .. out)

  -- Re-deriving the same feature must produce byte-identical output.
  local first = fs_lib.read_file(out)
  check.is_true(regenerate.run({ generated_dir = tmp, entries = { entry } }))
  check.equal(fs_lib.read_file(out), first)
end)

it("fails loudly when feature path is missing", function()
  local ok, err = regenerate.run({
    generated_dir = tmp,
    entries = { { feature = "features/does-not-exist.feature", generated = "test_missing.lua" } },
  })
  check.is_nil(ok)
  check.truthy(tostring(err):match("does%-not%-exist"))
end)
end)
