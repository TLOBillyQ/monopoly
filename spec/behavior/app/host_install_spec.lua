local support = require("spec.support.shared_support")
local with_patches = support.with_patches

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

describe("host_install", function()
  after_each(function()
    require("src.ui.coord.skin_panel").reset_for_tests()
    require("src.rules.ports.paid_purchase").reset_for_tests()
    require("src.rules.ports.achievement_progress").reset_for_tests()
    require("src.foundation.ports.runtime_ports").reset_for_tests()
    require("src.host.context").set_current(nil)
  end)

  it("rejects_removed_runtime_options", function()
    local host_install = require("src.app.host_install")

    local context_ok, context_err = pcall(host_install.install, {
      context_policy = {},
      skip_context_install = true,
    })
    _assert_eq(context_ok, false, "context_policy should be rejected")
    assert(tostring(context_err):find("context_policy option removed", 1, true) ~= nil,
      "context_policy error should identify removed option")

    local fallback_ok, fallback_err = pcall(host_install.install, {
      enable_legacy_helper_fallback = true,
      skip_context_install = true,
    })
    _assert_eq(fallback_ok, false, "legacy helper fallback should be rejected")
    assert(tostring(fallback_err):find("enable_legacy_helper_fallback option removed", 1, true) ~= nil,
      "legacy fallback error should identify removed option")
  end)

	  it("skip_context_install_wires_purchase_skins_to_paid_port", function()
    local host_install = require("src.app.host_install")
    local paid_purchase_port = require("src.rules.ports.paid_purchase")
    local skin_panel = require("src.ui.coord.skin_panel")
    local skin_equip = require("src.rules.cosmetics")
    local player = { id = 9 }
    local state = {
      ui = {},
      game = {
        find_player_by_id = function(_, role_id)
          if tostring(role_id) == "9" then
            return player
          end
          return nil
        end,
      },
    }
    local captured = nil

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function(game, start_player, entry)
          captured = { game = game, player = start_player, entry = entry }
          return true
        end,
      },
      {
        target = skin_equip,
        key = "equip",
        value = function()
          return true
        end,
      },
    }, function()
      host_install.install({ skip_context_install = true })
      skin_panel.open(state, 9)
      skin_panel.handle_action(state, { type = "equip", slot_index = 1 }, 9)
    end)

    _assert_eq(captured and captured.game, state.game, "purchase should use state game")
    _assert_eq(captured and captured.player, player, "purchase should resolve player")
	    _assert_eq(captured and captured.entry.kind, "skin", "purchase should create skin entry")
	  end)

	  it("install_subscribes_reward_day_events_and_grants_the_resolved_player", function()
	    local host_install = require("src.app.host_install")
	    local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
	    local captured = {}
	    local resolver_states = {}
	    local game_api = {
	      get_all_valid_roles = function() return {} end,
	      random_int = function(min) return min end,
	    }
	    local lua_api = {
	      call_delay_time = function(_, fn) fn() end,
	      global_register_custom_event = function(name, handler)
	        captured[name] = handler
	      end,
	      global_register_trigger_event = function() end,
	      unit_register_custom_event = function() end,
	      unit_register_trigger_event = function() end,
	      global_send_custom_event = function() end,
	    }
	    local client_player = { id = 1, cash = 0 }
	    local payload_player = { id = 5, cash = 0 }
	    local players = { [1] = client_player, [5] = payload_player }
	    local game = {
	      find_player_by_id = function(_, role_id) return players[role_id] end,
	      add_player_cash = function(_, player, amount) player.cash = (player.cash or 0) + amount end,
	    }
	    local app_state = { ui = {} }

	    with_patches({
	      { key = "GameAPI", value = game_api },
	      { key = "LuaAPI", value = lua_api },
	      { key = "SetTimeOut", value = nil },
	      { key = "RegisterCustomEvent", value = nil },
	      { key = "RegisterTriggerEvent", value = nil },
	      { key = "UnitCustomEvent", value = nil },
	      { key = "UnitTriggerEvent", value = nil },
	      { key = "TriggerCustomEvent", value = nil },
	      { key = "all_roles", value = nil },
	      { key = "ALLROLES", value = nil },
	      { key = "camera_helper", value = nil },
	      {
	        target = local_actor_resolver,
	        key = "resolve_from_event",
	        -- payload.role wins; absent → fall back to the client role (id 1).
	        value = function(state, data)
	          resolver_states[#resolver_states + 1] = state
	          if data and data.role ~= nil then return data.role end
	          return 1
	        end,
	      },
	    }, function()
	      host_install.install({
	        install_globals = true,
	        get_current_game = function() return game end,
	        get_app_state = function() return app_state end,
	      })

	      _assert_eq(type(captured.RewardDay4), "function", "RewardDay4 must be subscribed via the host port")
	      _assert_eq(captured.RewardDay8, nil, "unconfigured day RewardDay8 must not be subscribed")

	      captured.RewardDay4(nil, nil, { role = 5 })
	      captured.RewardDay1(nil, nil, {})
	    end, { skip_runtime_context_refresh = true })

	    _assert_eq(payload_player.cash, 4000, "RewardDay4 must credit the payload-resolved player the day-4 reward")
	    _assert_eq(client_player.cash, 500, "RewardDay1 with no payload role must fall back to the client player")
	    _assert_eq(resolver_states[1], app_state, "host_install must pass the live app state to the resolver")
	  end)

	  it("reward_day_events_refresh_player_ui_from_dirty_immediately", function()
	    local host_install = require("src.app.host_install")
	    local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
	    local captured = {}
	    local refresh_calls = {}
	    local lua_api = {
	      call_delay_time = function(_, fn) fn() end,
	      global_register_custom_event = function(name, handler)
	        captured[name] = handler
	      end,
	      global_register_trigger_event = function() end,
	      unit_register_custom_event = function() end,
	      unit_register_trigger_event = function() end,
	      global_send_custom_event = function() end,
	    }
	    local player = { id = 5, cash = 0 }
	    local game = {
	      dirty = { any = false, players = false },
	      find_player_by_id = function(_, role_id)
	        if role_id == 5 then return player end
	        return nil
	      end,
	      add_player_cash = function(self, target, amount)
	        target.cash = (target.cash or 0) + amount
	        self.dirty.any = true
	        self.dirty.players = true
	      end,
	      consume_dirty = function(self)
	        local snapshot = {
	          any = self.dirty.any,
	          players = self.dirty.players,
	        }
	        self.dirty.any = false
	        self.dirty.players = false
	        return snapshot
	      end,
	    }
	    local app_state = {
	      ui = {},
	      gameplay_loop_ports = {
	        ui_sync = {
	          refresh_from_dirty = function(refresh_game, refresh_state, dirty)
	            refresh_calls[#refresh_calls + 1] = {
	              game = refresh_game,
	              state = refresh_state,
	              dirty = dirty,
	            }
	            return true
	          end,
	        },
	      },
	    }

	    with_patches({
	      { key = "GameAPI", value = { get_all_valid_roles = function() return {} end, random_int = function(min) return min end } },
	      { key = "LuaAPI", value = lua_api },
	      { key = "SetTimeOut", value = nil },
	      { key = "RegisterCustomEvent", value = nil },
	      { key = "RegisterTriggerEvent", value = nil },
	      { key = "UnitCustomEvent", value = nil },
	      { key = "UnitTriggerEvent", value = nil },
	      { key = "TriggerCustomEvent", value = nil },
	      { key = "all_roles", value = nil },
	      { key = "ALLROLES", value = nil },
	      { key = "camera_helper", value = nil },
	      {
	        target = local_actor_resolver,
	        key = "resolve_from_event",
	        value = function(_, data)
	          return data and data.role or nil
	        end,
	      },
	    }, function()
	      host_install.install({
	        install_globals = true,
	        get_current_game = function() return game end,
	        get_app_state = function() return app_state end,
	      })

	      captured.RewardDay4(nil, nil, { role = 5 })
	    end, { skip_runtime_context_refresh = true })

	    _assert_eq(player.cash, 4000, "RewardDay4 must still grant the configured coins")
	    _assert_eq(#refresh_calls, 1, "RewardDay4 must refresh the UI in the same host event")
	    _assert_eq(refresh_calls[1].game, game, "refresh should use the live game")
	    _assert_eq(refresh_calls[1].state, app_state, "refresh should use the live app state")
	    _assert_eq(refresh_calls[1].dirty.players, true, "coin grant must refresh player rows")
	    _assert_eq(game.dirty.any, false, "immediate refresh should consume the dirty bucket")
	  end)

	  it("skips_reward_day_wiring_when_either_lazy_accessor_is_missing", function()
	    local host_install = require("src.app.host_install")
	    local captured = {}
	    local lua_api = {
	      call_delay_time = function(_, fn) fn() end,
	      global_register_custom_event = function(name, handler)
	        captured[name] = handler
	      end,
	      global_register_trigger_event = function() end,
	      unit_register_custom_event = function() end,
	      unit_register_trigger_event = function() end,
	      global_send_custom_event = function() end,
	    }
	    with_patches({
	      { key = "GameAPI", value = { get_all_valid_roles = function() return {} end, random_int = function(min) return min end } },
	      { key = "LuaAPI", value = lua_api },
	      { key = "SetTimeOut", value = nil },
	      { key = "RegisterCustomEvent", value = nil },
	      { key = "RegisterTriggerEvent", value = nil },
	      { key = "UnitCustomEvent", value = nil },
	      { key = "UnitTriggerEvent", value = nil },
	      { key = "TriggerCustomEvent", value = nil },
	      { key = "all_roles", value = nil },
	      { key = "ALLROLES", value = nil },
	      { key = "camera_helper", value = nil },
	    }, function()
	      -- get_current_game is a function but get_app_state is absent: the wiring
	      -- guard requires BOTH accessors, so sign-in rewards must NOT be subscribed.
	      host_install.install({
	        install_globals = true,
	        get_current_game = function() return nil end,
	      })
	      _assert_eq(captured.RewardDay1, nil, "reward-day wiring must be skipped when get_app_state is missing")
	    end, { skip_runtime_context_refresh = true })
	  end)

	  it("install_wires_runtime_context_aliases_and_default_ports", function()
	    local host_install = require("src.app.host_install")
	    local runtime_context = require("src.host.context")
	    local runtime_ports = require("src.foundation.ports.runtime_ports")
	    local role = { get_roleid = function() return 42 end }
	    local game_api = {
	      get_all_valid_roles = function()
	        return { role }
	      end,
	      random_int = function(min)
	        return min
	      end,
	    }
	    local lua_api = {
	      call_delay_time = function(_, fn) fn() end,
	      global_register_custom_event = function() end,
	      global_register_trigger_event = function() end,
	      unit_register_custom_event = function() end,
	      unit_register_trigger_event = function() end,
      global_send_custom_event = function() end,
    }

    with_patches({
      { key = "GameAPI", value = game_api },
      { key = "LuaAPI", value = lua_api },
	      { key = "SetTimeOut", value = nil },
	      { key = "RegisterCustomEvent", value = nil },
	      { key = "RegisterTriggerEvent", value = nil },
	      { key = "UnitCustomEvent", value = nil },
	      { key = "UnitTriggerEvent", value = nil },
	      { key = "TriggerCustomEvent", value = nil },
	      { key = "all_roles", value = nil },
	      { key = "ALLROLES", value = nil },
      { key = "camera_helper", value = nil },
    }, function()
      host_install.install({ install_globals = true })

      _assert_eq(runtime_context.current().env.GameAPI, game_api, "runtime context should keep GameAPI")
      _assert_eq(GameAPI, game_api, "global alias should expose GameAPI")
      _assert_eq(LuaAPI, lua_api, "global alias should expose LuaAPI")
	      _assert_eq(SetTimeOut, lua_api.call_delay_time, "global alias should expose delay helper")
	      _assert_eq(all_roles[1], role, "runtime helpers should publish all roles when requested")
	      _assert_eq(runtime_ports.resolve_role(42), role, "default runtime ports should resolve roles")
	    end, { skip_runtime_context_refresh = true })
	  end)

	  it("skip_context_install_wires_skin_panel_to_skin_equip", function()
	    local host_install = require("src.app.host_install")
    local skin_panel = require("src.ui.coord.skin_panel")
    local skin_equip = require("src.rules.cosmetics")
    local runtime_refs = require("src.config.content.runtime_refs")
    local captured = nil

    with_patches({
      {
        target = skin_equip,
	        key = "equip",
	        value = function(role_id, creature_key)
	          captured = { role_id = role_id, creature_key = creature_key }
	          return true
	        end,
	      },
	    }, function()
	      host_install.install({ skip_context_install = true })
	      local state = { ui = {} }
	      skin_panel.open(state, 9)
	      skin_panel.handle_action(state, { type = "buy", slot_index = 3 }, 9)
      skin_panel.handle_action(state, { type = "equip", slot_index = 3 }, 9)
    end)

    _assert_eq(captured and captured.role_id, 9, "skin equip should receive role id")
	    _assert_eq(captured and captured.creature_key,
	      runtime_refs.skins[tostring(skin_panel.catalog[3].product_id)],
	      "skin equip should receive the numeric resource id resolved from refs.skins")
	  end)

	  it("skip_context_install_wires_skin_panel_to_skin_unequip", function()
	    local host_install = require("src.app.host_install")
	    local skin_panel = require("src.ui.coord.skin_panel")
	    local skin_equip = require("src.rules.cosmetics")
	    local runtime_refs = require("src.config.content.runtime_refs")
	    local captured = nil

	    with_patches({
	      {
	        target = skin_equip,
	        key = "equip",
	        value = function()
	          return true
	        end,
	      },
	      {
	        target = skin_equip,
	        key = "unequip",
	        value = function(role_id, default_creature_key)
	          captured = { role_id = role_id, default_creature_key = default_creature_key }
	          return true
	        end,
	      },
	    }, function()
	      host_install.install({ skip_context_install = true })
	      local state = { ui = {} }
	      skin_panel.open(state, 9)
	      skin_panel.handle_action(state, { type = "buy", slot_index = 3 }, 9)
	      skin_panel.handle_action(state, { type = "equip", slot_index = 3 }, 9)
	      skin_panel.handle_action(state, { type = "unequip", slot_index = 3 }, 9)
	    end)

	    _assert_eq(captured and captured.role_id, 9, "skin unequip should receive role id")
	    _assert_eq(captured and captured.default_creature_key,
	      runtime_refs.default_creature,
	      "skin unequip should receive the default creature fallback from refs.default_creature")
	  end)
	end)
