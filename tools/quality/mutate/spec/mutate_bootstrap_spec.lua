---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/mutate/spec/mutate_bootstrap_spec.lua") end
require("spec.bootstrap").install_package_paths()

local boot = require("quality.mutate_bootstrap")

local _MANIFEST_HEAD = "--[[ mutate4lua-manifest\n"
local _MANIFEST_TAIL = "]]"

local function _no_manifest_src()
  return "local M = {}\nfunction M.f() return 1 end\nreturn M\n"
end

local function _v2_manifest_block(scopes_text)
  return _MANIFEST_HEAD ..
    "version=2\nprojectHash=abc\n" ..
    (scopes_text or "") ..
    _MANIFEST_TAIL
end

local function _v1_manifest_block(scopes_text)
  return _MANIFEST_HEAD ..
    "version=1\nprojectHash=abc\n" ..
    (scopes_text or "") ..
    _MANIFEST_TAIL
end

describe("mutate_bootstrap.classify_source", function()
  it("returns no_manifest when source has no marker", function()
    local result = boot.classify_source(_no_manifest_src())
    assert.are.equal("no_manifest", result.state)
  end)

  it("returns has_manifest when start and end markers match", function()
    local src = _no_manifest_src() .. "\n" .. _v2_manifest_block("")
    local result = boot.classify_source(src)
    assert.are.equal("has_manifest", result.state)
  end)

  it("returns corrupt when start marker has no closing end marker", function()
    local src = _no_manifest_src() .. "\n" .. _MANIFEST_HEAD ..
      "version=2\nprojectHash=abc\nscope.0.id=foo\n"
    local result = boot.classify_source(src)
    assert.are.equal("corrupt", result.state)
  end)

  it("treats empty source as no_manifest", function()
    local result = boot.classify_source("")
    assert.are.equal("no_manifest", result.state)
  end)
end)

describe("mutate_bootstrap.is_bootstrap_only", function()
  it("returns false when manifest data is nil", function()
    assert.is_false(boot.is_bootstrap_only(nil))
  end)

  it("returns false when scopes table is missing", function()
    assert.is_false(boot.is_bootstrap_only({ version = 2 }))
  end)

  it("returns false when scopes list is empty", function()
    assert.is_false(boot.is_bootstrap_only({ version = 2, scopes = {} }))
  end)

  it("returns true when every scope has nil last_mutation_status", function()
    local data = {
      version = 2,
      scopes = {
        { id = "a", semantic_hash = "h1" },
        { id = "b", semantic_hash = "h2" },
      },
    }
    assert.is_true(boot.is_bootstrap_only(data))
  end)

  it("returns false when at least one scope carries last_mutation_status", function()
    local data = {
      version = 2,
      scopes = {
        { id = "a", semantic_hash = "h1" },
        { id = "b", semantic_hash = "h2", last_mutation_status = "passed" },
      },
    }
    assert.is_false(boot.is_bootstrap_only(data))
  end)

  it("treats no_sites status as a real mutation run, not bootstrap", function()
    local data = {
      version = 2,
      scopes = {
        { id = "a", semantic_hash = "h1", last_mutation_status = "no_sites" },
      },
    }
    assert.is_false(boot.is_bootstrap_only(data))
  end)
end)

describe("mutate_bootstrap.detect_drift", function()
  it("reports drift when scope counts differ", function()
    local existing = { { id = "a", semantic_hash = "h" } }
    local current = {
      { id = "a", semantic_hash = "h" }, { id = "b", semantic_hash = "h2" },
    }
    assert.is_true(boot.detect_drift(existing, current))
  end)

  it("reports drift when any semantic_hash differs", function()
    local existing = { { id = "a", semantic_hash = "h1" } }
    local current = { { id = "a", semantic_hash = "h2" } }
    assert.is_true(boot.detect_drift(existing, current))
  end)

  it("reports clean when all ids and hashes match", function()
    local existing = {
      { id = "a", semantic_hash = "h1" }, { id = "b", semantic_hash = "h2" },
    }
    local current = {
      { id = "a", semantic_hash = "h1" }, { id = "b", semantic_hash = "h2" },
    }
    assert.is_false(boot.detect_drift(existing, current))
  end)
end)

local function _stub_runtime(overrides)
  local out_buf, err_buf, written = {}, {}, {}
  local runtime = {
    list_src_lua_files = function() return {} end,
    read_source = function() return _no_manifest_src() end,
    read_manifest = function() return nil end,
    scan_file = function(path)
      return { scopes = { { id = "x", semantic_hash = "h" } }, _path = path }
    end,
    write_manifest = function(path, data) written[#written + 1] = { path = path, data = data } end,
    out_write = function(s) out_buf[#out_buf + 1] = s end,
    err_write = function(s) err_buf[#err_buf + 1] = s end,
    out_buf = out_buf, err_buf = err_buf, written = written,
  }
  for k, v in pairs(overrides or {}) do runtime[k] = v end
  return runtime
end

describe("mutate_bootstrap.run", function()
  it("exits 0 with hint when no src files are listed", function()
    local runtime = _stub_runtime()
    local result = boot.run({}, runtime)
    assert.are.equal(0, result.exit_code)
    assert.are.equal(0, result.total)
    assert.is_truthy(table.concat(runtime.err_buf):find("无 src 文件", 1, true))
  end)

  it("buckets sources by manifest state", function()
    local cases = {
      {
        name = "no manifest -> written",
        path = "src/foundation/log.lua",
        bucket = "written",
        write_count = 1,
      },
      {
        name = "v1 manifest -> migrated",
        path = "src/old.lua",
        read_source = function()
          return _no_manifest_src() .. _v1_manifest_block("")
        end,
        read_manifest = function()
          return { version = 1, scopes = { { id = "x", semantic_hash = "h" } } }
        end,
        bucket = "migrated",
        write_count = 1,
      },
      {
        name = "v2 matching -> unchanged",
        path = "src/keep.lua",
        read_source = function()
          return _no_manifest_src() .. _v2_manifest_block("scope.0.id=x\nscope.0.semanticHash=h\n")
        end,
        read_manifest = function()
          return { version = 2, scopes = { { id = "x", semantic_hash = "h" } } }
        end,
        bucket = "unchanged",
        write_count = 0,
      },
      {
        name = "v2 drift -> written",
        path = "src/drift.lua",
        read_source = function()
          return _no_manifest_src() .. _v2_manifest_block("scope.0.id=x\nscope.0.semanticHash=OLD\n")
        end,
        read_manifest = function()
          return { version = 2, scopes = { { id = "x", semantic_hash = "OLD" } } }
        end,
        bucket = "written",
        write_count = 1,
      },
    }
    for _, case in ipairs(cases) do
      local overrides = {
        list_src_lua_files = function() return { case.path } end,
      }
      if case.read_source then overrides.read_source = case.read_source end
      if case.read_manifest then overrides.read_manifest = case.read_manifest end
      local runtime = _stub_runtime(overrides)
      local result = boot.run({}, runtime)
      assert.are.same({ case.path }, result[case.bucket], "[" .. case.name .. "] bucket")
      assert.are.equal(case.write_count, #runtime.written, "[" .. case.name .. "] write count")
    end
  end)

  it("buckets corrupt manifest as skipped, warns on stderr, exit 0, continues", function()
    local runtime = _stub_runtime({
      list_src_lua_files = function()
        return { "src/corrupt.lua", "src/clean.lua" }
      end,
      read_source = function(path)
        if path == "src/corrupt.lua" then
          return _no_manifest_src() .. "\n" .. _MANIFEST_HEAD .. "version=2\n"
        end
        return _no_manifest_src()
      end,
    })
    local result = boot.run({}, runtime)
    assert.are.equal(0, result.exit_code)
    assert.are.same({ "src/corrupt.lua" }, result.skipped)
    assert.are.same({ "src/clean.lua" }, result.written)
    local err_text = table.concat(runtime.err_buf)
    assert.is_truthy(err_text:find("src/corrupt.lua", 1, true))
  end)

  it("dry-run does not invoke write_manifest", function()
    local runtime = _stub_runtime({
      list_src_lua_files = function() return { "src/foundation/log.lua" } end,
    })
    local result = boot.run({ dry_run = true }, runtime)
    assert.are.equal(1, #result.written)
    assert.are.equal(0, #runtime.written)
    local out_text = table.concat(runtime.out_buf)
    assert.is_truthy(out_text:find("will-written", 1, true))
  end)

  it("summary line sums to total file count", function()
    local runtime = _stub_runtime({
      list_src_lua_files = function()
        return { "src/a.lua", "src/b.lua", "src/c.lua" }
      end,
    })
    local result = boot.run({}, runtime)
    assert.are.equal(3, result.total)
    local out_text = table.concat(runtime.out_buf)
    assert.is_truthy(out_text:find("total=3", 1, true))
  end)
end)
