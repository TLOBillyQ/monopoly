-- 验证：超时温柔跳过不扣资源（玩家 cash/inventory 在 force_skip 后保持不变）
local force_resolve = require("src.turn.deadlines")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  return state
end

local function _make_auto_play_port()
  return {
    is_auto_player = function(_, _p) return false end,
    auto_action_for_choice = function(_, _c) return nil end,
    pick_target_player = function() return nil end,
    pick_remote_dice_value = function() return nil end,
    pick_roadblock_target = function() return nil end,
  }
end

local function _build_game(player_cash, inventory)
  local advanced = { count = 0 }
  local game = {
    finished = false,
    players = { {
      id = 1,
      auto = false,
      cash = player_cash,
      inventory = inventory or {},
    } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    dirty = { any = false, turn = false },
    auto_play_port = _make_auto_play_port(),
  }
  function game:advance_turn()
    advanced.count = advanced.count + 1
  end
  function game:current_player()
    return self.players[1]
  end
  function game:find_player_by_id(id)
    for _, p in ipairs(self.players) do
      if p.id == id then return p end
    end
    return nil
  end
  return game, advanced
end

describe("gentle skip leaves no penalty", function()
  before_each(function() fallback_registry.reset() end)

  it("market_buy timeout does not change player cash", function()
    local state = _build_state()
    local game = _build_game(50000, {})
    local choice = {
      id = "mb1",
      kind = "market_buy",
      allow_cancel = false,
      owner_role_id = 1,
      options = {},
    }
    game.turn.pending_choice = choice
    state._game = game

    local before_cash = game.players[1].cash
    force_resolve.resolve_choice(game, state, choice, "tick_timeout")

    assert.equals(before_cash, game.players[1].cash)
    assert.is_nil(game.turn.pending_choice)
  end)

  it("item_target timeout does not change inventory", function()
    local state = _build_state()
    local game = _build_game(50000, { { id = 7, count = 2 } })
    local choice = {
      id = "it1",
      kind = "item_target_tile",
      allow_cancel = false,
      owner_role_id = 1,
      options = {},
      meta = { item_id = 7 },
    }
    game.turn.pending_choice = choice
    state._game = game

    local before_inv_count = game.players[1].inventory[1].count
    force_resolve.resolve_choice(game, state, choice, "tick_timeout")

    assert.equals(before_inv_count, game.players[1].inventory[1].count)
    assert.is_nil(game.turn.pending_choice)
  end)
end)
