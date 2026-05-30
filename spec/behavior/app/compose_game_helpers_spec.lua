local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local composition_root = require("src.app.compose_game")

describe("compose_game._install_class_mixin", function()
  it("copies_functions_to_target", function()
    local target = {}
    local source = {
      foo = function() return "foo" end,
      bar = function() return "bar" end,
    }
    composition_root._install_class_mixin(target, source, "test_source")
    _assert_eq(target.foo(), "foo", "foo copied")
    _assert_eq(target.bar(), "bar", "bar copied")
  end)

  it("errors_on_collision", function()
    local target = { existing = function() end }
    local source = { existing = function() end }
    local ok, err = pcall(composition_root._install_class_mixin, target, source, "collision_test")
    _assert_eq(ok, false, "should error on collision")
    assert(err:find("collision"), "error mentions collision")
  end)
end)

describe("compose_game._is_class_like", function()
  it("returns_false_for_non_tables", function()
    _assert_eq(composition_root._is_class_like(nil), false, "nil is not class-like")
    _assert_eq(composition_root._is_class_like(42), false, "number is not class-like")
    _assert_eq(composition_root._is_class_like("string"), false, "string is not class-like")
  end)

  it("returns_false_for_plain_tables", function()
    _assert_eq(composition_root._is_class_like({}), false, "empty table is not class-like")
    _assert_eq(composition_root._is_class_like({ __name = "Foo" }), false, "missing new is not class-like")
  end)

  it("returns_true_for_class_like_tables", function()
    local klass = {
      __name = "MyClass",
      new = function() end,
    }
    _assert_eq(composition_root._is_class_like(klass), true, "has __name and new")
  end)

  it("returns_false_for_instances_with_newindex_metamethod", function()
    local mt = {
      __newindex = function() end,
    }
    local instance = setmetatable({
      __name = "Instance",
      new = function() end,
    }, mt)
    _assert_eq(composition_root._is_class_like(instance), false, "instance with __newindex is not class-like")
  end)
end)

describe("compose_game._build_player_by_id", function()
  it("returns_empty_for_nil_players", function()
    local result = composition_root._build_player_by_id(nil)
    _assert_eq(next(result), nil, "nil players yields empty map")
  end)

  it("indexes_players_by_normalized_id", function()
    local players = {
      { id = 1, name = "A" },
      { id = 2, name = "B" },
    }
    local result = composition_root._build_player_by_id(players)
    _assert_eq(result[1].name, "A", "player A indexed")
    _assert_eq(result[2].name, "B", "player B indexed")
  end)

  it("skips_players_with_nil_id", function()
    local players = {
      { name = "NoId" },
      { id = 1, name = "HasId" },
    }
    local result = composition_root._build_player_by_id(players)
    _assert_eq(result[1].name, "HasId", "player with id indexed")
    local count = 0
    for _ in pairs(result) do count = count + 1 end
    _assert_eq(count, 1, "only one player indexed")
  end)
end)

describe("compose_game._build_initial_turn", function()
  it("returns_expected_structure", function()
    local turn = composition_root._build_initial_turn()
    _assert_eq(turn.current_player_index, 1, "starts at player 1")
    _assert_eq(turn.turn_count, 0, "zero turns")
    _assert_eq(turn.phase, "start", "start phase")
    _assert_eq(turn.move_followup_pending, false, "no followup pending")
    _assert_eq(turn.finished, nil, "no finished field")
  end)
end)
