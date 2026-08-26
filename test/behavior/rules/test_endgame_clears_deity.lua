local lu = require("luaunit")
local bankruptcy = require("src.rules.endgame")

local function _make_player(name, deity)
  return {
    id = 1,
    name = name,
    status = { deity = deity },
    inventory = { items = {}, _suspend_on_change = false },
    eliminated = false,
    properties = {},
  }
end

local function _make_game()
  return {
    board = { path = {}, get_tile_by_id = function() return nil end },
    occupants = {},
    clear_player_deity = function(self, player)
      player.status.deity = { type = "", remaining = 0 }
    end,
    set_player_eliminated = function(self, player, eliminated)
      player.eliminated = eliminated
    end,
    reset_tile = function() end,
    set_player_property = function() end,
  }
end

-- describe 级共享 fixture:场景循环 cases(原样留在块内)。
do
  local cases = {
    { name = "rich", deity = { type = "rich", remaining = 4 } },
    { name = "poor", deity = { type = "poor", remaining = 5 } },
    { name = "angel", deity = { type = "angel", remaining = 2 } },
    { name = "no-deity", deity = nil },
  }

  TestEndgameClearsDeity = {}

  for _, case in ipairs(cases) do
    TestEndgameClearsDeity["test_clears_deity_for_" .. case.name .. "_player"] = function(self)
      local game = _make_game()
      local player = _make_player(case.name, case.deity)

      bankruptcy.eliminate(game, player)

      lu.assertEquals(player.status.deity.type, "", "deity type should be cleared")
      lu.assertEquals(player.status.deity.remaining, 0, "deity remaining should be zero")
      lu.assertEquals(player.eliminated, true, "player should be eliminated")
    end
  end

  -- Moved from test_chance.lua -------------------------------------------------

  function TestEndgameClearsDeity:test_bankruptcy_eliminate_calls_life_die()
    local support = require("test.support.shared_support")
    local default_map = require("src.config.content.default_map")
    local function _new_game()
      return support.new_game({ map = default_map })
    end
    local _with_patches = support.with_patches

    local g = _new_game()
    local p = g:current_player()

    -- Track if life die was attempted
    local life_die_called = false
    local mock_role = {
      die = function() life_die_called = true end,
      get_component = function(_, name)
        if name == "LifeComp" then
          return { die = function() life_die_called = true end }
        end
        return nil
      end
    }

    _with_patches({
      { target = require("src.foundation.ports.runtime_ports"), key = "resolve_role", value = function() return mock_role end },
      { target = require("src.foundation.ports.runtime_ports"), key = "mark_role_lose", value = function() end },
    }, function()
      bankruptcy.eliminate(g, p, {})
    end)

    lu.assertEquals(p.eliminated, true, "eliminate should mark player as eliminated")
    lu.assertEquals(life_die_called, true, "eliminate should call life die on role")
  end
end


return TestEndgameClearsDeity
