-- luacheck: ignore 211
local support = require("support.presentation_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local gameplay_loop = support.gameplay_loop
local turn_move = support.turn_move
local event_handlers = require("src.ui.ctl.event_handlers")
local paid_currency_bridge = require("src.rules.commerce.paid_currency_bridge")
local dispatch = require("src.turn.actions.action_dispatcher")
local runtime_port = require("src.ui.render.runtime_ui")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local choice_openers = require("src.ui.ctl.choice_screens.openers")
local market_view = require("src.ui.render.market")
local market_layout = require("src.ui.schema.market_layout")
local canvas_event_router = require("src.ui.ctl.canvas_event_router")
local ui_view = require("src.ui.ctl.ui_runtime")
local ui_status_3d_layer = require("src.ui.render.status3d")
local action_anim = require("src.ui.render.action_anim")
local move_anim = require("src.ui.render.move_anim")
local runtime_cls = require("src.turn.loop.scheduler_runtime")
local turn_effects = require("src.ui.wid.turn_effects")
local popup_renderer = require("src.ui.ctl.popup")
local market_modal_renderer = require("src.ui.ctl.market")
local debug_ports_module = require("src.ui.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")
local host_runtime = require("src.host")
local runtime_state = require("src.ui.state")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
local vec3 = require("fixtures.vec3")

local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

local _wrap_ui_refs = support.wrap_ui_refs
local _build_popup_view_state = support.build_popup_view_state
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local _build_choice_modal_state = support.build_choice_modal_state
local _build_target_pick_env = support.build_target_pick_env

local function _build_status3d_test_env()
  local created_layers = {}
  local destroyed_layers = {}
  local layer_visibility = {}

  local function _set_layer_visible(layer, observer_id, visible)
    if not layer_visibility[layer] then
      layer_visibility[layer] = {}
    end
    layer_visibility[layer][observer_id] = visible == true
  end

  local observers = {
    { id = 1 },
    { id = 2 },
  }

  local layer_counter = { [1] = 0, [2] = 0 }
  local roles = {
    [1] = {
      get_ctrl_unit = function()
        return {
          create_scene_ui_bind_unit = function(layout_id, _, _, _, _, _)
            layer_counter[1] = layer_counter[1] + 1
            local layer = "layer_1_" .. tostring(layout_id)
            created_layers[#created_layers + 1] = layer
            return layer
          end,
        }
      end,
      set_label_text = function() end,
    },
    [2] = {
      get_ctrl_unit = function()
        return {
          create_scene_ui_bind_unit = function(layout_id, _, _, _, _, _)
            layer_counter[2] = layer_counter[2] + 1
            local layer = "layer_2_" .. tostring(layout_id)
            created_layers[#created_layers + 1] = layer
            return layer
          end,
        }
      end,
      set_label_text = function() end,
    },
  }

  local game_api = {
    get_role = function(player_id)
      return roles[player_id]
    end,
    get_all_valid_roles = function()
      return observers
    end,
    set_scene_ui_visible = function(layer, observer_role, visible)
      _set_layer_visible(layer, observer_role.id, visible)
    end,
    destroy_scene_ui = function(layer)
      destroyed_layers[#destroyed_layers + 1] = layer
    end,
  }

  return {
    game_api = game_api,
    created_layers = created_layers,
    destroyed_layers = destroyed_layers,
    layer_visibility = layer_visibility,
  }
end

local function _build_status3d_game(opts)
  opts = opts or {}
  local tile_type = opts.tile_type or "start"
  local player_status_1 = opts.player_status_1 or { stay_turns = 0, deity = { type = "", remaining = 0 } }
  local player_status_2 = opts.player_status_2 or { stay_turns = 0, deity = { type = "", remaining = 0 } }
  return {
    players = {
      [1] = {
        id = 1,
        position = 1,
        eliminated = false,
        status = player_status_1,
      },
      [2] = {
        id = 2,
        position = 2,
        eliminated = false,
        status = player_status_2,
      },
    },
    board = {
      get_tile = function(_, index)
        if index == 1 then
          return { type = tile_type }
        end
        return { type = "start" }
      end,
    },
    turn = opts.turn,
    last_turn = opts.last_turn,
  }
end

local function _build_turn_effect_runtime_env(role_ids)
  local active_role = nil
  local roles = {}
  for _, role_id in ipairs(role_ids or {}) do
    local captured_role_id = role_id
    roles[#roles + 1] = {
      get_roleid = function()
        return captured_role_id
      end,
    }
  end

  local per_role_nodes = {}
  for _, role_id in ipairs(role_ids or {}) do
    per_role_nodes[role_id] = {
      ["基础_星星中心爆开"] = { visible = false },
      ["基础_行动提示"] = { visible = false },
      ["基础_行动提示特效"] = { visible = false },
      ["基础_其他玩家行动提示"] = { visible = false, text = "" },
    }
  end

  local global_nodes = {
    ["基础_玩家1行动动效"] = { visible = false },
    ["基础_玩家2行动动效"] = { visible = false },
    ["基础_玩家3行动动效"] = { visible = false },
    ["基础_玩家4行动动效"] = { visible = false },
  }

  return {
    roles = roles,
    per_role_nodes = per_role_nodes,
    set_client_role = function(role)
      active_role = role
    end,
    for_each_role_or_global = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end,
    query_node = function(name)
      local global_node = global_nodes[name]
      if global_node then
        return global_node
      end
      local role_id = active_role and active_role.get_roleid and active_role.get_roleid() or nil
      assert(role_id ~= nil, "missing role_id for node: " .. tostring(name))
      local role_nodes = per_role_nodes[role_id]
      assert(role_nodes ~= nil, "missing role nodes: " .. tostring(role_id))
      local node = role_nodes[name]
      assert(node ~= nil, "missing role node: " .. tostring(name))
      return node
    end,
  }
end

local function _new_cash_delta_presenter_env(opts)
  opts = opts or {}
  local presenter = require("src.ui.wid.panel_presenter")
  local number_utils = require("src.core.utils.number_utils")
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY_AVATAR" }),
    ui = {
      item_slots = {},
      base_hidden_nodes = {},
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      item_slot_item_ids_by_role = {},
      labels = {},
      visible = {},
      set_label = function(self, name, text)
        if opts.missing_delta_node and string.match(name, "^基础%-玩家%d消耗金币显示$") then
          error("missing node")
        end
        self.labels[name] = text
      end,
      set_visible = function(self, name, value)
        if opts.missing_delta_node and string.match(name, "^基础%-玩家%d消耗金币显示$") then
          error("missing node")
        end
        self.visible[name] = value
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    auto_enabled_by_player = { [1] = false },
    board = { players = {} },
    item_slots_by_player = {},
    panel = {
      turn_label = "倒计时:0",
      auto_label = "自动：关",
      auto_label_by_player = { [1] = "自动：关" },
      no_action_visible = false,
      no_action_text = "",
      player_rows = {
        { name = "P1", avatar = nil, eliminated = false, cash_value = 0, total_assets_value = 0, cash = "现金: 0", land_count = "", total_assets = "总资产: 0" },
        { name = "P2", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P3", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P4", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
  }
  local runtime = {
    set_client_role = function() end,
    resolve_role_id = function() return nil end,
    for_each_role_or_global = function(fn)
      fn(nil)
    end,
    query_node = function()
      return {}
    end,
    set_node_texture_native_size = function() end,
  }
  local function set_cash(index, value)
    local row = ui_model.panel.player_rows[index]
    row.cash_value = value
    if value == nil then
      row.cash = ""
    else
      row.cash = "现金: " .. number_utils.format_integer_part(value)
    end
  end
  local function set_total_assets(index, value)
    local row = ui_model.panel.player_rows[index]
    row.total_assets_value = value
    if value == nil then
      row.total_assets = ""
    else
      row.total_assets = "总资产: " .. number_utils.format_integer_part(value)
    end
  end
  local function set_eliminated(index, value)
    local row = ui_model.panel.player_rows[index]
    row.eliminated = value == true
  end
  local function refresh()
    presenter.refresh(state, ui_model, {
      runtime = runtime,
      refresh_item_slots = function() end,
    })
  end
  return {
    state = state,
    ui_model = ui_model,
    refresh = refresh,
    set_cash = set_cash,
    set_total_assets = set_total_assets,
    set_eliminated = set_eliminated,
  }
end

local function _test_panel_avatar_uses_native_size_path()
  local presenter = require("src.ui.wid.panel_presenter")
  local native_size_calls = 0
  local client_role = { stale = true }
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY_AVATAR" }),
    ui = {
      item_slots = {},
      base_hidden_nodes = {},
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      item_slot_item_ids_by_role = {},
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    auto_enabled_by_player = { [1] = false },
    board = { players = {} },
    item_slots_by_player = {},
    panel = {
      turn_label = "倒计时:0",
      auto_label = "自动：关",
      auto_label_by_player = { [1] = "自动：关" },
      no_action_visible = false,
      no_action_text = "",
      player_rows = {
        { name = "P1", avatar = "A1", cash = "", land_count = "", total_assets = "" },
        { name = "P2", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P3", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P4", avatar = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
  }
  local runtime = {
    set_client_role = function(role)
      client_role = role
    end,
    resolve_role_id = function() return nil end,
    for_each_role_or_global = function(fn)
      fn(nil)
    end,
    set_node_texture_native_size = function()
      native_size_calls = native_size_calls + 1
    end,
  }

  presenter.refresh(state, ui_model, {
    runtime = runtime,
    refresh_item_slots = function() end,
  })

  _assert_eq(native_size_calls, 4, "panel avatar should use native-size path")
  _assert_eq(client_role, nil, "panel presenter should restore client_role to nil")
end

local function _test_panel_cash_delta_shows_negative_and_auto_hides()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 100)
    env.refresh()
    env.set_cash(1, 80)
    env.refresh()
  end)

  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "-20", "cash delta should render negative text")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "cash delta label should be visible")
  _assert_eq(#scheduled, 1, "cash delta should schedule hide once")
  _assert_eq(scheduled[1].delay, timing.panel_cash_delta_visible_seconds,
    "cash delta hide duration should follow dedicated gameplay rule")
  scheduled[1].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "cash delta label should clear after timeout")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "cash delta label should hide after timeout")
end

local function _test_panel_cash_delta_shows_positive_and_auto_hides()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 80)
    env.refresh()
    env.set_cash(1, 120)
    env.refresh()
  end)

  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40", "cash delta should render positive text")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "cash delta label should be visible")
  _assert_eq(#scheduled, 1, "cash delta should schedule hide once")
  scheduled[1].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "cash delta label should clear after timeout")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "cash delta label should hide after timeout")
end

local function _test_panel_cash_delta_keeps_latest_when_changes_are_continuous()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 100)
    env.refresh()
    env.set_cash(1, 80)
    env.refresh()
    env.set_cash(1, 120)
    env.refresh()
  end)

  _assert_eq(#scheduled, 2, "continuous changes should schedule two hides")
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40", "latest cash delta text should win")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "latest cash delta should stay visible")
  scheduled[1].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40", "old timer should not clear latest delta")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "old timer should not hide latest delta")
  scheduled[2].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "latest timer should clear latest delta")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "latest timer should hide latest delta")
end

local function _test_panel_cash_delta_hides_when_value_unchanged()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 100)
    env.refresh()
    env.set_cash(1, 100)
    env.refresh()
  end)

  _assert_eq(#scheduled, 0, "unchanged cash should not schedule hide")
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "unchanged cash should keep delta label empty")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "unchanged cash should keep delta label hidden")
end

local function _test_panel_cash_delta_missing_node_is_safe()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env({ missing_delta_node = true })
  local scheduled = {}
  local ok, err = pcall(function()
    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      env.set_cash(1, 100)
      env.refresh()
      env.set_cash(1, 80)
      env.refresh()
    end)
  end)

  assert(ok, "missing cash delta node should not crash: " .. tostring(err))
  _assert_eq(#scheduled, 0, "missing cash delta node should skip hide scheduling")
  _assert_eq(env.state.ui.labels["基础_玩家1现金"], "现金: 80", "base cash label should still update")
end

local function _test_panel_crown_shows_for_top_total_assets_and_ties()
  local env = _new_cash_delta_presenter_env()
  env.set_total_assets(1, 100)
  env.set_total_assets(2, 120)
  env.set_total_assets(3, 120)
  env.set_total_assets(4, 80)

  env.refresh()

  _assert_eq(env.state.ui.visible["基础_玩家1皇冠"], false, "player1 crown should hide when not top")
  _assert_eq(env.state.ui.visible["基础_玩家2皇冠"], true, "player2 crown should show when tied top")
  _assert_eq(env.state.ui.visible["基础_玩家3皇冠"], true, "player3 crown should show when tied top")
  _assert_eq(env.state.ui.visible["基础_玩家4皇冠"], false, "player4 crown should hide when not top")
end

local function _test_panel_crown_excludes_eliminated_players()
  local env = _new_cash_delta_presenter_env()
  env.set_total_assets(1, 80)
  env.set_total_assets(2, 200)
  env.set_total_assets(3, 100)
  env.set_total_assets(4, 60)
  env.set_eliminated(2, true)

  env.refresh()

  _assert_eq(env.state.ui.visible["基础_玩家1皇冠"], false, "player1 crown should hide when not top among active players")
  _assert_eq(env.state.ui.visible["基础_玩家2皇冠"], false, "eliminated player crown should hide")
  _assert_eq(env.state.ui.visible["基础_玩家3皇冠"], true, "active top player crown should show")
  _assert_eq(env.state.ui.visible["基础_玩家4皇冠"], false, "player4 crown should hide")
end

local function _test_panel_apply_player_colors_updates_image_and_labels()
  local panel_player_slots = require("src.ui.wid.panel_player_slots")
  local image_calls = {}
  local label_calls = {}

  panel_player_slots.apply_player_colors({
    set_image_color = function(_, node, color, alpha)
      image_calls[#image_calls + 1] = { node = node, color = color, alpha = alpha }
    end,
    set_label_color = function(_, node, color, alpha)
      label_calls[#label_calls + 1] = { node = node, color = color, alpha = alpha }
    end,
  }, {
    query_node = function(name)
      if name == "基础-玩家2消耗金币显示" then
        error("missing label node")
      end
      return name
    end,
  }, {
    id = 2,
  }, 2)

  _assert_eq(#image_calls, 1, "player color should tint one image node")
  _assert_eq(image_calls[1].node, "基础_玩家2底板颜色", "player color should target indexed image node")
  _assert_eq(image_calls[1].alpha, 0, "player color should keep image alpha at zero")
  _assert_eq(#label_calls, 4, "player color should tint every resolved label node")
  _assert_eq(label_calls[1].node, "基础_玩家2名字", "player color should tint player name label")
  _assert_eq(label_calls[#label_calls].alpha, 0, "player color should keep label alpha at zero")
end

local function _test_panel_apply_player_colors_skips_when_role_has_no_color_hooks()
  local panel_player_slots = require("src.ui.wid.panel_player_slots")
  local queried = 0

  panel_player_slots.apply_player_colors({}, {
    query_node = function()
      queried = queried + 1
      return {}
    end,
  }, {
    id = 1,
  }, 1)

  _assert_eq(queried, 0, "panel player colors should early-return before querying nodes without color hooks")
end

return {
  name = "presentation_player_panels",
  tests = {
    { name = "_test_panel_avatar_uses_native_size_path", run = _test_panel_avatar_uses_native_size_path },
    { name = "_test_panel_cash_delta_shows_negative_and_auto_hides", run = _test_panel_cash_delta_shows_negative_and_auto_hides },
    { name = "_test_panel_cash_delta_shows_positive_and_auto_hides", run = _test_panel_cash_delta_shows_positive_and_auto_hides },
    { name = "_test_panel_cash_delta_keeps_latest_when_changes_are_continuous", run = _test_panel_cash_delta_keeps_latest_when_changes_are_continuous },
    { name = "_test_panel_cash_delta_hides_when_value_unchanged", run = _test_panel_cash_delta_hides_when_value_unchanged },
    { name = "_test_panel_cash_delta_missing_node_is_safe", run = _test_panel_cash_delta_missing_node_is_safe },
    { name = "_test_panel_crown_shows_for_top_total_assets_and_ties", run = _test_panel_crown_shows_for_top_total_assets_and_ties },
    { name = "_test_panel_crown_excludes_eliminated_players", run = _test_panel_crown_excludes_eliminated_players },
    { name = "_test_panel_apply_player_colors_updates_image_and_labels", run = _test_panel_apply_player_colors_updates_image_and_labels },
    { name = "_test_panel_apply_player_colors_skips_when_role_has_no_color_hooks", run = _test_panel_apply_player_colors_skips_when_role_has_no_color_hooks },
  },
}
