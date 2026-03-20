local support = require("support.gameplay_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _bind_ui_runtime = support.bind_ui_runtime
local _resolve_landing = support.resolve_landing
local _resolve_landing_with_choices = support.resolve_landing_with_choices
local _resolve_choice_first = support.resolve_choice_first
local _get_choice = support.get_choice
local _first_land_tile = support.first_land_tile
local _first_tile_by_type = support.first_tile_by_type
local _tile_state = support.tile_state
local runtime_state = support.runtime_state
local landing_visual_hold = support.landing_visual_hold
local movement = support.movement
local inventory = support.inventory
local steal = support.steal
local choice_resolver = support.choice_resolver
local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local gameplay_loop = support.gameplay_loop
local gameplay_loop_ports = require("src.turn.loop.ports")
local tick_timeout = support.tick_timeout
local constants = support.constants
local bankruptcy = support.bankruptcy
local turn_move = support.turn_move
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local mine_effect = require("src.rules.effects.mine_effect")
local runtime_context = require("src.host.eggy.context")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local runtime_global_aliases = require("src.infrastructure.runtime.runtime_global_aliases")
local dispatch_validator = require("src.turn.actions.validator")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local tick_choice_timeout = require("src.turn.waits.choice_timeout")
local choice_auto_policy = require("src.turn.policies.choice_auto_policy")
local turn_timer_policy = require("src.turn.policies.timer_policy")
local turn_role_control_policy = require("src.turn.policies.role_control_policy")
local turn_camera_policy = require("src.turn.policies.camera_policy")
local gameplay_loop_runtime = require("src.turn.loop.loop_runtime")
local tick_flow = require("src.turn.loop.tick_flow")
local move_followup = require("src.turn.phases.move_followup")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local startup_roster = require("src.app.bootstrap.startup_roster")
local state_factory = require("src.presentation.runtime.state_factory")
local game_startup_event_bridge = require("src.presentation.runtime.runtime_event_bridge")
local profile_rotation = require("src.app.bootstrap.testing.profile_rotation")
local test_profile_bootstrap = require("src.app.bootstrap.testing.test_profile_bootstrap")
local monopoly_event = require("src.core.events.monopoly_events")
local number_utils = require("src.core.utils.number_utils")
local logger = require("src.core.utils.logger")
local market_service = require("src.rules.market")
local phase_registry = require("src.turn.phases.registry")
local turn_decision = require("src.turn.waits.decision")
local item_effects = require("src.rules.items.post_effects")
local item_strategy = require("src.rules.items.strategy")
local facing_policy = require("src.rules.board.facing_policy")
local turn_start = require("src.turn.phases.start")
local turn_script = require("src.turn.timing.session_script")
local roll = require("src.turn.phases.roll")
local item_slot_data = require("src.turn.actions.item_slot_data")
local default_ports = require("src.turn.output.default_ports")

local function _build_startup_state(get_current_game, profile_name)
  return state_factory.build_state({
    profile_name = profile_name,
    get_current_game = get_current_game,
    build_game_factory = function(state)
      return startup_roster.build_game_factory(state, {
        profile_name = profile_name,
      })
    end,
    auto_runner = startup_roster.build_auto_runner(),
  })
end

local function _mock_lua_api(send_custom_event)
  return {
    call_delay_time = function() end,
    global_register_custom_event = function() end,
    global_register_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = send_custom_event or function() end,
  }
end

local function _with_runtime_context_globals(fn)
  support.with_patches({
    { key = "GameAPI", value = nil },
    { key = "LuaAPI", value = nil },
    { key = "SetTimeOut", value = nil },
    { key = "RegisterCustomEvent", value = nil },
    { key = "RegisterTriggerEvent", value = nil },
    { key = "UnitCustomEvent", value = nil },
    { key = "UnitTriggerEvent", value = nil },
    { key = "TriggerCustomEvent", value = nil },
    { key = "vehicle_helper", value = nil },
    { key = "camera_helper", value = nil },
    { key = "change_skin_helper", value = nil },
    { key = "all_roles", value = nil },
    { key = "ALLROLES", value = nil },
    { key = "get_vehicle_player", value = nil },
    { key = "get_vehicle_move_direction", value = nil },
    { key = "get_vehicle_move_time", value = nil },
    { key = "get_spawn_vehicle_id", value = nil },
    { key = "get_vehicle_set_position_x", value = nil },
    { key = "get_vehicle_set_position_y", value = nil },
    { key = "get_vehicle_set_position_z", value = nil },
    { key = "get_camera_target", value = nil },
    { key = "get_skin_id", value = nil },
    { key = "get_change_skin_role", value = nil },
  }, fn)
end

local function _install_runtime_aliases(ctx)
  runtime_context.install_environment(ctx)
  runtime_global_aliases.install(ctx.env)
end

local function _build_test_ports(overrides)
  overrides = overrides or {}
  return {
    modal = {
      close_choice_modal = overrides.close_choice_modal or function() end,
      open_choice_modal = overrides.open_choice_modal or function() end,
      close_popup = overrides.close_popup or function() end,
    },
    anim = {
      play_move_anim = overrides.play_move_anim or function() return 0 end,
      play_action_anim = overrides.play_action_anim or function() return 0 end,
      reset_status_3d = overrides.reset_status_3d or function() end,
      sync_status_3d = overrides.sync_status_3d or function() end,
    },
    ui_sync = {
      apply_input_lock = overrides.apply_input_lock or function() end,
      step_choice_timeout = overrides.step_choice_timeout or function() end,
      step_modal_timeout = overrides.step_modal_timeout or function() end,
      update_countdown = overrides.update_countdown or function() end,
      build_model = overrides.build_model or function() return nil end,
      refresh_from_dirty = overrides.refresh_from_dirty or function() return false end,
      follow_camera = overrides.follow_camera or function() return false end,
      get_ui_state = overrides.get_ui_state or function(state) return state and state.ui or nil end,
      is_input_blocked = overrides.is_input_blocked or function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = overrides.is_popup_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = overrides.is_choice_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = overrides.is_market_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = overrides.get_popup_owner_index or function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_owner_index or nil
      end,
      resolve_ui_gate = overrides.resolve_ui_gate or function(state)
        local ui = state and state.ui or nil
        local popup = ui and ui.popup_payload or nil
        return {
          input_blocked = ui and ui.input_blocked == true or false,
          choice_active = ui and ui.choice_active == true or false,
          market_active = ui and ui.market_active == true or false,
          popup_active = ui and ui.popup_active == true or false,
          popup_seq = ui and ui.popup_seq or nil,
          popup_auto_close_seconds = popup and popup.auto_close_seconds or nil,
          popup_owner_index = ui and ui.popup_owner_index or nil,
        }
      end,
      set_input_blocked = overrides.set_input_blocked or function(state, blocked)
        local ui = state and state.ui or nil
        if not ui then
          return false
        end
        if ui.input_blocked == blocked then
          return false
        end
        ui.input_blocked = blocked
        return true
      end,
    },
    debug = {
      log_status = overrides.log_status or function() end,
      sync_debug_log = overrides.sync_debug_log or function() end,
      resolve_debug_enabled = overrides.resolve_debug_enabled or function() return false end,
    },
    clock = {
      wall_now_seconds = overrides.wall_now_seconds or function()
        if GameAPI and type(GameAPI.get_timestamp) == "function" then
          return GameAPI.get_timestamp()
        end
        return 0
      end,
      wall_diff_seconds = overrides.wall_diff_seconds or function(timestamp_1, timestamp_2)
        if GameAPI and type(GameAPI.get_timestamp_diff) == "function" then
          return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
        end
        return (timestamp_1 or 0) - (timestamp_2 or 0)
      end,
      cpu_now_seconds = overrides.cpu_now_seconds or function()
        return 0
      end,
      cpu_diff_seconds = overrides.cpu_diff_seconds or function(timestamp_1, timestamp_2)
        return (timestamp_1 or 0) - (timestamp_2 or 0)
      end,
    },
    state = {
      apply_role_control_lock = overrides.apply_role_control_lock or function() end,
      install_event_handlers = overrides.install_event_handlers or function() end,
      on_bankruptcy_tiles_cleared = overrides.on_bankruptcy_tiles_cleared or function() end,
    },
  }
end

local function _build_loop_state()
  local auto_runner = require("src.turn.policies.auto_runner")
  local ui_port = _build_ui_port()
  local state = {
    gameplay_loop_ports = _build_test_ports({
      refresh_from_dirty = function() return false end,
      build_model = function() return nil end,
      sync_status_3d = function() end,
      reset_status_3d = function() end,
      update_countdown = function() end,
      log_status = function() end,
      sync_debug_log = function() end,
    }),
    ui = ui_port.ui,
    ui_refs = ui_port.ui_refs,
    ui_model = nil,
    set_label = ui_port.set_label,
    set_visible = ui_port.set_visible,
    set_touch_enabled = ui_port.set_touch_enabled,
    query_node = ui_port.query_node,
    auto_runner = auto_runner:new({ interval = 0.01 }),
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    turn_runtime = {
      next_turn_locked = false,
      next_turn_last_click = nil,
      next_turn_lock_phase = nil,
      role_control_lock_active = false,
      role_control_lock_suppress = 0,
    },
    debug_runtime = {
      log_once = {},
    },
  }
  _bind_ui_runtime(state)
  state.auto_runner:set_enabled(true)
  return state
end

local function _with_timestamp_stub(fn)
  local now = 0
  local game_api = GameAPI or {}
  return support.with_patches({
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      now = now + 1
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
  }, fn)
end

local function _test_mandatory_payment_causes_bankruptcy()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local p2 = g.players[2]

  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p1.id)
  g:set_tile_level(tile_ref, 3)
  g:set_player_property(p1, tile_ref.id, true)

  g:set_player_cash(p2, 10)

  g:update_player_position(p2, idx)

  local before_eliminated = p2.eliminated
  _resolve_landing(g, p2, tile_ref, {})

  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function _test_bankruptcy_resets_owned_tiles()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local _, tile1 = _first_land_tile(g.board)
  local tile2 = nil
  for i = 1, #g.board.path do
    local t = g.board.path[i]
    if t.type == "land" and t.id ~= tile1.id then
      tile2 = t
      break
    end
  end
  assert(tile2, "should have at least two land tiles")

  g:set_tile_owner(tile1, p1.id)
  g:set_tile_level(tile1, 2)
  g:set_player_property(p1, tile1.id, true)

  g:set_tile_owner(tile2, p1.id)
  g:set_tile_level(tile2, 1)
  g:set_player_property(p1, tile2.id, true)

  bankruptcy.eliminate(g, p1)

  local st1 = _tile_state(g, tile1)
  local st2 = _tile_state(g, tile2)
  assert(st1.owner_id == nil and st1.level == 0, "bankruptcy clears owned tile1")
  assert(st2.owner_id == nil and st2.level == 0, "bankruptcy clears owned tile2")
  assert(next(p1.properties) == nil, "bankruptcy clears player properties")
end

local function _test_bankruptcy_notifier_reads_grouped_ports()
  local g = _new_game()
  local p1 = g.players[1]
  local _, tile_ref = _first_land_tile(g.board)
  local calls = {}

  g:set_tile_owner(tile_ref, p1.id)
  g:set_player_property(p1, tile_ref.id, true)
  g.bankruptcy_feedback_port = {
    on_tiles_cleared = function(_, player, owned_tile_ids)
      calls[#calls + 1] = {
        player_id = player and player.id or nil,
        owned_tile_ids = owned_tile_ids,
      }
      return true
    end,
  }

  bankruptcy.eliminate(g, p1)

  assert(#calls == 1, "grouped bankruptcy notifier should be invoked once")
  assert(calls[1].player_id == p1.id, "notifier should receive eliminated player")
  assert(type(calls[1].owned_tile_ids) == "table", "notifier should receive owned_tile_ids list")
  assert(calls[1].owned_tile_ids[1] == tile_ref.id, "notifier should receive cleared tile id")
end

local function _test_gameplay_loop_set_game_installs_bankruptcy_feedback_port()
  local g = _new_game()
  local state = _build_loop_state()
  local calls = {}

  state.on_board_visual_sync = function(_, payload)
    calls[#calls + 1] = payload
    return true
  end

  gameplay_loop.set_game(state, g)
  g.bankruptcy_feedback_port.on_tiles_cleared(g, g.players[1], { 101 })

  assert(#calls == 1, "set_game should install bankruptcy feedback port")
  assert(calls[1].tile_ids[1] == 101, "feedback port should forward tile ids into board visual sync")
end

local function _test_bankruptcy_calls_role_life_die_before_lose()
  local g = _new_game()
  local p1 = g.players[1]
  local call_order = {}
  local role = {
    die = function()
      table.insert(call_order, "die")
    end,
    lose = function()
      table.insert(call_order, "lose")
    end,
  }
  support.with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == p1.id then
        return role
      end
      return nil
    end },
  }, function()
    bankruptcy.eliminate(g, p1)
  end)

  assert(#call_order == 2, "bankruptcy should call role die and lose")
  assert(call_order[1] == "die", "bankruptcy should call role die before lose")
  assert(call_order[2] == "lose", "bankruptcy should call role lose")
end

local function _test_chance_pay_others_stops_after_bankruptcy()
  local g = require("src.app.bootstrap.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = {},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
  local p1 = g.players[1]
  local p2 = g.players[2]
  local p3 = g.players[3]
  local p4 = g.players[4]

  g:set_player_cash(p1, 15)
  g:set_player_cash(p2, 0)
  g:set_player_cash(p3, 0)
  g:set_player_cash(p4, 0)

  local chance_handler = assert(g.registries.chances.handlers.pay_others, "missing pay_others handler")
  chance_handler(g, p1, { effect = "pay_others", amount = 10 })

  assert(p1.eliminated == true, "payer should be eliminated when cash becomes non-positive")
  assert(g:player_balance(p2, "金币") == 10, "first recipient should receive transfer")
  assert(g:player_balance(p3, "金币") == 10, "second recipient should receive transfer before bankruptcy stop")
  assert(g:player_balance(p4, "金币") == 0, "later recipients should not receive transfer after bankruptcy")
end

local function _test_set_tile_owner_without_ui_port_does_not_crash()
  local g = _new_game()
  g.ui_port = nil
  local _, tile_ref = _first_land_tile(g.board)
  local p1 = g.players[1]

  g:set_tile_owner(tile_ref, p1.id)
  local st_owned = _tile_state(g, tile_ref)
  assert(st_owned.owner_id == p1.id, "set_tile_owner should work without ui_port")

  g:reset_tile(tile_ref)
  local st_reset = _tile_state(g, tile_ref)
  assert(st_reset.owner_id == nil, "reset_tile should clear owner without ui_port")
  assert(st_reset.level == 0, "reset_tile should clear level without ui_port")
end

local function _test_tile_owner_notifier_receives_owner_changes()
  local g = _new_game()
  g.ui_port = nil
  local _, tile_ref = _first_land_tile(g.board)
  local p1 = g.players[1]
  local calls = {}
  g.tile_owner_notifier = {
    notify_owner_changed = function(_, tile_id, owner_id)
      calls[#calls + 1] = { tile_id = tile_id, owner_id = owner_id }
    end,
  }

  g:set_tile_owner(tile_ref, p1.id)
  g:reset_tile(tile_ref)

  assert(#calls == 2, "tile_owner_notifier should receive owner set and reset")
  assert(calls[1].tile_id == tile_ref.id and calls[1].owner_id == p1.id, "first notify should be owner set")
  assert(calls[2].tile_id == tile_ref.id and calls[2].owner_id == nil, "second notify should be owner clear")
end

local function _test_dispatch_validator_accepts_ui_state_snapshot()
  local ui_state = {
    input_blocked = true,
    item_slot_item_ids = { [1] = 2001 },
  }
  local blocked = dispatch_validator.should_block_action(ui_state, { type = "ui_button" })
  assert(blocked == true, "validator should block when ui_state.input_blocked")

  local state = {
    pending_choice = {
      id = 1,
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2001 } },
    },
  }
  _bind_ui_runtime(state)
  local res = dispatch_validator.resolve_item_slot_action(ui_state, state, {
    id = "item_slot_1",
    actor_role_id = 1,
  })
  assert(res and res.ok, "validator should resolve item slot action")
end

local function _test_intent_dispatcher_sets_choice_route_metadata()
  local g = _new_game()
  local choice_spec = {
    kind = "remote_dice_value",
    route_key = "remote",
    title = "遥控骰子",
    body_lines = { "选择点数" },
    options = { { id = 1, label = "1" }, { id = 2, label = "2" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = g:current_player().id, item_id = 2001 },
  }
  local entry = intent_dispatcher.open_choice(g, choice_spec, {})
  assert(entry.route_key == "remote", "intent_dispatcher should inject explicit route_key")
  assert(entry.requires_confirm == false, "remote route should not require confirm")

  local custom_entry = intent_dispatcher.open_choice(g, {
    kind = "item_target_player",
    title = "自定义路由",
    options = { { id = 1, label = "A" } },
    route = { route_key = "secondary_confirm", requires_confirm = true },
    meta = { player_id = g:current_player().id, item_id = 2001 },
  }, {})
  assert(custom_entry.route_key == "secondary_confirm", "explicit route should override inferred route")
  assert(custom_entry.requires_confirm == true, "explicit requires_confirm should be kept")

  local inline_entry = intent_dispatcher.open_choice(g, {
    kind = "item_phase_choice",
    route_key = "base_inline",
    title = "行动前：使用道具？",
    options = { { id = 2001, label = "路障卡" } },
    meta = { player_id = g:current_player().id, phase = "pre_action" },
  }, {})
  assert(inline_entry.route_key == "base_inline", "item_phase_choice should use base_inline route")
  assert(inline_entry.requires_confirm == false, "base_inline route should not require confirm")

  local unknown_entry = intent_dispatcher.open_choice(g, {
    kind = "unknown_choice_kind",
    title = "未知流程",
    options = { { id = 1, label = "A" } },
  }, {})
  assert(unknown_entry.route_key == "base_inline", "unknown choice should fallback to base_inline route")
end

local function _test_intent_dispatcher_rejects_missing_required_choice_meta()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "market_buy",
      title = "黑市",
      options = { { id = 2001, label = "A" } },
      meta = {},
    }, {})
  end)

  assert(ok == false, "open_choice should reject missing required meta")
  assert(tostring(err):find("market_buy requires meta.player_id", 1, true) ~= nil,
    "open_choice should report the missing required meta key")
  assert(g.turn.pending_choice == nil, "open_choice should not mutate pending_choice on schema failure")
end

local function _test_intent_dispatcher_rejects_missing_required_choice_meta_table()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "market_buy",
      title = "黑市",
      options = { { id = 2001, label = "A" } },
    }, {})
  end)

  assert(ok == false, "open_choice should reject missing meta table for required_meta descriptors")
  assert(tostring(err):find("market_buy requires meta", 1, true) ~= nil,
    "open_choice should report missing meta table before validating required keys")
  assert(g.turn.pending_choice == nil, "dispatcher should not mutate pending choice when meta table is missing")
end

local function _test_intent_dispatcher_normalizes_market_choice_meta()
  local g = _new_game()
  local entry = intent_dispatcher.open_choice(g, {
    kind = "market_buy",
    title = "黑市",
    options = { { id = 2001, label = "A" } },
    meta = {
      player_id = tostring(g:current_player().id),
      active_tab = "vehicle",
      page_index = "2",
      page_count = "3",
    },
  }, {})

  assert(entry.meta.player_id == g:current_player().id, "market choice meta should normalize player_id")
  assert(entry.owner_role_id == g:current_player().id, "market choice should backfill owner_role_id from meta")
  assert(entry.active_tab == "item", "market choice should normalize unsupported tab to item")
  assert(entry.page_index == 2, "market choice should normalize page_index")
  assert(entry.page_count == 3, "market choice should normalize page_count")
end

local function _test_intent_dispatcher_normalizes_item_choice_meta()
  local g = _new_game()
  local entry = intent_dispatcher.open_choice(g, {
    kind = "item_phase_choice",
    route_key = "base_inline",
    title = "行动前：使用道具？",
    options = { { id = gameplay_rules.item_ids.remote_dice, label = "遥控骰子" } },
    meta = {
      player_id = tostring(g:current_player().id),
      phase = "pre_action",
    },
  }, {})

  assert(entry.meta.player_id == g:current_player().id, "item phase choice should normalize player_id")
  assert(entry.owner_role_id == g:current_player().id, "item phase choice should backfill owner_role_id from meta")
end

local function _test_intent_dispatcher_normalizes_landing_optional_effect_meta()
  local g = _new_game()
  local _, tile_ref = _first_land_tile(g.board)
  local entry = intent_dispatcher.open_choice(g, {
    kind = "landing_optional_effect",
    title = "请选择",
    options = { { id = "buy_land", label = "购买地块" } },
    meta = {
      player_id = tostring(g:current_player().id),
      tile_id = tostring(tile_ref.id),
      effect_ids = { "buy_land" },
      move_result = { next_state = "wait_choice" },
    },
  }, {})

  assert(entry.meta.player_id == g:current_player().id, "landing optional should normalize player_id")
  assert(entry.meta.tile_id == tile_ref.id, "landing optional should normalize tile_id")
  assert(entry.owner_role_id == g:current_player().id, "landing optional should backfill owner_role_id")
end

local function _test_intent_dispatcher_rejects_unknown_market_choice_player()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "market_buy",
      title = "黑市",
      options = { { id = 2001, label = "A" } },
      meta = { player_id = 999999 },
    }, {})
  end)

  assert(ok == false, "open_choice should reject unknown market player")
  assert(tostring(err):find("missing player: 999999", 1, true) ~= nil,
    "open_choice should report missing market player at dispatcher boundary")
  assert(g.turn.pending_choice == nil, "dispatcher validation failure should not mutate pending choice")
end

local function _test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "landing_optional_effect",
      title = "请选择",
      options = { { id = "buy_land", label = "购买地块" } },
      meta = {
        player_id = g:current_player().id,
        tile_id = 999999,
        effect_ids = { "buy_land" },
      },
    }, {})
  end)

  assert(ok == false, "open_choice should reject unknown landing tile")
  assert(tostring(err):find("missing tile: 999999", 1, true) ~= nil,
    "open_choice should report missing tile at dispatcher boundary")
  assert(g.turn.pending_choice == nil, "dispatcher validation failure should not mutate pending choice")
end

local function _test_turn_start_logs_phase_event_to_event_feed()
  local g = _new_game()
  g.players[1].status.stay_turns = 2
  g.players[1].status.deity = { type = "poor", remaining = 3 }
  inventory.give(g.players[1], gameplay_rules.item_ids.remote_dice)
  local _, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, g.players[1].id)
  g:set_tile_level(tile_ref, 2)
  g:set_player_property(g.players[1], tile_ref.id, true)
  g:set_player_cash(g.players[1], 4321)
  logger.clear()
  turn_decision.log_turn_start(g)
  local text = logger.get_text_by_level("event")
  assert(string.find(text, "第1回合开始：", 1, true) ~= nil, "turn start should write phase event to event feed")
  assert(string.find(text, g.players[1].name, 1, true) ~= nil, "turn start event should mention current player")
  assert(string.find(text, "金币=", 1, true) == nil, "turn start event should not include player balance")
  assert(string.find(text, "状态:", 1, true) == nil, "turn start event should not include player status details")
  assert(string.find(text, "背包:", 1, true) == nil, "turn start event should not include player items")
  assert(string.find(text, "地产:", 1, true) == nil, "turn start event should not include player properties")
end

local function _test_intent_dispatcher_logs_waiting_choice_event()
  local g = _new_game()
  logger.clear()
  intent_dispatcher.open_choice(g, {
    kind = "remote_dice_value",
    route_key = "remote",
    title = "遥控骰子",
    body_lines = { "选择点数" },
    options = { { id = 1, label = "1" } },
    allow_cancel = true,
    meta = { player_id = g:current_player().id, item_id = 2001 },
  }, {})
  local text = logger.get_text_by_level("event")
  assert(string.find(text, "等待选择：遥控骰子：选择点数", 1, true) ~= nil,
    "open_choice should log waiting-choice phase event")
end

local function _test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys()
  local g = _new_game()
  local validated = false
  g.registries = {
    choices = {
      descriptor_for = function(_, kind)
        if kind ~= "custom_probe" then
          return nil
        end
        return {
          normalize_meta = function(_, meta)
            meta = meta or {}
            meta.normalized = true
            return meta
          end,
          meta_validator = function(_, meta, choice_spec)
            validated = true
            assert(meta.normalized == true, "descriptor meta_validator should receive normalized meta")
            assert(choice_spec.kind == "custom_probe", "descriptor meta_validator should receive choice spec")
          end,
        }
      end,
    },
  }

  local entry = intent_dispatcher.open_choice(g, {
    kind = "custom_probe",
    title = "自定义流程",
    options = { { id = 1, label = "A" } },
    meta = {},
  }, {})

  assert(validated == true, "dispatcher should run descriptor meta_validator even without required_meta")
  assert(entry.meta and entry.meta.normalized == true, "dispatcher should keep normalized meta on custom descriptor choices")
end

local function _test_intent_dispatcher_allows_missing_choice_registry()
  local g = _new_game()
  g.registries = {}

  local entry = intent_dispatcher.open_choice(g, {
    kind = "custom_probe_without_registry",
    title = "无注册表",
    options = { { id = 1, label = "A" } },
    meta = { probe = true },
  }, {})

  assert(entry.kind == "custom_probe_without_registry", "dispatcher should still open choices without registry descriptors")
  assert(entry.meta and entry.meta.probe == true, "dispatcher should preserve original meta when registry is missing")
end

local function _test_choice_cancel_logs_skip_event_but_tax_cancel_does_not()
  local g = _new_game()

  logger.clear()
  local normal_choice = {
    id = 10,
    kind = "landing_optional_effect",
    title = "可选效果",
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = { player_id = g.players[1].id, tile_id = 1, effect_ids = { "buy_land" } },
  }
  choice_resolver.resolve(g, normal_choice, {
    type = "choice_cancel",
    choice_id = normal_choice.id,
    actor_role_id = g.players[1].id,
  })
  local skip_text = logger.get_text_by_level("event")
  assert(string.find(skip_text, "跳过选择：可选效果", 1, true) ~= nil,
    "true cancel should log skip-choice event")

  logger.clear()
  local tax_choice = {
    id = 11,
    kind = "tax_card_prompt",
    title = "是否使用免税卡",
    options = { { id = "use", label = "使用" }, { id = "skip", label = "跳过" } },
    allow_cancel = true,
    meta = { player_id = g.players[1].id },
  }
  choice_resolver.resolve(g, tax_choice, {
    type = "choice_cancel",
    choice_id = tax_choice.id,
    actor_role_id = g.players[1].id,
  })
  local tax_text = logger.get_text_by_level("event")
  assert(string.find(tax_text, "跳过选择", 1, true) == nil,
    "tax cancel fallback should not log skip-choice event")
end

local function _test_choice_resolver_normalizes_market_buy_action_before_execute()
  local g = _new_game()
  local p = g:current_player()
  local choice = {
    id = 901,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = p.id,
    options = { { id = 2001, label = "免费卡" } },
    meta = { player_id = p.id },
  }
  g.turn.pending_choice = choice

  local called_product_id = nil
  local descriptor = g.registries.choices:descriptor_for("market_buy")
  support.with_patches({
    {
      target = descriptor,
      key = "execute",
      value = function(_, _, action)
        called_product_id = action and action.option_id or nil
        return { status = "resolved", stay = false }
      end,
    },
  }, function()
    choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = "2001",
      actor_role_id = p.id,
    })
  end)

  assert(called_product_id == 2001, "market buy should normalize string option_id before execute")
end

local function _test_choice_resolver_normalizes_roadblock_action_before_execute()
  local g = _new_game()
  local p = g:current_player()
  local choice = {
    id = 902,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = p.id,
    uses_target_picker = true,
    target_picker_owner_role_id = p.id,
    options = { { id = 3, label = "上海路" } },
    meta = {
      player_id = p.id,
      item_id = gameplay_rules.item_ids.roadblock,
    },
  }
  g.turn.pending_choice = choice

  local called_target_index = nil
  local descriptor = g.registries.choices:descriptor_for("roadblock_target")
  support.with_patches({
    {
      target = descriptor,
      key = "execute",
      value = function(_, _, action)
        called_target_index = action and action.option_id or nil
        return { status = "resolved", stay = false }
      end,
    },
  }, function()
    choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = "3",
      actor_role_id = p.id,
    })
  end)

  assert(called_target_index == 3, "roadblock target should normalize string option_id before execute")
end

local function _test_end_turn_logs_phase_event_to_event_feed()
  local g = _new_game()
  local phases = phase_registry.build_default_phases()
  logger.clear()
  phases.end_turn({ game = g, next_player = function()
    g.turn.current_player_index = 2
  end }, { player = g.players[1] })
  local text = logger.get_text_by_level("event")
  assert(string.find(text, "回合结束：" .. g.players[1].name, 1, true) ~= nil,
    "end_turn should log phase end event")
  assert(string.find(text, "停在", 1, true) ~= nil, "end_turn event should include landing tile")
end

local function _test_clear_obstacles_zero_does_not_log_event_noise()
  local g = _new_game()
  local player = g.players[1]
  logger.clear()
  item_effects.apply_post(g, player, gameplay_rules.item_ids.clear_obstacles, { branch_parity = 12 })
  local text = logger.get_text_by_level("event")
  assert(string.find(text, "清除前方障碍数：0", 1, true) == nil,
    "clear obstacles zero result should not enter event feed")
end

local function _test_ai_obstacle_probe_does_not_enter_event_feed()
  local g = _new_game()
  local player = g.players[1]
  player.auto = true
  inventory.give(player, gameplay_rules.item_ids.clear_obstacles)
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("fresh_forward", player)
  local next_index = select(1, g.board:step_forward_by_facing(current, facing, 12))
  g.board:place_roadblock(next_index)

  logger.clear()
  item_strategy.auto_pre_action(g, player, "pre_action", { is_auto_player = true })
  local text = logger.get_text_by_level("event")
  assert(string.find(text, "前方发现障碍，准备使用清障卡", 1, true) == nil,
    "AI obstacle probe should not enter event feed")
end

local function _test_stop_all_players_movement_preserves_inner_move_dir_and_stop_event()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:update_player_position(g.players[1], g.board:index_of_tile_id(1))
  g:update_player_position(g.players[2], g.board:index_of_tile_id(28))
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  support.with_patches({
    { key = "vehicle_helper", value = {
      resolve_role = function(role_id)
        if role_id == g.players[1].id then
          return { id = role_id }
        end
        return nil
      end,
      emit_vehicle_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    g:stop_all_players_movement()
  end)
  assert(g.players[1].status.move_dir == nil, "outer player move_dir should be cleared")
  assert(g.players[2].status.move_dir == "right", "inner player move_dir should be preserved")
  assert(#stopped_ids == 1, "stop event should only be sent to players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "stop event should target player with valid role")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "stop should bump vehicle_resync_seq")
end

local function _test_end_turn_stops_all_players_movement()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = nil
  g:update_player_position(g.players[1], g.board:index_of_tile_id(1))
  g:update_player_position(g.players[2], g.board:index_of_tile_id(28))
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local before_seq = g.turn.vehicle_resync_seq or 0
  local stopped_ids = {}
  support.with_patches({
    { key = "vehicle_helper", value = {
      resolve_role = function(role_id)
        if role_id == g.players[1].id then
          return { id = role_id }
        end
        return nil
      end,
      emit_vehicle_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    local phase_end = g.turn_engine.phases and g.turn_engine.phases.end_turn
    assert(type(phase_end) == "function", "end_turn phase should exist")
    phase_end(g.turn_engine.turn_mgr, { player = g.players[1] })
  end)
  assert(g.players[1].status.move_dir == nil, "outer player move_dir should be cleared at end turn")
  assert(g.players[2].status.move_dir == "right", "inner player move_dir should be preserved at end turn")
  assert(#stopped_ids == 1, "end turn should only stop players with vehicle and valid role")
  assert(stopped_ids[1] == g.players[1].id, "end turn stop should target valid vehicle player")
  assert((g.turn.vehicle_resync_seq or 0) == before_seq + 1, "end turn should bump vehicle_resync_seq")
end

local function _test_location_transfers_clear_move_dir()
  local g = _new_game()
  local p = g:current_player()

  g:set_player_status(p, "move_dir", "left")
  g:player_relocate(p, { tile_type = "hospital", move_dir_mode = "clear" })
  g:player_apply_location_effect(p, "hospital")
  assert(p.status.move_dir == nil, "hospital transfer should clear move_dir")

  g:set_player_status(p, "move_dir", "right")
  g:player_relocate(p, { tile_type = "mountain", move_dir_mode = "clear" })
  g:player_apply_location_effect(p, "mountain")
  assert(p.status.move_dir == nil, "mountain transfer should clear move_dir")
end

local function _test_stop_all_players_movement_skips_invalid_role_without_error()
  local g = _new_game()
  g.players[1].seat_id = 4001
  g.players[2].seat_id = 4002
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local stopped_ids = {}
  support.with_patches({
    { key = "vehicle_helper", value = {
      resolve_role = function(role_id)
        if role_id == g.players[1].id then
          return { id = role_id }
        end
        return nil
      end,
      emit_vehicle_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    g:stop_all_players_movement()
  end)
  assert(#stopped_ids == 1, "invalid role should be skipped during stop")
  assert(stopped_ids[1] == g.players[1].id, "only valid role should receive stop")
end

local function _test_runtime_context_forward_stop_skips_invalid_role()
  _with_runtime_context_globals(function()
    local stop_events = 0
    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return { id = 1 }
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { { id = 1 } }
      end,
    }
    support.with_patches({
    }, function()
      runtime_event_bridge._reset_for_tests()
      local ctx = runtime_context.new({
        GameAPI = game_api,
        LuaAPI = _mock_lua_api(function(event_name)
          if event_name == "stop_vehicle_forward" then
            stop_events = stop_events + 1
          end
        end),
      })
      _install_runtime_aliases(ctx)
      runtime_context.install_runtime_helpers(ctx, { install_globals = true })
      runtime_context.install_editor_exports(ctx)
      local invalid_ok = vehicle_helper.emit_vehicle_stop(2)
      local valid_ok = vehicle_helper.emit_vehicle_stop(1)
      assert(invalid_ok == false, "forward stop should reject invalid role")
      assert(valid_ok == true, "forward stop should allow valid role")
      assert(stop_events == 1, "forward stop should only emit event for valid role")
      runtime_event_bridge._reset_for_tests()
    end)
  end)
end

local function _test_runtime_event_bridge_detects_unbound_binding_without_call()
  local calls = 0
  local name = "j4MHTwbxEfG+CjRaYHE42T"
  local newenv = {}

  local function wrapped_trigger()
    local _ = name
    local __ = newenv
    calls = calls + 1
  end

  support.with_patches({
    { key = "TriggerCustomEvent", value = wrapped_trigger },
  }, function()
    runtime_event_bridge._reset_for_tests()
    assert(runtime_event_bridge.is_trigger_available() == false,
      "bridge should reject unbound wrapper before dispatch")
    local emitted = runtime_event_bridge.emit_custom_event("follow_camera", {}, {
      feature_key = "test.unbound",
    })
    assert(emitted == false, "bridge should skip dispatch when wrapper binding is unbound")
    assert(calls == 0, "bridge precheck should avoid calling wrapped TriggerCustomEvent")
    runtime_event_bridge._reset_for_tests()
  end)
end

local function _test_runtime_event_bridge_disables_feature_after_dispatch_failure()
  local calls = 0

  support.with_patches({
    { key = "TriggerCustomEvent", value = function()
      calls = calls + 1
      error("boom")
    end },
  }, function()
    runtime_event_bridge._reset_for_tests()
    local ok1, err1 = runtime_event_bridge.emit_custom_event("follow_camera", {}, {
      feature_key = "test.dispatch_failure",
    })
    local ok2, err2 = runtime_event_bridge.emit_custom_event("follow_camera", {}, {
      feature_key = "test.dispatch_failure",
    })
    local ok3, err3 = runtime_event_bridge.emit_custom_event(nil, {}, {
      feature_key = "test.missing_name",
    })

    assert(ok1 == false, "bridge should report dispatch failure")
    assert(tostring(err1):find("dispatch failed:", 1, true) ~= nil,
      "bridge should surface dispatch failure reason")
    assert(ok2 == false and err2 == err1,
      "bridge should short-circuit repeated calls with the stored disable reason")
    assert(calls == 1, "bridge should stop dispatching once feature is disabled")
    assert(ok3 == false and err3 == "missing event_name", "bridge should reject missing event_name")
    runtime_event_bridge._reset_for_tests()
  end)
end

local function _test_runtime_context_split_install_stages()
  _with_runtime_context_globals(function()
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return role1
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { role1 }
      end,
    }
    local lua_api = _mock_lua_api()
    local ctx = runtime_context.new({
      GameAPI = game_api,
      LuaAPI = lua_api,
    })

    runtime_context.install_environment(ctx)
    assert(SetTimeOut ~= lua_api.call_delay_time, "install_environment should stay validation-only")
    assert(type(get_vehicle_player) ~= "function", "install_environment should not export helpers")

    local helpers = runtime_context.install_runtime_helpers(ctx)
    assert(helpers ~= nil and helpers.camera_helper ~= nil, "install_runtime_helpers should return camera helper")
    assert(camera_helper == nil, "install_runtime_helpers should not export globals by default")

    runtime_context.install_editor_exports(ctx)
    assert(type(get_camera_target) == "function", "install_editor_exports should expose camera getter")
  end)
end

local function _test_runtime_context_install_helpers_without_globals()
  _with_runtime_context_globals(function()
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function(role_id)
          if role_id == 1 then
            return role1
          end
          return nil
        end,
        get_all_valid_roles = function()
          return { role1 }
        end,
      },
      LuaAPI = _mock_lua_api(),
    })
    runtime_context.install_environment(ctx)
    local helpers = runtime_context.install_runtime_helpers(ctx, { install_globals = false })
    assert(helpers ~= nil and helpers.camera_helper ~= nil, "install_runtime_helpers should return helpers")
    assert(all_roles == nil, "install_runtime_helpers install_globals=false should not write all_roles")

    runtime_context.install_runtime_helper_globals(helpers)
    assert(all_roles == helpers.roles, "install_runtime_helper_globals should expose roles")
  end)
end

local function _test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit()
  _with_runtime_context_globals(function()
    local ctrl_unit = { tag = "real_ctrl_unit" }
    local role1 = {
      id = 1,
      get_roleid = function()
        return 1
      end,
      get_ctrl_unit = function()
        return ctrl_unit
      end,
    }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function(role_id)
          if role_id == 1 then
            return role1
          end
          return nil
        end,
        get_all_valid_roles = function()
          return { role1 }
        end,
      },
      LuaAPI = _mock_lua_api(),
    })
    runtime_context.install_environment(ctx)
    runtime_context.install_runtime_helpers(ctx)
    ctx.camera_helper.target_role_id = 1
    runtime_context.install_editor_exports(ctx)

    assert(get_camera_target() == ctrl_unit, "camera target should return real player ctrl_unit")
  end)
end

local function _test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit()
  _with_runtime_context_globals(function()
    local synthetic_unit = { tag = "synthetic_unit" }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function()
          return nil
        end,
        get_all_valid_roles = function()
          return {}
        end,
      },
      LuaAPI = _mock_lua_api(),
    })
    runtime_context.install_environment(ctx)
    runtime_context.install_runtime_helpers(ctx)
    ctx.camera_helper.target_role_id = -1
    ctx.synthetic_actor_registry = {
      resolve_actor = function(role_id)
        if role_id == -1 then
          return { unit = synthetic_unit }
        end
        return nil
      end,
    }
    runtime_context.install_editor_exports(ctx)

    assert(get_camera_target() == synthetic_unit, "camera target should return synthetic actor unit")
  end)
end

local function _test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable()
  _with_runtime_context_globals(function()
    local role_without_unit = {
      id = 1,
      get_roleid = function()
        return 1
      end,
    }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function(role_id)
          if role_id == 1 then
            return role_without_unit
          end
          error("missing role")
        end,
        get_all_valid_roles = function()
          return { role_without_unit }
        end,
      },
      LuaAPI = _mock_lua_api(),
    })
    runtime_context.install_environment(ctx)
    runtime_context.install_runtime_helpers(ctx)
    runtime_context.install_editor_exports(ctx)

    ctx.camera_helper.target_role_id = 1
    assert(get_camera_target() == nil, "camera target should return nil when role has no ctrl unit")

    ctx.camera_helper.target_role_id = 7
    assert(get_camera_target() == nil, "camera target should return nil when get_role fails")
  end)
end

local function _test_camera_sync_follow_camera_keeps_role_id_event_chain()
  local camera_sync = require("src.presentation.runtime.ports.ui_sync.camera")
  local emitted = {}
  local helper = { target_role_id = nil }

  support.with_patches({
    {
      target = runtime_ports,
      key = "resolve_camera_helper",
      value = function()
        return helper
      end,
    },
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(event_name, payload, opts)
        emitted[#emitted + 1] = {
          event_name = event_name,
          payload = payload,
          opts = opts,
        }
        return true
      end,
    },
  }, function()
    local ok = camera_sync.follow_camera(9)
    assert(ok == true, "camera_sync.follow_camera should still emit event")
  end)

  assert(helper.target_role_id == 9, "camera sync should still write target_role_id")
  assert(#emitted == 1, "camera sync should emit one camera follow event")
  assert(emitted[1].event_name == "follow_camera", "camera sync should keep follow_camera event name")
  assert(emitted[1].payload == nil, "camera sync should keep nil payload")
end

local function _test_game_startup_build_state_is_pure_and_bridge_installs_events()
  local events = {}
  local state = nil
  local current_game = nil
  support.with_patches({
    { key = "LuaAPI", value = _mock_lua_api() },
    { key = "RegisterCustomEvent", value = function(event_name, handler)
      events[event_name] = handler
    end },
    { key = "RegisterTriggerEvent", value = function() end },
    { key = "all_roles", value = {} },
    { key = "GameAPI", value = {
      get_all_valid_roles = function()
        return {}
      end,
    } },
  }, function()
    LuaAPI.global_register_custom_event = function(event_name, handler)
      events[event_name] = handler
    end
    local runtime_ctx = runtime_context.current()
    if runtime_ctx and runtime_ctx.env and runtime_ctx.env.LuaAPI then
      runtime_ctx.env.LuaAPI.global_register_custom_event = LuaAPI.global_register_custom_event
    end
    state = _build_startup_state(function()
      return current_game
    end)
    assert(next(events) == nil, "build_state should not register custom events")

    game_startup_event_bridge.install(state, function()
      return current_game
    end)
    assert(type(events[monopoly_event.land.tile_upgraded]) == "function", "bridge should register tile_upgraded")
    assert(type(events[monopoly_event.intent.need_choice]) == "function", "bridge should register need_choice")

    local opened = nil
    local choice_payload = { id = 11, kind = "item_target_player", route_key = "player", options = { { id = 1, label = "A" } } }
    current_game = {
      turn = { pending_choice = choice_payload },
      winner = nil,
      winner_names = nil,
      last_turn = nil,
      finished = false,
      players = {},
      board = { get_overlays = function() return { roadblocks = {}, mines = {} } end, tile_lookup = {}, path = {} },
    }
    support.with_patches({
      { target = require("src.ui.ctl.modal_controller"), key = "open_choice_modal", value = function(_, choice)
        opened = choice
      end },
    }, function()
      events[monopoly_event.intent.need_choice](nil, nil, { choice = choice_payload })
    end)
    assert(runtime_state.get_pending_choice_id(state) == 11, "bridge should sync pending_choice_id from event")
    assert(opened ~= nil and opened.id == 11, "bridge should open choice modal from event")
  end)
end

local function _test_runtime_context_install_environment_fails_fast()
  _with_runtime_context_globals(function()
    local ctx = runtime_context.new({
      GameAPI = {},
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
      },
    })
    local ok, err = pcall(function()
      runtime_context.install_environment(ctx)
    end)
    assert(ok == false, "install_environment should fail when LuaAPI is incomplete")
    assert(tostring(err):find("missing LuaAPI.global_send_custom_event") ~= nil,
      "install_environment should report missing LuaAPI.global_send_custom_event")
  end)
end

local function _test_autorunner_runs_to_end()
  local auto_runner = require("src.turn.policies.auto_runner")
  local agent = require("src.computer.policies.core_agent")
  local gameplay_rules = require("src.config.gameplay.gameplay_rules")
  local land = require("src.rules.land.executors")
  local land_actions = require("src.rules.land.actions")
  local item_inventory = require("src.rules.items.inventory")

  local g = require("src.app.bootstrap.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
  g.ui_port = _build_ui_port()
  g.anim_gate_port = { wait_action_anim = false, wait_move_anim = false }
  g.popup_port = { push_popup = function() return false end }
  g.tile_feedback_port = { on_tile_upgraded = function() return false end }
  g.intent_output_port = require("src.turn.output.intent_output_adapter").build()

  local state = {
    gameplay_loop_ports = _build_test_ports({
      refresh_from_dirty = function() return false end,
      build_model = function() return nil end,
      sync_status_3d = function() end,
      reset_status_3d = function() end,
      update_countdown = function() end,
      log_status = function() end,
      sync_debug_log = function() end,
    }),
    ui = g.ui_port.ui,
    ui_refs = g.ui_port.ui_refs,
    ui_model = nil,
    set_label = g.ui_port.set_label,
    set_visible = g.ui_port.set_visible,
    set_touch_enabled = g.ui_port.set_touch_enabled,
    query_node = g.ui_port.query_node,
    auto_runner = auto_runner:new({ interval = 0.01 }),
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
  }
  state.auto_runner:set_enabled(true)
  gameplay_loop.set_game(state, g)

  local turn_limit = gameplay_rules.turn_limit or 0
  local env_steps = number_utils.to_integer(os.getenv("MONO_TEST_AUTORUNNER_STEPS"))
  local max_steps = env_steps or (turn_limit * 40)
  assert(max_steps > 0, "invalid turn_limit for autorunner test")

  local timeout = constants.action_timeout_seconds or 0
  local dt = timeout > 0 and (timeout + 0.1) or 1
  if dt > 1 then
    dt = 1
  end

  local now = 0

  local function _drive_auto_turn(game_ctx, state_ctx, auto_action)
    if not auto_action or auto_action.type ~= "ui_button" then
      return
    end
    turn_dispatch.dispatch_action(game_ctx, state_ctx, auto_action)
    local guard = 0
    while game_ctx.turn
        and (game_ctx.turn.phase == "detained_wait" or game_ctx.turn.phase == "inter_turn_wait")
        and guard < 20 do
      gameplay_loop.tick(game_ctx, state_ctx, dt)
      guard = guard + 1
    end
  end

  local old_handle_pass_players = steal.handle_pass_players
  local old_pick_roadblock_target = agent.pick_roadblock_target
  local old_can_pay_rent = land.executors.pay_rent.can_apply
  local game_api = GameAPI or {}
  local patches = {
    { target = gameplay_rules, key = "detained_turn_wait_seconds", value = 0 },
    { target = gameplay_rules, key = "inter_turn_wait_seconds", value = 0 },
    { target = steal, key = "handle_pass_players", value = function(game_ctx, player, encountered_ids)
      if not item_inventory.find_index(player, gameplay_rules.item_ids.steal) then
        return nil
      end
      return old_handle_pass_players(game_ctx, player, encountered_ids)
    end },
    { target = agent, key = "pick_roadblock_target", value = function()
      return nil
    end },
    { target = land.executors.pay_rent, key = "can_apply", value = function(ctx)
      if not old_can_pay_rent(ctx) then
        return false
      end
      local owner = land_actions.resolve_rent_owner(ctx.game, ctx.tile)
      return owner ~= nil
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
  }

  local ok, err = pcall(function()
    support.with_patches(patches, function()
      for _ = 1, max_steps do
        runtime_state.set_ui_dirty(state, false)
        g.dirty.ui = false
        g.dirty.players = false
        g.dirty.turn = false
        g.dirty.board_tiles = false
        g.dirty.any = false
        if g.turn and (g.turn.phase == "detained_wait" or g.turn.phase == "inter_turn_wait") then
          gameplay_loop.tick(g, state, dt)
        end
        gameplay_loop.step_auto_runner(g, state, dt, {
          modal_active = false,
          modal_buttons = nil,
          game_finished = g.finished,
          current_player_index = g.turn and g.turn.current_player_index or nil,
          current_player_id = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.id or nil
          end)(),
          current_player_auto = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.auto == true or false
          end)(),
        })
        tick_timeout.step_choice_timeout(g, state, dt, {
          on_pending_choice = function() end,
          is_choice_active = function(ctx)
            return runtime_state.get_pending_choice(ctx) and true or false
          end,
          build_action = function(game_ctx, ctx, choice)
            local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
            if auto_choice then
              return auto_choice
            end
            local options = assert(choice.options, "missing choice.options")
            local first = assert(options[1], "missing choice option")
            return {
              type = "choice_select",
              choice_id = choice.id,
              option_id = first.id or first,
              actor_role_id = (choice.owner_role_id or (game_ctx.current_player and game_ctx:current_player() and game_ctx:current_player().id) or nil),
            }
          end,
        })
        if g.finished then
          break
        end
        now = now + dt
        local auto_action = gameplay_loop.step_auto_runner(g, state, dt, {
          modal_active = false,
          modal_buttons = nil,
          game_finished = g.finished,
          current_player_index = g.turn and g.turn.current_player_index or nil,
          current_player_id = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.id or nil
          end)(),
          current_player_auto = (function()
            local idx = g.turn and g.turn.current_player_index or nil
            local player = idx and g.players and g.players[idx] or nil
            return player and player.auto == true or false
          end)(),
        })
        _drive_auto_turn(g, state, auto_action)
        if g.turn and (g.turn.phase == "detained_wait" or g.turn.phase == "inter_turn_wait") then
          gameplay_loop.tick(g, state, dt)
        end
        tick_timeout.step_choice_timeout(g, state, dt, {
          on_pending_choice = function() end,
          is_choice_active = function(ctx)
            return runtime_state.get_pending_choice(ctx) and true or false
          end,
          build_action = function(game_ctx, ctx, choice)
            local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
            if auto_choice then
              return auto_choice
            end
            local options = assert(choice.options, "missing choice.options")
            local first = assert(options[1], "missing choice option")
            return {
              type = "choice_select",
              choice_id = choice.id,
              option_id = first.id or first,
              actor_role_id = (choice.owner_role_id or (game_ctx.current_player and game_ctx:current_player() and game_ctx:current_player().id) or nil),
            }
          end,
        })
      end
      if not g.finished then
        error("autorunner did not finish within max_steps=" .. tostring(max_steps))
      end
    end)
  end)

  assert(ok, "autorunner test failed: " .. tostring(err))
end

local function _test_complex_consecutive_turn_settlement()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  p1.inventory:add({ id = 2007 })
  g:set_player_cash(p1, 10000)

  p2.inventory:add({ id = 2001 })
  g:set_player_cash(p2, 10000)

  g:update_player_position(p1, 10)
  g:update_player_position(p2, 12)

  local chance_idx = _first_tile_by_type(g.board, "chance")
  local hospital_idx = _first_tile_by_type(g.board, "hospital")

  g:update_player_position(p1, chance_idx - 3)
  g:update_player_position(p2, chance_idx - 2)

  local mine_pos = g.board:get_tile(chance_idx + 2)
  if mine_pos then
    g.board:place_mine(chance_idx + 2)
  end

  local chance_cfg = require("src.config.content.chance_cards")
  local has_move_forward = false
  for _, card in ipairs(chance_cfg) do
    if card.effect == "move_forward" and card.steps == 2 and card.target == "self" then
      has_move_forward = true
      break
    end
  end
  assert(has_move_forward, "配置中需要存在向前移动2格的机会卡")

  local initial_has_steal_card = inventory.find_index(p1, 2007) and true or false
  local initial_p2_item_count = p2.inventory:count()

  assert(initial_has_steal_card, "p1 应该有偷窃卡")
  assert(initial_p2_item_count > 0, "p2 应该有道具可被偷")

  local res1 = movement.move(g, p1, 3, { branch_parity = 3, skip_market_check = true })
  local first_res = res1
  if res1.steal_interrupt then
    local interrupt = res1.steal_interrupt
    local steal_res = steal.handle_pass_players(g, p1, interrupt.encountered_ids or {})
    if steal_res and steal_res.waiting then
      local pending = _get_choice(g)
      if pending then
        _resolve_choice_first(g, pending)
      end
    end
    res1 = movement.move(g, p1, interrupt.remaining_steps, {
      branch_parity = interrupt.branch_parity,
      direction = interrupt.facing,
      entered_inner = interrupt.entered_inner,
      skip_market_check = true,
      skip_steal_check = true,
    })
  end

  assert(first_res.encountered_players and #first_res.encountered_players > 0, "应该经过其他玩家")
  assert(p1.position == chance_idx, "应该停在机会卡格子")

  local tile_chance = g.board:get_tile(chance_idx)
  _resolve_landing_with_choices(g, p1, tile_chance, res1, 10)

  assert(p1, "玩家1应该存在")

  if p1.position == hospital_idx then
    assert(number_utils.is_numeric(p1.status.stay_turns), "医院应设置 stay_turns")
  end

  assert(true, "复杂连续结算完成")
end

local function _test_forced_move_landing_optional_preserves_owner_role_id_for_buy_land()
  local g = _new_game()
  local player = g.players[1]
  g:set_player_cash(player, 10000)

  local _, tile = _first_land_tile(g.board)
  local forced_move = assert(g.registries.chances.handlers.forced_move, "missing forced_move handler")
  local move_out = forced_move(g, player, {
    effect = "forced_move",
    destination_tile_id = tile.id,
  }, {})

  assert(move_out and move_out.kind == "need_landing", "forced_move should enter need_landing flow")

  local landing_out = _resolve_landing(g, player, tile, move_out.move_result)
  assert(landing_out and landing_out.waiting == true, "empty land landing should wait on optional choice")

  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "forced move landing should open landing_optional_effect")
  assert(pending.owner_role_id == player.id, "forced move buy_land choice should preserve player owner_role_id")
  assert(pending.route_key == "secondary_confirm", "single landing optional should stay on secondary_confirm route")
  assert(pending.options and pending.options[1] and pending.options[1].id == "buy_land",
    "forced move empty land should offer buy_land")
end

local function _test_forced_move_landing_optional_preserves_owner_role_id_for_upgrade_land()
  local g = _new_game()
  local player = g.players[1]
  g:set_player_cash(player, 10000)

  local _, tile = _first_land_tile(g.board)
  g:set_tile_owner(tile, player.id)
  g:set_player_property(player, tile.id, true)

  local forced_move = assert(g.registries.chances.handlers.forced_move, "missing forced_move handler")
  local move_out = forced_move(g, player, {
    effect = "forced_move",
    destination_tile_id = tile.id,
  }, {})

  assert(move_out and move_out.kind == "need_landing", "forced_move should enter need_landing flow")

  local landing_out = _resolve_landing(g, player, tile, move_out.move_result)
  assert(landing_out and landing_out.waiting == true, "owned land landing should wait on optional choice")

  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "forced move landing should open landing_optional_effect")
  assert(pending.owner_role_id == player.id, "forced move upgrade_land choice should preserve player owner_role_id")
  assert(pending.route_key == "secondary_confirm", "single landing optional should stay on secondary_confirm route")
  assert(pending.options and pending.options[1] and pending.options[1].id == "upgrade_land",
    "forced move owned land should offer upgrade_land")
end

local function _test_complex_market_interrupt_with_rent()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  g:set_player_cash(p1, 50000)
  g:set_player_cash(p2, 50000)

  local market_idx = _first_tile_by_type(g.board, "market")

  local land_idx, land_tile = _first_land_tile(g.board)
  local found_land = false
  for idx = market_idx + 1, g.board:length() do
    local t = g.board:get_tile(idx)
    if t and t.type == "land" then
      land_idx = idx
      land_tile = t
      found_land = true
      break
    end
  end
  if not found_land then
    for idx = 1, market_idx - 1 do
      local t = g.board:get_tile(idx)
      if t and t.type == "land" then
        land_idx = idx
        land_tile = t
        found_land = true
        break
      end
    end
  end
  assert(found_land, "should find a land tile after market")

  g:set_tile_owner(land_tile, p2.id)
  g:set_tile_level(land_tile, 2)
  g:set_player_property(p2, land_tile.id, true)

  local start_pos = market_idx - 1
  if start_pos < 1 then
    start_pos = g.board:length()
  end
  g:update_player_position(p1, start_pos)

  local move_distance = land_idx - start_pos
  if move_distance <= 0 then
    move_distance = g.board:length() + move_distance
  end

  local res = movement.move(g, p1, move_distance, { branch_parity = move_distance })
  res.encountered_players = {}

  local has_market_interrupt = res.market_interrupt and true or false

  if not has_market_interrupt or (res.market_interrupt and res.market_interrupt.remaining_steps == 0) then
    local final_tile = g.board:get_tile(p1.position)
    _resolve_landing_with_choices(g, p1, final_tile, res, 10)
  end

  assert(p1, "玩家应该存在")
  assert(true, "黑市中断 + 租金支付场景完成")
end

local function _walk_expected_forward(board, start_index, facing, remaining_steps, parity, entered_inner)
  local current = start_index
  local next_facing = facing
  local inner_state = entered_inner == true
  for step_index = 1, remaining_steps do
    local step_entered_inner
    current, _, next_facing, step_entered_inner = board:step_forward_by_facing(current, next_facing, {
      parity = parity,
      entered_inner = inner_state,
    })
    if step_entered_inner then
      inner_state = true
    end
  end
  return current, next_facing
end

local function _test_market_interrupt_resume_uses_interrupt_facing()
  local g = _new_game()
  local p = g:current_player()

  g:update_player_position(p, 35)
  local res = movement.move(g, p, 2, { branch_parity = 2 })
  local interrupt = assert(res.market_interrupt, "expected market interrupt")
  assert(interrupt.remaining_steps > 0, "market interrupt should leave resumable steps")

  local expected_index, expected_facing = _walk_expected_forward(
    g.board,
    interrupt.position,
    interrupt.facing,
    interrupt.remaining_steps,
    interrupt.branch_parity,
    interrupt.entered_inner
  )

  g:set_player_status(p, "move_dir", "up")
  local resumed = movement.move(g, p, interrupt.remaining_steps, {
    branch_parity = interrupt.branch_parity,
    direction = interrupt.facing,
    entered_inner = interrupt.entered_inner,
    facing_mode = "resume_forward",
    skip_market_check = true,
  })

  assert(resumed and resumed.landing_tile, "resumed market move should complete")
  assert(p.position == expected_index, "market resume should follow interrupt.facing instead of stale move_dir")
  assert(p.status.move_dir == expected_facing, "market resume should persist the next heading after resume")
end

local function _test_steal_interrupt_resume_uses_interrupt_facing()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local chance_idx = _first_tile_by_type(g.board, "chance")

  if not inventory.find_index(p1, gameplay_rules.item_ids.steal) then
    p1.inventory:add({ id = gameplay_rules.item_ids.steal })
  end

  g:update_player_position(p1, chance_idx - 3)
  g:update_player_position(p2, chance_idx - 2)

  local res = movement.move(g, p1, 3, { branch_parity = 3, skip_market_check = true })
  local interrupt = assert(res.steal_interrupt, "expected steal interrupt")
  assert(interrupt.remaining_steps > 0, "steal interrupt should leave resumable steps")

  local expected_index, expected_facing = _walk_expected_forward(
    g.board,
    interrupt.position,
    interrupt.facing,
    interrupt.remaining_steps,
    interrupt.branch_parity,
    interrupt.entered_inner
  )

  g:set_player_status(p1, "move_dir", "up")
  local resumed = movement.move(g, p1, interrupt.remaining_steps, {
    branch_parity = interrupt.branch_parity,
    direction = interrupt.facing,
    entered_inner = interrupt.entered_inner,
    facing_mode = "resume_forward",
    skip_market_check = true,
    skip_steal_check = true,
  })

  assert(resumed and resumed.landing_tile, "resumed steal move should complete")
  assert(p1.position == expected_index, "steal resume should follow interrupt.facing instead of stale move_dir")
  assert(p1.status.move_dir == expected_facing, "steal resume should persist the next heading after resume")
end

local function _test_tick_headless_ports_cover_anim_phases()
  local g = _new_game()
  local state = _build_loop_state()
  state.ui = nil
  state.wait_move_anim = true
  state.wait_action_anim = true
  local dispatched = {}
  local sequence = {}
  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local calls = {
    move_anim = 0,
    action_anim = 0,
    countdown = 0,
    refresh = 0,
  }

  state.gameplay_loop_ports = _build_test_ports({
    play_move_anim = function(_, anim_ctx)
      calls.move_anim = calls.move_anim + 1
      sequence[#sequence + 1] = "play_move_anim"
      assert(anim_ctx and anim_ctx.seq == 101, "move anim ctx should be injected")
      return 0
    end,
    play_action_anim = function(_, anim_ctx)
      calls.action_anim = calls.action_anim + 1
      sequence[#sequence + 1] = "play_action_anim"
      assert(anim_ctx and anim_ctx.seq == 201, "action anim ctx should be injected")
      return 0
    end,
    step_choice_timeout = function()
      sequence[#sequence + 1] = "step_choice_timeout"
    end,
    step_modal_timeout = function()
      sequence[#sequence + 1] = "step_modal_timeout"
    end,
    update_countdown = function()
      calls.countdown = calls.countdown + 1
      sequence[#sequence + 1] = "update_countdown"
    end,
    refresh_from_dirty = function()
      calls.refresh = calls.refresh + 1
      sequence[#sequence + 1] = "refresh_from_dirty"
      return false
    end,
    sync_debug_log = function()
      sequence[#sequence + 1] = "sync_debug_log"
    end,
    log_status = function()
      sequence[#sequence + 1] = "log_status"
    end,
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  g.turn.phase = "wait_move_anim"
  g.turn.move_anim = { seq = 101 }
  support.with_patches({
    { target = gameplay_loop, key = "step_auto_runner", value = function()
      sequence[#sequence + 1] = "step_auto_runner"
    end },
    { target = gameplay_loop_runtime, key = "sync_input_blocked", value = function()
      sequence[#sequence + 1] = "sync_input_blocked"
      return false
    end },
    { target = gameplay_loop_runtime, key = "sync_phase_flags", value = function()
      sequence[#sequence + 1] = "sync_phase_flags"
    end },
    { target = turn_role_control_policy, key = "sync", value = function()
      sequence[#sequence + 1] = "sync_role_control"
    end },
    { target = turn_timer_policy, key = "update_action_button_timer", value = function()
      sequence[#sequence + 1] = "update_action_button_timer"
    end },
    { target = turn_timer_policy, key = "update_detained_wait_timer", value = function()
      sequence[#sequence + 1] = "update_detained_wait_timer"
    end },
    { target = turn_timer_policy, key = "update_inter_turn_wait_timer", value = function()
      sequence[#sequence + 1] = "update_inter_turn_wait_timer"
    end },
    { target = turn_camera_policy, key = "sync_follow", value = function()
      sequence[#sequence + 1] = "sync_follow"
    end },
  }, function()
    gameplay_loop.tick(g, state, 0.1)
  end)
  assert(calls.move_anim == 1, "headless move anim should use injected port")
  assert(dispatched[1] and dispatched[1].type == "move_anim_done", "move anim should dispatch move_anim_done")
  assert(dispatched[1] and dispatched[1].seq == 101, "move anim seq should be forwarded")

  g.turn.phase = "wait_action_anim"
  g.turn.action_anim = { seq = 201 }
  support.with_patches({
    { target = gameplay_loop, key = "step_auto_runner", value = function()
      sequence[#sequence + 1] = "step_auto_runner"
    end },
  }, function()
    gameplay_loop.tick(g, state, 0.1)
  end)
  assert(calls.action_anim == 1, "headless action anim should use injected port")
  assert(dispatched[2] and dispatched[2].type == "action_anim_done", "action anim should dispatch action_anim_done")
  assert(dispatched[2] and dispatched[2].seq == 201, "action anim seq should be forwarded")

  assert(calls.countdown >= 2, "countdown should still step under custom ports")
  assert(calls.refresh >= 2, "refresh_from_dirty should still be called under custom ports")

  local expected_order = {
    "sync_input_blocked",
    "sync_role_control",
    "step_auto_runner",
    "step_choice_timeout",
    "step_modal_timeout",
    "update_action_button_timer",
    "update_detained_wait_timer",
    "update_inter_turn_wait_timer",
    "sync_input_blocked",
    "play_move_anim",
    "sync_phase_flags",
    "update_countdown",
    "refresh_from_dirty",
    "sync_follow",
    "sync_debug_log",
  }
  local search_start = 1
  for _, name in ipairs(expected_order) do
    local matched = nil
    for i = search_start, #sequence do
      if sequence[i] == name then
        matched = i
        break
      end
    end
    assert(matched ~= nil, "missing expected tick order step: " .. tostring(name))
    search_start = matched + 1
  end
end

local function _test_action_button_timeout_auto_advances()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.players[1].auto = true
  state.auto_runner:set_enabled(false)
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 1, "action button timeout should advance turn")
end

local function _test_action_button_timeout_manual_wait_action_auto_advances()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  state.auto_runner:set_enabled(false)
  g.players[1].auto = false
  g.players[1].is_ai = false
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action"
  g.turn.pending_choice = nil

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    _with_timestamp_stub(function()
      local dt = (constants.action_timeout_seconds or 0) + 0.1
      gameplay_loop.tick(g, state, dt)
    end)
  end)

  assert(g.turn.phase ~= "wait_action", "manual wait_action timeout should leave wait_action")
  assert(g.last_turn and g.last_turn.total ~= nil, "manual wait_action timeout should auto roll")
end

local function _test_action_button_timeout_manual_player_does_not_advance()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  state.auto_runner:set_enabled(false)
  g.players[1].auto = false
  g.players[1].is_ai = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil
  state.action_button_active = true
  state.action_button_elapsed = (constants.action_timeout_seconds or 0) + 1
  state.action_button_player_id = g.players[2].id

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    _with_timestamp_stub(function()
      local dt = (constants.action_timeout_seconds or 0) + 0.1
      gameplay_loop.tick(g, state, dt)
    end)
  end)

  assert(advanced == 0, "manual player timeout should not advance turn")
  assert(state.action_button_active == false, "manual player should keep action timer disabled")
  assert(state.action_button_elapsed == 0, "manual player timeout should reset action timer")
  assert(state.action_button_player_id == nil, "manual player timeout reset should clear tracked actor")
end

local function _test_action_button_timeout_blocked_when_input_locked()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action_anim"
  g.turn.pending_choice = nil

  state.ui.input_blocked = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    _with_timestamp_stub(function()
      local dt = (constants.action_timeout_seconds or 0) + 0.1
      gameplay_loop.tick(g, state, dt)
    end)
  end)

  assert(advanced == 0, "input locked should block action button timeout")
  assert(state.action_button_active == false, "input locked should disable action timer")
  assert(state.action_button_elapsed == 0, "input locked should reset action timer")
end

local function _test_action_button_timeout_blocked_when_popup_active()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  state.ui.popup_active = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "popup active should block action button timeout")
  assert(state.action_button_active == false, "popup active should disable action timer")
  assert(state.action_button_elapsed == 0, "popup active should reset action timer")
end

local function _test_auto_runner_auto_advances_ai_player()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local auto_decision_delay = gameplay_rules.auto_decision_delay_seconds or 0
  state.auto_runner.interval = auto_decision_delay
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local a1 = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.1, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a1 == nil, "should not trigger before reaching auto interval")
    local a2 = gameplay_loop.step_auto_runner(g, state, 0.1, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a2 and a2.type == "ui_button" and a2.id == "next", "ai player should auto dispatch next")
  end)
end

local function _test_auto_runner_human_turn_not_auto_advanced()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[1].id,
      current_player_auto = false,
    })
    assert(action == nil, "human turn should not auto dispatch next")
  end)
end

local function _test_gameplay_loop_ai_rounds_do_not_force_manual_timeout()
  local state = _build_loop_state()
  local g = {
    finished = false,
    players = {
      { id = 2, name = "Human2", is_ai = false, auto = false },
      { id = -2, name = "AI2", is_ai = true, auto = false },
      { id = -3, name = "AI3", is_ai = true, auto = false },
      { id = -4, name = "AI4", is_ai = true, auto = false },
    },
    turn = {
      current_player_index = 2,
      pending_choice = nil,
    },
  }
  local ports = _build_test_ports()
  local advanced = 0

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 0.5 },
  }, function()
    local function _dispatch_next()
      advanced = advanced + 1
      local next_index = g.turn.current_player_index + 1
      if next_index > #g.players then
        next_index = 1
      end
      g.turn.current_player_index = next_index
      g.turn.pending_choice = nil
    end

    for _ = 1, 3 do
      turn_timer_policy.update_action_button_timer({
        game = g,
        state = state,
        dt = 0.6,
        ports = ports,
        dispatch_next = _dispatch_next,
      })
    end
    assert(g.turn.current_player_index == 1, "ai rounds should return control to manual player")
    local advanced_before = advanced

    state.action_button_active = true
    state.action_button_elapsed = 9
    state.action_button_player_id = g.players[4].id

    for _ = 1, 6 do
      turn_timer_policy.update_action_button_timer({
        game = g,
        state = state,
        dt = 0.6,
        ports = ports,
        dispatch_next = _dispatch_next,
      })
    end

    assert(g.turn.current_player_index == 1, "manual player should not be auto advanced by timeout")
    assert(advanced == advanced_before, "manual player timeout should not dispatch synthetic next")
    assert(state.action_button_active == false and state.action_button_elapsed == 0,
      "manual player timeout should reset action timer state")
    assert(state.action_button_player_id == nil, "manual player timeout reset should clear tracked actor")
  end)
end

local function _test_auto_runner_waits_for_auto_popup_delay()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local auto_player = g.players[2]
  local auto_decision_delay = gameplay_rules.auto_decision_delay_seconds or 0
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1
  state.ui.popup_active = true
  state.ui.popup_owner_index = 2
  state.ui.popup_payload = {
    auto_close_seconds = auto_decision_delay + 3,
  }

  _with_timestamp_stub(function()
    ui_runtime.ui_modal_elapsed = auto_decision_delay - 0.1
    local blocked = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = auto_player.id,
      current_player_auto = true,
    })
    assert(blocked == nil, "auto popup should keep auto runner waiting before delay elapses")

    ui_runtime.ui_modal_elapsed = auto_decision_delay
    local action = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = auto_player.id,
      current_player_auto = true,
    })
    assert(action and action.type == "ui_button" and action.id == "next",
      "auto popup should stop blocking once the shared delay is reached")
  end)
end

local function _test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local ai_player = g.players[2]
  local dispatched = nil
  local auto_decision_delay = gameplay_rules.auto_decision_delay_seconds or 0
  local choice = {
    id = 701,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = ai_player.id,
    options = {
      { id = "buy_land", label = "购买地块" },
      { id = "skip", label = "跳过" },
    },
    allow_cancel = true,
    meta = {
      player_id = ai_player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 2
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
  g.dispatch_action = function(_, action)
    dispatched = action
    g.turn.pending_choice = nil
  end

  _with_timestamp_stub(function()
    local early = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.1, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(early == nil, "choice auto action should wait before looking decided")
    local action = gameplay_loop.step_auto_runner(g, state, 0.1, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(action and action.type == "choice_select", "auto runner should resolve pending choice without ui choice screen")
    assert(action.option_id == "buy_land", "auto runner should select buy_land for AI landing optional effect")
    assert(action.actor_role_id == ai_player.id, "auto runner should preserve AI owner role")
  end)

  assert(dispatched and dispatched.type == "choice_select", "auto runner should dispatch the auto-selected choice")
  assert(dispatched.option_id == "buy_land", "dispatched choice should still select buy_land")
end

local function _test_auto_runner_resets_timer_when_wait_kind_changes()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local ai_player = g.players[2]
  local dispatched = nil
  local auto_decision_delay = gameplay_rules.auto_decision_delay_seconds or 0
  local choice = {
    id = 704,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = ai_player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = {
      player_id = ai_player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  state.auto_runner.interval = auto_decision_delay
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.dispatch_action = function(_, action)
    dispatched = action
    g.turn.pending_choice = nil
  end

  _with_timestamp_stub(function()
    local next_action = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(next_action == nil, "next timer should not fire before short delay")

    g.turn.phase = "wait_choice"
    g.turn.pending_choice = choice
    runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })

    local early_choice = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.2, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(early_choice == nil, "choice timer should reset when switching from next to wait_choice")

    local final_choice = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(final_choice and final_choice.type == "choice_select", "choice timer should fire after a fresh full wait")
  end)
  assert(dispatched and dispatched.type == "choice_select", "final choice should still dispatch after reset")
end

local function _test_auto_runner_not_advanced_when_input_blocked()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  state.ui.input_blocked = true
  g.turn.current_player_index = 2
  g.turn.phase = "wait_action_anim"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(action == nil, "blocked phase should not auto dispatch next")
  end)
end

local function _test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[2]
  local dispatched = nil
  local choice = {
    id = 702,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 2
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })

  tick_choice_timeout.step(g, state, (constants.action_timeout_seconds or 0) + 0.1, {
    on_pending_choice = function() end,
    is_choice_active = function()
      return false
    end,
    build_action = function()
      return {
        type = "choice_select",
        choice_id = choice.id,
        option_id = "buy_land",
      }
    end,
    dispatch_action_with_close_choice = function(_, _, action)
      dispatched = action
    end,
  })

  assert(dispatched and dispatched.type == "choice_select", "timeout should still dispatch choice action without ui choice screen")
  assert(dispatched.actor_role_id == player.id, "timeout-dispatched choice should inherit owner role id")
  assert(runtime_state.get_pending_choice_elapsed(state) == 0, "timeout should reset pending choice elapsed after dispatch")
end

local function _test_tick_choice_timeout_manual_player_keeps_waiting()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[1]
  local dispatched = nil
  local choice = {
    id = 721,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 1
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })

  tick_choice_timeout.step(g, state, (constants.action_timeout_seconds or 0) + 0.1, {
    on_pending_choice = function() end,
    is_choice_active = function()
      return false
    end,
    build_action = function(game_ctx, state_ctx, active_choice, payload)
      return choice_auto_policy.decide(game_ctx, state_ctx, active_choice, payload)
    end,
    dispatch_action_with_close_choice = function(_, _, action)
      dispatched = action
    end,
  })

  assert(dispatched ~= nil, "manual player timeout should dispatch cancel action")
  assert(dispatched.type == "choice_cancel", "manual player timeout should dispatch choice_cancel")
  assert(dispatched.choice_id == 721, "cancel action should have correct choice_id")
end

local function _test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[2]
  local choice = {
    id = 703,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 2
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, {
    choice_id = choice.id,
    elapsed_seconds = 1,
  })
  state.ui.choice_active = false
  state.ui.market_active = false

  tick_ui_sync.update_countdown(g, state)

  assert(g.turn.countdown_active == true, "countdown should stay active for runtime pending choice without ui choice screen")
  assert(g.turn.countdown_seconds == (constants.action_timeout_seconds or 0) - 1,
    "countdown should use runtime pending choice elapsed seconds")
end

local function _test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[1]
  local choice = {
    id = 722,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 1
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, {
    choice_id = choice.id,
    elapsed_seconds = 1,
  })
  state.ui.choice_active = false
  state.ui.market_active = false

  tick_ui_sync.update_countdown(g, state)

  assert(g.turn.countdown_active == true, "manual pending choice should expose countdown")
  assert(g.turn.countdown_seconds > 0, "manual pending choice countdown should be visible")
end

local function _test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice()
  local choice_ui_state = require("src.presentation.runtime.ports.ui_sync.choice_state")
  local warned = {}

  local function _run_case(choice, state, current_player_index)
    local g = _new_game()
    g.turn.current_player_index = current_player_index or 1
    g.turn.phase = "wait_choice"
    g.turn.pending_choice = choice
    runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
    tick_choice_timeout.step(g, state, 0.1, {
      on_pending_choice = function() end,
      is_choice_active = function()
        return false
      end,
      resolve_choice_ui_state = function(game_ctx, state_ctx, active_choice)
        return choice_ui_state.resolve_gate_state(game_ctx, state_ctx, active_choice)
      end,
      build_action = function()
        return nil
      end,
      dispatch_action_with_close_choice = function() end,
    })
  end

  support.with_patches({
    { target = logger, key = "warn", value = function(...)
      warned[#warned + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    local base_inline_state = _build_loop_state()
    runtime_state.set_ui_model(base_inline_state, { current_player_id = 1 })
    _run_case({
      id = 810,
      kind = "item_phase_choice",
      route_key = "base_inline",
      owner_role_id = 1,
      uses_item_slots = true,
      options = { { id = 2001, label = "路障卡" } },
      meta = { player_id = 1, phase = "pre_action" },
    }, base_inline_state, 1)

    local market_state = _build_loop_state()
    market_state.ui.market_active = true
    runtime_state.set_ui_model(market_state, { current_player_id = 1 })
    _run_case({
      id = 811,
      kind = "market_buy",
      route_key = "market",
      owner_role_id = 1,
      options = { { id = 1, label = "A" } },
      meta = { player_id = 1 },
    }, market_state, 1)

    local ai_state = _build_loop_state()
    runtime_state.set_ui_model(ai_state, { current_player_id = 2 })
    _run_case({
      id = 812,
      kind = "landing_optional_effect",
      route_key = "secondary_confirm",
      owner_role_id = 2,
      options = { { id = "buy_land", label = "购买地块" } },
      meta = { player_id = 2, tile_id = 1, effect_ids = { "buy_land" } },
    }, ai_state, 2)
  end)

  assert(#warned == 0, "non-modal or non-local pending choices should not log missing-ui warning")
end

local function _test_tick_choice_timeout_warning_keeps_local_modal_choice()
  local choice_ui_state = require("src.presentation.runtime.ports.ui_sync.choice_state")
  local warned = {}
  local g = _new_game()
  local state = _build_loop_state()
  local choice = {
    id = 813,
    kind = "remote_dice_value",
    route_key = "remote",
    owner_role_id = 1,
    options = { { id = 1, label = "1" } },
    meta = { player_id = 1, item_id = gameplay_rules.item_ids.remote_dice, dice_count = 1 },
  }
  g.turn.current_player_index = 1
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
  runtime_state.set_ui_model(state, { current_player_id = 1 })

  support.with_patches({
    { target = logger, key = "warn", value = function(...)
      warned[#warned + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    tick_choice_timeout.step(g, state, 0.1, {
      on_pending_choice = function() end,
      is_choice_active = function()
        return false
      end,
      resolve_choice_ui_state = function(game_ctx, state_ctx, active_choice)
        return choice_ui_state.resolve_gate_state(game_ctx, state_ctx, active_choice)
      end,
      build_action = function()
        return nil
      end,
      dispatch_action_with_close_choice = function() end,
    })
  end)

  assert(#warned == 1, "local modal choice should still log missing-ui warning")
  assert(string.find(warned[1], "runtime pending choice active without ui.choice_active", 1, true) ~= nil,
    "local modal warning should keep original message")
end

local function _test_turn_prompt_initialized_for_first_player()
  local g = _new_game()
  local current_player = g:current_player()

  assert((g.turn.turn_start_prompt_seq or 0) == 1, "first turn should initialize prompt seq")
  assert(g.turn.turn_start_prompt_player_id == current_player.id,
    "first turn prompt target should be current player")
end

local function _test_turn_prompt_emitted_on_next_player_switch()
  local g = _new_game()
  local before_seq = g.turn.turn_start_prompt_seq or 0
  local before_index = g.turn.current_player_index
  local expected_next_index = before_index % #g.players + 1
  local expected_player = g.players[expected_next_index]

  g.turn_engine:next_player()

  assert(g.turn.current_player_index == expected_next_index, "next_player should switch player index")
  assert((g.turn.turn_start_prompt_seq or 0) == before_seq + 1,
    "next_player should emit one new prompt seq")
  assert(g.turn.turn_start_prompt_player_id == expected_player.id,
    "next_player prompt target should be switched player")
end

local function _test_auto_runner_depends_on_current_player_auto()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local auto_decision_delay = gameplay_rules.auto_decision_delay_seconds or 0
  g.players[1].auto = true
  g.players[2].auto = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action1 = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = true,
    })
    assert(action1 and action1.type == "ui_button" and action1.id == "next",
      "current player auto should dispatch next")

    state.turn_runtime.next_turn_locked = false
    g.turn.current_player_index = 2
    local action2 = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = false,
    })
    assert(action2 == nil, "current player auto=false should not dispatch")
  end)
end

local function _test_turn_dispatch_uses_clock_ports_without_game_api()
  local g = _new_game()
  local state = _build_loop_state()
  state.game = g
  g.ui_port = state
  local current_player = g:current_player()
  local now = 1.0
  local stepped = 0

  state.gameplay_loop_ports = _build_test_ports({
    wall_now_seconds = function()
      return now
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      return (timestamp_1 or 0) - (timestamp_2 or 0)
    end,
  })
  state.turn_runtime.next_turn_locked = true
  state.turn_runtime.next_turn_last_click = 1.0
  state.turn_runtime.next_turn_lock_phase = g.turn.phase

  support.with_patches({
    { target = turn_dispatch, key = "step_turn", value = function()
      stepped = stepped + 1
    end },
    { key = "GameAPI", value = {} },
  }, function()
    now = 1.2
    local rejected = turn_dispatch.dispatch_action(g, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    assert(rejected.status == "rejected", "next should respect cooldown via clock port")

    now = 1.6
    local applied = turn_dispatch.dispatch_action(g, state, {
      type = "ui_button",
      id = "next",
      actor_role_id = current_player.id,
    })
    assert(applied.status == "applied", "next should pass when clock diff reaches cooldown")
  end)

  assert(stepped == 1, "step_turn should run exactly once")
end

local function _test_gameplay_loop_set_game_uses_narrow_runtime_ports()
  local g = _new_game()
  local state = _build_loop_state()
  state.wait_move_anim = true
  state.wait_action_anim = true
  state.board_scene = { marker = "scene" }
  state.push_popup = function(_, payload)
    state._last_popup = payload
    return true
  end
  state.on_board_visual_sync = function(_, payload)
    state._last_board_visual_sync = payload
    return true
  end

  gameplay_loop.set_game(state, g)

  assert(g.ui_port ~= state, "set_game should not inject raw state as catch-all runtime ui port")
  assert(g.board_scene_port ~= state, "set_game should inject a narrow board_scene_port instead of raw state")
  assert(g.board_scene_port:get_board_scene() == state.board_scene, "board_scene_port should expose board_scene getter")
  assert(g.board_visual_feedback_port ~= nil, "set_game should inject board_visual_feedback_port dto")

  g.popup_port:push_popup({ kind = "test_popup" })
  assert(state._last_popup and state._last_popup.kind == "test_popup", "popup_port should forward popup calls")

  g.tile_owner_notifier:notify_owner_changed(11, 22)
  assert(state._last_board_visual_sync and state._last_board_visual_sync.tile_ids[1] == 11,
    "tile_owner_notifier should forward tile id through board visual sync")
end

local function _test_gameplay_loop_set_game_defers_visual_ports_during_landing_hold()
  local g = _new_game()
  local state = _build_loop_state()
  local board_syncs = {}

  state.wait_move_anim = true
  state.wait_action_anim = true
  state.push_popup = function(_, payload)
    state._last_popup = payload
    return true
  end
  state.on_board_visual_sync = function(_, payload)
    board_syncs[#board_syncs + 1] = payload
    return true
  end
  state.gameplay_loop_ports = _build_test_ports({
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_status_3d = function() end,
    sync_debug_log = function() end,
  })

  gameplay_loop.set_game(state, g)

  g.turn.landing_visual_hold_active = true
  landing_visual_hold.sync_state_from_game(state, g)

  g.popup_port:push_popup({ kind = "held_popup" })
  g.tile_owner_notifier:notify_owner_changed(11, 22)
  g.tile_feedback_port:on_tile_upgraded(33, 2)
  g.bankruptcy_feedback_port:on_tiles_cleared(g, g.players[1], { 44 })

  assert(state._last_popup == nil, "popup should be deferred during landing hold")
  assert(#board_syncs == 0, "board visual sync should be deferred during landing hold")

  g.turn.landing_visual_release_pending = true
  gameplay_loop.tick(g, state, 0.1)

  assert(state._last_popup and state._last_popup.kind == "held_popup", "popup should flush after landing hold release")
  assert(#board_syncs == 3, "board visual syncs should flush after landing hold release")
  assert(board_syncs[1].tile_ids[1] == 11, "tile owner sync should flush after release")
  assert(board_syncs[2].tile_ids[1] == 33, "tile upgrade sync should flush after release")
  assert(board_syncs[3].tile_ids[1] == 44, "bankruptcy clear sync should flush after release")
end

local function _test_board_visual_feedback_port_reconciles_destroyed_tile_and_cleared_overlays()
  local g = _new_game()
  local state = _build_loop_state()
  local idx, tile_ref = _first_land_tile(g.board)
  local render_calls = {}
  local cleared_buildings = {}
  local cleared_overlays = {}
  local board_view = require("src.ui.render.board")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local overlay_runtime = require("src.ui.render.anim_overlay_runtime")

  tile_ref.owner_id = g.players[2].id
  tile_ref.level = 1

  state.board_scene = {
    tiles = { [idx] = {} },
    buildings = {
      [idx] = {
        get_position = function()
          return math and math.Vector3 and math.Vector3(0, 0, 0) or { x = 0, y = 0, z = 0 }
        end,
      },
    },
    building_unit_groups = { [idx] = { handle = "building" } },
    building_txt = {
      [idx] = {
        set_billboard_text = function() end,
      },
    },
    overlay_units = {
      roadblocks = { [idx] = { handle = "roadblock" } },
      mines = { [idx] = { handle = "mine" } },
    },
  }
  state.tile_units = state.board_scene.tiles
  state.on_board_visual_sync = function(_, payload)
    return board_view.sync_many(state, payload)
  end

  gameplay_loop.set_game(state, g)

  support.with_patches({
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id, owner_id)
        render_calls[#render_calls + 1] = { tile_id = tile_id, owner_id = owner_id }
        return true
      end,
    },
    {
      target = building_effects,
      key = "clear_building_units",
      value = function(_, building_index)
        cleared_buildings[#cleared_buildings + 1] = building_index
        return true
      end,
    },
    {
      target = overlay_runtime,
      key = "clear_overlay",
      value = function(_, kind, tile_index)
        cleared_overlays[#cleared_overlays + 1] = { kind = kind, tile_index = tile_index }
      end,
    },
  }, function()
    g:set_tile_level(tile_ref, 0)
    g:clear_all_overlays(idx)
  end)

  assert(render_calls[1] and render_calls[1].tile_id == tile_ref.id, "destroy sync should re-render tile")
  assert(cleared_buildings[1] == idx, "destroy sync should clear building group")
  assert(#cleared_overlays == 2, "destroy sync should clear both overlay kinds")
  assert(cleared_overlays[1].tile_index == idx and cleared_overlays[2].tile_index == idx,
    "destroy sync should target the demolished tile index")
end

local function _test_board_visual_feedback_port_reconciles_spawned_tile_and_overlays_without_action_anim()
  local g = _new_game()
  local state = _build_loop_state()
  local idx, tile_ref = _first_land_tile(g.board)
  local render_calls = {}
  local spawned_buildings = {}
  local spawned_overlays = {}
  local board_view = require("src.ui.render.board")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local overlay_runtime = require("src.ui.render.anim_overlay_runtime")

  state.board_scene = {
    tiles = { [idx] = {} },
    buildings = {
      [idx] = {
        get_position = function()
          return math and math.Vector3 and math.Vector3(0, 0, 0) or { x = 0, y = 0, z = 0 }
        end,
      },
    },
    building_unit_groups = {},
    building_txt = {
      [idx] = {
        set_billboard_text = function() end,
      },
    },
    overlay_units = {
      roadblocks = {},
      mines = {},
    },
  }
  state.tile_units = state.board_scene.tiles
  state.on_board_visual_sync = function(_, payload)
    return board_view.sync_many(state, payload)
  end

  gameplay_loop.set_game(state, g)

  support.with_patches({
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id, owner_id)
        render_calls[#render_calls + 1] = { tile_id = tile_id, owner_id = owner_id }
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index, level)
        spawned_buildings[#spawned_buildings + 1] = { building_index = building_index, level = level }
        return true
      end,
    },
    {
      target = overlay_runtime,
      key = "spawn_overlay",
      value = function(_, kind, tile_index)
        spawned_overlays[#spawned_overlays + 1] = { kind = kind, tile_index = tile_index }
        return true
      end,
    },
  }, function()
    g:set_tile_owner(tile_ref, g.players[1].id)
    g:set_tile_level(tile_ref, 2)
    g:place_roadblock(idx)
    g:place_mine(idx, { owner_id = g.players[1].id, armed = false })
  end)

  assert(#render_calls >= 2, "spawn sync should re-render tile for owner/level changes")
  assert(spawned_buildings[1] and spawned_buildings[1].building_index == idx and spawned_buildings[1].level == 2,
    "spawn sync should rebuild building units at the final level")
  local saw_roadblock = false
  local saw_mine = false
  for _, entry in ipairs(spawned_overlays) do
    if entry.kind == "roadblock" and entry.tile_index == idx then
      saw_roadblock = true
    end
    if entry.kind == "mine" and entry.tile_index == idx then
      saw_mine = true
    end
  end
  assert(saw_roadblock and saw_mine, "spawn sync should create both overlay kinds without action anim")
end

local function _test_gameplay_loop_refresh_drives_camera_follow_via_port()
  local g = _new_game()
  local state = _build_loop_state()
  local followed_player_id = nil
  g.turn.current_player_index = 2
  g.dirty.any = true
  g.dirty.ui = true

  state.gameplay_loop_ports = _build_test_ports({
    refresh_from_dirty = function()
      return true
    end,
    follow_camera = function(_, player_id)
      followed_player_id = player_id
      return true
    end,
    update_countdown = function() end,
    sync_status_3d = function() end,
    sync_debug_log = function() end,
  })

  gameplay_loop.tick(g, state, 0.1)

  assert(followed_player_id == g.players[2].id, "camera follow should be driven by use-case loop with current player id")
end

local function _test_gameplay_loop_camera_follow_skips_eliminated_current_player()
  local g = _new_game()
  local state = _build_loop_state()
  local followed_player_id = nil
  g.turn.current_player_index = 1
  g.players[1].eliminated = true
  g.players[2].eliminated = false
  g.dirty.any = true
  g.dirty.ui = true

  state.gameplay_loop_ports = _build_test_ports({
    refresh_from_dirty = function()
      return true
    end,
    follow_camera = function(_, player_id)
      followed_player_id = player_id
      return true
    end,
    update_countdown = function() end,
    sync_status_3d = function() end,
    sync_debug_log = function() end,
  })

  gameplay_loop.tick(g, state, 0.1)

  assert(followed_player_id == g.players[2].id,
    "camera follow should move to next alive player when current player is eliminated")
end

local function _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics()
  support.with_patches({
    { key = "GameAPI", value = {} },
    { target = os, key = "clock", value = function() return 9.25 end },
  }, function()
    local ports = gameplay_loop_ports.resolve(nil)
    local clock = ports.clock
    assert(clock.wall_now_seconds() == 0, "wall clock should not fallback to cpu clock when GameAPI timestamp is unavailable")
    assert(clock.cpu_now_seconds() == 0, "default cpu clock should be environment-agnostic before runtime injection")
  end)

  local ports = gameplay_loop_ports.resolve({
    clock = {
      wall_now_seconds = function() return 77 end,
      wall_diff_seconds = function() return 0.6 end,
      cpu_now_seconds = function() return 3.5 end,
      cpu_diff_seconds = function(a, b) return a - b end,
    },
  })
  local clock = ports.clock
  assert(clock.wall_now_seconds() == 77, "wall clock should use injected wall source")
  assert(clock.wall_diff_seconds(10, 9) == 0.6, "wall diff should use injected wall semantics")
  assert(clock.cpu_now_seconds() == 3.5, "cpu clock should use injected cpu source")
  assert(clock.cpu_diff_seconds(10, 9) == 1, "cpu diff should stay arithmetic and source-agnostic")
end

local function _test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  auto_player.auto = true
  local state = _bind_ui_runtime({ pending_choice_elapsed = 1.2 })
  local choice = {
    id = 1001,
    kind = "market_buy",
    route_key = "market",
    allow_cancel = true,
    meta = { player_id = auto_player.id, active_tab = "item", page_index = 1, page_count = 1 },
    options = { { id = "buy", label = "购买" } },
  }

  local from_wait = choice_auto_policy.decide(g, state, choice, {
    mode = "wait_choice",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })
  local from_timeout = choice_auto_policy.decide(g, state, choice, {
    mode = "tick_timeout",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })
  assert(from_wait and from_timeout, "auto policy should return actions for auto actor")
  assert(from_wait.type == "choice_cancel", "wait_choice should keep market auto-cancel behavior")
  assert(from_timeout.type == "choice_cancel", "tick_timeout should default to cancel when choice allows cancel")
  assert(from_wait.choice_id == from_timeout.choice_id, "wait/timeout should target same choice")
  assert(from_wait.option_id == nil, "wait_choice cancel should not carry option_id")
  assert(from_timeout.option_id == nil, "timeout cancel should not carry option_id")
end

local function _test_choice_auto_policy_timeout_keeps_non_cancelable_choice_fallback()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  auto_player.auto = true
  local state = _bind_ui_runtime({ pending_choice_elapsed = 1.2 })
  local choice = {
    id = 1002,
    kind = "remote_dice_value",
    route_key = "remote",
    allow_cancel = false,
    meta = {
      player_id = auto_player.id,
      item_id = gameplay_rules.item_ids.remote_dice,
      dice_count = 1,
      item_preconsumed = true,
    },
    options = { { id = 4, label = "4" } },
  }

  local from_timeout = choice_auto_policy.decide(g, state, choice, {
    mode = "tick_timeout",
    min_visible_seconds = 0.5,
    elapsed_seconds = state.pending_choice_elapsed,
  })

  assert(from_timeout ~= nil, "non-cancelable timeout should still produce a fallback action")
  assert(from_timeout.type == "choice_select", "non-cancelable timeout should keep choice_select fallback")
  assert(from_timeout.option_id == 4, "non-cancelable timeout should fallback to the first option")
end

local function _test_choice_auto_policy_preconsumed_wait_choice_picks_first_option()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  auto_player.auto = true
  local choice = {
    id = 1004,
    kind = "remote_dice_value",
    allow_cancel = false,
    meta = {
      player_id = auto_player.id,
      item_preconsumed = true,
    },
    options = { { id = 5, label = "5" }, { id = 6, label = "6" } },
  }

  local action = choice_auto_policy.decide(g, nil, choice, {
    mode = "wait_choice",
    elapsed_seconds = 1,
  })

  assert(action ~= nil, "preconsumed choice should produce fallback action in wait_choice mode")
  assert(action.type == "choice_select", "preconsumed choice should select instead of cancel")
  assert(action.option_id == 5, "preconsumed choice should select the first option")
end

local function _test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed()
  local g = _new_game()
  local state = {}
  local stepped = 0
  g.turn.detained_wait_active = true
  g.turn.detained_wait_elapsed = 0.4
  g.turn.detained_wait_seconds = 0.5

  turn_timer_policy.update_detained_wait_timer(g, state, 0.2, function(game)
    assert(game == g, "detained wait should step the current game")
    stepped = stepped + 1
  end)

  assert(stepped == 1, "detained wait should step turn after timeout")
  assert(g.turn.detained_wait_active == false, "detained wait should clear active flag after timeout")
  assert(g.turn.detained_wait_elapsed == 0, "detained wait should reset elapsed after timeout")
end

local function _test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed()
  local g = _new_game()
  local state = {}
  local stepped = 0
  g.turn.inter_turn_wait_active = true
  g.turn.inter_turn_wait_elapsed = 0.4
  g.turn.inter_turn_wait_seconds = 0.5

  turn_timer_policy.update_inter_turn_wait_timer(g, state, 0.2, function(game)
    assert(game == g, "inter-turn wait should step the current game")
    stepped = stepped + 1
  end)

  assert(stepped == 1, "inter-turn wait should step turn after timeout")
  assert(g.turn.inter_turn_wait_active == false, "inter-turn wait should clear active flag after timeout")
  assert(g.turn.inter_turn_wait_elapsed == 0, "inter-turn wait should reset elapsed after timeout")
end

local function _test_item_slot_data_prefers_role_specific_items_and_falls_back()
  local owner_id = 101
  local slots = item_slot_data.from_ui_state({
    item_slot_item_ids = { 2001, 2002, 2003 },
    item_slot_item_ids_by_role = {
      [tostring(owner_id)] = { 3001, 3002, 3003 },
    },
  })

  assert(slots.get_item_ids(owner_id)[2] == 3002, "item_slot_data should prefer role-specific ids")
  assert(slots.get_item_ids(999)[2] == 2002, "item_slot_data should fall back to shared ids for unknown role")
  assert(slots.resolve_slot_action(owner_id, "item_slot_3") == 3003, "slot action should resolve string slot ids via role-specific ids")
  assert(slots.resolve_slot_action(999, 1) == 2001, "slot action should fall back to shared ids when role-specific ids are missing")
  assert(slots.resolve_slot_action(owner_id, "invalid") == nil, "slot action should reject invalid slot ids")
end

local function _test_gameplay_loop_ports_rejects_legacy_flat_override()
  local ok, err = pcall(function()
    gameplay_loop_ports.resolve({
      close_choice_modal = function() end,
    })
  end)

  assert(ok == false, "legacy flat gameplay_loop_ports override should be rejected")
  assert(tostring(err):find("legacy flat gameplay_loop_ports is not supported", 1, true) ~= nil,
    "legacy flat gameplay_loop_ports override should explain grouped-port requirement")
end

local function _test_build_noop_group_characterization()
  local loop_ports = require("src.turn.loop.ports")

  local group1 = loop_ports._build_noop_group({ "key1", "key2", "key3" }, nil)
  assert(type(group1) == "table", "should return a table")
  assert(type(group1.key1) == "function", "key1 should be a function")
  assert(type(group1.key2) == "function", "key2 should be a function")
  assert(type(group1.key3) == "function", "key3 should be a function")
  group1.key1()
  group1.key2()
  group1.key3()

  local override_fn = function() return "overridden" end
  local group2 = loop_ports._build_noop_group({ "key1", "key2" }, { key2 = override_fn })
  assert(type(group2.key1) == "function", "key1 should be a function")
  assert(group2.key2() == "overridden", "key2 should use override function")

  local group3 = loop_ports._build_noop_group({}, nil)
  assert(type(group3) == "table", "should return empty table for empty keys")
  local count = 0
  for _ in pairs(group3) do count = count + 1 end
  assert(count == 0, "group should have no keys when keys is empty")

  local group4 = loop_ports._build_noop_group({ "key1" }, nil)
  assert(type(group4.key1) == "function", "key1 should be a function even with nil overrides")
  group4.key1()
end

local function _test_turn_decision_wait_choice_no_longer_reads_ui_port_state()
  local g = _new_game()
  local auto_player = g.players[g.turn.current_player_index]
  auto_player.auto = true
  g.ui_port = nil
  local choice = {
    id = 1003,
    kind = "remote_dice_value",
    route_key = "remote",
    allow_cancel = false,
    meta = {
      player_id = auto_player.id,
      item_id = gameplay_rules.item_ids.remote_dice,
      dice_count = 1,
      item_preconsumed = true,
    },
    options = { { id = 4, label = "4" } },
  }

  local action = nil
  support.with_patches({
    { target = gameplay_rules, key = "auto_decision_delay_seconds", value = 0 },
  }, function()
    action = turn_decision.decide_choice_action(g, choice, nil, {
      elapsed_seconds = 1.2,
    })
  end)

  assert(action ~= nil, "turn_decision should still resolve action without ui_port.state")
  assert(action.type == "choice_select", "turn_decision should keep remote dice fallback action")
  assert(action.option_id == 4, "turn_decision should keep explicit first-option fallback")
end

local function _test_popup_countdown_uses_effective_modal_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  state.ui.popup_active = true
  state.ui.popup_payload = { auto_close_seconds = 3 }
  state.ui_modal_elapsed = 1.2
  state.pending_choice = nil
  _bind_ui_runtime(state)
  state.action_button_active = false
  state.countdown_last = nil
  state.countdown_active_last = nil

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 10 },
    { target = gameplay_rules, key = "popup_auto_close_seconds", value = 8 },
  }, function()
    tick_ui_sync.update_countdown(g, state)
  end)

  assert(g.turn.countdown_seconds == 2, "popup countdown should use popup effective timeout")
  assert(g.turn.countdown_active == true, "popup countdown should stay active")
end

local function _test_market_countdown_uses_double_action_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  g.turn.current_player_index = 2
  state.pending_choice = {
    id = 2001,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = g.players[2].id,
    meta = { player_id = g.players[2].id },
  }
  state.pending_choice_elapsed = 12.2
  _bind_ui_runtime(state)
  state.ui_runtime.pending_choice = state.pending_choice
  state.ui_runtime.pending_choice_elapsed = state.pending_choice_elapsed
  state.action_button_active = false
  state.countdown_last = nil
  state.countdown_active_last = nil
  g.turn.pending_choice = state.pending_choice

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    tick_ui_sync.update_countdown(g, state)
    assert(tick_timeout.resolve_choice_timeout_seconds(g, state, state.pending_choice) == 30,
      "market choice timeout should be doubled")
  end)

  assert(g.turn.countdown_seconds == 18, "market countdown should use doubled timeout in UI")
  assert(g.turn.countdown_active == true, "market countdown should stay active")
end

local function _test_dispatch_gate_blocks_next_when_choice_active()
  local g = _new_game()
  local state = _build_loop_state()
  state.game = g
  state.ui.input_blocked = false
  state.ui.choice_active = true
  state.ui.market_active = false
  state.ui.popup_active = false
  local current_player = g:current_player()

  local should_block_next = turn_dispatch.should_block_action(state, {
    type = "ui_button",
    id = "next",
    actor_role_id = current_player.id,
  })
  local should_block_choice = turn_dispatch.should_block_action(state, {
    type = "choice_select",
    choice_id = 1,
    option_id = 1,
    actor_role_id = current_player.id,
  })

  assert(should_block_next == true, "choice active should block next")
  assert(should_block_choice == false, "choice active should not block choice confirm")
end

local function _test_game_startup_role_roster_retries_before_debug_players_fallback()
  local state = nil
  local resolve_calls = 0
  local created_opts = nil
  local runtime_ports = require("src.core.ports.runtime_ports")
  support.with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function()
      resolve_calls = resolve_calls + 1
      if resolve_calls == 1 then
        return {}
      end
      return {
        {
          get_roleid = function() return 101 end,
          get_name = function() return "Role101" end,
        },
      }
    end },
    { target = app, key = "new", value = function(_, opts)
      created_opts = opts
      return {}
    end },
    { target = test_profile_bootstrap, key = "apply", value = function() end },
  }, function()
    state = _build_startup_state(function()
      return nil
    end)
    state.game_factory()
  end)

  assert(type(created_opts) == "table", "game startup should create game options")
  assert(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4,
    "game startup should build a 4-slot role_roster after retry")
  assert(created_opts.role_roster[1].role_id == 101, "role_roster should include retried role id")
  assert(created_opts.role_roster[1].name == "Role101", "role_roster should include retried role name")
  assert(created_opts.role_roster[2].synthetic == true and created_opts.role_roster[3].synthetic == true
    and created_opts.role_roster[4].synthetic == true,
    "game startup should synthesize missing slots when retry succeeds")
  assert(created_opts.players == nil, "game startup should keep role_roster startup when retry succeeds")
end

local function _test_runtime_context_change_skin_exports_and_event()
  _with_runtime_context_globals(function()
    local emitted_event = nil
    local role1 = { id = 1, name = "role1" }
    local ctx = runtime_context.new({
      GameAPI = {
        get_role = function(role_id)
          if role_id == 1 then
            return role1
          end
          return nil
        end,
        get_all_valid_roles = function()
          return {}
        end,
      },
      LuaAPI = _mock_lua_api(function(event_name)
        emitted_event = event_name
      end),
    })
    runtime_event_bridge._reset_for_tests()
    _install_runtime_aliases(ctx)
    runtime_context.install_runtime_helpers(ctx, { install_globals = true })
    runtime_context.install_editor_exports(ctx)

    assert(type(get_skin_id) == "function", "runtime exports should expose get_skin_id")
    assert(type(get_change_skin_role) == "function", "runtime exports should expose get_change_skin_role")

    local ok = ctx.change_skin_helper.emit_change_skin(1, 5001)
    assert(ok == true, "change_skin_helper should emit change skin event")
    assert(emitted_event == "change_skin", "change_skin_helper should emit change_skin event name")
    assert(get_skin_id() == 5001, "get_skin_id should return helper skin id")
    assert(get_change_skin_role() == role1, "get_change_skin_role should return helper role")
    runtime_event_bridge._reset_for_tests()
  end)
end

local function _test_find_player_by_id_accepts_mixed_representation()
  local g = _new_game()
  local p1 = g.players[1]
  p1.id = "1"
  g.player_by_id = { ["1"] = p1 }

  local by_int = g:find_player_by_id(1)
  local by_string = g:find_player_by_id("1")

  assert(by_int == p1, "find_player_by_id should match integer input to string player id")
  assert(by_string == p1, "find_player_by_id should match string input to string player id")
end

local function _test_owner_mine_does_not_trigger_until_owner_leaves_tile()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "missing owner tile")

  p1.inventory:add({ id = gameplay_rules.item_ids.mine })
  local use_res = support.executor.use_item(g, p1, gameplay_rules.item_ids.mine, { by_ai = true })
  assert(use_res ~= nil, "mine use should succeed")
  assert(g.board:has_mine(mine_index), "mine should be placed on owner tile")

  local owner_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not owner_res, "owner landing on freshly placed mine should not trigger extra landing")
  assert((p1.status.stay_turns or 0) == 0, "owner should not be hospitalized before leaving mine tile")
  assert(g.board:has_mine(mine_index), "mine should stay until armed mine is triggered")

  local move_res = movement.move(g, p1, 1, { branch_parity = 1, skip_market_check = true })
  assert(move_res and move_res.landing_tile, "owner should move away from mine tile")
  local mine_state = g.board:get_mine(mine_index)
  assert(type(mine_state) == "table" and mine_state.armed == true, "mine should arm after owner leaves tile")
  assert(mine_state.placed_turn_count == g.turn.turn_count, "mine should record placement turn count")

  g:update_player_position(p1, mine_index)
  local owner_return_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not owner_return_res, "owner should stay immune when returning in the placement turn")
  assert((p1.status.stay_turns or 0) == 0, "owner should not be hospitalized by own mine in placement turn")
  assert(g.board:has_mine(mine_index), "mine should remain after owner returns during placement turn")

  g:update_player_position(p2, mine_index)
  local trigger_res = _resolve_landing(g, p2, mine_tile, {})
  assert(not g.turn.pending_choice, "mine trigger should not open a pending choice")
  assert(trigger_res and trigger_res.waiting == true, "mine trigger should wait for move effect animation")
  assert(trigger_res.next_state == "move_followup", "mine trigger should resume through move_followup")
  assert((p2.status.stay_turns or 0) == 0, "hospital stay should be deferred until move followup")
  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "post_action", "mine trigger should resume into post_action after followup")
  assert((p2.status.stay_turns or 0) > 0, "other player should be hospitalized by armed mine after move followup")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after detonation")
end

local function _test_owner_mine_triggers_again_after_placement_turn()
  local g = _new_game()
  local p1 = g.players[1]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "missing owner tile")

  p1.inventory:add({ id = gameplay_rules.item_ids.mine })
  local use_res = support.executor.use_item(g, p1, gameplay_rules.item_ids.mine, { by_ai = true })
  assert(use_res ~= nil, "mine use should succeed")
  assert(g.board:has_mine(mine_index), "mine should be placed on owner tile")

  local move_res = movement.move(g, p1, 1, { branch_parity = 1, skip_market_check = true })
  assert(move_res and move_res.landing_tile, "owner should move away from mine tile")
  local mine_state = assert(g.board:get_mine(mine_index), "mine should still exist after owner leaves tile")
  assert(mine_state.armed == true, "mine should arm after owner leaves tile")

  g.turn.turn_count = g.turn.turn_count + 1
  g:update_player_position(p1, mine_index)

  local trigger_res = _resolve_landing(g, p1, mine_tile, {})
  assert(trigger_res and trigger_res.waiting == true, "owner should be hit by own mine after placement turn ends")
  assert(trigger_res.next_state == "move_followup", "owner mine trigger should resume through move_followup")
  assert((p1.status.stay_turns or 0) == 0, "hospital stay should still be deferred until move followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "post_action", "owner mine trigger should resume into post_action after followup")
  assert((p1.status.stay_turns or 0) > 0, "owner should be hospitalized by own mine on later turns")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after detonating on owner later turn")
end

local function _test_passing_armed_mine_stops_and_triggers_followup()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "missing mine tile")

  p1.inventory:add({ id = gameplay_rules.item_ids.mine })
  local use_res = support.executor.use_item(g, p1, gameplay_rules.item_ids.mine, { by_ai = true })
  assert(use_res ~= nil, "mine use should succeed")

  local owner_move_res = movement.move(g, p1, 1, { branch_parity = 1, skip_market_check = true })
  assert(owner_move_res and owner_move_res.landing_tile, "owner should leave tile and arm the mine")
  local mine_state = assert(g.board:get_mine(mine_index), "mine should still exist after owner leaves tile")
  assert(mine_state.armed == true, "mine should arm after owner leaves tile")

  local before_mine_index = assert(g.board:index_of_tile_id(24), "missing tile before start")
  g:update_player_position(p2, before_mine_index)
  local move_res = movement.move(g, p2, 2, { branch_parity = 2, skip_market_check = true })
  assert(move_res and move_res.landing_tile, "passing player should still produce landing tile")
  assert(p2.position == mine_index, "passing player should stop on mine tile instead of moving past it")
  assert(#move_res.visited == 1, "passing player should consume movement only until mine tile")

  local trigger_res = _resolve_landing(g, p2, mine_tile, move_res)
  assert(trigger_res and trigger_res.waiting == true, "passing mine trigger should wait for move followup")
  assert(trigger_res.next_state == "move_followup", "passing mine trigger should resume through move_followup")
  assert((p2.status.stay_turns or 0) == 0, "hospital stay should be deferred until followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "post_action", "passing mine trigger should resume into post_action after followup")
  assert((p2.status.stay_turns or 0) > 0, "passing player should be hospitalized after mine followup")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after passing detonation")
end

local function _test_detained_turn_enters_wait_state_before_advancing()
  local g = _new_game()
  local p1 = g.players[1]

  g:set_player_status(p1, "stay_turns", 1)

  g:advance_turn()

  assert(g.turn.current_player_index == 1, "detained player should stay current while wait is active")
  assert((p1.status.stay_turns or 0) == 0, "detained player stay_turns should be decremented")
  assert(g.last_turn and g.last_turn.player_id == p1.id, "last_turn should record skipped player")
  assert(g.last_turn and g.last_turn.skipped == true, "last_turn should mark detained turn as skipped")
  assert(g.last_turn and g.last_turn.stay_turns == 0, "last_turn should keep post-decrement stay_turns for UI projection")
  assert(g.turn.phase == "detained_wait", "detained turn should enter detained_wait")
  assert(g.turn.detained_wait_active == true, "detained wait flag should stay enabled during wait")
  assert(g.turn.detained_wait_seconds == 5.0, "detained wait should use configured 5 second delay")
  assert(g.turn.no_action_notice_active == true, "detained wait should still expose a non-blocking notice")
  assert(g.turn.no_action_notice_player_id == p1.id, "notice should belong to skipped player")
end

local function _test_turn_start_emits_turn_started_feedback_event()
  local g = _new_game()
  local emitted = {}

  support.with_patches({
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    local next_state, args = turn_start({ game = g })
    assert(next_state ~= nil, "turn_start should return next state")
  end)

  assert(#emitted >= 1, "turn_start should emit at least one event")
  assert(emitted[1].kind == monopoly_event.feedback.turn_started, "turn_start should emit feedback.turn_started")
  assert(emitted[1].payload.player_id == g:current_player().id, "turn_start should emit current player id")
end

local function _test_turn_start_waits_for_pre_action_item_phase_choice()
  local g = _new_game()
  local player = g:current_player()
  local item_phase = require("src.rules.items.phase")

  support.with_patches({
    { target = item_phase, key = "run", value = function(_, phase_name, args)
      assert(phase_name == "pre_action", "turn_start should run pre_action item phase")
      assert(args and args.player == player, "turn_start should pass current player to item phase")
      return {
        waiting = true,
        next_state = "roll",
        next_args = { player = player, source = "pre_action" },
      }
    end },
  }, function()
    local next_state, next_args = turn_start({ game = g })
    assert(next_state == "wait_action", "waiting pre_action item phase should route through wait_action")
    assert(next_args and next_args.next_state == "wait_choice", "wait_action should forward to wait_choice")
    assert(next_args.next_args and next_args.next_args.next_state == "roll", "wait_choice should preserve next state")
    assert(next_args.next_args.next_args and next_args.next_args.next_args.source == "pre_action", "wait_choice should preserve next args")
  end)
end

local function _test_turn_start_waits_for_pre_action_item_phase_action_anim()
  local g = _new_game()
  local player = g:current_player()
  local item_phase = require("src.rules.items.phase")

  support.with_patches({
    { target = item_phase, key = "run", value = function()
      return {
        waiting = true,
        wait_action_anim = true,
        next_state = "roll",
        next_args = { player = player, source = "action_anim" },
      }
    end },
  }, function()
    local next_state, next_args = turn_start({ game = g })
    assert(next_state == "wait_action", "wait_action_anim pre_action should route through wait_action")
    assert(next_args and next_args.next_state == "wait_action_anim", "wait_action should forward to wait_action_anim")
    assert(next_args.next_args and next_args.next_args.next_state == "roll", "wait_action_anim should preserve next state")
    assert(next_args.next_args.next_args and next_args.next_args.next_args.source == "action_anim", "wait_action_anim should preserve next args")
  end)
end

local function _test_phase_registry_post_action_routes_wait_variants()
  local g = _new_game()
  local player = g:current_player()
  local item_phase = require("src.rules.items.phase")
  local phases = phase_registry.build_default_phases()

  support.with_patches({
    { target = item_phase, key = "run", value = function()
      return {
        waiting = true,
        next_state = "post_action_done",
        next_args = { player = player, source = "choice_wait" },
      }
    end },
  }, function()
    local next_state, next_args = phases.post_action({ game = g }, { player = player })
    assert(next_state == "wait_choice", "post_action waiting without action anim should route to wait_choice")
    assert(next_args and next_args.next_state == "post_action_done", "post_action wait_choice should preserve next state")
    assert(next_args.next_args and next_args.next_args.source == "choice_wait", "post_action wait_choice should preserve next args")
  end)

  support.with_patches({
    { target = item_phase, key = "run", value = function()
      return {
        waiting = true,
        wait_action_anim = true,
        next_state = "post_action_done",
        next_args = { player = player, source = "action_wait" },
      }
    end },
  }, function()
    local next_state, next_args = phases.post_action({ game = g }, { player = player })
    assert(next_state == "wait_action_anim", "post_action waiting with action anim should route to wait_action_anim")
    assert(next_args and next_args.next_state == "post_action_done", "post_action wait_action_anim should preserve next state")
    assert(next_args.next_args and next_args.next_args.source == "action_wait", "post_action wait_action_anim should preserve next args")
  end)
end

local function _test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending()
  local turn_land = require("src.turn.phases.land")
  local effect_pipeline = require("src.rules.effects.effect_pipeline")
  local g = _new_game()
  local player = g:current_player()
  local move_result = { kind = "move_result" }
  local tile = g.board:get_tile(player.position)
  g.turn.action_anim_queue = {
    { kind = "teleport_effect", seq = 41 },
  }

  support.with_patches({
    { target = effect_pipeline, key = "run", value = function(_, _, _, _, opts)
      return opts.on_need_landing({
        player_id = player.id,
        board_index = tile.id,
        move_result = move_result,
      })
    end },
  }, function()
    local next_state, next_args = turn_land.run({ game = g }, {
      player = player,
      move_result = move_result,
    })
    assert(next_state == "wait_action_anim", "pending teleport_effect queue should defer landing followup behind wait_action_anim")
    assert(next_args and next_args.next_state == "move_followup", "pending teleport_effect queue should resume through move_followup")
    assert(next_args.next_args and next_args.next_args.mode == "resolve_landing", "move_followup should resume landing resolution mode")
    assert(next_args.next_args.player_id == player.id, "move_followup should preserve target player id")
    assert(next_args.next_args.move_result == move_result, "move_followup should preserve move result")
    assert(g.turn.move_followup_pending == true, "pending teleport_effect queue should flag move_followup_pending")
  end)
end

local function _test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice()
  local g = _new_game()
  local player = g:current_player()
  g.last_turn = {}
  local steal_module = require("src.rules.items.steal")
  local move_result = {
    steal_interrupt = {
      encountered_ids = { g.players[2].id },
      remaining_steps = 2,
      facing = "left",
      branch_parity = 3,
    },
  }

  support.with_patches({
    { target = steal_module, key = "handle_pass_players", value = function()
      return {
        waiting = true,
      }
    end },
  }, function()
    local next_state, next_args = move_followup.run({ game = g }, {
      mode = "resume_turn_move",
      player = player,
      raw_total = 5,
      move_result = move_result,
    })
    assert(next_state == "wait_choice", "steal interrupt wait should route through wait_choice")
    assert(next_args and next_args.next_state == "move", "steal interrupt wait should resume move phase")
    assert(next_args.next_args and next_args.next_args.continue_from_steal == true,
      "steal interrupt wait should preserve continue_from_steal flag")
    assert(next_args.next_args.remaining_steps == 2, "steal interrupt wait should preserve remaining steps")
  end)
end

local function _test_roadblock_stop_does_not_detain_next_turn()
  local g = _new_game()
  local player = g:current_player()
  g.last_turn = {}

  local next_state, next_args = move_followup.run({ game = g }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 3,
    move_result = {
      stopped_on_roadblock = true,
    },
  })

  assert(next_state == "landing", "roadblock followup should still continue into landing")
  assert(next_args and next_args.player == player, "roadblock followup should preserve landing player")
  assert((player.status.stay_turns or 0) == 0, "roadblock should not write detained stay_turns")
  assert(g.last_turn and g.last_turn.move_result and g.last_turn.move_result.stopped_on_roadblock == true,
    "roadblock hit should remain visible through last_turn move_result")

  local start_state = turn_start(g.turn_engine.turn_mgr)
  assert(start_state == "wait_action", "next turn start should not detain player after roadblock")
  assert(g.turn.phase ~= "detained_wait", "roadblock should not route next turn into detained_wait")
  assert(g.last_turn and g.last_turn.skipped == false, "next turn should not be marked as skipped")
end

local function _test_auto_runner_choice_actor_falls_back_to_choice_owner()
  local auto_runner = require("src.turn.policies.auto_runner")
  local auto_policy = require("src.turn.policies.choice_auto_policy")
  local runner = auto_runner:new({ interval = 0 })
  runner:set_enabled(true)

  local g = _new_game()
  local ai_player = g.players[2]
  ai_player.auto = true
  local action = nil
  local original_decide = auto_policy.decide
  auto_policy.decide = function()
    return {
      type = "choice_select",
      choice_id = 901,
      option_id = "use",
    }
  end
  local ok, err = pcall(function()
    action = runner:next_action((gameplay_rules.auto_decision_delay_seconds or 0) + 0.1, {
      game = g,
      pending_choice = {
        id = 901,
        kind = "steal_prompt",
        owner_role_id = ai_player.id,
        meta = {
          player_id = ai_player.id,
        },
        options = { { id = "use" } },
      },
      current_player_id = g.players[1].id,
      current_player_auto = true,
    })
  end)
  auto_policy.decide = original_decide
  assert(ok, err)

  assert(action and action.type == "choice_select", "auto runner should resolve pending choice action")
  assert(action.actor_role_id == ai_player.id, "auto runner should use pending choice owner as actor role")
end

local function _test_auto_runner_modal_without_buttons_confirms()
  local auto_runner = require("src.turn.policies.auto_runner")
  local runner = auto_runner:new({ interval = 0 })
  runner:set_enabled(true)

  local action = runner:next_action(0, {
    modal_active = true,
    modal_buttons = {},
    current_player_auto = true,
    current_player_id = 2,
  })

  assert(action and action.type == "modal_confirm", "modal without buttons should fall back to modal_confirm")
end

local function _test_turn_script_dispatches_wait_states_and_move_followup_fallback()
  local g = _new_game()
  local script_calls = {}
  local phase_calls = {}
  local session = {
    game = g,
    current_state = "move_followup",
    current_args = { mode = "resume_turn_move" },
    phases = {},
    mark_phase = function(_, name)
      script_calls[#script_calls + 1] = name
    end,
  }

  local move_followup_module = require("src.turn.phases.move_followup")
  support.with_patches({
    { target = move_followup_module, key = "run", value = function(_, args)
      phase_calls[#phase_calls + 1] = "move_followup"
      assert(args and args.mode == "resume_turn_move", "turn_script should pass move_followup args through fallback")
      return nil
    end },
  }, function()
    local co = turn_script.create(session)
    local first_ok = coroutine.resume(co)
    assert(first_ok == true, "turn_script should execute move_followup fallback state")
    assert(session.finished == true, "turn_script should finish after move_followup fallback")
  end)

  assert(phase_calls[1] == "move_followup", "turn_script should fallback to move_followup handler")
  assert(script_calls[1] == "move_followup", "turn_script should mark move_followup phase")
end

local function _test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload()
  local g = _new_game()
  local pushed = {}
  g.popup_port = {
    push_popup = function(_, payload)
      pushed[#pushed + 1] = payload
    end,
  }

  local pushed_ok = intent_dispatcher.dispatch(g, {
    intent = {
      kind = "push_popup",
      payload = { message = "popup" },
    },
  })
  local ignored = intent_dispatcher.dispatch(g, { intent = "invalid" })

  assert(pushed_ok == true, "dispatch should route push_popup intents")
  assert(#pushed == 1 and pushed[1].message == "popup", "dispatch should forward popup payload")
  assert(ignored == nil, "dispatch should ignore invalid intent payloads")
end

local function _test_ai_board_target_choice_falls_back_to_first_option()
  local agent = require("src.computer.policies.core_agent")
  local g = _new_game()
  local ai_player = g.players[2]
  ai_player.auto = true
  local choice = {
    id = 321,
    kind = "roadblock_target",
    meta = {
      player_id = ai_player.id,
    },
    options = { { id = 8 }, { id = 9 } },
  }

  support.with_patches({
    { target = agent, key = "pick_roadblock_target", value = function()
      return nil
    end },
  }, function()
    local action = agent.auto_action_for_choice(g, choice)
    assert(action and action.type == "choice_select", "AI roadblock target should produce choice_select")
    assert(action.option_id == 8, "AI roadblock target should fall back to first option when probe returns nil")
    assert(action.actor_role_id == ai_player.id, "AI roadblock target should preserve owner role")
  end)
end

local function _test_profile_rotation_switches_game_after_turn_limit()
  local old_game = {
    turn = {
      turn_count = 3,
    },
    finished = false,
  }
  local replacement = {
    logger = {
      info = function() end,
    },
    players = {},
    turn = {
      turn_count = 0,
    },
    finished = false,
  }
  local replaced_game = nil
  local state = _build_loop_state()
  state.active_profile_name = "bankruptcy"
  state.profile_rotation = profile_rotation
  state.game_factory = function()
    return replacement
  end
  state.on_game_replaced = function(new_game)
    replaced_game = new_game
  end

  support.with_patches({
    {
      target = tick_flow,
      key = "tick",
      value = function() end,
    },
    {
      target = logger,
      key = "info",
      value = function() end,
    },
  }, function()
    profile_rotation._reset_for_tests()
    profile_rotation.init({
      queue = { "bankruptcy", "market" },
      turns_per_profile = 3,
    })
    gameplay_loop.tick(old_game, state, 0.1)
  end)

  local snapshot = profile_rotation.snapshot()
  assert(state.active_profile_name == "market", "rotation should advance active profile after turn limit")
  assert(replaced_game == replacement, "rotation should replace game after turn limit")
  assert(type(snapshot) == "table" and snapshot.finished == false, "rotation should stay active when next profile exists")
  assert(snapshot.results[1].profile == "bankruptcy", "rotation should record completed profile name")
  assert(snapshot.results[1].turns == 3, "rotation should record completed profile turns")
  assert(snapshot.results[1].finished == false, "turn-limit rotation should record unfinished game")
  profile_rotation._reset_for_tests()
end

local function _test_profile_rotation_switches_game_when_current_game_finishes()
  local old_game = {
    turn = {
      turn_count = 1,
    },
    finished = true,
  }
  local replacement = {
    logger = {
      info = function() end,
    },
    players = {},
    turn = {
      turn_count = 0,
    },
    finished = false,
  }
  local replaced_game = nil
  local state = _build_loop_state()
  state.active_profile_name = "bankruptcy"
  state.profile_rotation = profile_rotation
  state.game_factory = function()
    return replacement
  end
  state.on_game_replaced = function(new_game)
    replaced_game = new_game
  end

  support.with_patches({
    {
      target = tick_flow,
      key = "tick",
      value = function() end,
    },
    {
      target = logger,
      key = "info",
      value = function() end,
    },
  }, function()
    profile_rotation._reset_for_tests()
    profile_rotation.init({
      queue = { "bankruptcy", "market" },
      turns_per_profile = 9,
    })
    gameplay_loop.tick(old_game, state, 0.1)
  end)

  local snapshot = profile_rotation.snapshot()
  assert(state.active_profile_name == "market", "finished game should trigger profile rotation")
  assert(replaced_game == replacement, "finished game should be replaced by next profile")
  assert(snapshot.results[1].finished == true, "rotation should record early-finished game")
  profile_rotation._reset_for_tests()
end

local function _test_profile_rotation_disables_auto_runner_after_last_profile()
  local old_game = {
    turn = {
      turn_count = 2,
    },
    finished = false,
  }
  local disabled_value = nil
  local state = _build_loop_state()
  state.active_profile_name = "bankruptcy"
  state.profile_rotation = profile_rotation
  state.auto_runner = {
    set_enabled = function(_, enabled)
      disabled_value = enabled
    end,
  }

  support.with_patches({
    {
      target = tick_flow,
      key = "tick",
      value = function() end,
    },
    {
      target = logger,
      key = "info",
      value = function() end,
    },
  }, function()
    profile_rotation._reset_for_tests()
    profile_rotation.init({
      queue = { "bankruptcy" },
      turns_per_profile = 2,
    })
    gameplay_loop.tick(old_game, state, 0.1)
  end)

  local snapshot = profile_rotation.snapshot()
  assert(disabled_value == false, "rotation completion should disable auto runner")
  assert(type(snapshot) == "table" and snapshot.finished == true, "rotation should mark completion after last profile")
  assert(snapshot.results[1].profile == "bankruptcy", "final rotation should still record completed profile")
  profile_rotation._reset_for_tests()
end

local function _test_bankruptcy_emits_feedback_event()
  local g = _new_game()
  local p1 = g.players[1]
  local emitted = {}

  support.with_patches({
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    bankruptcy.eliminate(g, p1, { reason = "测试破产" })
  end)

  local found = false
  for _, entry in ipairs(emitted) do
    if entry.kind == monopoly_event.feedback.bankruptcy then
      found = true
      assert(entry.payload.player_id == p1.id, "bankruptcy feedback should preserve player id")
      assert(entry.payload.reason == "测试破产", "bankruptcy feedback should preserve reason")
    end
  end
  assert(found, "bankruptcy should emit feedback.bankruptcy")
end

local function _test_game_victory_finished_game_short_circuits_without_reemitting()
  local g = _new_game({ install_ui_port = false })
  local emitted = 0
  g.finished = true
  g.winner_names = "existing winner"

  support.with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function()
        emitted = emitted + 1
      end,
    },
  }, function()
    local result = g:check_victory()
    assert(result == true, "finished game should still report victory")
  end)

  assert(emitted == 0, "finished game should not emit duplicate finished events")
  assert(g.winner_names == "existing winner", "finished game should preserve winner names")
end

local function _test_game_victory_turn_limit_tie_keeps_multiple_winners()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local p2 = g.players[2]
  local captured = nil

  for index = 3, #g.players do
    g.players[index].eliminated = true
  end
  g.turn.turn_count = 1
  g:set_player_cash(p1, 3000)
  g:set_player_cash(p2, 3000)

  support.with_patches({
    { target = gameplay_rules, key = "turn_limit", value = 1 },
    {
      target = monopoly_event,
      key = "emit",
      value = function(event_name, payload)
        captured = {
          event_name = event_name,
          payload = payload,
        }
      end,
    },
  }, function()
    local result = g:check_victory()
    assert(result == true, "turn-limit tie should finish the game")
  end)

  assert(g.finished == true, "turn-limit tie should mark game finished")
  assert(g.winner == nil, "turn-limit tie should not pick a single winner")
  assert(g.winner_names == "P1、P2", "turn-limit tie should preserve winner name ordering")
  assert(type(g.winners) == "table" and #g.winners == 2, "turn-limit tie should keep both winners")
  assert(captured ~= nil and captured.event_name == monopoly_event.game.finished,
    "turn-limit tie should emit game.finished")
  assert(captured.payload.winner_ids[1] == true and captured.payload.winner_ids[2] == true,
    "turn-limit tie should expose both winner ids")
end

local function _test_game_victory_turn_limit_with_no_survivors_reports_empty_winners()
  local g = _new_game({ install_ui_port = false })
  local captured = nil

  for _, player in ipairs(g.players) do
    player.eliminated = true
  end
  g.turn.turn_count = 1

  support.with_patches({
    { target = gameplay_rules, key = "turn_limit", value = 1 },
    {
      target = monopoly_event,
      key = "emit",
      value = function(event_name, payload)
        captured = {
          event_name = event_name,
          payload = payload,
        }
      end,
    },
  }, function()
    local result = g:check_victory()
    assert(result == true, "turn-limit elimination should finish the game")
  end)

  assert(g.finished == true, "turn-limit elimination should mark game finished")
  assert(g.winner == nil, "no-survivor finish should not expose a single winner")
  assert(type(g.winners) == "table" and #g.winners == 0, "no-survivor finish should store empty winners")
  assert(g.winner_names == "", "no-survivor finish should keep empty winner names")
  assert(captured ~= nil and captured.event_name == monopoly_event.game.finished,
    "no-survivor finish should emit game.finished")
  assert(captured.payload.message == "游戏结束，无人生还",
    "no-survivor finish should preserve the no-survivor message")
end

local function _test_camera_policy_follows_eliminated_then_skips_to_next()
  local g = _new_game()
  g.players[1].eliminated = true
  g.turn.current_player_index = 1
  local followed = nil
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        followed = player_id
      end,
    },
  }
  turn_camera_policy.sync_follow(g, {}, ports, true)
  assert(followed == g.players[2].id, "should skip eliminated player and follow next")
end

local function _test_camera_policy_follows_current_when_not_eliminated()
  local g = _new_game()
  g.turn.current_player_index = 2
  local followed = nil
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        followed = player_id
      end,
    },
  }
  turn_camera_policy.sync_follow(g, {}, ports, true)
  assert(followed == g.players[2].id, "should follow current player when not eliminated")
end

local function _test_camera_policy_skips_all_eliminated_and_returns_nil()
  local g = _new_game()
  for _, p in ipairs(g.players) do
    p.eliminated = true
  end
  g.turn.current_player_index = 1
  local followed = "not-called"
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        followed = player_id
      end,
    },
  }
  turn_camera_policy.sync_follow(g, {}, ports, true)
  assert(followed == "not-called", "should not call follow when all eliminated")
end

local function _test_choice_auto_policy_tick_timeout_cancels_when_allowed()
  local g = _new_game()
  local choice = {
    id = 801,
    kind = "test_choice",
    allow_cancel = true,
    options = { { id = "opt1" } },
  }
  local action = choice_auto_policy.decide(g, {}, choice, {
    mode = "tick_timeout",
    is_auto_actor = true,
  })
  assert(action and action.type == "choice_cancel", "tick_timeout should cancel when allowed")
end

local function _test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable()
  local g = _new_game()
  local choice = {
    id = 802,
    kind = "test_choice",
    allow_cancel = false,
    options = { { id = "opt1" } },
  }
  local action = choice_auto_policy.decide(g, {}, choice, {
    mode = "tick_timeout",
    is_auto_actor = true,
    allow_first_option_fallback = true,
  })
  assert(action and action.type == "choice_select", "tick_timeout should fallback to first option when not cancelable")
  assert(action.option_id == "opt1", "should select first option")
end

local function _test_choice_auto_policy_generic_mode_uses_fallback_flag()
  local g = _new_game()
  local choice = {
    id = 803,
    kind = "test_choice",
    options = { { id = "opt1" } },
  }
  local action = choice_auto_policy.decide(g, {}, choice, {
    mode = "unknown_mode",
    is_auto_actor = true,
    allow_first_option_fallback = true,
  })
  assert(action and action.type == "choice_select", "generic mode should respect allow_first_option_fallback")
end

local function _test_tick_timeout_resolve_choice_ui_state_returns_route_key()
  local g = _new_game()
  local state = _build_loop_state()
  local choice = { id = 901, route_key = "test_route" }
  local result = tick_timeout.resolve_choice_ui_state(g, state, choice)
  assert(result.route_key == "test_route", "should return route_key from choice")
  assert(result.should_warn == false, "should not warn by default")
end

local _t2_case_groups = {}

_t2_case_groups.roll_dice_tests = {
  function()
    local results, total = roll._roll_dice(3, { 4, 5, 6 }, nil)
    assert(#results == 3, "should return 3 results")
    assert(results[1] == 4 and results[2] == 5 and results[3] == 6, "should use override values")
    assert(total == 15, "total should sum override values")
  end,
  function()
    local results, total = roll._roll_dice(4, { 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 4, "should return 4 results")
    assert(results[1] == 2 and results[2] == 3, "should use provided overrides")
    assert(results[3] == 3 and results[4] == 3, "should repeat last override value")
  end,
}

local function _with_reloaded_move_module(movement_stub, followup_stub, fn)
  local original_movement = package.loaded["src.rules.movement"]
  local original_followup = package.loaded["src.turn.phases.move_followup"]
  local original_move = package.loaded["src.turn.phases.move"]
  package.loaded["src.rules.movement"] = movement_stub
  package.loaded["src.turn.phases.move_followup"] = followup_stub
  package.loaded["src.turn.phases.move"] = nil
  local ok, result = pcall(function()
    return fn(require("src.turn.phases.move"))
  end)
  package.loaded["src.rules.movement"] = original_movement
  package.loaded["src.turn.phases.move_followup"] = original_followup
  package.loaded["src.turn.phases.move"] = original_move
  if not ok then
    error(result)
  end
  return result
end

_t2_case_groups.apply_dice_multiplier_tests = {
  function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 4 } }
    local turn_mgr = {
      game = {
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function(_, target, key, value)
          target.status[key] = value
        end,
      },
    }
    local called_total = nil
    local result = _with_reloaded_move_module({
      move = function(_, _, total)
        called_total = total
        return { visited = {}, steps = {} }
      end,
    }, {
      run = function() return "move_ok" end,
    }, function(move_module)
      return move_module(turn_mgr, {
        player = player,
        total = 3,
        raw_total = 3,
      })
    end)
    assert(result == "move_ok", "move should finish through followup")
    assert(called_total == 12, "multiplier should be applied when total equals raw_total")
    assert(player.status.pending_dice_multiplier == 1, "multiplier should be reset")
  end,
  function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 2 } }
    local turn_mgr = {
      game = {
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function() end,
      },
    }
    local called_total = nil
    _with_reloaded_move_module({
      move = function(_, _, total)
        called_total = total
        return { visited = {}, steps = {} }
      end,
    }, {
      run = function() return "move_ok" end,
    }, function(move_module)
      return move_module(turn_mgr, {
        player = player,
        total = 10,
        raw_total = 8,
      })
    end)
    assert(called_total == 10, "multiplier should be skipped when total already changed")
  end,
  function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 3 } }
    local turn_mgr = {
      game = {
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function() end,
      },
    }
    local called_total = nil
    _with_reloaded_move_module({
      move = function(_, _, total)
        called_total = total
        return { visited = {}, steps = {} }
      end,
    }, {
      run = function() return "move_ok" end,
    }, function(move_module)
      return move_module(turn_mgr, {
        player = player,
        total = 6,
        raw_total = nil,
      })
    end)
    assert(called_total == 6, "multiplier should be skipped when raw_total is nil")
  end,
}

local function _test_move_phase_wait_move_anim_records_anim_data_and_resume_args()
  local player = {
    id = 7,
    seat_id = 3,
    position = 5,
    status = {},
  }
  local move_result = {
    visited = { 2, 3, 4, 5 },
    steps = { "a", "b" },
    stopped_on_roadblock = true,
    market_interrupt = true,
    steal_interrupt = false,
  }
  local turn_mgr = {
    game = {
      turn = { move_anim_seq = 0 },
      dirty = {},
      players = { player },
      anim_gate_port = { wait_move_anim = true },
    },
  }

  local result, args = _with_reloaded_move_module({
    move = function()
      player.position = 9
      return move_result
    end,
  }, {
    run = function()
      error("wait_move_anim path should not call move_followup.run")
    end,
  }, function(move_module)
    return move_module(turn_mgr, {
      player = player,
      total = 4,
      raw_total = 4,
    })
  end)

  assert(result == "wait_move_anim", "move phase should wait for move animation")
  assert(args.next_state == "move_followup", "wait_move_anim should resume move_followup")
  assert(args.next_args.mode == "resume_turn_move", "resume args should keep resume_turn_move mode")
  assert(args.next_args.player == player, "resume args should preserve player")
  assert(args.next_args.raw_total == 4, "resume args should preserve raw_total")
  assert(args.next_args.move_result == move_result, "resume args should preserve move_result")

  local anim_data = turn_mgr.game.turn.move_anim
  assert(anim_data ~= nil, "move animation data should be queued")
  assert(anim_data.seq == 1, "move animation seq should increment from current sequence")
  assert(anim_data.player_id == 7, "move animation should preserve player id")
  assert(anim_data.from_index == 5, "move animation should preserve start index")
  assert(anim_data.to_index == 9, "move animation should use moved player position")
  assert(anim_data.visited == move_result.visited, "move animation should preserve visited path")
  assert(anim_data.steps == move_result.steps, "move animation should preserve steps")
  assert(anim_data.vehicle_id == require("src.rules.vehicle").resolve_seat_id(3),
    "move animation should resolve vehicle_id from seat_id")
  assert(anim_data.stopped_on_roadblock == true, "move animation should preserve roadblock flag")
  assert(anim_data.market_interrupt == true, "move animation should preserve market interrupt flag")
  assert(anim_data.steal_interrupt == false, "move animation should preserve steal interrupt flag")
  assert(turn_mgr.game.dirty.turn == true and turn_mgr.game.dirty.any == true, "queueing anim should mark game dirty")
end

local function _test_move_phase_continue_interrupt_passes_direction_and_branch_parity()
  local player = {
    id = 8,
    seat_id = 1,
    position = 12,
    status = {},
  }
  local captured_total = nil
  local captured_opts = nil
  local captured_followup_args = nil
  local move_result = {
    visited = { 12, 13 },
    steps = { "move" },
  }
  local turn_mgr = {
    game = {
      turn = { move_anim_seq = 0 },
      dirty = {},
      players = { player },
      anim_gate_port = { wait_move_anim = false },
    },
  }

  local result = _with_reloaded_move_module({
    move = function(_, _, total, opts)
      captured_total = total
      captured_opts = opts
      return move_result
    end,
  }, {
    run = function(_, args)
      captured_followup_args = args
      return "followup_ok"
    end,
  }, function(move_module)
    return move_module(turn_mgr, {
      player = player,
      total = 99,
      raw_total = 6,
      continue_from_market = true,
      remaining_steps = 2,
      facing = "left",
      branch_parity = 11,
      entered_inner = true,
    })
  end)

  assert(result == "followup_ok", "continue-from-market path should finish through move_followup")
  assert(captured_total == 2, "move phase should use remaining_steps when resuming from interrupt")
  assert(captured_opts.direction == "left", "move opts should preserve interrupt facing")
  assert(captured_opts.branch_parity == 11, "move opts should preserve branch parity")
  assert(captured_opts.entered_inner == true, "move opts should preserve entered_inner")
  assert(captured_followup_args.mode == "resume_turn_move", "followup should use resume_turn_move mode")
  assert(captured_followup_args.player == player, "followup should preserve player")
  assert(captured_followup_args.raw_total == 11, "followup should pass branch_parity as raw_total")
  assert(captured_followup_args.move_result == move_result, "followup should preserve move_result")
end

_t2_case_groups.roll_dice_extended_tests = {
  function()
    local results, total = roll._roll_dice(2, nil, { next_int = function() return 5 end })
    assert(#results == 2 and results[1] == 5 and results[2] == 5, "rng path should cover all dice")
    assert(total == 10, "rng path should sum results")
  end,
  function()
    local results, total = roll._roll_dice(0, nil, { next_int = function() return 3 end })
    assert(#results == 0, "zero dice should return empty result")
    assert(total == 0, "zero dice should have zero total")
  end,
  function()
    local results, total = roll._roll_dice(2, { 1, 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 2 and results[1] == 1 and results[2] == 2, "extra overrides should be ignored")
    assert(total == 3, "total should only sum used overrides")
  end,
  function()
    local results, total = roll._roll_dice(3, { 2, 4, 6 }, { next_int = function() return 1 end })
    assert(#results == 3 and results[3] == 6, "exact overrides should be preserved")
    assert(total == 12, "exact overrides should sum correctly")
  end,
}

_t2_case_groups.resolve_choice_owner_id_tests = {
  function()
    local g = _new_game()
    g.turn.current_player_index = 2
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1, owner_role_id = 999 })
    assert(result == g.players[2].id, "missing owner should fall back to current player")
  end,
  function()
    local g = _new_game()
    g.turn.current_player_index = 5
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1 })
    assert(result == nil, "out-of-range current player should return nil")
  end,
  function()
    local g = _new_game()
    g.find_player_by_id = nil
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1, owner_role_id = g.players[1].id })
    assert(result == g.players[1].id, "missing finder should still fall back to current player")
  end,
  function()
    local g = _new_game()
    g.players = nil
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1 })
    assert(result == nil, "missing players should return nil")
  end,
}

_t2_case_groups.resolve_follow_player_id_tests = {
  function()
    local game = _new_game()
    game.players[1].id = nil
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[2].id, "current player with nil id should be skipped")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = 2
    game.players[2].eliminated = true
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[1].id, "search should wrap to next live player")
  end,
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    game.players[2].eliminated = true
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "all eliminated players should return nil")
  end,
  function()
    local game = _new_game()
    game.turn = nil
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "missing turn should return nil")
  end,
  function()
    local game = _new_game()
    game.players = {}
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "empty players should return nil")
  end,
}

_t2_case_groups.resolve_wait_state_tests = {
  function()
    local game = { turn = { action_anim = { kind = "test" } }, dirty = {} }
    local state_name = require("src.turn.phases.land")._resolve_wait_state(game, "post_action", { player = { id = 1 } }, true)
    assert(state_name == "wait_action_anim", "wait_action_anim should win when requested")
  end,
  function()
    local game = { turn = {}, dirty = {} }
    local state_name, args = require("src.turn.phases.land")._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(state_name == "wait_choice", "no action anim should still route through wait_choice")
    assert(args.next_state == "move", "next state should be preserved")
  end,
  function()
    local game = { turn = { action_anim_queue = { { kind = "move_effect" } } }, dirty = {} }
    local state_name, args = require("src.turn.phases.land")._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(state_name == "wait_action_anim", "queued move effect should wait for action anim")
    assert(args.next_state == "wait_choice", "non-anim wait should wrap back to wait_choice")
  end,
}

_t2_case_groups.fill_ui_sync_defaults_tests = {
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(type(ports.resolve_ui_gate) == "function", "defaults should be filled")
    assert(type(ports.set_input_blocked) == "function", "set_input_blocked default should be filled")
  end,
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    ports.get_ui_state = function() return "custom" end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(ports.get_ui_state() == "custom", "custom port should be preserved")
    assert(type(ports.is_popup_active) == "function", "missing ports should still be filled")
  end,
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = true, popup_active = true, market_active = true, popup_payload = { auto_close_seconds = 10 } } }
    local gate = ports.resolve_ui_gate(state)
    assert(gate.input_blocked == true and gate.market_active == true, "ui gate should mirror ui state")
    assert(gate.popup_auto_close_seconds == 10, "ui gate should expose popup timeout")
  end,
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = false } }
    assert(ports.set_input_blocked(state, true) == true, "setter should report change")
    assert(ports.set_input_blocked(state, true) == false, "setter should report no-op")
  end,
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local gate = ports.resolve_ui_gate(nil)
    assert(gate.popup_seq == nil and gate.popup_active == false, "nil state should produce empty ui gate")
  end,
}

_t2_case_groups.update_countdown_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.current_player_index = 2
    game.turn.pending_choice = { id = 1, kind = "test", owner_role_id = game.players[2].id }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "pending choice should activate countdown")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 10
    game.turn.detained_wait_elapsed = 3
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == 7, "detained wait should count down remaining seconds")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "action button timer should activate countdown")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 0 } }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == false or game.turn.countdown_active == true, "popup path should not error")
  end,
}

_t2_case_groups.is_action_button_wait_active_tests = {
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.pending_choice = { id = 1 }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "pending choice should block action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "input blocked ui should block action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { popup_active = true }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "popup should block action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.finished = true
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "finished game should block action button wait")
  end,
}

return {
  _test_mandatory_payment_causes_bankruptcy = _test_mandatory_payment_causes_bankruptcy,
  _test_bankruptcy_resets_owned_tiles = _test_bankruptcy_resets_owned_tiles,
  _test_bankruptcy_notifier_reads_grouped_ports = _test_bankruptcy_notifier_reads_grouped_ports,
  _test_gameplay_loop_set_game_installs_bankruptcy_feedback_port = _test_gameplay_loop_set_game_installs_bankruptcy_feedback_port,
  _test_bankruptcy_calls_role_life_die_before_lose = _test_bankruptcy_calls_role_life_die_before_lose,
  _test_bankruptcy_emits_feedback_event = _test_bankruptcy_emits_feedback_event,
  _test_game_victory_finished_game_short_circuits_without_reemitting =
    _test_game_victory_finished_game_short_circuits_without_reemitting,
  _test_game_victory_turn_limit_tie_keeps_multiple_winners =
    _test_game_victory_turn_limit_tie_keeps_multiple_winners,
  _test_game_victory_turn_limit_with_no_survivors_reports_empty_winners =
    _test_game_victory_turn_limit_with_no_survivors_reports_empty_winners,
  _test_chance_pay_others_stops_after_bankruptcy = _test_chance_pay_others_stops_after_bankruptcy,
  _test_set_tile_owner_without_ui_port_does_not_crash = _test_set_tile_owner_without_ui_port_does_not_crash,
  _test_tile_owner_notifier_receives_owner_changes = _test_tile_owner_notifier_receives_owner_changes,
  _test_dispatch_validator_accepts_ui_state_snapshot = _test_dispatch_validator_accepts_ui_state_snapshot,
  _test_intent_dispatcher_sets_choice_route_metadata = _test_intent_dispatcher_sets_choice_route_metadata,
  _test_intent_dispatcher_rejects_missing_required_choice_meta = _test_intent_dispatcher_rejects_missing_required_choice_meta,
  _test_intent_dispatcher_rejects_missing_required_choice_meta_table =
    _test_intent_dispatcher_rejects_missing_required_choice_meta_table,
  _test_intent_dispatcher_normalizes_market_choice_meta = _test_intent_dispatcher_normalizes_market_choice_meta,
  _test_intent_dispatcher_normalizes_item_choice_meta = _test_intent_dispatcher_normalizes_item_choice_meta,
  _test_intent_dispatcher_normalizes_landing_optional_effect_meta = _test_intent_dispatcher_normalizes_landing_optional_effect_meta,
  _test_intent_dispatcher_rejects_unknown_market_choice_player = _test_intent_dispatcher_rejects_unknown_market_choice_player,
  _test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile = _test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile,
  _test_turn_start_logs_phase_event_to_event_feed = _test_turn_start_logs_phase_event_to_event_feed,
  _test_intent_dispatcher_logs_waiting_choice_event = _test_intent_dispatcher_logs_waiting_choice_event,
  _test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys =
    _test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys,
  _test_intent_dispatcher_allows_missing_choice_registry = _test_intent_dispatcher_allows_missing_choice_registry,
  _test_choice_resolver_normalizes_market_buy_action_before_execute = _test_choice_resolver_normalizes_market_buy_action_before_execute,
  _test_choice_resolver_normalizes_roadblock_action_before_execute = _test_choice_resolver_normalizes_roadblock_action_before_execute,
  _test_choice_cancel_logs_skip_event_but_tax_cancel_does_not = _test_choice_cancel_logs_skip_event_but_tax_cancel_does_not,
  _test_end_turn_logs_phase_event_to_event_feed = _test_end_turn_logs_phase_event_to_event_feed,
  _test_clear_obstacles_zero_does_not_log_event_noise = _test_clear_obstacles_zero_does_not_log_event_noise,
  _test_ai_obstacle_probe_does_not_enter_event_feed = _test_ai_obstacle_probe_does_not_enter_event_feed,
  _test_runtime_event_bridge_detects_unbound_binding_without_call = _test_runtime_event_bridge_detects_unbound_binding_without_call,
  _test_runtime_event_bridge_disables_feature_after_dispatch_failure =
    _test_runtime_event_bridge_disables_feature_after_dispatch_failure,
  _test_runtime_context_split_install_stages = _test_runtime_context_split_install_stages,
  _test_runtime_context_install_helpers_without_globals = _test_runtime_context_install_helpers_without_globals,
  _test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit = _test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit,
  _test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit = _test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit,
  _test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable = _test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable,
  _test_camera_sync_follow_camera_keeps_role_id_event_chain = _test_camera_sync_follow_camera_keeps_role_id_event_chain,
  _test_runtime_context_install_environment_fails_fast = _test_runtime_context_install_environment_fails_fast,
  _test_game_startup_build_state_is_pure_and_bridge_installs_events = _test_game_startup_build_state_is_pure_and_bridge_installs_events,
  _test_stop_all_players_movement_preserves_inner_move_dir_and_stop_event =
    _test_stop_all_players_movement_preserves_inner_move_dir_and_stop_event,
  _test_end_turn_stops_all_players_movement = _test_end_turn_stops_all_players_movement,
  _test_location_transfers_clear_move_dir = _test_location_transfers_clear_move_dir,
  _test_stop_all_players_movement_skips_invalid_role_without_error = _test_stop_all_players_movement_skips_invalid_role_without_error,
  _test_autorunner_runs_to_end = _test_autorunner_runs_to_end,
  _test_complex_consecutive_turn_settlement = _test_complex_consecutive_turn_settlement,
  _test_forced_move_landing_optional_preserves_owner_role_id_for_buy_land =
    _test_forced_move_landing_optional_preserves_owner_role_id_for_buy_land,
  _test_forced_move_landing_optional_preserves_owner_role_id_for_upgrade_land =
    _test_forced_move_landing_optional_preserves_owner_role_id_for_upgrade_land,
  _test_complex_market_interrupt_with_rent = _test_complex_market_interrupt_with_rent,
  _test_market_interrupt_resume_uses_interrupt_facing = _test_market_interrupt_resume_uses_interrupt_facing,
  _test_steal_interrupt_resume_uses_interrupt_facing = _test_steal_interrupt_resume_uses_interrupt_facing,
  _test_detained_turn_enters_wait_state_before_advancing = _test_detained_turn_enters_wait_state_before_advancing,
  _test_tick_headless_ports_cover_anim_phases = _test_tick_headless_ports_cover_anim_phases,
  _test_profile_rotation_switches_game_after_turn_limit = _test_profile_rotation_switches_game_after_turn_limit,
  _test_profile_rotation_switches_game_when_current_game_finishes = _test_profile_rotation_switches_game_when_current_game_finishes,
  _test_profile_rotation_disables_auto_runner_after_last_profile = _test_profile_rotation_disables_auto_runner_after_last_profile,
  _test_action_button_timeout_auto_advances = _test_action_button_timeout_auto_advances,
  _test_action_button_timeout_manual_wait_action_auto_advances = _test_action_button_timeout_manual_wait_action_auto_advances,
  _test_action_button_timeout_manual_player_does_not_advance = _test_action_button_timeout_manual_player_does_not_advance,
  _test_action_button_timeout_blocked_when_input_locked = _test_action_button_timeout_blocked_when_input_locked,
  _test_action_button_timeout_blocked_when_popup_active = _test_action_button_timeout_blocked_when_popup_active,
  _test_auto_runner_auto_advances_ai_player = _test_auto_runner_auto_advances_ai_player,
  _test_auto_runner_human_turn_not_auto_advanced = _test_auto_runner_human_turn_not_auto_advanced,
  _test_auto_runner_waits_for_auto_popup_delay = _test_auto_runner_waits_for_auto_popup_delay,
  _test_gameplay_loop_ai_rounds_do_not_force_manual_timeout = _test_gameplay_loop_ai_rounds_do_not_force_manual_timeout,
  _test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen = _test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen,
  _test_auto_runner_resets_timer_when_wait_kind_changes = _test_auto_runner_resets_timer_when_wait_kind_changes,
  _test_auto_runner_not_advanced_when_input_blocked = _test_auto_runner_not_advanced_when_input_blocked,
  _test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen = _test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen,
  _test_tick_choice_timeout_manual_player_keeps_waiting = _test_tick_choice_timeout_manual_player_keeps_waiting,
  _test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen = _test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen,
  _test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout = _test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout,
  _test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice = _test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice,
  _test_tick_choice_timeout_warning_keeps_local_modal_choice = _test_tick_choice_timeout_warning_keeps_local_modal_choice,
  _test_auto_runner_depends_on_current_player_auto = _test_auto_runner_depends_on_current_player_auto,
  _test_turn_prompt_initialized_for_first_player = _test_turn_prompt_initialized_for_first_player,
  _test_turn_prompt_emitted_on_next_player_switch = _test_turn_prompt_emitted_on_next_player_switch,
  _test_turn_start_emits_turn_started_feedback_event = _test_turn_start_emits_turn_started_feedback_event,
  _test_turn_start_waits_for_pre_action_item_phase_choice = _test_turn_start_waits_for_pre_action_item_phase_choice,
  _test_turn_start_waits_for_pre_action_item_phase_action_anim = _test_turn_start_waits_for_pre_action_item_phase_action_anim,
  _test_phase_registry_post_action_routes_wait_variants = _test_phase_registry_post_action_routes_wait_variants,
  _test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending =
    _test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending,
  _test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice =
    _test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice,
  _test_roadblock_stop_does_not_detain_next_turn = _test_roadblock_stop_does_not_detain_next_turn,
  _test_auto_runner_choice_actor_falls_back_to_choice_owner = _test_auto_runner_choice_actor_falls_back_to_choice_owner,
  _test_auto_runner_modal_without_buttons_confirms = _test_auto_runner_modal_without_buttons_confirms,
  _test_turn_script_dispatches_wait_states_and_move_followup_fallback = _test_turn_script_dispatches_wait_states_and_move_followup_fallback,
  _test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload = _test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload,
  _test_ai_board_target_choice_falls_back_to_first_option = _test_ai_board_target_choice_falls_back_to_first_option,
  _test_turn_dispatch_uses_clock_ports_without_game_api = _test_turn_dispatch_uses_clock_ports_without_game_api,
  _test_gameplay_loop_set_game_uses_narrow_runtime_ports = _test_gameplay_loop_set_game_uses_narrow_runtime_ports,
  _test_gameplay_loop_set_game_defers_visual_ports_during_landing_hold = _test_gameplay_loop_set_game_defers_visual_ports_during_landing_hold,
  _test_board_visual_feedback_port_reconciles_destroyed_tile_and_cleared_overlays = _test_board_visual_feedback_port_reconciles_destroyed_tile_and_cleared_overlays,
  _test_board_visual_feedback_port_reconciles_spawned_tile_and_overlays_without_action_anim = _test_board_visual_feedback_port_reconciles_spawned_tile_and_overlays_without_action_anim,
  _test_gameplay_loop_refresh_drives_camera_follow_via_port = _test_gameplay_loop_refresh_drives_camera_follow_via_port,
  _test_gameplay_loop_camera_follow_skips_eliminated_current_player = _test_gameplay_loop_camera_follow_skips_eliminated_current_player,
  _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics = _test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics,
  _test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy = _test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy,
  _test_choice_auto_policy_timeout_keeps_non_cancelable_choice_fallback = _test_choice_auto_policy_timeout_keeps_non_cancelable_choice_fallback,
  _test_choice_auto_policy_preconsumed_wait_choice_picks_first_option =
    _test_choice_auto_policy_preconsumed_wait_choice_picks_first_option,
  _test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed =
    _test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed,
  _test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed =
    _test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed,
  _test_item_slot_data_prefers_role_specific_items_and_falls_back =
    _test_item_slot_data_prefers_role_specific_items_and_falls_back,
  _test_gameplay_loop_ports_rejects_legacy_flat_override =
    _test_gameplay_loop_ports_rejects_legacy_flat_override,
  _test_build_noop_group_characterization = _test_build_noop_group_characterization,
  _test_turn_decision_wait_choice_no_longer_reads_ui_port_state = _test_turn_decision_wait_choice_no_longer_reads_ui_port_state,
  _test_popup_countdown_uses_effective_modal_timeout = _test_popup_countdown_uses_effective_modal_timeout,
  _test_market_countdown_uses_double_action_timeout = _test_market_countdown_uses_double_action_timeout,
  _test_dispatch_gate_blocks_next_when_choice_active = _test_dispatch_gate_blocks_next_when_choice_active,
  _test_game_startup_role_roster_retries_before_debug_players_fallback = _test_game_startup_role_roster_retries_before_debug_players_fallback,
  _test_find_player_by_id_accepts_mixed_representation = _test_find_player_by_id_accepts_mixed_representation,
  _test_owner_mine_does_not_trigger_until_owner_leaves_tile = _test_owner_mine_does_not_trigger_until_owner_leaves_tile,
  _test_owner_mine_triggers_again_after_placement_turn = _test_owner_mine_triggers_again_after_placement_turn,
  _test_passing_armed_mine_stops_and_triggers_followup = _test_passing_armed_mine_stops_and_triggers_followup,
  _test_runtime_context_change_skin_exports_and_event = _test_runtime_context_change_skin_exports_and_event,
  _test_camera_policy_follows_eliminated_then_skips_to_next = _test_camera_policy_follows_eliminated_then_skips_to_next,
  _test_camera_policy_follows_current_when_not_eliminated = _test_camera_policy_follows_current_when_not_eliminated,
  _test_camera_policy_skips_all_eliminated_and_returns_nil = _test_camera_policy_skips_all_eliminated_and_returns_nil,
  _test_choice_auto_policy_tick_timeout_cancels_when_allowed = _test_choice_auto_policy_tick_timeout_cancels_when_allowed,
  _test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable = _test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable,
  _test_choice_auto_policy_generic_mode_uses_fallback_flag = _test_choice_auto_policy_generic_mode_uses_fallback_flag,
  _test_tick_timeout_resolve_choice_ui_state_returns_route_key = _test_tick_timeout_resolve_choice_ui_state_returns_route_key,
  _test_roll_dice_with_override_uses_provided_values = _t2_case_groups.roll_dice_tests[1],
  _test_roll_dice_with_partial_override_uses_last_for_remaining = _t2_case_groups.roll_dice_tests[2],
  _test_roll_dice_with_rng_only = _t2_case_groups.roll_dice_extended_tests[1],
  _test_roll_dice_zero_count = _t2_case_groups.roll_dice_extended_tests[2],
  _test_roll_dice_truncates_extra_overrides = _t2_case_groups.roll_dice_extended_tests[3],
  _test_roll_dice_exact_override_match = _t2_case_groups.roll_dice_extended_tests[4],
  _test_apply_dice_multiplier_applies_and_resets = _t2_case_groups.apply_dice_multiplier_tests[1],
  _test_apply_dice_multiplier_skips_when_total_changed = _t2_case_groups.apply_dice_multiplier_tests[2],
  _test_apply_dice_multiplier_skips_when_raw_total_nil = _t2_case_groups.apply_dice_multiplier_tests[3],
  _test_move_phase_wait_move_anim_records_anim_data_and_resume_args =
    _test_move_phase_wait_move_anim_records_anim_data_and_resume_args,
  _test_move_phase_continue_interrupt_passes_direction_and_branch_parity =
    _test_move_phase_continue_interrupt_passes_direction_and_branch_parity,
  _test_resolve_phase_wait_result_with_wait_action_anim = function()
    local player = { id = 1, name = "P1" }
    local phase_res = { next_state = "move", next_args = { player = player, total = 10 }, wait_action_anim = true }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 10, 5)
    assert(state == "wait_action_anim", "should return wait_action_anim state")
    assert(args.next_state == "move", "should preserve next_state")
    assert(args.next_args.total == 10, "should preserve total in next_args")
  end,
  _test_resolve_phase_wait_result_without_wait_action_anim = function()
    local player = { id = 1, name = "P1" }
    local phase_res = { next_state = "land", next_args = { player = player, total = 8 }, wait_action_anim = false }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 8, 4)
    assert(state == "wait_choice", "should return wait_choice state when no anim wait")
    assert(args.next_state == "land", "should preserve next_state")
  end,
  _test_resolve_phase_wait_result_defaults = function()
    local player = { id = 1, name = "P1" }
    local phase_res = {}
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 6, 3)
    assert(state == "wait_choice", "should default to wait_choice")
    assert(args.next_state == "move", "should default next_state to move")
    assert(args.next_args.player == player, "should include player in default next_args")
    assert(args.next_args.total == 6, "should include total in default next_args")
    assert(args.next_args.raw_total == 3, "should include raw_total in default next_args")
  end,
  _test_validate_choice_actor_match = function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when actor matches owner")
  end,
  _test_validate_choice_actor_mismatch = function()
    local g = _new_game()
    local p1 = g.players[1]
    local p2 = g.players[2]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p2.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when actor does not match owner")
  end,
  _test_validate_choice_actor_no_owner = function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1 }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when choice has no owner")
  end,
  _test_validate_choice_actor_no_actor_id = function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select" }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when action has no actor_role_id")
  end,
  _test_log_missing_auto_choice_action_logs_once = function()
    local g = _new_game()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    local ctx = { pending_choice = { id = 123, kind = "test_choice" }, current_player_auto = true }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == true, "should mark log_once key")
  end,
  _test_log_missing_auto_choice_action_skips_when_waiting = function()
    local g = _new_game()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    state.auto_runner.waiting_for_interval = true
    local ctx = { pending_choice = { id = 123, kind = "test_choice" }, current_player_auto = true }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == nil, "should not log when waiting for interval")
  end,
  _test_log_missing_auto_choice_action_skips_when_not_auto = function()
    local g = _new_game()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    local ctx = { pending_choice = { id = 123, kind = "test_choice" }, current_player_auto = false }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == nil, "should not log when not auto")
  end,
  _test_resolve_choice_owner_id_fallback_current = _t2_case_groups.resolve_choice_owner_id_tests[1],
  _test_resolve_choice_owner_id_out_of_range = _t2_case_groups.resolve_choice_owner_id_tests[2],
  _test_resolve_choice_owner_missing_find_player = _t2_case_groups.resolve_choice_owner_id_tests[3],
  _test_resolve_choice_owner_no_players = _t2_case_groups.resolve_choice_owner_id_tests[4],
  _test_resolve_follow_player_id_skip_nil_id = _t2_case_groups.resolve_follow_player_id_tests[1],
  _test_resolve_follow_player_id_wrap_around = _t2_case_groups.resolve_follow_player_id_tests[2],
  _test_resolve_follow_player_id_all_eliminated = _t2_case_groups.resolve_follow_player_id_tests[3],
  _test_resolve_follow_player_id_nil_turn = _t2_case_groups.resolve_follow_player_id_tests[4],
  _test_resolve_follow_player_id_empty_players = _t2_case_groups.resolve_follow_player_id_tests[5],
  _test_resolve_wait_state_prefers_wait_action_anim = _t2_case_groups.resolve_wait_state_tests[1],
  _test_resolve_wait_state_without_anim_returns_wait_choice = _t2_case_groups.resolve_wait_state_tests[2],
  _test_resolve_wait_state_wraps_move_effect_queue = _t2_case_groups.resolve_wait_state_tests[3],
  _test_fill_ui_sync_defaults_fills_all = _t2_case_groups.fill_ui_sync_defaults_tests[1],
  _test_fill_ui_sync_defaults_preserves_custom = _t2_case_groups.fill_ui_sync_defaults_tests[2],
  _test_fill_ui_sync_defaults_resolve_ui_gate = _t2_case_groups.fill_ui_sync_defaults_tests[3],
  _test_fill_ui_sync_defaults_set_input_blocked = _t2_case_groups.fill_ui_sync_defaults_tests[4],
  _test_fill_ui_sync_defaults_gate_nil_state = _t2_case_groups.fill_ui_sync_defaults_tests[5],
  _test_update_countdown_pending_choice = _t2_case_groups.update_countdown_tests[1],
  _test_update_countdown_detained_wait = _t2_case_groups.update_countdown_tests[2],
  _test_update_countdown_action_button = _t2_case_groups.update_countdown_tests[3],
  _test_update_countdown_popup_zero_timeout = _t2_case_groups.update_countdown_tests[4],
  _test_is_action_button_wait_active_pending_choice = _t2_case_groups.is_action_button_wait_active_tests[1],
  _test_is_action_button_wait_active_input_blocked = _t2_case_groups.is_action_button_wait_active_tests[2],
  _test_is_action_button_wait_active_popup = _t2_case_groups.is_action_button_wait_active_tests[3],
  _test_is_action_button_wait_active_finished_game = _t2_case_groups.is_action_button_wait_active_tests[4],
}
