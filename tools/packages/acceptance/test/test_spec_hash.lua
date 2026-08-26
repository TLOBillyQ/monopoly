local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local spec_hash = require("acceptance4lua.spec_hash")

-- 原 busted 结构为 5 个顶层 describe(sha256 / compute_feature_content_hash /
-- compute_background_hash / compute_scenario_hash / compute_generated_files_hash),
-- 均无钩子、无嵌套,拍平为单个 TestSpecHash 类;describe 体内的 local helper
-- (_scenario_with / _with_tmp) 提升为文件级 local。用例数 16。

local function _scenario_with(name, example_value)
  return {
    name = name,
    steps = {
      { keyword = "Given", text = "input is <key>", parameters = { "key" } },
    },
    examples = {
      { key = example_value },
    },
  }
end

local function _with_tmp(fn)
  local tmp_root = env_lib.make_temp_path("acceptance_spec_hash_", "")
  fs_lib.remove_path(tmp_root)
  lu.assertEvalToTrue(fs_lib.ensure_dir(tmp_root))
  local ok, err = xpcall(function()
    fn(tmp_root)
  end, debug.traceback)
  fs_lib.remove_path(tmp_root)
  if not ok then
    error(err)
  end
end

TestSpecHash = {}

function TestSpecHash:test_sha256_matches_the_empty_string_fips_180_4_test_vector()
  lu.assertIs(
    spec_hash.sha256(""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
end

function TestSpecHash:test_sha256_is_deterministic_across_repeated_calls()
  local first = spec_hash.sha256("the same input every time")
  local second = spec_hash.sha256("the same input every time")
  lu.assertIs(second, first)
end

function TestSpecHash:test_sha256_treats_nil_input_as_empty_string()
  lu.assertIs(spec_hash.sha256(nil), spec_hash.sha256(""))
end

function TestSpecHash:test_sha256_returns_64_hex_characters()
  lu.assertIs(#spec_hash.sha256("any payload"), 64)
  lu.assertNotNil(spec_hash.sha256("any payload"):match("^[0-9a-f]+$"))
end

function TestSpecHash:test_compute_feature_content_hash_strips_the_first_mutation_stamp_line_before_hashing()
  local without_stamp = "Feature: example\n\nScenario: it works\n  Given a step\n"
  local with_stamp =
    "# mutation-stamp: sha256=deadbeef\nFeature: example\n\nScenario: it works\n  Given a step\n"
  lu.assertIs(
    spec_hash.compute_feature_content_hash(with_stamp),
    spec_hash.compute_feature_content_hash(without_stamp)
  )
end

function TestSpecHash:test_compute_feature_content_hash_only_strips_the_first_stamp_line_when_more_than_one_is_present()
  local one_stamp = "# mutation-stamp: sha256=aaa\nFeature: x\n# mutation-stamp: sha256=bbb\n"
  local two_stamps_stripped = "# mutation-stamp: sha256=bbb\nFeature: x\n"

  local computed = spec_hash.compute_feature_content_hash(one_stamp)
  local without_first = spec_hash.compute_feature_content_hash(two_stamps_stripped)

  lu.assertIs(computed, spec_hash.sha256("Feature: x\n# mutation-stamp: sha256=bbb\n"))
  lu.assertNotIs(without_first, computed)
end

function TestSpecHash:test_compute_feature_content_hash_matches_plain_sha256_when_no_stamp_is_present()
  local source = "Feature: example\nScenario: noop\n"
  lu.assertIs(spec_hash.compute_feature_content_hash(source), spec_hash.sha256(source))
end

function TestSpecHash:test_compute_background_hash_returns_a_stable_hex_hash_for_a_fixed_background_array()
  local background = {
    { keyword = "Given", text = "a configured project", parameters = {} },
  }
  local first = spec_hash.compute_background_hash(background)
  local second = spec_hash.compute_background_hash(background)
  lu.assertIs(second, first)
  lu.assertIs(#first, 64)
end

function TestSpecHash:test_compute_background_hash_changes_when_any_step_text_changes()
  local before = spec_hash.compute_background_hash({
    { keyword = "Given", text = "alpha", parameters = {} },
  })
  local after = spec_hash.compute_background_hash({
    { keyword = "Given", text = "beta", parameters = {} },
  })
  lu.assertNotIs(after, before)
end

function TestSpecHash:test_compute_background_hash_treats_nil_and_empty_array_as_the_same_hash()
  lu.assertIs(
    spec_hash.compute_background_hash({}),
    spec_hash.compute_background_hash(nil)
  )
end

function TestSpecHash:test_compute_scenario_hash_returns_the_same_hash_for_example_objects_whose_key_insertion_order_differs()
  local first = spec_hash.compute_scenario_hash({
    name = "two columns",
    steps = {},
    examples = { { alpha = "1", beta = "2" } },
  })
  local second = spec_hash.compute_scenario_hash({
    name = "two columns",
    steps = {},
    examples = { { beta = "2", alpha = "1" } },
  })
  lu.assertIs(second, first)
end

function TestSpecHash:test_compute_scenario_hash_changes_when_scenario_name_changes()
  lu.assertNotIs(
    spec_hash.compute_scenario_hash(_scenario_with("second", "x")),
    spec_hash.compute_scenario_hash(_scenario_with("first", "x"))
  )
end

function TestSpecHash:test_compute_scenario_hash_changes_when_an_example_value_changes()
  lu.assertNotIs(
    spec_hash.compute_scenario_hash(_scenario_with("name", "beta")),
    spec_hash.compute_scenario_hash(_scenario_with("name", "alpha"))
  )
end

function TestSpecHash:test_compute_scenario_hash_changes_when_example_row_order_changes()
  local one = {
    name = "ordered",
    steps = {},
    examples = { { k = "1" }, { k = "2" } },
  }
  local two = {
    name = "ordered",
    steps = {},
    examples = { { k = "2" }, { k = "1" } },
  }
  lu.assertNotIs(
    spec_hash.compute_scenario_hash(two),
    spec_hash.compute_scenario_hash(one)
  )
end

function TestSpecHash:test_compute_generated_files_hash_returns_a_sha256_prefixed_hash_for_generated_files()
  _with_tmp(function(tmp_root)
    local generated_path = path_lib.join_path(tmp_root, "generated/test_a.lua")
    lu.assertEvalToTrue(fs_lib.write_file(generated_path, "return true\n"))

    local hash = spec_hash.compute_generated_files_hash({ generated_path })
    lu.assertEvalToTrue(hash:match("^sha256:[0-9a-f]+$"))
    lu.assertIs(#hash, 71)
  end)
end

function TestSpecHash:test_compute_generated_files_hash_changes_when_generated_file_content_changes()
  _with_tmp(function(tmp_root)
    local generated_path = path_lib.join_path(tmp_root, "generated/test_a.lua")
    lu.assertEvalToTrue(fs_lib.write_file(generated_path, "return true\n"))
    local before = spec_hash.compute_generated_files_hash({ generated_path })

    lu.assertEvalToTrue(fs_lib.write_file(generated_path, "return false\n"))
    local after = spec_hash.compute_generated_files_hash({ generated_path })
    lu.assertNotIs(after, before)
  end)
end


return TestSpecHash
