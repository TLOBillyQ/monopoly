-- LuaUnit 原生风格：两个顶层 describe（acceptance feature registry / acceptance regenerate）
-- 拍平为单个 TestRegenerate 类，共 4 个用例；regenerate 组的 after_each 收进 tearDown，
-- tmp 目录路径为只读共享数据，保留文件级 local。
local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local registry = require("packages.acceptance.acceptance_features")
local regenerate = require("packages.acceptance.regenerate")

TestRegenerate = {}

local tmp = path_lib.join_path("build/acceptance", "regenerate_spec_tmp")

function TestRegenerate:tearDown()
  fs_lib.remove_path(tmp)
end

function TestRegenerate:test_lists_features_with_unique_well_formed_generated_spec_names()
  lu.assertTrue(#registry.entries > 0)
  lu.assertIsString(registry.generated_dir)
  local seen = {}
  for _, entry in ipairs(registry.entries) do
    lu.assertIsString(entry.feature)
    lu.assertIsString(entry.generated)
    lu.assertEvalToTrue(entry.generated:match("^test_.*_acceptance%.lua$"))
    lu.assertNil(seen[entry.generated], "duplicate generated name: " .. tostring(entry.generated))
    seen[entry.generated] = true
  end
end

function TestRegenerate:test_points_every_entry_at_a_readable_feature_file()
  for _, entry in ipairs(registry.entries) do
    lu.assertEvalToTrue(fs_lib.path_exists(entry.feature), "missing feature: " .. entry.feature)
  end
end

function TestRegenerate:test_regenerates_a_features_spec_into_the_target_dir_deterministically()
  local entry = registry.entries[1]
  local out = path_lib.join_path(tmp, entry.generated)

  local ok = regenerate.run({ generated_dir = tmp, entries = { entry } })
  lu.assertTrue(ok)
  lu.assertEvalToTrue(fs_lib.path_exists(out), "expected regenerated spec at " .. out)

  -- Re-deriving the same feature must produce byte-identical output.
  local first = fs_lib.read_file(out)
  lu.assertTrue(regenerate.run({ generated_dir = tmp, entries = { entry } }))
  lu.assertIs(fs_lib.read_file(out), first)
end

function TestRegenerate:test_fails_loudly_when_a_feature_path_is_missing()
  local ok, err = regenerate.run({
    generated_dir = tmp,
    entries = { { feature = "features/does-not-exist.feature", generated = "test_missing.lua" } },
  })
  lu.assertNil(ok)
  lu.assertEvalToTrue(tostring(err):match("does%-not%-exist"))
end


return TestRegenerate
