---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/mutate/spec/mutate_wrapper_preflight_spec.lua") end
require("spec.bootstrap").install_package_paths()

local mutate = require("quality.mutate")

describe("quality.mutate.preflight_target", function()
  it("returns nil when args is nil", function()
    assert.is_nil(mutate.preflight_target(nil))
  end)

  it("returns nil when args list is empty", function()
    assert.is_nil(mutate.preflight_target({}))
  end)

  it("returns the first positional argument", function()
    assert.are.equal("src/foundation/log.lua",
      mutate.preflight_target({ "src/foundation/log.lua" }))
  end)

  it("returns nil when --mutate-all is present", function()
    assert.is_nil(mutate.preflight_target({ "src/foundation/log.lua", "--mutate-all" }))
  end)

  it("returns nil when --scan is present", function()
    assert.is_nil(mutate.preflight_target({ "src/foundation/log.lua", "--scan" }))
  end)

  it("returns nil when --update-manifest is present", function()
    assert.is_nil(mutate.preflight_target({ "src/foundation/log.lua", "--update-manifest" }))
  end)

  it("returns nil when --lines is present", function()
    assert.is_nil(mutate.preflight_target({ "src/foundation/log.lua", "--lines", "12,18" }))
  end)

  it("returns nil when --help is present", function()
    assert.is_nil(mutate.preflight_target({ "--help" }))
  end)

  -- Value-taking flags must not have their argument mistaken for the positional
  -- target. Flags stay explicit per case so each one is independently pinned.
  for _, case in ipairs({
    { flag = "--lane", value = "contract" },
    { flag = "--test-command", value = "busted --run behavior" },
    { flag = "--poll-interval", value = "0.05" },
  }) do
    it("skips value of " .. case.flag .. " when picking positional target", function()
      assert.are.equal("src/foo.lua",
        mutate.preflight_target({ case.flag, case.value, "src/foo.lua" }))
    end)
  end

  it("returns nil when only flags are present without a positional", function()
    assert.is_nil(mutate.preflight_target({ "--lane", "behavior", "--verbose" }))
  end)
end)

describe("quality.mutate.check_bootstrap_only", function()
  local manifest_mod = require("mutate4lua.internal.manifest")
  local _original_read = manifest_mod.read

  local function stub_read(value)
    if type(value) == "function" then
      manifest_mod.read = value
    else
      manifest_mod.read = function() return value end
    end
  end

  after_each(function()
    manifest_mod.read = _original_read
  end)

  it("passes when target is nil", function()
    assert.is_true(mutate.check_bootstrap_only(nil))
  end)

  it("passes when target is not a .lua file", function()
    assert.is_true(mutate.check_bootstrap_only("README.md"))
  end)

  it("passes when manifest read raises an error", function()
    stub_read(function() error("missing") end)
    assert.is_true(mutate.check_bootstrap_only("src/foo.lua"))
  end)

  it("passes when manifest returns nil (no manifest block)", function()
    stub_read(nil)
    assert.is_true(mutate.check_bootstrap_only("src/foo.lua"))
  end)

  it("passes when at least one scope has last_mutation_status", function()
    stub_read({
      version = 2,
      scopes = {
        { id = "a", semantic_hash = "h1" },
        { id = "b", semantic_hash = "h2", last_mutation_status = "passed" },
      },
    })
    assert.is_true(mutate.check_bootstrap_only("src/foo.lua"))
  end)

  it("fails and writes hint via injected stderr writer when every scope lacks last_mutation_status", function()
    stub_read({
      version = 2,
      scopes = {
        { id = "a", semantic_hash = "h1" },
        { id = "b", semantic_hash = "h2" },
      },
    })
    local captured = {}
    local writer = function(text) captured[#captured + 1] = text end
    local ok = mutate.check_bootstrap_only("src/foo.lua", writer)
    assert.is_false(ok)
    local message = table.concat(captured)
    assert.is_truthy(message:find("bootstrap%-only"))
    assert.is_truthy(message:find("%-%-mutate%-all"))
  end)
end)
