require("test.bootstrap").install_package_paths()
local lu = require("luaunit")
local proc = require("foundation.proc")
local lua54 = require("packages.luaunit_runner.lua54")
local root = require("foundation.bootstrap").resolve(debug.getinfo(1, "S").source).repo_root

TestDualBackend = {}
function TestDualBackend:test_real_busted_and_legacy_results_are_reconciled()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/manifest.lua", "--output=TAP", "--",
    "test/fixtures/dual_backend/legacy.lua", "test/fixtures/dual_backend/passing.lua" })
  lu.assertEquals(result.code, 0, result.output)
  lu.assertStrContains(result.output, "# COUNTS: files=2 cases=3 passed=3 failed=0 errors=0")
  local _, count = result.output:gsub("# COUNTS:", "")
  lu.assertEquals(count, 1, result.output)
end
function TestDualBackend:test_nested_hooks_replay_rng_and_restore_ports_after_teardown()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/lifecycle_manifest.lua", "--output=TAP",
    "--helper=test/helper.lua", "--", "test/fixtures/dual_backend/test/behavior/lifecycle.lua" })
  lu.assertEquals(result.code, 0, result.output)
  lu.assertStrContains(result.output, "# COUNTS: files=1 cases=2 passed=2 failed=0 errors=0")
end
function TestDualBackend:test_teardown_leak_fails_and_is_restored_for_next_case()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/leak_manifest.lua", "--output=TAP",
    "--helper=test/helper.lua", "--", "test/fixtures/dual_backend/test/behavior/leak.lua" })
  lu.assertEquals(result.code, 1, result.output)
  lu.assertStrContains(result.output, "# BASELINE LEAK:")
  local compressed = require("foundation.tap_summary").compress(result.output)
  lu.assertStrContains(compressed, "# BASELINE LEAK:")
  lu.assertStrContains(compressed, "errors=1")
  lu.assertStrContains(result.output, "cases=2 passed=2 failed=0 errors=1")
end
function TestDualBackend:test_actual_failure_and_empty_busted_are_nonzero()
  for _, name in ipairs({ "failing", "empty" }) do
    local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
      "--backend-manifest=test/fixtures/dual_backend/negative_manifest.lua", "--output=TAP", "--",
      "test/fixtures/dual_backend/" .. name .. ".lua" })
    lu.assertEquals(result.code, 1, result.output)
    if name == "failing" then lu.assertStrContains(result.output, "cases=1 passed=0 failed=1 errors=0")
    else lu.assertStrContains(result.output, "empty result") end
  end
end
function TestDualBackend:test_manifest_rejects_missing_and_duplicate_file_identities()
  for _, files in ipairs({ { "test/fixtures/dual_backend/empty.lua" },
    { "test/fixtures/dual_backend/passing.lua", "test/fixtures/dual_backend/passing.lua" } }) do
    local command = { lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
      "--backend-manifest=test/fixtures/dual_backend/manifest.lua", "--output=TAP", "--" }
    for _, file in ipairs(files) do command[#command + 1] = file end
    local result = proc.run_command(command)
    lu.assertEquals(result.code, 1, result.output)
    lu.assertStrContains(result.output, "identity")
  end
end
function TestDualBackend:test_failed_setup_and_teardown_are_errors_and_restore_baseline()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/hook_manifest.lua", "--output=TAP", "--helper=test/helper.lua", "--",
    "test/fixtures/dual_backend/test/behavior/hook_errors.lua" })
  lu.assertEquals(result.code, 1, result.output)
  lu.assertStrContains(result.output, "victim still sees shared ports")
  lu.assertStrContains(result.output, "# BASELINE LEAK:")
  lu.assertStrContains(result.output, "setup exploded")
  lu.assertStrContains(result.output, "teardown exploded")
  lu.assertStrContains(result.output, "files=1 cases=3 passed=1 failed=0 errors=4")
end
function TestDualBackend:test_cache_provenance_rejects_preloaded_fake_busted()
  local script = 'dofile("tools/foundation/bootstrap.lua").install("tools/cli.lua"); package.loaded["busted.core"]={}; require("packages.test_runner.cache_loader").install("' .. root .. '")'
  local result = proc.run_command({ lua54.lua54_bin(), "-e", script })
  lu.assertEquals(result.code, 1, result.output)
  lu.assertStrContains(result.output, "unverified preloaded module: busted.core")
end
function TestDualBackend:test_registered_lists_are_disjoint_and_cover_actual_profiles()
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
  lu.assertEquals(#selected.legacy + #selected.busted, #manifest.legacy + #manifest.busted)
end
function TestDualBackend:test_one_runtime_error_is_counted_once()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/negative_manifest.lua", "--output=TAP", "--",
    "test/fixtures/dual_backend/runtime_error.lua" })
  lu.assertEquals(result.code, 1, result.output)
  lu.assertStrContains(result.output, "body exploded")
  lu.assertStrContains(result.output, "cases=1 passed=0 failed=0 errors=1")
end
function TestDualBackend:test_cross_file_modules_keep_identity_and_explicit_patch_restoration()
  local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
    "--backend-manifest=test/fixtures/dual_backend/manifest.lua", "--output=TAP", "--",
    "test/fixtures/dual_backend/polluter.lua", "test/fixtures/dual_backend/victim.lua" })
  lu.assertEquals(result.code, 0, result.output)
  lu.assertStrContains(result.output, "files=2 cases=2 passed=2 failed=0 errors=0")
end
function TestDualBackend:test_legacy_file_list_rejects_empty_missing_and_invalid_data()
  local fs = require("foundation.fs")
  local file = require("foundation.env").make_temp_path("file_list_negative", ".txt")
  local ok, err = pcall(function()
    for _, content in ipairs({ "", "return {}\n", "invalid\0.lua\n" }) do
      assert(fs.write_file(file, content))
      local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/luaunit_runner/runner.lua",
        "--file-list=" .. file })
      lu.assertEquals(result.code, 1, result.output)
    end
    fs.remove_path(file)
    local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/luaunit_runner/runner.lua",
      "--file-list=" .. file })
    lu.assertEquals(result.code, 1, result.output)
  end)
  fs.remove_path(file)
  if not ok then error(err) end
end
function TestDualBackend:test_each_backend_rejects_an_empty_file_even_beside_passing_cases()
  for _, sample in ipairs({ { "manifest", "legacy", "legacy_empty" }, { "negative_manifest", "passing", "empty" } }) do
    local result = proc.run_command({ lua54.lua54_bin(), root .. "/tools/packages/test_runner/runner.lua",
      "--backend-manifest=test/fixtures/dual_backend/" .. sample[1] .. ".lua", "--output=TAP", "--",
      "test/fixtures/dual_backend/" .. sample[2] .. ".lua", "test/fixtures/dual_backend/" .. sample[3] .. ".lua" })
    lu.assertEquals(result.code, 1, result.output)
    lu.assertStrContains(result.output, "empty spec file: test/fixtures/dual_backend/" .. sample[3] .. ".lua")
  end
end
return TestDualBackend
