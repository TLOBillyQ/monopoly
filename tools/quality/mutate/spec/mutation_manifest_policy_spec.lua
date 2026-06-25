---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/mutate/spec/mutation_manifest_policy_spec.lua") end
require("spec.bootstrap").install_package_paths()

local policy = require("quality.mutation_manifest_policy")

local _MANIFEST_HEAD = "--[[ mutate4lua-manifest\n"
local _MANIFEST_TAIL = "]]"

local function _source()
  return "local M = {}\nfunction M.f() return 1 end\nreturn M\n"
end

local function _manifest_block(version)
  return _MANIFEST_HEAD ..
    "version=" .. tostring(version or 2) .. "\nprojectHash=abc\n" ..
    "scope.0.id=x\nscope.0.semanticHash=h\n" ..
    _MANIFEST_TAIL
end

describe("mutation_manifest_policy.classify_source", function()
  it("classifies a file without a manifest marker as missing", function()
    local result = policy.classify_source(_source())
    assert.are.equal(policy.STATE_MISSING, result.state)
  end)

  it("classifies corrupt manifest tails before consulting parsed data", function()
    local result = policy.classify_source(_source() .. "\n" .. _MANIFEST_HEAD .. "version=2\n")
    assert.are.equal(policy.STATE_CORRUPT, result.state)
  end)

  it("classifies v1 manifests as migration candidates", function()
    local result = policy.classify_source(_source() .. "\n" .. _manifest_block(1), {
      version = 1,
      scopes = { { id = "x", semantic_hash = "h" } },
    })
    assert.are.equal(policy.STATE_V1, result.state)
  end)

  it("classifies v2 manifests without mutation status as bootstrap-only", function()
    local result = policy.classify_source(_source() .. "\n" .. _manifest_block(2), {
      version = 2,
      scopes = { { id = "x", semantic_hash = "h" } },
    }, {
      scopes = { { id = "x", semantic_hash = "h" } },
    })
    assert.are.equal(policy.STATE_BOOTSTRAP_ONLY, result.state)
  end)

  it("classifies v2 manifests with matching scope hashes as current", function()
    local result = policy.classify_source(_source() .. "\n" .. _manifest_block(2), {
      version = 2,
      scopes = { { id = "x", semantic_hash = "h", last_mutation_status = "passed" } },
    }, {
      scopes = { { id = "x", semantic_hash = "h" } },
    })
    assert.are.equal(policy.STATE_CURRENT, result.state)
  end)

  it("classifies v2 manifests with changed scope hashes as drifted", function()
    local result = policy.classify_source(_source() .. "\n" .. _manifest_block(2), {
      version = 2,
      scopes = { { id = "x", semantic_hash = "old", last_mutation_status = "passed" } },
    }, {
      scopes = { { id = "x", semantic_hash = "new" } },
    })
    assert.are.equal(policy.STATE_DRIFTED, result.state)
  end)
end)

local function _runtime(overrides)
  local runtime = {
    read_source = function() return _source() end,
    read_manifest = function() return nil end,
    scan_file = function(path)
      return { path = path, scopes = { { id = "x", semantic_hash = "h" } } }
    end,
  }
  for key, value in pairs(overrides or {}) do
    runtime[key] = value
  end
  return runtime
end

describe("mutation_manifest_policy.categorize_bootstrap", function()
  it("marks unreadable files as skipped", function()
    local result = policy.categorize_bootstrap("src/missing.lua", _runtime({
      read_source = function() return nil, "cannot read" end,
    }))
    assert.are.equal(policy.BOOTSTRAP_SKIPPED, result.action)
    assert.are.equal("cannot read", result.reason)
  end)

  it("marks files without manifest as written", function()
    local result = policy.categorize_bootstrap("src/new.lua", _runtime())
    assert.are.equal(policy.BOOTSTRAP_WRITTEN, result.action)
  end)

  it("marks v1 manifests as migrated", function()
    local result = policy.categorize_bootstrap("src/old.lua", _runtime({
      read_source = function() return _source() .. "\n" .. _manifest_block(1) end,
      read_manifest = function()
        return { version = 1, scopes = { { id = "x", semantic_hash = "h" } } }
      end,
    }))
    assert.are.equal(policy.BOOTSTRAP_MIGRATED, result.action)
  end)

  it("marks current v2 manifests as unchanged", function()
    local result = policy.categorize_bootstrap("src/current.lua", _runtime({
      read_source = function() return _source() .. "\n" .. _manifest_block(2) end,
      read_manifest = function()
        return { version = 2, scopes = { { id = "x", semantic_hash = "h", last_mutation_status = "passed" } } }
      end,
    }))
    assert.are.equal(policy.BOOTSTRAP_UNCHANGED, result.action)
  end)

  it("marks drifted v2 manifests as written", function()
    local result = policy.categorize_bootstrap("src/drift.lua", _runtime({
      read_source = function() return _source() .. "\n" .. _manifest_block(2) end,
      read_manifest = function()
        return { version = 2, scopes = { { id = "x", semantic_hash = "old", last_mutation_status = "passed" } } }
      end,
    }))
    assert.are.equal(policy.BOOTSTRAP_WRITTEN, result.action)
  end)

  it("marks corrupt source manifest tails as skipped", function()
    local result = policy.categorize_bootstrap("src/corrupt.lua", _runtime({
      read_source = function() return _source() .. "\n" .. _MANIFEST_HEAD .. "version=2\n" end,
    }))
    assert.are.equal(policy.BOOTSTRAP_SKIPPED, result.action)
  end)
end)

describe("mutation_manifest_policy.preflight_differential", function()
  it("allows nil and non-Lua targets", function()
    assert.is_true(policy.preflight_differential(nil, nil).allowed)
    assert.is_true(policy.preflight_differential("README.md", nil).allowed)
  end)

  it("allows missing manifests", function()
    local result = policy.preflight_differential("src/foo.lua", nil)
    assert.is_true(result.allowed)
  end)

  it("rejects bootstrap-only manifests with a stable reason", function()
    local result = policy.preflight_differential("src/foo.lua", {
      version = 2,
      scopes = {
        { id = "a", semantic_hash = "h1" },
        { id = "b", semantic_hash = "h2" },
      },
    })
    assert.is_false(result.allowed)
    assert.are.equal(policy.REASON_BOOTSTRAP_ONLY, result.reason)
  end)
end)

describe("mutation_manifest_policy.manifest_write_decision", function()
  it("allows explicit update-manifest writes", function()
    local result = policy.manifest_write_decision({ update_manifest = true }, {
      survived = 12,
      timeout = 3,
    })
    assert.is_true(result.write)
    assert.are.equal(policy.REASON_EXPLICIT_UPDATE, result.reason)
  end)

  it("does not write manifests in lines mode", function()
    local result = policy.manifest_write_decision({ lines_mode = true }, {
      survived = 0,
      timeout = 0,
    })
    assert.is_false(result.write)
    assert.are.equal(policy.REASON_LINES_MODE, result.reason)
  end)

  it("does not write pass manifests when mutants survive", function()
    local result = policy.manifest_write_decision({}, {
      survived = 1,
      timeout = 0,
    })
    assert.is_false(result.write)
    assert.are.equal(policy.REASON_SURVIVED, result.reason)
  end)

  it("does not write pass manifests when mutants time out", function()
    local result = policy.manifest_write_decision({}, {
      survived = 0,
      timeout = 1,
    })
    assert.is_false(result.write)
    assert.are.equal(policy.REASON_TIMEOUT, result.reason)
  end)

  it("allows pass-record writes when no mutants survive or time out", function()
    local result = policy.manifest_write_decision({}, {
      survived = 0,
      timeout = 0,
    })
    assert.is_true(result.write)
    assert.are.equal(policy.REASON_PASS, result.reason)
  end)
end)

describe("mutation_manifest_policy.summarize_mutation_result", function()
  it("normalizes mutation JSON fields and flags survived mutants", function()
    local summary = policy.summarize_mutation_result("src/foo.lua", {
      total_sites = 4,
      killed = 3,
      survived = 1,
      timeout = 0,
      score = 75,
    })
    assert.are.equal("src/foo.lua", summary.file)
    assert.are.equal(4, summary.total_sites)
    assert.is_true(summary.has_survived)
    assert.is_false(summary.has_timeout)
    assert.is_false(summary.write_decision.write)
  end)

  it("flags timed-out mutants as non-pass manifest results", function()
    local summary = policy.summarize_mutation_result("src/foo.lua", {
      total_sites = 2,
      killed = 1,
      survived = 0,
      timeout = 1,
      score = 50,
    })
    assert.is_false(summary.has_survived)
    assert.is_true(summary.has_timeout)
    assert.are.equal(policy.REASON_TIMEOUT, summary.write_decision.reason)
  end)
end)
