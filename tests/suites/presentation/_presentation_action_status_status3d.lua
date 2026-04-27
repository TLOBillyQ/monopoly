local P = require("support.presentation_action_status_prelude")
local _assert_eq = P.assert_eq
local _bind_ui_runtime = P.bind_ui_runtime
local _with_patches = P.with_patches
local _wrap_ui_refs = P.wrap_ui_refs
local gameplay_loop = P.gameplay_loop
local runtime_port = require("src.ui.render.runtime_ui")
local ui_view = require("src.ui.ctl.ui_runtime")
local ui_status_3d_layer = require("src.ui.render.status3d")
local turn_effects = require("src.ui.wid.turn_effects")
local vec3 = require("fixtures.vec3")

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
  local helper = { target_role_id = nil }
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
    { target = game_api, key = "get_role", value = function() return {} end },
    { key = "Enums", value = {
      CameraBindMode = { TRACK = 0 },
      BuffState = { BUFF_FORBID_CONTROL = 32 },
    } },
    { key = "camera_helper", value = helper },
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
    state.gameplay_loop_ports = require("src.ui.ports").build(state)
    gameplay_loop.tick(game, state, 0.1)
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should follow current player")
end

local function _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local board_view_mod = require("src.ui.render.board")
  local status3d = require("src.ui.render.status3d")
  local helper = { target_role_id = nil }
  local follow_events = 0
  local game_api = GameAPI or {}
  local function wrapped_trigger()
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
    { target = game_api, key = "get_role", value = function() return {} end },
    { key = "Enums", value = {
      CameraBindMode = { TRACK = 0 },
      BuffState = { BUFF_FORBID_CONTROL = 32 },
    } },
    { key = "camera_helper", value = helper },
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
    local ok, err = pcall(function()
      state.gameplay_loop_ports = require("src.ui.ports").build(state)
      gameplay_loop.tick(game, state, 0.1)
    end)
    assert(ok == true, "turn switch should not fail when follow event is unavailable: " .. tostring(err))
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should still track current player on degraded follow event")
  _assert_eq(follow_events, 0, "degraded follow event path should avoid wrapped TriggerCustomEvent call")
end

local function _test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop()
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local ui_model_sync = require("src.ui.ports.ui_sync.model")
  local anchors = require("src.ui.render.board.anchors")
  local startup_render = require("src.ui.render.board.startup_render")
  local player_units = require("src.ui.render.board.player_units")
  local base_presenter = require("src.ui.wid.panel_presenter")
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
  local ui_model_sync = require("src.ui.ports.ui_sync.model")
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

return {
  name = "presentation_status3d_and_turn_effects",
  tests = {
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
    { name = "_test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop", run = _test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop },
    { name = "_test_ui_sync_refresh_from_dirty_only_turn_countdown_updates_label_without_full_render", run = _test_ui_sync_refresh_from_dirty_only_turn_countdown_updates_label_without_full_render },
    { name = "_test_ui_runtime_refresh_turn_label_toggles_countdown_nodes_and_label", run = _test_ui_runtime_refresh_turn_label_toggles_countdown_nodes_and_label },
  },
}
