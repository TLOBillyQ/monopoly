-- 验证：全人类玩家全程不操作，每个 scope 仍按 timeout 自动推进，不卡死
-- 这里用一个简化的多回合模拟：连续多次 force_skip + advance_turn
local force_resolve = require("src.turn.deadlines.force_resolve")
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

local function _build_game(num_players)
  local advanced = { count = 0 }
  local players = {}
  for i = 1, num_players do
    players[i] = { id = i, auto = false, cash = 100000, inventory = {} }
  end
  local game = {
    finished = false,
    players = players,
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    dirty = { any = false, turn = false },
    auto_play_port = _make_auto_play_port(),
  }
  function game:advance_turn()
    advanced.count = advanced.count + 1
    self.turn.current_player_index = (self.turn.current_player_index % #self.players) + 1
  end
  function game:current_player() return self.players[self.turn.current_player_index] end
  function game:find_player_by_id(id)
    for _, p in ipairs(self.players) do if p.id == id then return p end end
    return nil
  end
  return game, advanced
end

describe("all human no input full game", function()
  before_each(function() fallback_registry.reset() end)

  it("4 idle players each timeout in sequence advances turns N times", function()
    local state = _build_state()
    local game, advanced = _build_game(4)
    state._game = game

    for round = 1, 4 do
      local choice = {
        id = "c_" .. tostring(round),
        kind = "unknown_idle_kind",
        allow_cancel = false,
        owner_role_id = game.turn.current_player_index,
        options = {},
      }
      game.turn.pending_choice = choice
      force_resolve.resolve_choice(game, state, choice, "tick_timeout")
      assert.is_nil(game.turn.pending_choice)
    end
    assert.equals(4, advanced.count)
    -- 玩家资源未变化（无惩罚）
    for _, p in ipairs(game.players) do
      assert.equals(100000, p.cash)
    end
  end)
end)
