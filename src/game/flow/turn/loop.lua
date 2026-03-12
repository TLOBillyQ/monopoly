local items_cfg = require("Config.generated.items")
local gameplay_rules = require("src.core.config.gameplay_rules")
local logger = require("src.core.utils.logger")
local auto_play_port = require("src.game.ports.auto_play_port")
local turn_dispatch = require("src.game.flow.turn.dispatch")
local gameplay_loop_ports = require("src.game.flow.turn.loop_ports")
local gameplay_loop_runtime = require("src.game.flow.turn.loop_runtime")
local intent_output_adapter = require("src.game.flow.output_adapters.intent_output_adapter")
local auto_context = require("src.game.flow.turn.auto_context")
local tick_flow = require("src.game.flow.turn.loop_tick_flow")
local turn_timer_policy = require("src.game.flow.turn.timer_policy")
local paid_currency_bridge = require("src.game.systems.commerce.paid_currency_bridge")
local market_purchase = require("src.game.systems.market.application.purchase")
local runtime_state = require("src.core.state_access.runtime_state")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")
local role_id_utils = require("src.core.utils.role_id")
local gameplay_loop = {}

local function _ensure_fallback_ports(game)
  if type(game.auto_play_port) ~= "table" then
    game.auto_play_port = {
      is_auto_player = function(_, _, player)
        return player and (player.auto == true or player.is_ai == true or player.ai == true) or false
      end,
      choose_action = function()
        return nil
      end,
    }
  end
  if type(game.bankruptcy_port) ~= "table" then
    game.bankruptcy_port = {
      on_bankruptcy = function()
        return nil
      end,
    }
  end
end

local function _ensure_runtime_ports(game)
  if not game then
    return
  end
  if type(game.intent_output_port) ~= "table" then
    game.intent_output_port = intent_output_adapter.build()
  end
  _ensure_fallback_ports(game)
end

local function _resolve_ports(state)
  if not state then
    return gameplay_loop_ports.resolve(nil)
  end
  local override = state.gameplay_loop_ports
  if state._resolved_gameplay_loop_ports and state._resolved_gameplay_loop_ports_source == override then
    return state._resolved_gameplay_loop_ports
  end
  local resolved = gameplay_loop_ports.resolve(override)
  state._resolved_gameplay_loop_ports = resolved
  state._resolved_gameplay_loop_ports_source = override
  state.gameplay_loop_ports = resolved
  return resolved
end
local function _dispatch_action_with_close_choice(game, state, action, ports)
  local modal_ports = ports.modal
  turn_dispatch.dispatch_action(game, state, action, {
    on_close_choice = function(ctx)
      modal_ports.close_choice_modal(ctx)
    end,
  })
end
local function _build_item_index(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    ui_runtime.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end
local function _is_auto_popup_owner(game, state)
  local ports = _resolve_ports(state)
  local ui_sync_ports = ports.ui_sync
  if not (game and state and ui_sync_ports and ui_sync_ports.get_popup_owner_index) then
    return false
  end
  local idx = ui_sync_ports.get_popup_owner_index(state)
  if not idx or not game.players then
    return false
  end
  local actor = game.players[idx]
  return actor and auto_play_port.is_auto_player(game, actor) or false
end

local function _is_auto_popup_waiting(game, state, ui_sync_ports)
  local min_popup_visible = gameplay_rules.auto_popup_min_visible_seconds or 0
  if min_popup_visible <= 0 then
    return false
  end
  if not (ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state)) then
    return false
  end
  if not _is_auto_popup_owner(game, state) then
    return false
  end
  local elapsed = runtime_state.get_modal_elapsed(state)
  return elapsed < min_popup_visible
end

local function _fill_auto_action_actor(auto_action, current_player_id)
  if auto_action and auto_action.type == "ui_button" and not auto_action.actor_role_id then
    auto_action.actor_role_id = current_player_id
  end
end

local function _log_missing_auto_choice_action(state, ctx)
  if not (ctx.pending_choice and ctx.current_player_auto == true) then
    return
  end
  if state.auto_runner.waiting_for_interval == true then
    return
  end
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  local key = "auto_runner_choice_no_action_" .. tostring(ctx.pending_choice.id)
  if debug_runtime.log_once[key] then
    return
  end
  debug_runtime.log_once[key] = true
  logger.warn(
    "[Eggy]",
    "auto runner produced no action for runtime pending choice",
    "choice_id=" .. tostring(ctx.pending_choice.id),
    "kind=" .. tostring(ctx.pending_choice.kind),
    "actor_role_id=" .. tostring(ctx.current_player_id)
  )
end
local function _reset_afk_tracking(state, actor_role_id)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local normalized = role_id_utils.normalize(actor_role_id)
  if normalized ~= nil then
    role_id_utils.write(turn_runtime.afk_elapsed_seconds_by_role, normalized, 0)
  end
  turn_runtime.afk_actor_role_id = normalized
  turn_runtime.afk_elapsed_seconds = 0
  turn_runtime.afk_tracking_active = false
end
local function _read_afk_elapsed(turn_runtime, actor_role_id)
  return role_id_utils.read(turn_runtime.afk_elapsed_seconds_by_role, actor_role_id) or 0
end
local function _write_afk_elapsed(turn_runtime, actor_role_id, elapsed_seconds)
  local normalized = role_id_utils.write(turn_runtime.afk_elapsed_seconds_by_role, actor_role_id, elapsed_seconds or 0)
  if normalized ~= nil and role_id_utils.equals(turn_runtime.afk_actor_role_id, normalized) then
    turn_runtime.afk_elapsed_seconds = elapsed_seconds or 0
  end
  return normalized
end
local function _sync_afk_view(turn_runtime, actor_role_id, tracking_active)
  local normalized = role_id_utils.normalize(actor_role_id)
  turn_runtime.afk_actor_role_id = normalized
  turn_runtime.afk_elapsed_seconds = _read_afk_elapsed(turn_runtime, normalized)
  turn_runtime.afk_tracking_active = tracking_active == true
end

local function _is_afk_enabled()
  local timeout = gameplay_rules.afk_auto_host_seconds or 0
  return timeout and timeout > 0
end

local function _resolve_current_player(game)
  return game.turn and game.players and game.players[game.turn.current_player_index] or nil
end

local function _is_player_afk_eligible(player)
  return player and player.auto ~= true
end

local function _is_afk_trackable(game, state, ports)
  return turn_timer_policy.is_afk_trackable_wait(game, state, ports)
end

local function _update_afk_tracking(turn_runtime, player, dt)
  local elapsed_seconds = _read_afk_elapsed(turn_runtime, player.id) + (dt or 0)
  _write_afk_elapsed(turn_runtime, player.id, elapsed_seconds)
  turn_runtime.afk_actor_role_id = role_id_utils.normalize(player.id)
  turn_runtime.afk_elapsed_seconds = elapsed_seconds
  turn_runtime.afk_tracking_active = true
  return elapsed_seconds
end

local function _mark_players_dirty(game)
  if game.mark_players_dirty then
    game:mark_players_dirty()
  else
    game.dirty.any = true
    game.dirty.players = true
  end
end

local function _reset_auto_runner_timer(auto_runner)
  if auto_runner and auto_runner.reset_timer then
    auto_runner:reset_timer()
  end
end

local function _log_afk_auto_host_enabled(player)
  logger.event_no_tips(tostring(player.name) .. " AFK 超时，进入托管")
  logger.warn("afk auto host enabled:", tostring(player.name), "role_id=" .. tostring(player.id))
end

local function _enable_afk_auto_host(game, state, player, timeout)
  player.auto = true
  _mark_players_dirty(game)
  local ports = _resolve_ports(state)
  ports.output.invalidate_ui(state)
  _reset_auto_runner_timer(state.auto_runner)
  _reset_afk_tracking(state, player.id)
  _log_afk_auto_host_enabled(player)
  return true
end

function gameplay_loop.step_afk_auto_host(game, state, dt)
  assert(game ~= nil, "missing game")
  local timeout = gameplay_rules.afk_auto_host_seconds or 0
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  if not _is_afk_enabled() then
    _sync_afk_view(turn_runtime, nil, false)
    return false
  end
  local current_player = _resolve_current_player(game)
  if not _is_player_afk_eligible(current_player) then
    _sync_afk_view(turn_runtime, nil, false)
    return false
  end
  local ports = _resolve_ports(state)
  if not _is_afk_trackable(game, state, ports) then
    _sync_afk_view(turn_runtime, current_player.id, false)
    return false
  end
  local elapsed_seconds = _update_afk_tracking(turn_runtime, current_player, dt)
  if elapsed_seconds < timeout then
    return false
  end
  return _enable_afk_auto_host(game, state, current_player, timeout)
end
local function _initialize_ports(state, game)
  local ports = _resolve_ports(state)
  state.game = game
  state.gameplay_loop_ports = ports
  game.board_scene_port = gameplay_loop_runtime.build_board_scene_port(state)
  game.popup_port = gameplay_loop_runtime.build_popup_port(state)
  game.board_visual_feedback_port = gameplay_loop_runtime.build_board_visual_feedback_port(state)
  game.tile_feedback_port = gameplay_loop_runtime.build_tile_feedback_port(state)
  game.bankruptcy_feedback_port = {
    on_tiles_cleared = function(arg1, arg2, arg3, arg4)
      local game_ctx = nil
      local owned_tile_ids = nil
      if arg4 ~= nil then
        game_ctx = arg2
        owned_tile_ids = arg4
      else
        game_ctx = arg1
        owned_tile_ids = arg3
      end
      return game.board_visual_feedback_port.sync_many(game_ctx, {
        tile_ids = owned_tile_ids,
      })
    end,
  }
  game.anim_gate_port = gameplay_loop_runtime.build_anim_gate_port(state)
  game.intent_output_port = intent_output_adapter.build()
  _ensure_fallback_ports(game)
  return ports
end
local function _configure_tile_owner_notifier(state, game)
  game.tile_owner_notifier = {
    notify_owner_changed = function(_, tile_id, owner_id)
      return game.board_visual_feedback_port.sync_many(game, {
        tile_ids = { tile_id },
      })
    end,
  }
end
local function _configure_environment(state, game, ports)
  local anim_ports = ports.anim
  local state_ports = ports.state
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  state_ports.apply_role_control_lock(state, false)
  turn_runtime.role_control_lock_active = false
  turn_runtime.role_control_lock_suppress = 0
  anim_ports.reset_status_3d(state)
  _configure_tile_owner_notifier(state, game)
  paid_currency_bridge.setup_for_game(game)
  market_purchase.setup_for_game(game)
  state_ports.install_event_handlers(game, logger, state)
  logger.set_info_per_turn_limit(gameplay_rules.info_log_per_turn_limit)
  logger.set_info_turn_provider(function() return game.turn and game.turn.turn_count end)
end
local function _configure_pending_choice(state, game, ports)
  local output_ports = ports.output
  local ui_sync_ports = ports.ui_sync
  local modal_ports = ports.modal
  assert(game.pending_choice ~= nil, "missing game.pending_choice")
  local pending = game:pending_choice()
  output_ports.sync_pending_choice(state, pending)
  if pending then
    local model = ui_sync_ports.build_model(state, game)
    output_ports.sync_ui_model(state, model)
    if model.choice then
      modal_ports.open_choice_modal(state, model.choice, model.market)
    end
  end
end
local function _reset_runtime_state(state, ports)
  local ui_sync_ports = ports.ui_sync
  state.player_units = nil
  state.player_units_missing = false
  ports.output.invalidate_ui(state)
  state.countdown_last = nil
  state.countdown_active_last = nil
  if ui_sync_ports.set_input_blocked then
    ui_sync_ports.set_input_blocked(state, false)
  end
  if state.auto_runner then
    state.auto_runner:set_enabled(true)
    state.auto_runner:reset_timer()
  end
end
function gameplay_loop.set_game(state, game)
  assert(game ~= nil, "missing game")
  runtime_state.ensure_all(state)
  landing_visual_hold.reset_state(state)
  game.landing_visual_hold_state = state
  local ports = _initialize_ports(state, game)
  _configure_environment(state, game, ports)
  _configure_pending_choice(state, game, ports)
  _reset_runtime_state(state, ports)
end
function gameplay_loop.new_game(state)
  logger.clear()
  assert(state.game_factory, "game_factory not set")
  local game = state.game_factory()
  _build_item_index(state)
  local auto_runner = assert(state.auto_runner, "missing auto_runner")
  assert(auto_runner.reset_timer ~= nil, "missing auto_runner.ResetTimer")
  if auto_runner.set_enabled then
    auto_runner:set_enabled(true)
  end
  auto_runner:reset_timer()
  game.logger.info("启动蛋仔大富翁，玩家数:", #game.players)
  return game
end

local function _resolve_profile_rotation_hook(state)
  local hook = state and state.profile_rotation or nil
  if type(hook) ~= "table" then
    return nil
  end
  if type(hook.is_active) ~= "function"
      or type(hook.turns_per_profile) ~= "function"
      or type(hook.record_result) ~= "function"
      or type(hook.advance) ~= "function"
      or type(hook.current_profile_name) ~= "function" then
    return nil
  end
  return hook
end

local function _maybe_rotate_profile(game, state)
  local rotation = _resolve_profile_rotation_hook(state)
  if not rotation or not rotation.is_active() then
    return false
  end
  local turn_count = game.turn and game.turn.turn_count or 0
  local should_rotate = game.finished == true or turn_count >= rotation.turns_per_profile()
  if not should_rotate then
    return false
  end
  local current_profile_name = state and state.active_profile_name or rotation.current_profile_name() or "default"
  rotation.record_result(current_profile_name, turn_count, game.finished == true)
  if rotation.advance() then
    local next_profile_name = rotation.current_profile_name()
    if state then
      state.active_profile_name = next_profile_name
    end
    local next_game = gameplay_loop.new_game(state)
    if state and type(state.on_game_replaced) == "function" then
      state.on_game_replaced(next_game)
    else
      gameplay_loop.set_game(state, next_game)
    end
    return true
  end
  if state and state.auto_runner and state.auto_runner.set_enabled then
    state.auto_runner:set_enabled(false)
  end
  return true
end

function gameplay_loop.step_auto_runner(game, state, dt, context)
  assert(game ~= nil, "missing game")
  assert(state.auto_runner ~= nil, "missing auto_runner")
  local ports = _resolve_ports(state)
  local ui_sync_ports = ports.ui_sync
  if ui_sync_ports.is_input_blocked and ui_sync_ports.is_input_blocked(state) then
    return nil
  end
  if _is_auto_popup_waiting(game, state, ui_sync_ports) then
    return nil
  end
  local ctx = auto_context.build(game, context)
  local auto_action = state.auto_runner:next_action(dt, ctx)
  _fill_auto_action_actor(auto_action, ctx.current_player_id)
  if auto_action == nil then
    _log_missing_auto_choice_action(state, ctx)
  end
  if auto_action then
    _dispatch_action_with_close_choice(game, state, auto_action, ports)
  end
  return auto_action
end
function gameplay_loop.tick(game, state, dt)
  if not game then
    return
  end
  _ensure_runtime_ports(game)
  local ports = _resolve_ports(state)
  tick_flow.tick(game, state, dt, ports, {
    step_afk_auto_host = gameplay_loop.step_afk_auto_host,
    step_auto_runner = gameplay_loop.step_auto_runner,
    dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
  })
  if _maybe_rotate_profile(game, state) then
    return
  end
end
gameplay_loop._log_missing_auto_choice_action = _log_missing_auto_choice_action
return gameplay_loop
