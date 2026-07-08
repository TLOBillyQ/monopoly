local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local owner = require("src.turn.choice.owner")

describe("turn.choice.owner.resolve_role_id", function()
  it("resolves via find_player_by_id, not the current-player fallback", function()
    local game = {
      find_player_by_id = function(_, id) return { id = 700 + id } end,
      turn = { current_player_index = 1 },
      players = { { id = 11 } },
    }
    _assert_eq(owner.resolve_role_id(game, { owner_role_id = 7 }), 707,
      "a resolvable owner resolves through find_player_by_id")
  end)

  it("falls back to the current player id when find is absent", function()
    local game = {
      find_player_by_id = nil,
      turn = { current_player_index = 1 },
      players = { { id = 11 } },
    }
    _assert_eq(owner.resolve_role_id(game, { owner_role_id = 7 }), 11,
      "a missing find_player_by_id short-circuits to the current-player fallback")
  end)
end)

describe("turn.choice.owner.resolve_player", function()
  it("returns the found player object", function()
    local found = { id = 42 }
    local game = { find_player_by_id = function() return found end }
    assert(owner.resolve_player(game, { owner_role_id = 42 }) == found,
      "resolve_player returns the player object, not its id")
  end)

  it("falls back to game:current_player() via method call", function()
    local cur = { id = 9 }
    local game = { current_player = function() return cur end }
    assert(owner.resolve_player(game, {}) == cur,
      "no owner resolves through the current_player() method fallback")
  end)
end)

describe("turn.choice.owner.ensure_actor_role_id", function()
  it("returns a nil action untouched without resolving", function()
    assert(owner.ensure_actor_role_id({}, {}, nil) == nil, "a nil action is returned as-is")
  end)

  it("does not overwrite an already-set actor", function()
    local action = { actor_role_id = 3 }
    owner.ensure_actor_role_id({ find_player_by_id = function() return { id = 99 } end }, { owner_role_id = 1 }, action)
    _assert_eq(action.actor_role_id, 3, "a present actor_role_id is preserved")
  end)

  it("fills actor from the resolved owner id when absent", function()
    local action = {}
    local game = { find_player_by_id = function(_, id) return { id = id } end }
    owner.ensure_actor_role_id(game, { owner_role_id = 5 }, action)
    _assert_eq(action.actor_role_id, 5, "an absent actor is filled from resolve_role_id")
  end)
end)
