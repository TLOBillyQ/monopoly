local anchors = require("src.ui.render.board.anchors")
local sequence_builder = require("src.ui.render.move_anim.sequence_builder")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local _find_owner_name = anchors._M_test._find_owner_name

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("anchors_sequence_crap_coverage", function()
  it("_find_owner_name finds matching player", function()
    _assert_eq(
      _find_owner_name({ { id = 1, name = "Alice" }, { id = 2, name = "Bob" } }, 1),
      "Alice",
      "finds matching player"
    )
  end)

  it("_find_owner_name finds second player", function()
    _assert_eq(
      _find_owner_name({ { id = 1, name = "Alice" }, { id = 2, name = "Bob" } }, 2),
      "Bob",
      "finds second player"
    )
  end)

  it("_find_owner_name no match returns nil", function()
    _assert_eq(_find_owner_name({ { id = 1, name = "Alice" } }, 99), nil, "no match returns nil")
  end)

  it("_find_owner_name nil owner_id returns nil", function()
    _assert_eq(_find_owner_name({ { id = 1, name = "Alice" } }, nil), nil, "nil owner_id returns nil")
  end)

  it("_find_owner_name nil players returns nil", function()
    _assert_eq(_find_owner_name(nil, 1), nil, "nil players returns nil")
  end)

  it("_find_owner_name non-table players returns nil", function()
    _assert_eq(_find_owner_name("abc", 1), nil, "non-table players returns nil")
  end)

  it("_find_owner_name empty players returns nil", function()
    _assert_eq(_find_owner_name({}, 1), nil, "empty players returns nil")
  end)

  it("resolve_direction returns explicit direction", function()
    _assert_eq(sequence_builder.resolve_direction({ direction = "north" }), "north", "explicit direction returned")
  end)

  it("resolve_direction negative steps returns right", function()
    _assert_eq(
      sequence_builder.resolve_direction({ steps = -1 }),
      runtime_constants.v3_right,
      "negative steps returns v3_right"
    )
  end)

  it("resolve_direction positive steps returns left", function()
    _assert_eq(
      sequence_builder.resolve_direction({ steps = 3 }),
      runtime_constants.v3_left,
      "positive steps returns v3_left"
    )
  end)

  it("resolve_direction zero steps returns nil", function()
    _assert_eq(sequence_builder.resolve_direction({ steps = 0 }), nil, "zero steps returns nil")
  end)

  it("resolve_direction no steps no direction returns nil", function()
    _assert_eq(sequence_builder.resolve_direction({}), nil, "no steps and no direction returns nil")
  end)

  it("resolve_direction direction takes priority", function()
    _assert_eq(
      sequence_builder.resolve_direction({ direction = "east", steps = -1 }),
      "east",
      "direction has priority"
    )
  end)
end)
