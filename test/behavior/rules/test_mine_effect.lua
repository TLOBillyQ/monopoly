local mine_effect = require("src.rules.effects.mine")

local _find = mine_effect._M_test._find_pending_roadblock_trigger

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

do -- describe("mine_effect_crap_coverage")
  local _config_reset = require("test.support.config_reset")

  TestMineEffect = {}

  function TestMineEffect:setUp()
    _config_reset.reset_all()
  end

  TestMineEffect["test_nil game returns nil"] = function(self)
    _assert_eq(_find(nil, { id = 1 }, 5), nil, "nil game returns nil")
  end

  TestMineEffect["test_game without turn returns nil"] = function(self)
    _assert_eq(_find({}, { id = 1 }, 5), nil, "game without turn returns nil")
  end

  TestMineEffect["test_matching current action_anim returns current"] = function(self)
    local current = { kind = "roadblock_trigger", player_id = 1, tile_index = 5 }
    local game = { turn = { action_anim = current } }
    _assert_eq(_find(game, { id = 1 }, 5), current, "matching current action_anim")
  end

  TestMineEffect["test_current anim wrong kind returns nil"] = function(self)
    local game = {
      turn = {
        action_anim = { kind = "mine_trigger", player_id = 1, tile_index = 5 },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong kind returns nil")
  end

  TestMineEffect["test_current anim wrong player returns nil"] = function(self)
    local game = {
      turn = {
        action_anim = { kind = "roadblock_trigger", player_id = 2, tile_index = 5 },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong player returns nil")
  end

  TestMineEffect["test_current anim wrong position returns nil"] = function(self)
    local game = {
      turn = {
        action_anim = { kind = "roadblock_trigger", player_id = 1, tile_index = 3 },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong position returns nil")
  end

  TestMineEffect["test_found in queue returns queue entry"] = function(self)
    local queued = { kind = "roadblock_trigger", player_id = 1, tile_index = 5 }
    local game = {
      turn = {
        action_anim = nil,
        action_anim_queue = { queued },
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), queued, "finds match in queue")
  end

  TestMineEffect["test_queue has non-matching entries returns nil"] = function(self)
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
  end

  TestMineEffect["test_queue is not a table returns nil"] = function(self)
    local game = {
      turn = {
        action_anim = nil,
        action_anim_queue = nil,
      },
    }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "nil queue returns nil")
  end

  TestMineEffect["test_no current anim and no queue returns nil"] = function(self)
    local game = { turn = {} }
    _assert_eq(_find(game, { id = 1 }, 5), nil, "no current and no queue returns nil")
  end
end

-- can_trigger / _is_mine_grace_expired / apply closures live in
-- test_mine_closure.lua (coder superset; see rules-mutation-bootstrap-debt.md).


return TestMineEffect
