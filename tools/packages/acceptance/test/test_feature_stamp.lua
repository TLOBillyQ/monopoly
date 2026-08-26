-- 原生 LuaUnit 迁移:四个顶层 describe(read_stamp / is_stamp_current / apply_stamp /
-- apply_stamp_to_file)均无钩子、无嵌套、无共享 local,全部拍平进单一类
-- TestFeatureStamp,用例数与改写前一致(4 + 4 + 4 + 2 = 14 例)。apply_stamp 与
-- apply_stamp_to_file 两组各有一个同名 it「replaces an existing stamp instead of
-- duplicating it」,后者加 _2 后缀避开方法名冲突。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local feature_stamp = require("acceptance4lua.feature_stamp")
local spec_hash = require("acceptance4lua.spec_hash")

local function _sample_feature(body)
  return body or table.concat({
    "Feature: example",
    "",
    "Scenario: it works",
    "  Given a step",
    "",
  }, "\n")
end

local function _with_tmp_file(content, fn)
  local tmp_dir = env_lib.make_temp_path("acceptance_feature_stamp_", "")
  fs_lib.remove_path(tmp_dir)
  fs_lib.ensure_dir(tmp_dir)
  local path = tmp_dir .. "/feature.feature"
  local handle = assert(io.open(path, "w"))
  handle:write(content)
  handle:close()
  local ok, err = xpcall(function()
    fn(path)
  end, debug.traceback)
  fs_lib.remove_path(tmp_dir)
  if not ok then
    error(err)
  end
end

TestFeatureStamp = {}

function TestFeatureStamp:test_returns_nil_when_no_stamp_line_is_present()
  lu.assertNil(feature_stamp.read_stamp(_sample_feature()))
end

function TestFeatureStamp:test_reads_a_stamp_at_the_very_first_line()
  local source = "# mutation-stamp: sha256=deadbeef\nFeature: x\n"
  lu.assertIs(feature_stamp.read_stamp(source), "deadbeef")
end

function TestFeatureStamp:test_reads_a_stamp_that_is_not_the_first_line()
  local source = "# language: zh-CN\n# mutation-stamp: sha256=cafebabe\n功能: 例子\n"
  lu.assertIs(feature_stamp.read_stamp(source), "cafebabe")
end

function TestFeatureStamp:test_returns_nil_when_the_stamp_marker_exists_but_the_hash_is_malformed()
  local source = "# mutation-stamp: sha256=NOT_HEX\nFeature: x\n"
  lu.assertNil(feature_stamp.read_stamp(source))
end

function TestFeatureStamp:test_returns_false_when_no_stamp_is_present()
  lu.assertFalse(feature_stamp.is_stamp_current(_sample_feature()))
end

function TestFeatureStamp:test_returns_true_immediately_after_apply_stamp()
  local stamped = feature_stamp.apply_stamp(_sample_feature())
  lu.assertTrue(feature_stamp.is_stamp_current(stamped))
end

function TestFeatureStamp:test_returns_false_after_content_changes_following_a_stamp()
  local stamped = feature_stamp.apply_stamp(_sample_feature())
  local mutated = stamped .. "\n# added comment\n"
  lu.assertFalse(feature_stamp.is_stamp_current(mutated))
end

function TestFeatureStamp:test_returns_false_when_stamp_hash_does_not_match_content_hash()
  local source = "# mutation-stamp: sha256=" .. string.rep("0", 64) .. "\nFeature: x\n"
  lu.assertFalse(feature_stamp.is_stamp_current(source))
end

function TestFeatureStamp:test_prepends_a_stamp_line_to_an_unstamped_feature()
  local source = _sample_feature()
  local stamped = feature_stamp.apply_stamp(source)
  lu.assertEvalToTrue(stamped:match("^# mutation%-stamp: sha256=[0-9a-f]+\n"))
  lu.assertEvalToTrue(stamped:find(source, 1, true))
end

function TestFeatureStamp:test_replaces_an_existing_stamp_instead_of_duplicating_it()
  local source = _sample_feature()
  local first_pass = feature_stamp.apply_stamp(source)
  local second_pass = feature_stamp.apply_stamp(first_pass)
  local _, stamp_count = second_pass:gsub("mutation%-stamp:", "")
  lu.assertIs(stamp_count, 1)
end

function TestFeatureStamp:test_is_idempotent_for_a_feature_that_has_not_been_edited()
  local stamped_once = feature_stamp.apply_stamp(_sample_feature())
  local stamped_twice = feature_stamp.apply_stamp(stamped_once)
  lu.assertIs(stamped_twice, stamped_once)
end

function TestFeatureStamp:test_encodes_the_hash_as_sha256_of_the_feature_content_minus_the_stamp_line()
  local source = _sample_feature()
  local stamped = feature_stamp.apply_stamp(source)
  local hash = feature_stamp.read_stamp(stamped)
  lu.assertIs(hash, spec_hash.sha256(source))
end

function TestFeatureStamp:test_writes_a_stamp_line_at_the_top_of_the_target_file()
  _with_tmp_file(_sample_feature(), function(path)
    local ok, err = feature_stamp.apply_stamp_to_file(path)
    lu.assertTrue(ok)
    lu.assertNil(err)
    local content = assert(fs_lib.read_file(path))
    lu.assertEvalToTrue(content:match("^# mutation%-stamp: sha256=[0-9a-f]+\n"))
    lu.assertTrue(feature_stamp.is_stamp_current(content))
  end)
end

function TestFeatureStamp:test_replaces_an_existing_stamp_instead_of_duplicating_it_2()
  _with_tmp_file(_sample_feature(), function(path)
    lu.assertTrue(feature_stamp.apply_stamp_to_file(path))
    local first = assert(fs_lib.read_file(path))
    lu.assertTrue(feature_stamp.apply_stamp_to_file(path))
    local second = assert(fs_lib.read_file(path))
    lu.assertIs(second, first)
  end)
end


return TestFeatureStamp
