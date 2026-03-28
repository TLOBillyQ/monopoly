local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local monopoly_events = require("src.core.events.monopoly_events")
local runtime_event_bridge = require("src.host.event_bridge")
local land_events = require("src.rules.land.events")
local land_rules = require("src.rules.land.rules")
local land_rent_resolver = require("src.rules.land.rent_resolver")
local action_anim = require("src.ui.render.action_anim")
local handlers = require("src.ui.render.anim_handlers")

local function _test_event_contract_land_events_use_catalog_keys()
  local emitted = {}
  _with_patches({
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(kind, payload)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
      end,
    },
  }, function()
    land_events.apply({}, {
      ok = true,
      event = "rent_paid",
      payload = { amount = 66 },
    })
    land_events.apply({}, {
      ok = false,
      event = "rent_skipped_mountain",
      payload = { reason = "mountain" },
    })
  end)

  _assert_eq(emitted[1].kind, monopoly_events.land.rent_paid, "land event should map rent_paid to stable catalog key")
  _assert_eq(emitted[1].payload.amount, 66, "land event should keep payload")
  _assert_eq(emitted[2].kind, monopoly_events.land.rent_skipped_mountain,
    "land skip event should use dedicated catalog key")
end

local function _test_land_rent_chain_contract_rules_match_resolver()
  local game = support.new_game()
  local owner = game.players[1]
  local idx1, tile1, _, tile2 = support.first_adjacent_land_pair(game.board)

  game:set_tile_owner(tile1, owner.id)
  game:set_tile_owner(tile2, owner.id)
  game:set_tile_level(tile1, 1)
  game:set_tile_level(tile2, 2)
  game:set_player_property(owner, tile1.id, true)
  game:set_player_property(owner, tile2.id, true)

  local from_rules = land_rules.contiguous_rent(game, game.board, idx1, owner.id)
  local from_resolver = land_rent_resolver.contiguous_rent(game, game.board, idx1, owner.id)
  _assert_eq(from_rules, from_resolver, "land rules contiguous rent should match resolver chain semantics")
end

local function _test_action_anim_bridge_contract_dispatches_by_kind()
  local calls = { overlay = 0, missile = 0, monster = 0, clear_obstacles = 0 }
  local state = { ui = {} }

  _with_patches({
    { target = handlers, key = "build_tip", value = function() return "tip" end },
    { target = handlers, key = "play_overlay", value = function() calls.overlay = calls.overlay + 1 end },
    { target = handlers, key = "play_missile", value = function() calls.missile = calls.missile + 1 end },
    { target = handlers, key = "play_monster", value = function() calls.monster = calls.monster + 1 end },
    {
      target = handlers,
      key = "play_clear_obstacles",
      value = function()
        calls.clear_obstacles = calls.clear_obstacles + 1
      end,
    },
    { key = "GlobalAPI", value = { show_tips = function() end } },
  }, function()
    _assert_eq(action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 }), 0.2,
      "roadblock should keep anim duration")
    _assert_eq(action_anim.play(state, { kind = "mine", tile_index = 1, duration = 0.2 }), 0.2,
      "mine should keep anim duration")
    _assert_eq(action_anim.play(state, { kind = "missile", tile_index = 1, duration = 0.2 }), 0.2,
      "missile should keep anim duration")
    _assert_eq(action_anim.play(state, { kind = "monster", tile_index = 1, duration = 0.2 }), 0.2,
      "monster should keep anim duration")
    _assert_eq(action_anim.play(state, { kind = "clear_obstacles", tile_index = 1, duration = 0.2 }), 0.2,
      "clear_obstacles should keep anim duration")
  end)

  _assert_eq(calls.overlay, 2, "roadblock/mine should share overlay handler bridge")
  _assert_eq(calls.missile, 1, "missile should dispatch to missile handler bridge")
  _assert_eq(calls.monster, 1, "monster should dispatch to monster handler bridge")
  _assert_eq(calls.clear_obstacles, 1, "clear_obstacles should dispatch to clear handler bridge")
end

return {
  name = "cross_module_contract",
  tests = {
    { name = "event_contract_land_events_use_catalog_keys", run = _test_event_contract_land_events_use_catalog_keys },
    { name = "land_rent_chain_contract_rules_match_resolver", run = _test_land_rent_chain_contract_rules_match_resolver },
    { name = "action_anim_bridge_contract_dispatches_by_kind", run = _test_action_anim_bridge_contract_dispatches_by_kind },
  },
}
