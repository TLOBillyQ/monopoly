require("test.bootstrap").install_package_paths()
local check = require("luassert")
local proc = require("foundation.proc")
local lua54 = require("packages.luaunit_runner.lua54")
local root = require("foundation.bootstrap").resolve(debug.getinfo(1, "S").source).repo_root

describe("dual backend", function()
it("real busted and legacy results are reconciled", function()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/manifest.lua", "--output=TAP", "--",
    "test/fixtures/dual_backend/legacy.lua", "test/fixtures/dual_backend/passing.lua" })
  check.equal(0, result.code, result.output)
  check.matches("# COUNTS: files=2 cases=3 passed=3 failed=0 errors=0", result.output, 1, true)
  local _, count = result.output:gsub("# COUNTS:", "")
  check.equal(1, count, result.output)
end)
it("nested hooks replay rng and restore ports after teardown", function()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/lifecycle_manifest.lua", "--output=TAP",
    "--helper=test/helper.lua", "--", "test/fixtures/dual_backend/test/behavior/lifecycle.lua" })
  check.equal(0, result.code, result.output)
  check.matches("# COUNTS: files=1 cases=2 passed=2 failed=0 errors=0", result.output, 1, true)
end)
it("teardown leak fails and is restored for next case", function()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/leak_manifest.lua", "--output=TAP",
    "--helper=test/helper.lua", "--", "test/fixtures/dual_backend/test/behavior/leak.lua" })
  check.equal(1, result.code, result.output)
  check.matches("# BASELINE LEAK:", result.output, 1, true)
  local compressed = require("foundation.tap_summary").compress(result.output)
  check.matches("# BASELINE LEAK:", compressed, 1, true)
  check.matches("errors=1", compressed, 1, true)
  check.matches("cases=2 passed=2 failed=0 errors=1", result.output, 1, true)
end)
it("actual failure and empty busted are nonzero", function()
  for _, name in ipairs({ "failing", "empty" }) do
    local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
      "--backend-manifest=test/fixtures/dual_backend/negative_manifest.lua", "--output=TAP", "--",
      "test/fixtures/dual_backend/" .. name .. ".lua" })
    check.equal(1, result.code, result.output)
    if name == "failing" then check.matches("cases=1 passed=0 failed=1 errors=0", result.output, 1, true)
    else check.matches("empty result", result.output, 1, true) end
  end
end)
it("manifest rejects missing and duplicate file identities", function()
  for _, files in ipairs({ { "test/fixtures/dual_backend/empty.lua" },
    { "test/fixtures/dual_backend/passing.lua", "test/fixtures/dual_backend/passing.lua" } }) do
    local command = { lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
      "--backend-manifest=test/fixtures/dual_backend/manifest.lua", "--output=TAP", "--" }
    for _, file in ipairs(files) do command[#command + 1] = file end
    local result = proc.run_command(command)
    check.equal(1, result.code, result.output)
    check.matches("identity", result.output, 1, true)
  end
end)
it("failed setup and teardown are errors and restore baseline", function()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/hook_manifest.lua", "--output=TAP", "--helper=test/helper.lua", "--",
    "test/fixtures/dual_backend/test/behavior/hook_errors.lua" })
  check.equal(1, result.code, result.output)
  check.matches("victim still sees shared ports", result.output, 1, true)
  check.matches("# BASELINE LEAK:", result.output, 1, true)
  check.matches("setup exploded", result.output, 1, true)
  check.matches("teardown exploded", result.output, 1, true)
  check.matches("files=1 cases=3 passed=1 failed=0 errors=4", result.output, 1, true)
end)
it("cache provenance rejects preloaded fake busted", function()
  local script = 'dofile("tools/foundation/bootstrap.lua").install("tools/cli.lua"); package.loaded["busted.core"]={}; require("packages.test_runner.cache_loader").install("' .. root .. '")'
  local result = proc.run_command({ lua54.lua54_bin(), "-e", script })
  check.equal(1, result.code, result.output)
  check.matches("unverified preloaded module: busted.core", result.output, 1, true)
end)
it("registered lists are disjoint and cover actual profiles", function()
  local profiles = dofile(root .. "/tools/packages/spec_lane/spec_profiles.lua")
  local manifest = dofile(root .. "/tools/packages/test_runner/backend_manifest.lua")
  local discovered, seen = {}, {}
  for _, name in ipairs({ "contract", "guards", "behavior", "tooling" }) do
    for _, directory in ipairs(profiles[name].ROOT) do
      for _, file in ipairs(require("foundation.spec_sharding").discover_spec_files(directory)) do
        if not seen[file] then discovered[#discovered + 1] = file; seen[file] = true end
      end
    end
  end
  local selected = require("packages.test_runner.manifest").partition(manifest, discovered, root)
  check.equal(#manifest.legacy + #manifest.busted, #selected.legacy + #selected.busted)
end)
it("one runtime error is counted once", function()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/negative_manifest.lua", "--output=TAP", "--",
    "test/fixtures/dual_backend/runtime_error.lua" })
  check.equal(1, result.code, result.output)
  check.matches("body exploded", result.output, 1, true)
  check.matches("cases=1 passed=0 failed=0 errors=1", result.output, 1, true)
end)
it("cross file modules keep identity and explicit patch restoration", function()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/manifest.lua", "--output=TAP", "--",
    "test/fixtures/dual_backend/polluter.lua", "test/fixtures/dual_backend/victim.lua" })
  check.equal(0, result.code, result.output)
  check.matches("files=2 cases=2 passed=2 failed=0 errors=0", result.output, 1, true)
end)
it("legacy file list rejects empty missing and invalid data", function()
  local fs = require("foundation.fs")
  local file = require("foundation.env").make_temp_path("file_list_negative", ".txt")
  local ok, err = pcall(function()
    for _, content in ipairs({ "", "return {}\n", "invalid\0.lua\n" }) do
      assert(fs.write_file(file, content))
      local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/luaunit_runner/runner.lua",
        "--file-list=" .. file })
      check.equal(1, result.code, result.output)
    end
    fs.remove_path(file)
    local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/luaunit_runner/runner.lua",
      "--file-list=" .. file })
    check.equal(1, result.code, result.output)
  end)
  fs.remove_path(file)
  if not ok then error(err) end
end)
it("each backend rejects an empty file even beside passing cases", function()
  for _, sample in ipairs({ { "manifest", "legacy", "legacy_empty" }, { "negative_manifest", "passing", "empty" } }) do
    local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
      "--backend-manifest=test/fixtures/dual_backend/" .. sample[1] .. ".lua", "--output=TAP", "--",
      "test/fixtures/dual_backend/" .. sample[2] .. ".lua", "test/fixtures/dual_backend/" .. sample[3] .. ".lua" })
    check.equal(1, result.code, result.output)
    check.matches("empty spec file: test/fixtures/dual_backend/" .. sample[3] .. ".lua", result.output, 1, true)
  end
end)
end)
