local common = require("shared.lib.common")
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
  local tmp_dir = common.make_temp_path("acceptance_feature_stamp_", "")
  common.remove_path(tmp_dir)
  common.ensure_dir(tmp_dir)
  local path = tmp_dir .. "/feature.feature"
  local handle = assert(io.open(path, "w"))
  handle:write(content)
  handle:close()
  local ok, err = xpcall(function()
    fn(path)
  end, debug.traceback)
  common.remove_path(tmp_dir)
  if not ok then
    error(err)
  end
end

describe("acceptance4lua.feature_stamp.read_stamp", function()
  it("returns nil when no stamp line is present", function()
    assert.is_nil(feature_stamp.read_stamp(_sample_feature()))
  end)

  it("reads a stamp at the very first line", function()
    local source = "# mutation-stamp: sha256=deadbeef\nFeature: x\n"
    assert.are.equal("deadbeef", feature_stamp.read_stamp(source))
  end)

  it("reads a stamp that is not the first line", function()
    local source = "# language: zh-CN\n# mutation-stamp: sha256=cafebabe\n功能: 例子\n"
    assert.are.equal("cafebabe", feature_stamp.read_stamp(source))
  end)

  it("returns nil when the stamp marker exists but the hash is malformed", function()
    local source = "# mutation-stamp: sha256=NOT_HEX\nFeature: x\n"
    assert.is_nil(feature_stamp.read_stamp(source))
  end)
end)

describe("acceptance4lua.feature_stamp.is_stamp_current", function()
  it("returns false when no stamp is present", function()
    assert.is_false(feature_stamp.is_stamp_current(_sample_feature()))
  end)

  it("returns true immediately after apply_stamp", function()
    local stamped = feature_stamp.apply_stamp(_sample_feature())
    assert.is_true(feature_stamp.is_stamp_current(stamped))
  end)

  it("returns false after content changes following a stamp", function()
    local stamped = feature_stamp.apply_stamp(_sample_feature())
    local mutated = stamped .. "\n# added comment\n"
    assert.is_false(feature_stamp.is_stamp_current(mutated))
  end)

  it("returns false when stamp hash does not match content hash", function()
    local source = "# mutation-stamp: sha256=" .. string.rep("0", 64) .. "\nFeature: x\n"
    assert.is_false(feature_stamp.is_stamp_current(source))
  end)
end)

describe("acceptance4lua.feature_stamp.apply_stamp", function()
  it("prepends a stamp line to an unstamped feature", function()
    local source = _sample_feature()
    local stamped = feature_stamp.apply_stamp(source)
    assert.is_truthy(stamped:match("^# mutation%-stamp: sha256=[0-9a-f]+\n"))
    assert.is_truthy(stamped:find(source, 1, true))
  end)

  it("replaces an existing stamp instead of duplicating it", function()
    local source = _sample_feature()
    local first_pass = feature_stamp.apply_stamp(source)
    local second_pass = feature_stamp.apply_stamp(first_pass)
    local _, stamp_count = second_pass:gsub("mutation%-stamp:", "")
    assert.are.equal(1, stamp_count)
  end)

  it("is idempotent for a feature that has not been edited", function()
    local stamped_once = feature_stamp.apply_stamp(_sample_feature())
    local stamped_twice = feature_stamp.apply_stamp(stamped_once)
    assert.are.equal(stamped_once, stamped_twice)
  end)

  it("encodes the hash as sha256 of the feature content minus the stamp line", function()
    local source = _sample_feature()
    local stamped = feature_stamp.apply_stamp(source)
    local hash = feature_stamp.read_stamp(stamped)
    assert.are.equal(spec_hash.sha256(source), hash)
  end)
end)

describe("acceptance4lua.feature_stamp.apply_stamp_to_file", function()
  it("writes a stamp line at the top of the target file", function()
    _with_tmp_file(_sample_feature(), function(path)
      local ok, err = feature_stamp.apply_stamp_to_file(path)
      assert.is_true(ok)
      assert.is_nil(err)
      local content = assert(common.read_file(path))
      assert.is_truthy(content:match("^# mutation%-stamp: sha256=[0-9a-f]+\n"))
      assert.is_true(feature_stamp.is_stamp_current(content))
    end)
  end)

  it("replaces an existing stamp instead of duplicating it", function()
    _with_tmp_file(_sample_feature(), function(path)
      assert.is_true(feature_stamp.apply_stamp_to_file(path))
      local first = assert(common.read_file(path))
      assert.is_true(feature_stamp.apply_stamp_to_file(path))
      local second = assert(common.read_file(path))
      assert.are.equal(first, second)
    end)
  end)
end)
