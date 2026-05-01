local mine_effect = require("src.rules.effects.mine")

local _find = mine_effect._M_test._find_pending_roadblock_trigger

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("mine_effect_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("nil game returns nil", function()
    _assert_eq(_find(nil, { id = 1 }, 5), nil, "nil game returns nil")
  end)

  it("game without turn returns nil", function()
    _assert_eq(_find({}, { id = 1 }, 5), nil, "game without turn returns nil")
  end)

  it("matching current action_anim returns current", function()
    local current = { kind = "roadblock_trigger", player_id = 1, tile_index = 5 }
    local game = { turn = { action_anim = current } }
    _assert_eq(_find(game, { id = 1 }, 5), current, "matching current action_anim")
  end)

  it("current anim wrong kind returns nil", function()
    local game = {
      turn = {
        action_anim = { kind = "mine_trigger", player_id = 1, tile_index = 5 },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong kind returns nil")
  end)

  it("current anim wrong player returns nil", function()
    local game = {
      turn = {
        action_anim = { kind = "roadblock_trigger", player_id = 2, tile_index = 5 },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong player returns nil")
  end)

  it("current anim wrong position returns nil", function()
    local game = {
      turn = {
        action_anim = { kind = "roadblock_trigger", player_id = 1, tile_index = 3 },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong position returns nil")
  end)

  it("found in queue returns queue entry", function()
    local queued = { kind = "roadblock_trigger", player_id = 1, tile_index = 5 }
    local game = {
      turn = {
        action_anim = nil,
        action_anim_queue = { queued },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), queued, "finds match in queue")
  end)

  it("queue has non-matching entries returns nil", function()
    local game = {
      turn = {
        action_anim = nil,
        action_anim_queue = {
          { kind = "mine_trigger", player_id = 1, tile_index = 5 },
          { kind = "roadblock_trigger", player_id = 2, tile_index = 5 },
        },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "non-matching queue returns nil")
  end)

  it("queue is not a table returns nil", function()
    local game = {
      turn = {
        action_anim = nil,
        action_anim_queue = nil,
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "nil queue returns nil")
  end)

  it("no current anim and no queue returns nil", function()
    local game = { turn = {} }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "no current and no queue returns nil")
  end)
end)
