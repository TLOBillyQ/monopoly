---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/mutate/spec/verify_mutation_diff_spec.lua") end
require("spec.bootstrap").install_package_paths()

local verify = require("quality.verify_mutation_diff")

local function _stub_runtime(overrides)
  local out_buf, err_buf = {}, {}
  local runtime = {
    diff_name_status = function() return "" end,
    mutate_file = function() return { exit_code = 0, json = {}, stderr = "" } end,
    out_write = function(s) out_buf[#out_buf + 1] = s end,
    err_write = function(s) err_buf[#err_buf + 1] = s end,
    out_buf = out_buf,
    err_buf = err_buf,
  }
  for k, v in pairs(overrides or {}) do runtime[k] = v end
  return runtime
end

describe("verify_mutation_diff.parse_name_status", function()
  it("parses M/A/D entries", function()
    local entries = verify.parse_name_status(
      "M\tsrc/foundation/log.lua\n" ..
      "A\tsrc/foundation/new.lua\n" ..
      "D\tsrc/foundation/retired.lua\n"
    )
    assert.are.equal(3, #entries)
    assert.are.same({ status = "M", path = "src/foundation/log.lua" }, entries[1])
    assert.are.same({ status = "A", path = "src/foundation/new.lua" }, entries[2])
    assert.are.same({ status = "D", path = "src/foundation/retired.lua" }, entries[3])
  end)

  it("parses rename entries by taking the new path", function()
    local entries = verify.parse_name_status("R100\tsrc/old.lua\tsrc/new.lua\n")
    assert.are.equal(1, #entries)
    assert.are.equal("R", entries[1].status)
    assert.are.equal("src/new.lua", entries[1].path)
  end)

  it("ignores blank lines", function()
    local entries = verify.parse_name_status("\n\nM\tsrc/foundation/log.lua\n\n")
    assert.are.equal(1, #entries)
  end)
end)

describe("verify_mutation_diff.filter_changed_src", function()
  it("keeps src/**/*.lua and drops deleted entries", function()
    local kept = verify.filter_changed_src({
      { status = "M", path = "src/foundation/log.lua" },
      { status = "A", path = "src/foundation/new.lua" },
      { status = "D", path = "src/foundation/retired.lua" },
      { status = "M", path = "docs/decisions/0004-mutation.md" },
      { status = "M", path = "spec/contract/state/state_machine.lua" },
      { status = "M", path = "tools/quality/verify_full.lua" },
      { status = "A", path = "features/quality/dice.feature" },
    })
    local paths = {}
    for _, e in ipairs(kept) do paths[#paths + 1] = e.path end
    assert.are.same({
      "src/foundation/log.lua",
      "src/foundation/new.lua",
    }, paths)
  end)
end)

describe("verify_mutation_diff.run", function()
  it("exits 0 with hint when there are no src changes", function()
    local runtime = _stub_runtime({
      diff_name_status = function() return "M\tdocs/x.md\n" end,
    })
    local result = verify.run({}, runtime)
    assert.are.equal(0, result.exit_code)
    assert.are.equal(0, #result.processed)
    local err_text = table.concat(runtime.err_buf)
    assert.is_truthy(err_text:find("无 src 变更", 1, true))
  end)

  it("exits 0 silently when all files are clean", function()
    local mutate_calls = {}
    local runtime = _stub_runtime({
      diff_name_status = function() return "M\tsrc/foundation/log.lua\n" end,
      mutate_file = function(file)
        mutate_calls[#mutate_calls + 1] = file
        return { exit_code = 0, json = {
          file = file, total_sites = 5, killed = 5,
          survived = 0, timeout = 0, score = 100,
        }, stderr = "" }
      end,
    })
    local result = verify.run({}, runtime)
    assert.are.equal(0, result.exit_code)
    assert.are.same({ "src/foundation/log.lua" }, mutate_calls)
    local err_text = table.concat(runtime.err_buf)
    assert.is_nil(err_text:find("survived", 1, true))
  end)

  it("exits 0 silently when diff yielded zero mutation sites", function()
    local runtime = _stub_runtime({
      diff_name_status = function() return "M\tsrc/foundation/log.lua\n" end,
      mutate_file = function(file)
        return { exit_code = 0, json = {
          file = file, total_sites = 0, killed = 0,
          survived = 0, timeout = 0, score = 100,
        }, stderr = "" }
      end,
    })
    local result = verify.run({}, runtime)
    assert.are.equal(0, result.exit_code)
    local err_text = table.concat(runtime.err_buf)
    assert.is_nil(err_text:find("survived", 1, true))
  end)

  it("warns on stderr and exits 0 when any file has survived mutants", function()
    local runtime = _stub_runtime({
      diff_name_status = function() return "M\tsrc/foundation/log.lua\n" end,
      mutate_file = function(file)
        return { exit_code = 3, json = {
          file = file, total_sites = 10, killed = 7,
          survived = 3, timeout = 0, score = 70,
        }, stderr = "" }
      end,
    })
    local result = verify.run({}, runtime)
    assert.are.equal(0, result.exit_code)
    local err_text = table.concat(runtime.err_buf)
    assert.is_truthy(err_text:find("src/foundation/log.lua", 1, true))
    assert.is_truthy(err_text:find("survived=3", 1, true))
  end)

  it("aborts with exit 1 on baseline failure and does not process later files", function()
    local mutate_calls = {}
    local runtime = _stub_runtime({
      diff_name_status = function()
        return "M\tsrc/foundation/log.lua\nM\tsrc/foundation/tips.lua\n"
      end,
      mutate_file = function(file)
        mutate_calls[#mutate_calls + 1] = file
        if file == "src/foundation/log.lua" then
          return { exit_code = 1, json = nil, stderr = "baseline test failed (exit 1)" }
        end
        return { exit_code = 0, json = {
          file = file, total_sites = 1, killed = 1,
          survived = 0, timeout = 0, score = 100,
        }, stderr = "" }
      end,
    })
    local result = verify.run({}, runtime)
    assert.are.equal(1, result.exit_code)
    assert.are.same({ "src/foundation/log.lua" }, mutate_calls)
    local err_text = table.concat(runtime.err_buf)
    assert.is_truthy(err_text:find("src/foundation/log.lua", 1, true))
  end)

  it("aborts the batch when a file's manifest is bootstrap-only", function()
    local mutate_calls = {}
    local runtime = _stub_runtime({
      diff_name_status = function()
        return "M\tsrc/foundation/log.lua\nM\tsrc/foundation/tips.lua\n"
      end,
      mutate_file = function(file)
        mutate_calls[#mutate_calls + 1] = file
        if file == "src/foundation/log.lua" then
          return {
            exit_code = 1,
            json = nil,
            stderr = "[mutate] src/foundation/log.lua manifest is bootstrap-only\n",
          }
        end
        return { exit_code = 0, json = {}, stderr = "" }
      end,
    })
    local result = verify.run({}, runtime)
    assert.are.equal(1, result.exit_code)
    assert.are.same({ "src/foundation/log.lua" }, mutate_calls)
    local err_text = table.concat(runtime.err_buf)
    assert.is_truthy(err_text:find("bootstrap%-only"))
  end)

  it("uses --base override for diff invocation", function()
    local seen_base
    local runtime = _stub_runtime({
      diff_name_status = function(base)
        seen_base = base
        return ""
      end,
    })
    verify.run({ base = "origin/main" }, runtime)
    assert.are.equal("origin/main", seen_base)
  end)

  it("defaults base to main when --base not given", function()
    local seen_base
    local runtime = _stub_runtime({
      diff_name_status = function(base)
        seen_base = base
        return ""
      end,
    })
    verify.run({}, runtime)
    assert.are.equal("main", seen_base)
  end)

  it("emits per-file JSON to stdout in --json mode", function()
    local runtime = _stub_runtime({
      diff_name_status = function()
        return "M\tsrc/foundation/log.lua\nA\tsrc/foundation/new.lua\n"
      end,
      mutate_file = function(file)
        return { exit_code = 0, json = {
          file = file, total_sites = 4, killed = 4,
          survived = 0, timeout = 0, score = 100,
        }, stderr = "" }
      end,
    })
    local result = verify.run({ json = true }, runtime)
    assert.are.equal(0, result.exit_code)
    local out_text = table.concat(runtime.out_buf)
    assert.is_truthy(out_text:find('"file"', 1, true))
    assert.is_truthy(out_text:find("src/foundation/log.lua", 1, true))
    assert.is_truthy(out_text:find("src/foundation/new.lua", 1, true))
    for _, field in ipairs({
      "file", "total_sites", "killed", "survived", "timeout", "score",
    }) do
      assert.is_truthy(out_text:find('"' .. field .. '"', 1, true),
        "JSON output should contain field: " .. field)
    end
  end)
end)
