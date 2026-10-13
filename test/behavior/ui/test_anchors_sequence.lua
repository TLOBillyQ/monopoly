-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
local anchors = require("src.ui.render.board.anchors")
local sequence_builder = require("src.ui.render.move_anim.sequence_builder")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local _find_owner_name = anchors._M_test._find_owner_name

local function _assert_eq(a, b, msg)
  luassert.truthy(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("TestAnchorsSequence", function()

  it("test_find_owner_name_finds_matching_player", function()
    _assert_eq(
      _find_owner_name({ { id = 1, name = "Alice" }, { id = 2, name = "Bob" } }, 1),
      "Alice",
      "finds matching player"
    )
  end)

  it("test_find_owner_name_finds_second_player", function()
    _assert_eq(
      _find_owner_name({ { id = 1, name = "Alice" }, { id = 2, name = "Bob" } }, 2),
      "Bob",
      "finds second player"
    )
  end)

  it("test_find_owner_name_no_match_returns_nil", function()
    _assert_eq(_find_owner_name({ { id = 1, name = "Alice" } }, 99), nil, "no match returns nil")
  end)

  it("test_find_owner_name_nil_owner_id_returns_nil", function()
    _assert_eq(_find_owner_name({ { id = 1, name = "Alice" } }, nil), nil, "nil owner_id returns nil")
  end)

  it("test_find_owner_name_nil_players_returns_nil", function()
    _assert_eq(_find_owner_name(nil, 1), nil, "nil players returns nil")
  end)

  it("test_find_owner_name_non_table_players_returns_nil", function()
    _assert_eq(_find_owner_name("abc", 1), nil, "non-table players returns nil")
  end)

  it("test_find_owner_name_empty_players_returns_nil", function()
    _assert_eq(_find_owner_name({}, 1), nil, "empty players returns nil")
  end)

  it("test_resolve_direction_returns_explicit_direction", function()
    _assert_eq(sequence_builder.resolve_direction({ direction = "north" }), "north", "explicit direction returned")
  end)

  it("test_resolve_direction_negative_steps_returns_right", function()
    _assert_eq(
      sequence_builder.resolve_direction({ steps = -1 }),
      runtime_constants.v3_right,
      "negative steps returns v3_right"
    )
  end)

  it("test_resolve_direction_positive_steps_returns_left", function()
    _assert_eq(
      sequence_builder.resolve_direction({ steps = 3 }),
      runtime_constants.v3_left,
      "positive steps returns v3_left"
    )
  end)

  it("test_resolve_direction_zero_steps_returns_nil", function()
    _assert_eq(sequence_builder.resolve_direction({ steps = 0 }), nil, "zero steps returns nil")
  end)

  it("test_resolve_direction_no_steps_no_direction_returns_nil", function()
    _assert_eq(sequence_builder.resolve_direction({}), nil, "no steps and no direction returns nil")
  end)

  it("test_resolve_direction_direction_takes_priority", function()
    _assert_eq(
      sequence_builder.resolve_direction({ direction = "east", steps = -1 }),
      "east",
      "direction has priority"
    )
  end)


end)
