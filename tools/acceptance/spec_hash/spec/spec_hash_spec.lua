local common = require("shared.lib.common")
local spec_hash = require("acceptance4lua.spec_hash")

describe("acceptance4lua.spec_hash.sha256", function()
  it("matches the empty-string FIPS 180-4 test vector", function()
    assert.are.equal(
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      spec_hash.sha256("")
    )
  end)

  it("is deterministic across repeated calls", function()
    local first = spec_hash.sha256("the same input every time")
    local second = spec_hash.sha256("the same input every time")
    assert.are.equal(first, second)
  end)

  it("treats nil input as empty string", function()
    assert.are.equal(spec_hash.sha256(""), spec_hash.sha256(nil))
  end)

  it("returns 64 hex characters", function()
    assert.are.equal(64, #spec_hash.sha256("any payload"))
    assert.is_not_nil(spec_hash.sha256("any payload"):match("^[0-9a-f]+$"))
  end)
end)

describe("acceptance4lua.spec_hash.compute_feature_content_hash", function()
  it("strips the first mutation-stamp line before hashing", function()
    local without_stamp = "Feature: example\n\nScenario: it works\n  Given a step\n"
    local with_stamp =
      "# mutation-stamp: sha256=deadbeef\nFeature: example\n\nScenario: it works\n  Given a step\n"
    assert.are.equal(
      spec_hash.compute_feature_content_hash(without_stamp),
      spec_hash.compute_feature_content_hash(with_stamp)
    )
  end)

  it("only strips the first stamp line when more than one is present", function()
    local one_stamp = "# mutation-stamp: sha256=aaa\nFeature: x\n# mutation-stamp: sha256=bbb\n"
    local two_stamps_stripped = "# mutation-stamp: sha256=bbb\nFeature: x\n"

    local computed = spec_hash.compute_feature_content_hash(one_stamp)
    local without_first = spec_hash.compute_feature_content_hash(two_stamps_stripped)

    assert.are.equal(computed, spec_hash.sha256("Feature: x\n# mutation-stamp: sha256=bbb\n"))
    assert.are.not_equal(computed, without_first)
  end)

  it("matches plain sha256 when no stamp is present", function()
    local source = "Feature: example\nScenario: noop\n"
    assert.are.equal(spec_hash.sha256(source), spec_hash.compute_feature_content_hash(source))
  end)
end)

describe("acceptance4lua.spec_hash.compute_background_hash", function()
  it("returns a stable hex hash for a fixed background array", function()
    local background = {
      { keyword = "Given", text = "a configured project", parameters = {} },
    }
    local first = spec_hash.compute_background_hash(background)
    local second = spec_hash.compute_background_hash(background)
    assert.are.equal(first, second)
    assert.are.equal(64, #first)
  end)

  it("changes when any step text changes", function()
    local before = spec_hash.compute_background_hash({
      { keyword = "Given", text = "alpha", parameters = {} },
    })
    local after = spec_hash.compute_background_hash({
      { keyword = "Given", text = "beta", parameters = {} },
    })
    assert.are.not_equal(before, after)
  end)

  it("treats nil and empty array as the same hash", function()
    assert.are.equal(
      spec_hash.compute_background_hash(nil),
      spec_hash.compute_background_hash({})
    )
  end)
end)

describe("acceptance4lua.spec_hash.compute_scenario_hash", function()
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

  it("returns the same hash for example objects whose key insertion order differs", function()
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
    assert.are.equal(first, second)
  end)

  it("changes when scenario name changes", function()
    assert.are.not_equal(
      spec_hash.compute_scenario_hash(_scenario_with("first", "x")),
      spec_hash.compute_scenario_hash(_scenario_with("second", "x"))
    )
  end)

  it("changes when an example value changes", function()
    assert.are.not_equal(
      spec_hash.compute_scenario_hash(_scenario_with("name", "alpha")),
      spec_hash.compute_scenario_hash(_scenario_with("name", "beta"))
    )
  end)

  it("changes when example row order changes", function()
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
    assert.are.not_equal(
      spec_hash.compute_scenario_hash(one),
      spec_hash.compute_scenario_hash(two)
    )
  end)
end)

describe("acceptance4lua.spec_hash.compute_generated_files_hash", function()
  local function _with_tmp(fn)
    local tmp_root = common.make_temp_path("acceptance_spec_hash_", "")
    common.remove_path(tmp_root)
    assert(common.ensure_dir(tmp_root))
    local ok, err = xpcall(function()
      fn(tmp_root)
    end, debug.traceback)
    common.remove_path(tmp_root)
    if not ok then
      error(err)
    end
  end

  it("returns a sha256-prefixed hash for generated files", function()
    _with_tmp(function(tmp_root)
      local generated_path = common.join_path(tmp_root, "generated/a_spec.lua")
      assert(common.write_file(generated_path, "return true\n"))

      local hash = spec_hash.compute_generated_files_hash({ generated_path })
      assert.is_truthy(hash:match("^sha256:[0-9a-f]+$"))
      assert.are.equal(71, #hash)
    end)
  end)

  it("changes when generated file content changes", function()
    _with_tmp(function(tmp_root)
      local generated_path = common.join_path(tmp_root, "generated/a_spec.lua")
      assert(common.write_file(generated_path, "return true\n"))
      local before = spec_hash.compute_generated_files_hash({ generated_path })

      assert(common.write_file(generated_path, "return false\n"))
      local after = spec_hash.compute_generated_files_hash({ generated_path })
      assert.are_not.equal(before, after)
    end)
  end)
end)
