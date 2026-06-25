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

local function _scope(hash, status)
  return {
    id = "x",
    semantic_hash = hash or "h",
    last_mutation_status = status,
  }
end

local function _manifest_data(version, hash, status)
  return {
    version = version or 2,
    scopes = { _scope(hash, status) },
  }
end

local function _current_data(hash)
  return {
    scopes = { _scope(hash) },
  }
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

  for _, case in ipairs({
    {
      name = "classifies v1 manifests as migration candidates",
      version = 1,
      expected = policy.STATE_V1,
    },
    {
      name = "classifies v2 manifests without mutation status as bootstrap-only",
      version = 2,
      expected = policy.STATE_BOOTSTRAP_ONLY,
      current_hash = "h",
    },
    {
      name = "classifies v2 manifests with matching scope hashes as current",
      version = 2,
      status = "passed",
      expected = policy.STATE_CURRENT,
      current_hash = "h",
    },
    {
      name = "classifies v2 manifests with changed scope hashes as drifted",
      version = 2,
      hash = "old",
      status = "passed",
      expected = policy.STATE_DRIFTED,
      current_hash = "new",
    },
  }) do
    it(case.name, function()
      local current = case.current_hash and _current_data(case.current_hash) or nil
      local result = policy.classify_source(_source() .. "\n" .. _manifest_block(case.version),
        _manifest_data(case.version, case.hash, case.status),
        current)
      assert.are.equal(case.expected, result.state)
    end)
  end
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

  for _, case in ipairs({
    {
      name = "marks v1 manifests as migrated",
      path = "src/old.lua",
      version = 1,
      expected = policy.BOOTSTRAP_MIGRATED,
    },
    {
      name = "marks current v2 manifests as unchanged",
      path = "src/current.lua",
      version = 2,
      status = "passed",
      expected = policy.BOOTSTRAP_UNCHANGED,
    },
    {
      name = "marks drifted v2 manifests as written",
      path = "src/drift.lua",
      version = 2,
      hash = "old",
      status = "passed",
      expected = policy.BOOTSTRAP_WRITTEN,
    },
  }) do
    it(case.name, function()
      local result = policy.categorize_bootstrap(case.path, _runtime({
        read_source = function() return _source() .. "\n" .. _manifest_block(case.version) end,
        read_manifest = function()
          return _manifest_data(case.version, case.hash, case.status)
        end,
      }))
      assert.are.equal(case.expected, result.action)
    end)
  end

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
  for _, case in ipairs({
    {
      name = "allows explicit update-manifest writes",
      opts = { update_manifest = true },
      result = { survived = 12, timeout = 3 },
      write = true,
      reason = policy.REASON_EXPLICIT_UPDATE,
    },
    {
      name = "does not write manifests in lines mode",
      opts = { lines_mode = true },
      result = { survived = 0, timeout = 0 },
      write = false,
      reason = policy.REASON_LINES_MODE,
    },
    {
      name = "does not write pass manifests when mutants survive",
      result = { survived = 1, timeout = 0 },
      write = false,
      reason = policy.REASON_SURVIVED,
    },
    {
      name = "does not write pass manifests when mutants time out",
      result = { survived = 0, timeout = 1 },
      write = false,
      reason = policy.REASON_TIMEOUT,
    },
    {
      name = "allows pass-record writes when no mutants survive or time out",
      result = { survived = 0, timeout = 0 },
      write = true,
      reason = policy.REASON_PASS,
    },
  }) do
    it(case.name, function()
      local result = policy.manifest_write_decision(case.opts or {}, case.result)
      assert.are.equal(case.write, result.write)
      assert.are.equal(case.reason, result.reason)
    end)
  end
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
