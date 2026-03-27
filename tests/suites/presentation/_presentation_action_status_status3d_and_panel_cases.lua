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
local debug_ports_module = require("src.presentation.runtime.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")
local host_runtime = require("src.host.eggy")
local runtime_state = require("src.ui.runtime.state")
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

local function _build_turn_switch_camera_roles(target_role_id, target_pos)
  local bind_modes = {}
  local lock_positions = {}
  local roles = {
    [1] = {
      id = 1,
      set_camera_bind_mode = function(mode)
        bind_modes[1] = mode
      end,
      set_camera_lock_position = function(pos)
        lock_positions[1] = pos
      end,
    },
    [2] = {
      id = 2,
      set_camera_bind_mode = function(mode)
        bind_modes[2] = mode
      end,
      set_camera_lock_position = function(pos)
        lock_positions[2] = pos
      end,
    },
  }
  roles[target_role_id].get_ctrl_unit = function()
    return {
      get_position = function()
        return target_pos
      end,
    }
  end
  return roles, bind_modes, lock_positions
end


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

local function _test_status3d_init_and_global_visibility()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game()
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true })
  end)

  _assert_eq(#env.created_layers, 12, "status3d should create 6 layers per player (2 players)")
  for _, layer in ipairs(env.created_layers) do
    _assert_eq(env.layer_visibility[layer][1], false, "observer1 should see hidden layer when player has no status")
    _assert_eq(env.layer_visibility[layer][2], false, "observer2 should see hidden layer when player has no status")
  end
end

local function _test_status3d_priority_single_status()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 2,
      deity = { type = "poor", remaining = 5 },
    },
  })
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(env.layer_visibility[hospital_layer][1], true, "hospital layer should be visible (priority over poor)")
  _assert_eq(env.layer_visibility[poor_layer][1], false, "poor layer should be hidden when hospital active")
end

local function _test_status3d_roadblock_only_current_turn()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    last_turn = {
      player_id = 1,
      move_result = { stopped_on_roadblock = true },
    },
  })
  local prefab = require("Data.Prefab")
  local roadblock_layout = prefab.scene_eui["路障状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, turn = true })
    local roadblock_layer = "layer_1_" .. tostring(roadblock_layout)
    _assert_eq(env.layer_visibility[roadblock_layer][1], true, "roadblock should show at trigger turn")

    game.last_turn = {
      player_id = 2,
      move_result = { stopped_on_roadblock = true },
    }
    ui_status_3d_layer.sync(game, state, { any = true, turn = true })
    _assert_eq(env.layer_visibility[roadblock_layer][1], false, "roadblock should hide after trigger turn")
  end)
end

local function _test_status3d_hospital_visible_when_no_action_notice_even_if_stay_turns_zero()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "poor", remaining = 5 },
    },
    turn = {
      phase = "end_turn",
      detained_wait_active = false,
      no_action_notice_active = true,
      no_action_notice_player_id = 1,
      no_action_notice_text = "本回合无法行动",
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 0,
      note = "被扣留",
    },
  })
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true, turn = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(env.layer_visibility[hospital_layer][1], true,
    "hospital layer should stay visible during no-action notice when stay_turns is zero")
  _assert_eq(env.layer_visibility[poor_layer][1], false,
    "deity layer should be hidden when hospital no-action notice is active")
end

local function _test_status3d_hospital_visible_during_pending_location_effect()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 0,
      pending_location_effect = "hospital",
      deity = { type = "poor", remaining = 5 },
    },
    turn = {
      phase = "wait_action_anim",
      detained_wait_active = false,
      no_action_notice_active = false,
    },
  })
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true, turn = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(env.layer_visibility[hospital_layer][1], true,
    "hospital layer should be visible while hospital effect is pending")
  _assert_eq(env.layer_visibility[poor_layer][1], false,
    "deity layer should stay hidden while hospital effect is pending")
end

local function _test_status3d_roadblock_anim_pending_overrides_hospital_pending()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 0,
      pending_location_effect = "hospital",
      deity = { type = "poor", remaining = 5 },
    },
    turn = {
      phase = "wait_action_anim",
      action_anim = {
        kind = "roadblock_trigger",
        player_id = 1,
        tile_index = 1,
      },
      action_anim_queue = {},
      detained_wait_active = false,
      no_action_notice_active = false,
    },
    last_turn = {
      player_id = 1,
      move_result = { stopped_on_roadblock = true },
    },
  })
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local roadblock_layout = prefab.scene_eui["路障状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true, turn = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local roadblock_layer = "layer_1_" .. tostring(roadblock_layout)
  _assert_eq(env.layer_visibility[roadblock_layer][1], true,
    "roadblock should stay visible while roadblock trigger anim is pending")
  _assert_eq(env.layer_visibility[hospital_layer][1], false,
    "hospital should remain hidden until roadblock trigger anim drains")
end

local function _test_status3d_mountain_visible_when_no_action_notice_even_if_stay_turns_zero()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "mountain",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "rich", remaining = 5 },
    },
    turn = {
      phase = "end_turn",
      detained_wait_active = false,
      no_action_notice_active = true,
      no_action_notice_player_id = 1,
      no_action_notice_text = "本回合无法行动",
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 0,
      note = "被扣留",
    },
  })
  local prefab = require("Data.Prefab")
  local mountain_layout = prefab.scene_eui["深山状态"]
  local rich_layout = prefab.scene_eui["财神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true, turn = true })
  end)

  local mountain_layer = "layer_1_" .. tostring(mountain_layout)
  local rich_layer = "layer_1_" .. tostring(rich_layout)
  _assert_eq(env.layer_visibility[mountain_layer][1], true,
    "mountain layer should stay visible during no-action notice when stay_turns is zero")
  _assert_eq(env.layer_visibility[rich_layer][1], false,
    "deity layer should be hidden when mountain no-action notice is active")
end

local function _test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero()
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local mountain_layout = prefab.scene_eui["深山状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  local rich_layout = prefab.scene_eui["财神状态"]

  local hospital_env = _build_status3d_test_env()
  local hospital_state = {}
  local hospital_game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "poor", remaining = 5 },
    },
    turn = {
      phase = "start",
      detained_wait_active = false,
    },
  })
  _with_patches({
    { key = "GameAPI", value = hospital_env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(hospital_game, hospital_state, { any = true, players = true, turn = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(hospital_env.layer_visibility[hospital_layer][1], false,
    "hospital layer should stay hidden when stay_turns is zero and turn is not detained")
  _assert_eq(hospital_env.layer_visibility[poor_layer][1], true,
    "deity layer should be visible when hospital detained status is inactive")

  local mountain_env = _build_status3d_test_env()
  local mountain_state = {}
  local mountain_game = _build_status3d_game({
    tile_type = "mountain",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "rich", remaining = 5 },
    },
    turn = {
      phase = "start",
      detained_wait_active = false,
    },
  })
  _with_patches({
    { key = "GameAPI", value = mountain_env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(mountain_game, mountain_state, { any = true, players = true, turn = true })
  end)

  local mountain_layer = "layer_1_" .. tostring(mountain_layout)
  local rich_layer = "layer_1_" .. tostring(rich_layout)
  _assert_eq(mountain_env.layer_visibility[mountain_layer][1], false,
    "mountain layer should stay hidden when stay_turns is zero and turn is not detained")
  _assert_eq(mountain_env.layer_visibility[rich_layer][1], true,
    "deity layer should be visible when mountain detained status is inactive")
end

local function _test_status3d_reset_destroy_layers()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game()
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true })
    ui_status_3d_layer.reset(state)
  end)

  _assert_eq(#env.destroyed_layers, 12, "reset should destroy all created layers (6 per player × 2)")
  assert(state.ui_status_3d == nil, "reset should clear state cache")
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

local function _test_turn_effects_prompt_visibility_follows_phase_and_role()
  local env = _build_turn_effect_runtime_env({ 1, 2 })
  local state = {}
  local ui_model = {
    current_player_id = 1,
    current_player_name = "P1",
    board = {
      phase = "wait_action",
      players = { { id = 1 }, { id = 2 } },
    },
  }

  _with_patches({
    { target = runtime_port, key = "set_client_role", value = env.set_client_role },
    { target = runtime_port, key = "for_each_role_or_global", value = env.for_each_role_or_global },
    { target = runtime_port, key = "query_node", value = env.query_node },
  }, function()
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, true, "current player should see action prompt in wait_action phase")
    _assert_eq(env.per_role_nodes[1]["基础_行动提示特效"].visible, true, "current player should see action star in wait_action phase")
    _assert_eq(env.per_role_nodes[2]["基础_行动提示"].visible, false, "other player should hide local action prompt")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, true, "other player should always see other-action prompt")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].text, "P1正在行动", "other prompt text should use current player name")

    ui_model.board.phase = "start"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, false, "current player prompt should stay hidden before countdown phase")
    _assert_eq(env.per_role_nodes[1]["基础_行动提示特效"].visible, false, "current player star should stay hidden before countdown phase")

    ui_model.board.phase = "wait_move_anim"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, false, "current player prompt should hide after action begins")
    _assert_eq(env.per_role_nodes[1]["基础_行动提示特效"].visible, false, "current player star should hide after action begins")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, true, "other player prompt should stay visible in non-turn phase")

    ui_model.board.phase = "end_turn"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, false, "current player prompt should hide after countdown phase ends")

    ui_model.current_player_id = 2
    ui_model.current_player_name = "P2"
    ui_model.board.phase = "wait_action"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_其他玩家行动提示"].visible, true, "switched non-current player should see other-action prompt")
    _assert_eq(env.per_role_nodes[1]["基础_其他玩家行动提示"].text, "P2正在行动", "other prompt text should follow current player switch")
    _assert_eq(env.per_role_nodes[2]["基础_行动提示"].visible, true, "new current player should see local action prompt")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, false, "current player should hide other-action prompt")
  end)
end

local function _test_turn_effects_other_prompt_fallback_text()
  local env = _build_turn_effect_runtime_env({ 1, 2 })
  local state = {}
  local ui_model = {
    current_player_id = 1,
    current_player_name = nil,
    board = {
      phase = "wait_action_anim",
      players = { { id = 1 }, { id = 2 } },
    },
  }

  _with_patches({
    { target = runtime_port, key = "set_client_role", value = env.set_client_role },
    { target = runtime_port, key = "for_each_role_or_global", value = env.for_each_role_or_global },
    { target = runtime_port, key = "query_node", value = env.query_node },
  }, function()
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, false, "current player local prompt should hide in wait_action_anim")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, true, "other player prompt should show without current player name")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].text, "其他玩家正在行动", "other prompt should use fallback text")
  end)
end

local function _test_turn_effects_sync_restores_client_role_nil()
  local env = _build_turn_effect_runtime_env({ 1, 2 })
  local manager = { client_role = { marker = "seed" } }
  local state = {}
  local ui_model = {
    current_player_id = 1,
    current_player_name = "P1",
    board = {
      phase = "start",
      players = { { id = 1 }, { id = 2 } },
    },
  }

  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime_port, key = "set_client_role", value = function(role)
      env.set_client_role(role)
      manager.client_role = role
    end },
    { target = runtime_port, key = "for_each_role_or_global", value = env.for_each_role_or_global },
    { target = runtime_port, key = "query_node", value = env.query_node },
    { target = runtime_port, key = "with_client_role", value = function(role, fn)
      local prev = manager.client_role
      manager.client_role = role
      env.set_client_role(role)
      local ok, err = pcall(fn)
      env.set_client_role(prev)
      manager.client_role = prev
      if not ok then
        error(err)
      end
    end },
  }, function()
    turn_effects.sync(state, ui_model)
  end)

  _assert_eq(manager.client_role, nil, "turn_effects.sync should restore client_role to nil")
end

local function _test_tick_ui_sync_turn_switch_still_follows()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local board_view_mod = require("src.ui.render.board")
  local status3d = require("src.ui.render.status3d")
  local target_pos = { x = 1, y = 2, z = 3 }
  local camera_roles, bind_modes, lock_positions = _build_turn_switch_camera_roles(2, target_pos)
  local follow_events = 0
  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh", value = function() end },
    { target = main_view, key = "apply_role_control_lock", value = function() end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function() end },
    { target = status3d, key = "sync", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { key = "Enums", value = {
      CameraBindMode = { TRACK = 0 },
      BuffState = { BUFF_FORBID_CONTROL = 32 },
    } },
    { target = runtime_ports, key = "resolve_role", value = function(player_id) return camera_roles[player_id] end },
    { target = runtime_ports, key = "resolve_roles", value = function() return { camera_roles[1], camera_roles[2] } end },
    { key = "TriggerCustomEvent", value = function(event_name, payload)
      follow_events = follow_events + 1
    end },
  }
  local game = {
    finished = false,
    winner = nil,
    players = {
      [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } },
      [2] = { id = 2, name = "P2", cash = 0, eliminated = false, inventory = { items = {} } },
    },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 2,
      turn_count = 3,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    ui_dirty = true,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      },
      [2] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = ui_view.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
  }
  _bind_ui_runtime(state)

  _with_patches(patches, function()
    runtime_event_bridge._reset_for_tests()
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
    gameplay_loop.tick(game, state, 0.1)
    runtime_event_bridge._reset_for_tests()
  end)

  _assert_eq(bind_modes[1], 1, "turn switch should set fixed camera bind mode for observer 1")
  _assert_eq(bind_modes[2], 1, "turn switch should set fixed camera bind mode for observer 2")
  assert(lock_positions[1] == target_pos, "turn switch should lock observer 1 to current player position")
  assert(lock_positions[2] == target_pos, "turn switch should lock observer 2 to current player position")
  _assert_eq(follow_events, 0, "turn switch should not depend on legacy follow_camera custom event")
end

local function _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local board_view_mod = require("src.ui.render.board")
  local status3d = require("src.ui.render.status3d")
  local target_pos = { x = 7, y = 8, z = 9 }
  local camera_roles, bind_modes, lock_positions = _build_turn_switch_camera_roles(2, target_pos)
  local follow_events = 0
  local game_api = GameAPI or {}
  local name = "j4MHTwbxEfG+CjRaYHE42T"
  local newenv = {}
  local function wrapped_trigger()
    local _ = name
    local __ = newenv
    follow_events = follow_events + 1
  end
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh", value = function() end },
    { target = main_view, key = "apply_role_control_lock", value = function() end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function() end },
    { target = status3d, key = "sync", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { key = "Enums", value = {
      CameraBindMode = { TRACK = 0 },
      BuffState = { BUFF_FORBID_CONTROL = 32 },
    } },
    { target = runtime_ports, key = "resolve_role", value = function(player_id) return camera_roles[player_id] end },
    { target = runtime_ports, key = "resolve_roles", value = function() return { camera_roles[1], camera_roles[2] } end },
    { key = "TriggerCustomEvent", value = wrapped_trigger },
  }
  local game = {
    finished = false,
    winner = nil,
    players = {
      [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } },
      [2] = { id = 2, name = "P2", cash = 0, eliminated = false, inventory = { items = {} } },
    },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 2,
      turn_count = 3,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    ui_dirty = true,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      },
      [2] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = ui_view.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
  }
  _bind_ui_runtime(state)

  _with_patches(patches, function()
    runtime_event_bridge._reset_for_tests()
    local ok, err = pcall(function()
      state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
      gameplay_loop.tick(game, state, 0.1)
    end)
    runtime_event_bridge._reset_for_tests()
    assert(ok == true, "turn switch should not fail when follow event is unavailable: " .. tostring(err))
  end)

  _assert_eq(bind_modes[1], 1, "degraded turn switch should set fixed camera bind mode for observer 1")
  _assert_eq(bind_modes[2], 1, "degraded turn switch should set fixed camera bind mode for observer 2")
  assert(lock_positions[1] == target_pos, "degraded turn switch should still lock observer 1 to current player position")
  assert(lock_positions[2] == target_pos, "degraded turn switch should still lock observer 2 to current player position")
  _assert_eq(follow_events, 0, "degraded follow event path should avoid wrapped TriggerCustomEvent call")
end

local function _test_ui_sync_defers_choice_modal_during_wait_action_anim()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local opened = 0
  local game = {
      turn = {
        phase = "wait_action_anim",
        current_player_index = 1,
        turn_count = 1,
        pending_choice = {
          id = 7,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
        body_lines = { "A" },
        options = { { id = 1, label = "A" } },
        allow_cancel = true,
        cancel_label = "取消",
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
  }
  _with_patches({
    { target = ui_view_service, key = "render", value = function() end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 7, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 7, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 7, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 7, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)
  _assert_eq(opened, 0, "wait_action_anim should defer opening choice modal")
end

local function _test_ui_sync_opens_choice_modal_after_wait_action_anim()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local opened = 0
  local game = {
    turn = {
      phase = "wait_action_anim",
      current_player_index = 1,
      turn_count = 1,
        pending_choice = {
          id = 8,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
        body_lines = { "A" },
        options = { { id = 1, label = "A" } },
        allow_cancel = true,
        cancel_label = "取消",
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
  }
  _with_patches({
    { target = ui_view_service, key = "render", value = function() end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        current_player_id = 1,
        panel = { turn_label = "" },
        board = {},
        choice = { id = 8, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 8, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        current_player_id = 1,
        panel = { turn_label = "" },
        board = {},
        choice = { id = 8, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 8, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
    _assert_eq(opened, 0, "choice modal should remain deferred during wait_action_anim")
    game.turn.phase = "wait_choice"
    state.ui_dirty = true
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)
  _assert_eq(opened, 1, "choice modal should open once after leaving wait_action_anim")
end

local function _test_ui_sync_defers_choice_modal_during_wait_move_anim()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local opened = 0
  local game = {
    turn = {
      phase = "wait_move_anim",
      current_player_index = 1,
      turn_count = 1,
        pending_choice = {
          id = 9,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
        body_lines = { "A" },
        options = { { id = 1, label = "A" } },
        allow_cancel = true,
        cancel_label = "取消",
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
  }
  _with_patches({
    { target = ui_view_service, key = "render", value = function() end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 9, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 9, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 9, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 9, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)
  _assert_eq(opened, 0, "wait_move_anim should defer opening choice modal")
end

local function _test_ui_sync_step_choice_timeout_reopens_remote_choice_for_local_owner()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_sync_ports = require("src.presentation.runtime.ports.ui_sync")
  local gameplay_loop_ports = require("src.turn.loop.ports")
  local common = require("src.presentation.runtime.ports.common")
  local runtime_ports_module = require("src.core.ports.runtime_ports")
  local opened = 0
  local game = {
    turn = {
      phase = "wait_choice",
      current_player_index = 1,
      turn_count = 1,
      pending_choice = {
        id = 10,
        kind = "remote_dice_value",
        route_key = "remote",
        owner_role_id = 1,
        title = "遥控骰子",
        body_lines = { "A" },
        options = { { id = 1, label = "1" } },
        allow_cancel = true,
        cancel_label = "取消",
        meta = { player_id = 1, item_id = 2004, dice_count = 1 },
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, auto = false, is_ai = false, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = false,
    ui_model = { current_player_id = 1 },
    _log_once = {},
  }
  _bind_ui_runtime(state)

  _with_patches({
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        current_player_id = 1,
        panel = { turn_label = "" },
        board = {},
        choice = {
          id = 10,
          kind = "remote_dice_value",
          route_key = "remote",
          options = { { id = 1, label = "1" } },
          allow_cancel = true,
          meta = { player_id = 1, item_id = 2004, dice_count = 1 },
        },
      }
    end },
    { target = runtime_ports_module, key = "resolve_roles", value = function()
      return {}
    end },
  }, function()
    state.gameplay_loop_ports = gameplay_loop_ports.resolve({
      ui_sync = ui_sync_ports.build(common),
    })
    state.gameplay_loop_ports.ui_sync.step_choice_timeout(game, state, 0.1)
  end)

  _assert_eq(opened, 1, "step_choice_timeout should reopen remote choice for local owner")
end

local function _test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local anchors = require("src.ui.render.board.anchors")
  local startup_render = require("src.ui.render.board.startup_render")
  local player_units = require("src.ui.render.board.player_units")
  local base_presenter = require("src.ui.wid.panel_presenter")
  local turn_effects = require("src.ui.wid.turn_effects")
  local fixed_zero = { kind = "fixed_zero", value = 0 }
  local calls = {}
  local game = {
    turn = {
      phase = "start",
      current_player_index = 1,
      turn_count = 1,
    },
    players = {
      [1] = { id = 1, name = "P1", position = 1, seat_id = nil, eliminated = false, inventory = { items = {} }, cash = 0 },
    },
  }
  local state
  state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
    board_scene = {
      ground = {
        get_position = function()
          return { y = 0 }
        end,
      },
    },
    tile_positions = {
      [1] = vec3.with_add(10, 0, 20),
    },
    tile_spacing = 0,
    player_units = {
      [1] = {
        ai_command_stop_move = function(duration)
          _assert_eq(duration, fixed_zero, "refresh_from_dirty should pass Fix32 zero into ai stop")
          calls[#calls + 1] = "ai_command_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
        set_position = function(pos)
          calls[#calls + 1] = "set_position"
          state._last_target_pos = pos
        end,
      },
    },
  }

  _with_patches({
    { target = anchors, key = "ensure_tile_anchors", value = function() end },
    { target = startup_render, key = "apply", value = function() end },
    { target = player_units, key = "ensure_player_units", value = function() end },
    { target = base_presenter, key = "refresh", value = function() end },
    { target = turn_effects, key = "sync", value = function() end },
    { target = math, key = "tofixed", value = function(value)
      _assert_eq(value, 0, "refresh_from_dirty should only request zero stop duration")
      return fixed_zero
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {
          phase = "start",
          move_anim = nil,
          move_followup_pending = false,
          vehicle_resync_seq = 0,
          tile_count = 1,
          tiles = { { id = 1 } },
          players = {
            { id = 1, name = "P1", position = 1, seat_id = nil, eliminated = false },
          },
        },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {
          phase = "start",
          move_anim = nil,
          move_followup_pending = false,
          vehicle_resync_seq = 0,
          tile_count = 1,
          tiles = { { id = 1 } },
          players = {
            { id = 1, name = "P1", position = 1, seat_id = nil, eliminated = false },
          },
        },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)

  _assert_eq(calls[1], "ai_command_stop_move", "refresh_from_dirty should reach ai stop fallback")
  _assert_eq(calls[2], "stop_anim", "refresh_from_dirty should stop anim after ai stop")
  _assert_eq(calls[3], "set_position", "refresh_from_dirty should still place the player")
  _assert_eq(state._last_target_pos.x, 10, "refresh_from_dirty should preserve tile x during board render")
  _assert_eq(state._last_target_pos.y, 0.5, "refresh_from_dirty should clamp player y during board render")
  _assert_eq(state._last_target_pos.z, 20, "refresh_from_dirty should preserve tile z during board render")
end

local function _test_ui_sync_refresh_from_dirty_only_turn_countdown_updates_label_without_full_render()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local render_calls = 0
  local refreshed_label = nil
  local refreshed_visible = nil
  local game = {
    turn = {
      phase = "wait_choice",
      current_player_index = 1,
      turn_count = 1,
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = false,
    ui_model = {
      panel = { turn_label = "旧标签" },
    },
  }

  _with_patches({
    { target = ui_view_service, key = "render", value = function()
      render_calls = render_calls + 1
    end },
    { target = ui_view_service, key = "refresh_turn_label", value = function(_, label, visible)
      refreshed_label = label
      refreshed_visible = visible
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "倒计时 3", countdown_visible = false },
      }
    end },
  }, function()
    local changed = ui_model_sync.refresh_from_dirty(game, state, {
      any = true,
      turn_countdown = true,
    }, {
      log_once = function() end,
      build_log_prefix = function()
        return "[test]"
      end,
    })

    _assert_eq(changed, false, "countdown-only refresh should report no full render")
  end)

  _assert_eq(render_calls, 0, "countdown-only refresh should skip full render")
  _assert_eq(refreshed_label, "倒计时 3", "countdown-only refresh should update turn label directly")
  _assert_eq(refreshed_visible, false, "countdown-only refresh should forward countdown visibility")
  _assert_eq(state.ui_dirty, false, "countdown-only refresh should clear ui dirty flag")
end

local function _test_ui_runtime_refresh_turn_label_toggles_countdown_nodes_and_label()
  local runtime_ui = require("src.ui.render.runtime_ui")
  local visible_calls = {}
  local label_calls = {}
  local reset_calls = 0
  local state = {
    ui = {
      set_visible = function(_, node, value)
        visible_calls[#visible_calls + 1] = { node = node, value = value }
      end,
      set_label = function(_, node, value)
        label_calls[#label_calls + 1] = { node = node, value = value }
      end,
    },
  }

  _with_patches({
    { target = package.loaded, key = "src.ui.ctl.ui_runtime", value = nil },
    { target = runtime_ui, key = "for_each_role_or_global", value = function(fn) fn() end },
    { target = runtime_ui, key = "set_client_role", value = function(role)
      if role == nil then
        reset_calls = reset_calls + 1
      end
    end },
  }, function()
    local ui_view_service = require("src.ui.ctl.ui_runtime")
    ui_view_service.refresh_turn_label(state, "倒计时 9", false)
  end)

  _assert_eq(#visible_calls, 2, "refresh_turn_label should update countdown and countdown_line visibility together")
  _assert_eq(visible_calls[1].value, false, "refresh_turn_label should forward hidden countdown visibility")
  _assert_eq(visible_calls[2].value, false, "refresh_turn_label should hide countdown line with countdown label")
  _assert_eq(#label_calls, 1, "refresh_turn_label should update countdown label text")
  _assert_eq(label_calls[1].value, "倒计时 9", "refresh_turn_label should pass the latest label text")
  _assert_eq(reset_calls, 1, "refresh_turn_label should reset runtime client role after iteration")
end

local function _test_popup_defer_policy_queues_and_replays_in_order()
  local modal_presenter = require("src.ui.ctl.modal")
  local popup_presenter = require("src.ui.ctl.popup")
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local state = {
    ui = ui_view.build_ui_state(),
    ui_dirty = false,
  }
  local shown = {}
  local hide_calls = 0
  _with_patches({
    { target = popup_presenter, key = "show", value = function(_, payload)
      shown[#shown + 1] = payload and payload.title or ""
    end },
    { target = popup_presenter, key = "hide", value = function()
      hide_calls = hide_calls + 1
    end },
    { target = popup_presenter, key = "switch_canvas", value = function() end },
    { target = canvas, key = "resolve_popup_return_canvas", value = function()
      return canvas.CANVAS_BASE
    end },
    { target = canvas, key = "resolve_canvas_after_popup", value = function()
      return canvas.CANVAS_BASE
    end },
  }, function()
    modal_presenter.push_popup(state, { title = "A", body = "A" })
    modal_presenter.push_popup(state, { title = "B", body = "B" }, { policy = "defer" })
    _assert_eq(#shown, 1, "defer popup should not replace active popup immediately")
    _assert_eq(state.ui.popup_queue and #state.ui.popup_queue or 0, 1, "defer popup should be queued")
    modal_presenter.close_popup(state)
  end)

  _assert_eq(hide_calls, 1, "close should hide current popup once")
  _assert_eq(#shown, 2, "queued popup should be shown after close")
  _assert_eq(shown[1], "A", "first popup title should be A")
  _assert_eq(shown[2], "B", "queued popup title should be B")
end

local function _test_popup_paths_do_not_mark_ui_model_dirty()
  local modal_presenter = require("src.ui.ctl.modal")
  local popup_presenter = require("src.ui.ctl.popup")
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local state = {
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)
  runtime_state.set_ui_dirty(state, false)

  _with_patches({
    { target = popup_presenter, key = "show", value = function() end },
    { target = popup_presenter, key = "hide", value = function() end },
    { target = popup_presenter, key = "switch_canvas", value = function() end },
    { target = canvas, key = "resolve_popup_return_canvas", value = function()
      return canvas.CANVAS_BASE
    end },
    { target = canvas, key = "resolve_canvas_after_popup", value = function()
      return canvas.CANVAS_BASE
    end },
  }, function()
    modal_presenter.push_popup(state, { title = "A", body = "A" })
    _assert_eq(runtime_state.is_ui_dirty(state), false, "push_popup should not invalidate ui_model")
    modal_presenter.close_popup(state)
  end)

  _assert_eq(runtime_state.is_ui_dirty(state), false, "close_popup should not invalidate ui_model")
end

local function _test_popup_renderer_switch_popup_canvas_restores_client_role_nil()
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local role_ctx = require("src.ui.pres.role_context")
  local manager = { client_role = { stale = true } }
  local role1 = { id = 1, get_roleid = function() return 1 end }
  local role2 = { id = 2, get_roleid = function() return 2 end }

  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      fn(role1)
      fn(role2)
    end },
    { target = runtime_port, key = "set_client_role", value = function(role)
      manager.client_role = role
    end },
    { target = runtime_port, key = "with_client_role", value = function(role, fn)
      local prev = manager.client_role
      manager.client_role = role
      local ok, err = pcall(fn)
      manager.client_role = prev
      if not ok then
        error(err)
      end
    end },
    { target = role_ctx, key = "resolve", value = function(role)
      return { can_operate = role == role1 }
    end },
    { target = canvas, key = "switch_for_role", value = function() end },
    { target = canvas, key = "switch", value = function() end },
  }, function()
    popup_renderer.switch_popup_canvas({
      ui = {},
      ui_model = {},
    }, "card", canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
  end)

  _assert_eq(manager.client_role, nil, "popup renderer should restore client_role to nil")
end

local function _test_market_modal_renderer_open_restores_client_role_nil()
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local role_ctx = require("src.ui.pres.role_context")
  local manager = { client_role = { stale = true } }
  local role1 = { id = 1, get_roleid = function() return 1 end }
  local role2 = { id = 2, get_roleid = function() return 2 end }

  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      fn(role1)
      fn(role2)
    end },
    { target = runtime_port, key = "set_client_role", value = function(role)
      manager.client_role = role
    end },
    { target = runtime_port, key = "with_client_role", value = function(role, fn)
      local prev = manager.client_role
      manager.client_role = role
      local ok, err = pcall(fn)
      manager.client_role = prev
      if not ok then
        error(err)
      end
    end },
    { target = role_ctx, key = "resolve", value = function(role)
      return { can_operate = role == role1 }
    end },
    { target = canvas, key = "switch_for_role", value = function() end },
    { target = canvas, key = "switch", value = function() end },
    { target = market_view, key = "refresh_market", value = function() return true end },
  }, function()
    local state = {
      ui = {},
      ui_model = {},
      pending_choice_selected_option_id = nil,
    }
    local choice = {
      options = { { id = 1 } },
      allow_cancel = true,
      cancel_label = "取消",
    }
    market_modal_renderer.open_market_panel(state, choice, 10, nil)
  end)

  _assert_eq(manager.client_role, nil, "market modal renderer should restore client_role to nil")
end

local function _test_debug_ports_sync_restores_client_role_nil()
  local ui_event_state = require("src.ui.ctl.event_state")
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local manager = { client_role = { stale = true } }
  local role1 = { id = 1, get_roleid = function() return 1 end }
  local role2 = { id = 2, get_roleid = function() return 2 end }
  local ports = debug_ports_module.build({
    log_status = function() end,
  })

  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      fn(role1)
      fn(role2)
    end },
    { target = runtime_port, key = "set_client_role", value = function(role)
      manager.client_role = role
    end },
    { target = runtime_port, key = "with_client_role", value = function(role, fn)
      local prev = manager.client_role
      manager.client_role = role
      local ok, err = pcall(fn)
      manager.client_role = prev
      if not ok then
        error(err)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role and role.id or nil
    end },
    { target = ui_event_state, key = "resolve_debug_enabled", value = function(_, role_id)
      return role_id == 1
    end },
    { target = ui_view_service, key = "set_debug_visible_for_role", value = function() end },
    { target = ui_view_service, key = "set_debug_log_for_role", value = function() end },
  }, function()
    local state = {
      ui = ui_view.build_ui_state(),
      _debug_log_enabled_by_role = {},
      _debug_log_seq_by_role = {},
    }
    ports.sync_debug_log(state)
  end)

  _assert_eq(manager.client_role, nil, "debug ports sync should restore client_role to nil")
end

local function _test_market_modal_renderer_refreshes_market_only_for_operable_role()
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local role_ctx = require("src.ui.pres.role_context")
  local manager = { client_role = { stale = true } }
  local role1 = { id = 1, get_roleid = function() return 1 end }
  local role2 = { id = 2, get_roleid = function() return 2 end }
  local refresh_roles = {}

  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      fn(role1)
      fn(role2)
    end },
    { target = runtime_port, key = "set_client_role", value = function(role)
      manager.client_role = role
    end },
    { target = runtime_port, key = "with_client_role", value = function(role, fn)
      local prev = manager.client_role
      manager.client_role = role
      local ok, err = pcall(fn)
      manager.client_role = prev
      if not ok then
        error(err)
      end
    end },
    { target = role_ctx, key = "resolve", value = function(role)
      return { can_operate = role == role1 }
    end },
    { target = canvas, key = "switch_for_role", value = function() end },
    { target = canvas, key = "switch", value = function() end },
    { target = market_view, key = "refresh_market", value = function()
      refresh_roles[#refresh_roles + 1] = manager.client_role and manager.client_role.id or 0
      return true
    end },
  }, function()
    local state = {
      ui = {},
      ui_model = {},
      pending_choice_selected_option_id = nil,
    }
    local choice = {
      options = { { id = 1 } },
      allow_cancel = true,
      cancel_label = "取消",
    }
    market_modal_renderer.open_market_panel(state, choice, 10, nil)
    _assert_eq(state.ui.market_active, true, "market should stay active for the operable role")
  end)

  _assert_eq(#refresh_roles, 1, "market refresh should run only once for the operable role")
  _assert_eq(refresh_roles[1], 1, "market refresh should stay scoped to the operable role")
  _assert_eq(manager.client_role, nil, "market refresh should restore client_role to nil")
end

local function _test_debug_ports_sync_ignores_non_event_log_seq_changes()
  local ui_event_state = require("src.ui.ctl.event_state")
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local manager = { client_role = { stale = true } }
  local role1 = { id = 1, get_roleid = function() return 1 end }
  local role2 = { id = 2, get_roleid = function() return 2 end }
  local ports = debug_ports_module.build({
    log_status = function() end,
  })
  local log_calls = {}

  logger.clear()
  local ok, err = pcall(function()
    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
        fn(role1)
        fn(role2)
      end },
      { target = runtime_port, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime_port, key = "with_client_role", value = function(role, fn)
        local prev = manager.client_role
        manager.client_role = role
        local inner_ok, inner_err = pcall(fn)
        manager.client_role = prev
        if not inner_ok then
          error(inner_err)
        end
      end },
      { target = runtime_port, key = "resolve_role_id", value = function(role)
        return role and role.id or nil
      end },
      { target = ui_event_state, key = "resolve_debug_enabled", value = function(_, role_id)
        return role_id == 1
      end },
      { target = ui_view_service, key = "set_debug_visible_for_role", value = function() end },
      { target = ui_view_service, key = "set_debug_log_for_role", value = function(_, role, text)
        log_calls[#log_calls + 1] = {
          role_id = role and role.id or nil,
          text = text,
        }
      end },
    }, function()
      local state = {
        ui = ui_view.build_ui_state(),
        _debug_log_enabled_by_role = {
          [2] = false,
        },
        _debug_log_seq_by_role = {},
      }

      ports.sync_debug_log(state)
      _assert_eq(#log_calls, 1, "first sync should write empty event feed once for enabled role")
      _assert_eq(log_calls[1].role_id, 1, "first sync should target enabled role")
      _assert_eq(log_calls[1].text, "", "first sync should clear stale action log text")

      logger.info("info only")
      ports.sync_debug_log(state)
      _assert_eq(#log_calls, 1, "info logs should not retrigger empty action log sync")

      logger.event_no_tips("event only")
      ports.sync_debug_log(state)
      _assert_eq(#log_calls, 2, "event logs should retrigger action log sync")
      _assert_eq(log_calls[2].role_id, 1, "event sync should target enabled role")
      assert(string.find(log_calls[2].text or "", "event only", 1, true) ~= nil, "event sync should include latest event text")
    end)
  end)
  logger.clear()
  if not ok then
    error(err)
  end
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

local function _test_panel_cash_delta_shows_negative_and_auto_hides()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local timing = require("src.config.gameplay.timing")
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
  { name = "_test_status3d_init_and_global_visibility", run = _test_status3d_init_and_global_visibility },
  { name = "_test_status3d_priority_single_status", run = _test_status3d_priority_single_status },
  { name = "_test_status3d_roadblock_only_current_turn", run = _test_status3d_roadblock_only_current_turn },
  { name = "_test_status3d_hospital_visible_when_no_action_notice_even_if_stay_turns_zero", run = _test_status3d_hospital_visible_when_no_action_notice_even_if_stay_turns_zero },
  { name = "_test_status3d_hospital_visible_during_pending_location_effect", run = _test_status3d_hospital_visible_during_pending_location_effect },
  { name = "_test_status3d_roadblock_anim_pending_overrides_hospital_pending", run = _test_status3d_roadblock_anim_pending_overrides_hospital_pending },
  { name = "_test_status3d_mountain_visible_when_no_action_notice_even_if_stay_turns_zero", run = _test_status3d_mountain_visible_when_no_action_notice_even_if_stay_turns_zero },
  { name = "_test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero", run = _test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero },
  { name = "_test_status3d_reset_destroy_layers", run = _test_status3d_reset_destroy_layers },
  { name = "_test_turn_effects_prompt_visibility_follows_phase_and_role", run = _test_turn_effects_prompt_visibility_follows_phase_and_role },
  { name = "_test_turn_effects_other_prompt_fallback_text", run = _test_turn_effects_other_prompt_fallback_text },
  { name = "_test_turn_effects_sync_restores_client_role_nil", run = _test_turn_effects_sync_restores_client_role_nil },
  { name = "_test_tick_ui_sync_turn_switch_still_follows", run = _test_tick_ui_sync_turn_switch_still_follows },
  { name = "_test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable", run = _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable },
  { name = "_test_ui_sync_defers_choice_modal_during_wait_action_anim", run = _test_ui_sync_defers_choice_modal_during_wait_action_anim },
  { name = "_test_ui_sync_opens_choice_modal_after_wait_action_anim", run = _test_ui_sync_opens_choice_modal_after_wait_action_anim },
  { name = "_test_ui_sync_defers_choice_modal_during_wait_move_anim", run = _test_ui_sync_defers_choice_modal_during_wait_move_anim },
  { name = "_test_ui_sync_step_choice_timeout_reopens_remote_choice_for_local_owner", run = _test_ui_sync_step_choice_timeout_reopens_remote_choice_for_local_owner },
  { name = "_test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop", run = _test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop },
  { name = "_test_ui_sync_refresh_from_dirty_only_turn_countdown_updates_label_without_full_render", run = _test_ui_sync_refresh_from_dirty_only_turn_countdown_updates_label_without_full_render },
  { name = "_test_ui_runtime_refresh_turn_label_toggles_countdown_nodes_and_label", run = _test_ui_runtime_refresh_turn_label_toggles_countdown_nodes_and_label },
  { name = "_test_popup_defer_policy_queues_and_replays_in_order", run = _test_popup_defer_policy_queues_and_replays_in_order },
  { name = "_test_popup_paths_do_not_mark_ui_model_dirty", run = _test_popup_paths_do_not_mark_ui_model_dirty },
  { name = "_test_popup_renderer_switch_popup_canvas_restores_client_role_nil", run = _test_popup_renderer_switch_popup_canvas_restores_client_role_nil },
  { name = "_test_market_modal_renderer_open_restores_client_role_nil", run = _test_market_modal_renderer_open_restores_client_role_nil },
  { name = "_test_market_modal_renderer_refreshes_market_only_for_operable_role", run = _test_market_modal_renderer_refreshes_market_only_for_operable_role },
  { name = "_test_debug_ports_sync_restores_client_role_nil", run = _test_debug_ports_sync_restores_client_role_nil },
  { name = "_test_debug_ports_sync_ignores_non_event_log_seq_changes", run = _test_debug_ports_sync_ignores_non_event_log_seq_changes },
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
}
