local support = require("TestSupport")
local gameplay_loop = support.gameplay_loop
local gameplay_rules = require("src.core.config.gameplay_rules")
local game_startup = require("src.app.bootstrap.game_startup")
local move_followup = require("src.game.flow.turn.move_followup")
local choice_resolver = support.choice_resolver
local _build_ui_port = support.build_ui_port
local _bind_ui_runtime = support.bind_ui_runtime
local _get_choice = support.get_choice
local _open_choice = support.open_choice
local _tile_state = support.tile_state

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
      build_model = overrides.build_model or function() return { choice = nil, market = nil } end,
      refresh_from_dirty = overrides.refresh_from_dirty or function() return false end,
      follow_camera = overrides.follow_camera or function() return false end,
      get_ui_state = overrides.get_ui_state or function(state) return state and state.ui or nil end,
      is_input_blocked = overrides.is_input_blocked or function() return false end,
      is_popup_active = overrides.is_popup_active or function() return false end,
      is_choice_active = overrides.is_choice_active or function() return false end,
      is_market_active = overrides.is_market_active or function() return false end,
      get_popup_owner_index = overrides.get_popup_owner_index or function() return nil end,
      resolve_ui_gate = overrides.resolve_ui_gate or function()
        return {
          input_blocked = false,
          choice_active = false,
          market_active = false,
          popup_active = false,
          popup_seq = nil,
          popup_auto_close_seconds = nil,
          popup_owner_index = nil,
        }
      end,
      set_input_blocked = overrides.set_input_blocked or function() return false end,
    },
    debug = {
      log_status = overrides.log_status or function() end,
      sync_debug_log = overrides.sync_debug_log or function() end,
      resolve_debug_enabled = overrides.resolve_debug_enabled or function() return false end,
    },
    clock = {
      wall_now_seconds = overrides.wall_now_seconds or function() return 0 end,
      wall_diff_seconds = overrides.wall_diff_seconds or function(a, b) return (a or 0) - (b or 0) end,
      cpu_now_seconds = overrides.cpu_now_seconds or function() return 0 end,
      cpu_diff_seconds = overrides.cpu_diff_seconds or function(a, b) return (a or 0) - (b or 0) end,
    },
    state = {
      apply_role_control_lock = overrides.apply_role_control_lock or function() end,
      install_event_handlers = overrides.install_event_handlers or function() end,
      on_bankruptcy_tiles_cleared = overrides.on_bankruptcy_tiles_cleared or function() end,
    },
    output = {
      invalidate_ui = overrides.invalidate_ui or function() end,
      sync_pending_choice = overrides.sync_pending_choice or function(state, pending)
        state.pending_choice = pending
      end,
      sync_ui_model = overrides.sync_ui_model or function(state, model)
        state.ui_model = model
      end,
    },
  }
end

local function _new_profile_game(profile_name)
  local state = game_startup.build_state(function()
    return nil
  end, {
    profile_name = profile_name,
    release_mode = false,
    force_non_p1_ai = true,
    fail_fast_when_roles_empty = false,
  })
  state.gameplay_loop_ports = _build_test_ports()
  state.ui = _build_ui_port().ui
  _bind_ui_runtime(state)
  local game = gameplay_loop.new_game(state)
  gameplay_loop.set_game(state, game)
  return game, state
end

local function _test_monster_startup_profile_runs_choice_to_action_anim()
  local g, state = _new_profile_game("scenario_monster_staging")
  local dispatched = {}
  local player = g.players[1]
  local target_tile = assert(g.board:get_tile_by_id(12), "monster staging target tile should exist")

  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local res = support.executor.use_item(g, player, gameplay_rules.item_ids.monster, {})
  assert(type(res) == "table" and res.waiting == true, "monster staging should open target choice")
  _open_choice(g, res.intent.choice_spec)

  local pending = _get_choice(g)
  assert(pending and pending.kind == "demolish_target", "monster staging should expose demolish target choice")
  choice_resolver.resolve(g, pending, { option_id = pending.options[1].id })

  assert(_tile_state(g, target_tile).level == 0, "monster staging should destroy the configured building")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "monster", "monster staging should queue monster anim")

  state.gameplay_loop_ports = _build_test_ports({
    play_action_anim = function(_, anim_ctx)
      assert(anim_ctx and anim_ctx.kind == "monster", "monster staging should route monster anim through gameplay loop")
      return 0
    end,
  })
  g.turn.phase = "wait_action_anim"
  gameplay_loop.tick(g, state, 0.1)

  assert(dispatched[1] and dispatched[1].type == "action_anim_done", "monster staging should dispatch action_anim_done")
end

local function _test_missile_startup_profile_defers_hospital_followup_until_after_anim()
  local g, state = _new_profile_game("scenario_missile_staging")
  local dispatched = {}
  local player = g.players[1]
  local target_tile = assert(g.board:get_tile_by_id(11), "missile staging target tile should exist")
  local target_index = assert(g.board:index_of_tile_id(11), "missile staging target tile should exist in board path")

  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local res = support.executor.use_item(g, player, gameplay_rules.item_ids.missile, {})
  assert(type(res) == "table" and res.waiting == true, "missile staging should open target choice")
  _open_choice(g, res.intent.choice_spec)

  local pending = _get_choice(g)
  assert(pending and pending.kind == "demolish_target", "missile staging should expose demolish target choice")
  local choice_result = choice_resolver.resolve(g, pending, { option_id = pending.options[1].id })

  assert(_tile_state(g, target_tile).level == 0, "missile staging should destroy the configured building")
  assert(g.board:has_roadblock(target_index) == false, "missile staging should clear roadblock before followup")
  assert(g.board:has_mine(target_index) == false, "missile staging should clear mine before followup")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "missile", "missile staging should queue missile anim")
  assert(type(choice_result.after_action_anim) == "table", "missile staging should expose move followup continuation")
  assert((g.players[2].status.stay_turns or 0) == 0, "missile staging should defer hospital stay before followup")

  state.gameplay_loop_ports = _build_test_ports({
    play_action_anim = function(_, anim_ctx)
      assert(anim_ctx and anim_ctx.kind == "missile", "missile staging should route missile anim through gameplay loop")
      return 0
    end,
  })
  g.turn.phase = "wait_action_anim"
  gameplay_loop.tick(g, state, 0.1)

  assert(dispatched[1] and dispatched[1].type == "action_anim_done", "missile staging should dispatch action_anim_done")

  local next_state, _ = move_followup.run({ game = g }, choice_result.after_action_anim.next_args)
  assert(next_state == nil, "missile staging followup should return caller continuation")
  assert((g.players[2].status.stay_turns or 0) > 0, "missile staging should apply hospital stay after followup")
end

return {
  name = "gameplay_items_startup",
  tests = {
    {
      name = "monster_startup_profile_runs_choice_to_action_anim",
      run = _test_monster_startup_profile_runs_choice_to_action_anim,
    },
    {
      name = "missile_startup_profile_defers_hospital_followup_until_after_anim",
      run = _test_missile_startup_profile_defers_hospital_followup_until_after_anim,
    },
  },
}
