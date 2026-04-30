local support = require("spec.support.runtime_support")

local monopoly_events = require("src.foundation.events")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local land_events = require("src.rules.land.events")
local land_rules = require("src.rules.land.rules")
local land_rent_resolver = require("src.rules.land.rent_resolver")
local action_anim = require("src.ui.render.action_anim")
local handlers = require("src.ui.render.anim.handlers")
local timing = require("src.config.gameplay.timing")

describe("cross_module_contract", function()
  it("event_contract_land_events_use_catalog_keys", function()
    local emitted = {}
    support.with_patches({
      {
        target = runtime_ports,
        key = "emit_event",
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

    assert.equals(monopoly_events.land.rent_paid, emitted[1].kind,
      "land event should map rent_paid to stable catalog key")
    assert.equals(66, emitted[1].payload.amount, "land event should keep payload")
    assert.equals(monopoly_events.land.rent_skipped_mountain, emitted[2].kind,
      "land skip event should use dedicated catalog key")
  end)

  it("land_rent_chain_contract_rules_match_resolver", function()
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
    assert.equals(from_resolver, from_rules, "land rules contiguous rent should match resolver chain semantics")
  end)

  it("action_anim_bridge_contract_dispatches_by_kind", function()
    local calls = { overlay = 0, missile = 0, monster = 0, clear_obstacles = 0 }
    local state = { ui = {} }

    support.with_patches({
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
      assert.equals(0.2, action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 }),
        "roadblock should keep anim duration")
      assert.equals(0.2, action_anim.play(state, { kind = "mine", tile_index = 1, duration = 0.2 }),
        "mine should keep anim duration")
      assert.equals(0.2 + (timing.demolish_effect_start_delay_seconds or 0.2),
        action_anim.play(state, { kind = "missile", tile_index = 1, duration = 0.2 }),
        "missile should include startup delay in anim duration")
      assert.equals(0.2 + (timing.demolish_effect_start_delay_seconds or 0.2),
        action_anim.play(state, { kind = "monster", tile_index = 1, duration = 0.2 }),
        "monster should include startup delay in anim duration")
      assert.equals(0.2, action_anim.play(state, { kind = "clear_obstacles", tile_index = 1, duration = 0.2 }),
        "clear_obstacles should keep anim duration")
    end)

    assert.equals(2, calls.overlay, "roadblock/mine should share overlay handler bridge")
    assert.equals(1, calls.missile, "missile should dispatch to missile handler bridge")
    assert.equals(1, calls.monster, "monster should dispatch to monster handler bridge")
    assert.equals(1, calls.clear_obstacles, "clear_obstacles should dispatch to clear handler bridge")
  end)
end)
