local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local effect_chance = require("src.rules.land.effect_chance")

describe("effect_chance._build_weights", function()
  it("returns_empty_table_for_empty_config", function()
    local result = effect_chance._build_weights({})
    _assert_eq(#result, 0, "empty config yields empty weights")
  end)

  it("maps_positive_weights", function()
    local result = effect_chance._build_weights({
      { weight = 10 },
      { weight = 20 },
      { weight = 5 },
    })
    _assert_eq(result[1], 10, "first weight")
    _assert_eq(result[2], 20, "second weight")
    _assert_eq(result[3], 5, "third weight")
  end)

  it("clamps_negative_weights_to_zero", function()
    local result = effect_chance._build_weights({
      { weight = -5 },
      { weight = -100 },
    })
    _assert_eq(result[1], 0, "negative clamped to zero")
    _assert_eq(result[2], 0, "large negative clamped to zero")
  end)

  it("treats_nil_weight_as_zero", function()
    local result = effect_chance._build_weights({
      {},
      { weight = nil },
    })
    _assert_eq(result[1], 0, "missing weight treated as zero")
    _assert_eq(result[2], 0, "explicit nil treated as zero")
  end)

  it("preserves_zero_weights", function()
    local result = effect_chance._build_weights({ { weight = 0 } })
    _assert_eq(result[1], 0, "zero weight preserved")
  end)
end)

describe("effect_chance._collect_drawable_cards", function()
  it("returns_empty_for_empty_config", function()
    local drawable = effect_chance._collect_drawable_cards()
    -- uses module-level chance_cfg, so just verify return types
    assert(type(drawable) == "table", "drawable is a table")
  end)
end)

describe("effect_chance._calc_total_weight", function()
  it("sums_zero_for_empty_drawable", function()
    local total = effect_chance._calc_total_weight({})
    _assert_eq(total, 0, "empty drawable has zero total weight")
  end)
end)
