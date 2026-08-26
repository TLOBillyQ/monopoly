-- 验证：未注册的 choice.kind 走 force_skip，不抛异常
local lu = require("luaunit")
local luax = require("test.support.luax")

local fallback_registry = require("src.rules.choice.fallback_registry")
local force_resolve = require("src.turn.deadlines")
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

local function _build_game()
  local advanced = { count = 0 }
  local game = {
    finished = false,
    players = { { id = 1, auto = false } },
    turn = { current_player_index = 1, pending_choice = nil },
    dirty = { any = false, turn = false },
    auto_play_port = _make_auto_play_port(),
  }
  function game:advance_turn() advanced.count = advanced.count + 1 end
  function game:current_player() return self.players[1] end
  function game:find_player_by_id(id)
    for _, p in ipairs(self.players) do if p.id == id then return p end end
    return nil
  end
  return game, advanced
end

TestFallbackRegistryUnregisteredKind = {}

function TestFallbackRegistryUnregisteredKind:setUp()
  fallback_registry.reset()
end

function TestFallbackRegistryUnregisteredKind:test_resolve_returns_nil_for_unknown_kind()
  lu.assertNil(fallback_registry.resolve("unknown_kind", nil, nil))
end

function TestFallbackRegistryUnregisteredKind:test_force_resolve_resolve_choice_on_unknown_kind_triggers_force_skip_without_error()
  local state = _build_state()
  local game, advanced = _build_game()
  local choice = {
    id = "u1",
    kind = "totally_new_unregistered_kind",
    allow_cancel = false,
    owner_role_id = 1,
    options = {},
  }
  game.turn.pending_choice = choice
  state._game = game

  local ok, err = pcall(force_resolve.resolve_choice, game, state, choice, "tick_timeout")
  lu.assertTrue(ok, tostring(err))
  lu.assertNil(game.turn.pending_choice)
  lu.assertTrue(advanced.count >= 1)
end

function TestFallbackRegistryUnregisteredKind:test_registered_fallback_gets_used_when_present()
  fallback_registry.register("market_buy", function(_, choice)
    return { type = "choice_cancel", choice_id = choice.id }
  end)
  local resolved = fallback_registry.resolve("market_buy", nil, { id = "x" })
  lu.assertIsTable(resolved)
  lu.assertEquals(resolved.type, "choice_cancel")
  lu.assertEquals(resolved.choice_id, "x")
end


function TestFallbackRegistryUnregisteredKind:test_register_rejects_an_empty_string_kind()
  -- #293:register 的 kind 校验断言(and/or/""/nil 变异)未测。
  luax.has_error(function()
    fallback_registry.register("", function() end)
  end, "invalid kind")
end

function TestFallbackRegistryUnregisteredKind:test_register_rejects_a_non_function_fallback()
  -- #293:register 的 fn 校验断言("invalid fallback fn"→nil 变异)未测。
  luax.has_error(function()
    fallback_registry.register("test_kind", "not_a_function")
  end, "invalid fallback fn")
end

return TestFallbackRegistryUnregisteredKind
