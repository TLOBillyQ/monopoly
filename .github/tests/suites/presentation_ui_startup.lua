local support = require("TestSupport")

local function _with_module_patches(patches, fn)
  local originals = {}
  local names = {}
  for name, value in pairs(patches) do
    names[#names + 1] = name
    originals[name] = package.loaded[name]
    package.loaded[name] = value
  end
  local ok, err = xpcall(fn, debug.traceback)
  for _, name in ipairs(names) do
    package.loaded[name] = originals[name]
  end
  if not ok then
    error(err)
  end
end

local function _run_bootstrap_test(assertions)
  local calls = {
    sent_events = {},
  }
  local role = {
    get_roleid = function()
      return 1
    end,
    get_name = function()
      return "P1"
    end,
  }
  support.with_patches({
    { key = "main", value = nil },
    { key = "GameAPI", value = {
      get_all_valid_roles = function()
        return { role }
      end,
      get_role = function(role_id)
        if role_id == 1 then
          return role
        end
        return nil
      end,
    } },
    { key = "LuaAPI", value = {
      call_delay_time = function(delay, cb)
        calls.timeout = { delay = delay, cb = cb }
      end,
      global_register_custom_event = function(_, cb)
        calls.custom_event_cb = cb
      end,
      global_register_trigger_event = function(events, cb)
        calls.trigger_events = events
        calls.trigger_cb = cb
      end,
      unit_register_custom_event = function() end,
      unit_register_trigger_event = function() end,
      global_send_custom_event = function(name, payload)
        calls.sent_events[#calls.sent_events + 1] = { name = name, payload = payload }
      end,
    } },
    { key = "EVENT", value = { GAME_INIT = "GAME_INIT" } },
    { key = "UIManager", value = {
      Builder = {
        new = function(_, nodes)
          calls.ui_manager_nodes = nodes
        end,
      },
      query_nodes_by_name = function()
        return {}
      end,
    } },
    { key = "SetFrameOut", value = function(interval, cb, repeat_count)
      calls.frame_out = { interval = interval, cb = cb, repeat_count = repeat_count }
    end },
  }, function()
    _with_module_patches({
      ["main"] = nil,
      ["src.app.init"] = nil,
      ["src.game.core.runtime.Bankruptcy"] = {},
      ["src.game.core.runtime.AgentTargeting"] = {},
      ["src.game.core.runtime.Agent"] = {},
      ["src.game.core.runtime.GameVictory"] = {},
      ["src.game.core.runtime.CompositionRoot"] = {},
      ["src.game.flow.turn.AutoRunner"] = {
        new = function(_, opts)
          return { interval = opts and opts.interval }
        end,
      },
      ["src.presentation.render.BoardScene"] = {
        init = function()
          calls.board_scene_init = (calls.board_scene_init or 0) + 1
        end,
      },
      ["src.presentation.render.BoardView"] = {
        on_tile_upgraded = function() end,
        on_tile_owner_changed = function() end,
      },
      ["src.game.core.runtime.Game"] = {
        new = function()
          return {}
        end,
      },
      ["src.game.flow.turn.GameplayLoop"] = {
        new_game = function()
          return { turn = { current_player_index = 1 } }
        end,
        set_game = function()
          calls.set_game = (calls.set_game or 0) + 1
        end,
        tick = function()
          calls.tick = (calls.tick or 0) + 1
        end,
      },
      ["src.presentation.api.UIView"] = {
        build_ui_state = function()
          return { auto_interval = 1 }
        end,
        init_ui_assets = function()
          calls.init_ui_assets = (calls.init_ui_assets or 0) + 1
        end,
        capture_player_colors = function()
          calls.capture_player_colors = (calls.capture_player_colors or 0) + 1
        end,
        push_popup = function()
          return true
        end,
        open_choice_modal = function() end,
      },
      ["src.presentation.state.UIModel"] = { build = function() return {} end },
      ["src.presentation.interaction.UIEventRouter"] = {
        bind = function()
          calls.ui_bind = (calls.ui_bind or 0) + 1
        end,
      },
      ["src.presentation.shared.UINodes"] = {
        required_click_nodes = function()
          return { "基础屏" }
        end,
      },
      ["src.presentation.shared.MarketLayout"] = { item_buttons = {} },
      ["src.presentation.api.GameplayLoopPortsAdapter"] = { build = function() return {} end },
      ["Config.Map"] = {},
      ["Config.Generated.Tiles"] = {},
      ["Config.GameplayRules"] = {},
      ["src.presentation.shared.UIEvents"] = {
        show = { ["加载屏"] = "show_loading", ["基础屏"] = "show_base" },
        hide = { ["加载屏"] = "hide_loading" },
        send_to_all = function(name, payload)
          calls.sent_events[#calls.sent_events + 1] = { name = name, payload = payload }
        end,
        set_roles = function(roles)
          calls.roles = roles
        end,
      },
      ["src.core.Logger"] = {
        configure_game_time = function() end,
        info = function() end,
        warn = function() end,
      },
      ["src.game.core.runtime.MonopolyEvents"] = {
        land = { tile_upgraded = "tile_upgraded" },
        intent = { need_choice = "need_choice" },
      },
      ["vendor.third_party.UIManager.Utils"] = {},
      ["Data.UIManagerNodes"] = {
        validate = function()
          return {}
        end,
      },
    }, function()
      require("main")
      assertions(calls)
      package.loaded["main"] = nil
      package.loaded["src.app.init"] = nil
    end)
  end)
end

local function _test_bootstrap_registers_game_init_trigger()
  _run_bootstrap_test(function(calls)
    assert(type(get_vehicle_player) == "function", "editor exports should be installed during bootstrap")
    assert(type(calls.trigger_events) == "table", "bootstrap should register trigger events")
    assert(calls.trigger_events[1] == EVENT.GAME_INIT, "bootstrap should register GAME_INIT trigger")
    assert(type(calls.trigger_cb) == "function", "bootstrap should register GAME_INIT callback")
  end)
end

local function _test_game_init_trigger_runs_presentation_startup_flow()
  _run_bootstrap_test(function(calls)
    assert(type(calls.trigger_cb) == "function", "missing GAME_INIT callback")
    calls.trigger_cb()
    assert(calls.ui_manager_nodes ~= nil, "GAME_INIT should build UI manager")
    assert(calls.board_scene_init == 1, "GAME_INIT should initialize board scene")
    assert(calls.init_ui_assets == 1, "GAME_INIT should initialize ui assets")
    assert(calls.capture_player_colors == 1, "GAME_INIT should capture player colors")
    assert(calls.ui_bind == 1, "GAME_INIT should bind ui events")
    assert(calls.set_game == 1, "GAME_INIT should set gameplay loop game")
    assert(calls.frame_out and calls.frame_out.repeat_count == -1, "GAME_INIT should start frame tick loop")
    assert(calls.sent_events[1] and calls.sent_events[1].name == "show_loading", "GAME_INIT should show loading panel")
    assert(calls.timeout and type(calls.timeout.cb) == "function", "GAME_INIT should schedule loading hide")
    calls.timeout.cb()
    assert(calls.sent_events[2] and calls.sent_events[2].name == "hide_loading", "timeout should hide loading panel")
    assert(calls.sent_events[3] and calls.sent_events[3].name == "show_base", "timeout should show base panel")
  end)
end

return {
  _test_bootstrap_registers_game_init_trigger,
  _test_game_init_trigger_runs_presentation_startup_flow,
}
