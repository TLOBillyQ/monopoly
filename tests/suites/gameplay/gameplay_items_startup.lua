local support = require("support.gameplay_support")
local gameplay_loop = support.gameplay_loop
local item_ids = require("src.config.gameplay.item_ids")
local startup_roster = require("src.app.bootstrap.startup_roster")
local state_factory = require("src.presentation.runtime.state_factory")
local turn_start = require("src.turn.phases.start")
local turn_roll = require("src.turn.phases.roll")
local phase_registry = require("src.turn.phases.registry")
local move_followup = require("src.turn.phases.move_followup")
local await = require("src.turn.waits.await")
local board_utils = require("src.rules.land.board_utils")
local land_rules = require("src.rules.land.rules")
local item_phase = require("src.rules.items.phase")
local item_strategy = require("src.rules.items.strategy")
local choice_resolver = support.choice_resolver
local movement = support.movement
local steal = support.steal
local _build_ui_port = support.build_ui_port
local _bind_ui_runtime = support.bind_ui_runtime
local _get_choice = support.get_choice
local _open_choice = support.open_choice
local _tile_state = support.tile_state
local _turn_move = support.turn_move
local _resolve_landing = support.resolve_landing

local function _build_startup_state(profile_name)
  return state_factory.build_state({
    profile_name = profile_name,
    get_current_game = function()
      return nil
    end,
    build_game_factory = function(state)
      return startup_roster.build_game_factory(state, {
        profile_name = profile_name,
      })
    end,
    auto_runner = startup_roster.build_auto_runner(),
  })
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
      invalidate_ui_model = overrides.invalidate_ui_model or function() end,
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
  local state = _build_startup_state(profile_name)
  state.gameplay_loop_ports = _build_test_ports()
  state.ui = _build_ui_port().ui
  _bind_ui_runtime(state)
  local game = gameplay_loop.new_game(state)
  gameplay_loop.set_game(state, game)
  return game, state
end

local function _new_await_session(game, action)
  local session = {
    game = game,
    _action = action,
  }

  function session:mark_phase(name)
    self.marked_phase = name
  end

  function session:take_pending_action()
    local next_action = self._action
    self._action = nil
    return next_action
  end

  function session:peek_pending_action()
    return self._action
  end

  function session:clear_pending_action()
    self._action = nil
  end

  return session
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

local function _find_option_id_by_label(choice, label)
  for _, option in ipairs(choice.options or {}) do
    if option.label == label then
      return option.id
    end
  end
  return nil
end

local function _find_option_by_id(choice, option_id)
  for _, option in ipairs(choice.options or {}) do
    if option.id == option_id then
      return option
    end
  end
  return nil
end

local function _setup_circle_market_bought_roadblock_and_mine()
  local g, _ = _new_profile_game("circle")
  local player = g.players[1]
  local remote_dice_id = item_ids.remote_dice
  local roadblock_id = item_ids.roadblock
  local mine_id = item_ids.mine

  g.last_turn = {}
  g.anim_gate_port.wait_action_anim = false
  g.anim_gate_port.wait_move_anim = false

  local function _remote_roll_four()
    local use_result = support.executor.use_item(g, player, remote_dice_id, { by_ai = false })
    assert(type(use_result) == "table" and use_result.waiting == true, "circle market setup should open remote dice choice")
    _open_choice(g, use_result.intent.choice_spec)

    local pending = assert(_get_choice(g), "circle market setup should expose remote dice choice")
    local choice_result = choice_resolver.resolve(g, pending, { option_id = 4 })
    assert(choice_result and choice_result.stay == false, "circle market setup remote dice choice should resolve")

    local roll_state, roll_args = turn_roll._phase_roll({ game = g }, { player = player, skip_anim = true })
    assert(roll_state == "move", "circle market setup should continue from roll to move")
    return _turn_move({ game = g }, roll_args)
  end

  local first_move_state, _ = _remote_roll_four()
  assert(first_move_state == "landing", "circle market setup first turn should land directly")

  g:clear_player_temporal_flags(player)
  g:stop_all_players_movement()
  g.last_turn = {}

  local second_move_state, second_move_args = _remote_roll_four()
  assert(second_move_state == "wait_choice", "circle market setup second turn should pause at market interrupt")

  local market_choice = assert(_get_choice(g), "circle market setup should open market choice")
  assert(market_choice.kind == "market_buy", "circle market setup should expose market choice")
  assert(_find_option_by_id(market_choice, mine_id), "market choice should offer mine")
  assert(_find_option_by_id(market_choice, roadblock_id), "market choice should offer roadblock")

  local roadblock_buy_result = choice_resolver.resolve(g, market_choice, { option_id = roadblock_id })
  assert(roadblock_buy_result and roadblock_buy_result.stay == true, "buying roadblock should keep market open")
  market_choice = assert(_get_choice(g), "market should reopen after buying roadblock")

  local mine_buy_result = choice_resolver.resolve(g, market_choice, { option_id = mine_id })
  assert(mine_buy_result and mine_buy_result.stay == true, "buying mine should keep market open")
  market_choice = assert(_get_choice(g), "market should reopen after buying mine")

  local market_cancel_result = choice_resolver.resolve(g, market_choice, {
    type = "choice_cancel",
    choice_id = market_choice.id,
  })
  assert(market_cancel_result and market_cancel_result.status == "resolved", "market cancel should close market choice")
  assert(_count_item(player, roadblock_id) == 1, "market purchase should add roadblock to inventory")
  assert(_count_item(player, mine_id) == 1, "market purchase should add mine to inventory")

  local final_move_state, _ = _turn_move({ game = g }, second_move_args.next_args)
  assert(final_move_state == "landing", "circle market setup should land after market resume")
  assert(player.position == assert(g.board:index_of_tile_id(45)), "circle market setup should still reach chance 45")

  return g, player, roadblock_id, mine_id
end

local function _reopen_circle_post_action_after_roadblock(g, player, roadblock_id)
  local phases = phase_registry.build_default_phases()
  g.anim_gate_port.wait_action_anim = true
  g.auto_play_port.is_auto_player = function()
    return false
  end

  local wait_state, wait_args = phases.post_action({ game = g }, { player = player })
  assert(wait_state == "wait_choice", "post_action should first wait on item choice")
  local pending = assert(_get_choice(g), "post_action should open item phase choice")
  assert(_find_option_by_id(pending, roadblock_id), "post_action should offer roadblock before using it")

  local roadblock_select_result = choice_resolver.resolve(g, pending, { option_id = roadblock_id })
  assert(roadblock_select_result and roadblock_select_result.stay == true,
    "selecting roadblock from post_action should open target choice")

  pending = assert(_get_choice(g), "roadblock selection should expose target choice")
  assert(pending.kind == "roadblock_target", "roadblock selection should expose roadblock target choice")
  local roadblock_target_result = choice_resolver.resolve(g, pending, {
    option_id = pending.options[1].id,
  })
  assert(roadblock_target_result and roadblock_target_result.stay == false,
    "roadblock target choice should resolve current choice")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "roadblock",
    "roadblock target choice should queue roadblock action anim")

  local action_anim_seq = g.turn.action_anim.seq
  local after_roadblock = await.action_anim(_new_await_session(g, {
    type = "action_anim_done",
    seq = action_anim_seq,
  }), {
    next_state = wait_args.next_state,
    next_args = wait_args.next_args,
  })

  assert(after_roadblock and after_roadblock.next_state == "post_action",
    "roadblock action anim should resume back into post_action")
  local reopen_state, reopen_wait_args = phases.post_action({ game = g }, after_roadblock.next_args)
  assert(reopen_state == "wait_choice", "post_action should reopen after roadblock action anim")
  pending = assert(_get_choice(g), "reopened post_action should expose item phase choice")

  return phases, reopen_wait_args, pending
end

local function _start_steal_interrupt(game, player)
  local move_result = movement.move(game, player, 3, {
    branch_parity = 3,
    skip_market_check = true,
  })
  local interrupt = assert(move_result.steal_interrupt, "steal staging should produce steal interrupt")
  return move_result, interrupt
end

local function _open_steal_prompt_from_interrupt(game, player, interrupt)
  local steal_res = steal.handle_pass_players(game, player, interrupt.encountered_ids or {})
  assert(type(steal_res) == "table" and steal_res.waiting == true, "steal interrupt should open steal prompt")
  local pending = _open_choice(game, steal_res.intent.choice_spec)
  assert(pending and pending.kind == "steal_prompt", "pending choice should be steal_prompt")
  assert(pending.route_key == "secondary_confirm", "steal prompt should route to secondary confirm")
  assert(pending.requires_confirm == true, "steal prompt should require confirm")
  return pending
end

local function _resume_after_steal_interrupt(game, player, interrupt)
  local resumed = movement.move(game, player, interrupt.remaining_steps, {
    branch_parity = interrupt.branch_parity,
    direction = interrupt.facing,
    entered_inner = interrupt.entered_inner,
    skip_market_check = true,
    skip_steal_check = true,
  })
  assert(resumed and resumed.landing_tile and resumed.landing_tile.id == 40,
    "resumed steal move should land on tile 40 chance")
  return resumed
end

local function _advance_strong_card_staging_to_rent_prompt()
  local g, state = _new_profile_game("strong_card")
  local player = g.players[1]

  g.anim_gate_port.wait_action_anim = false
  g.anim_gate_port.wait_move_anim = false
  g.last_turn = {}

  local use_result = support.executor.use_item(g, player, item_ids.remote_dice, { by_ai = false })
  assert(type(use_result) == "table" and use_result.waiting == true, "strong card staging should open remote dice choice")
  _open_choice(g, use_result.intent.choice_spec)

  local pending = _get_choice(g)
  assert(pending and pending.kind == "remote_dice_value", "strong card staging should expose remote dice value choice")
  local choice_result = choice_resolver.resolve(g, pending, { option_id = 1 })
  assert(choice_result and choice_result.stay == false, "remote dice value choice should resolve immediately")

  local next_state, next_args = turn_roll._phase_roll({ game = g }, { player = player, skip_anim = true })
  assert(next_state == "move", "strong card staging should proceed from roll to move")

  local landing_state, landing_args = _turn_move({ game = g }, next_args)
  assert(landing_state == "landing", "strong card staging should proceed from move to landing")

  local target_tile = assert(g.board:get_tile(player.position), "strong card staging target tile should exist after move")
  local landing_result = _resolve_landing(g, player, target_tile, landing_args.move_result)
  assert(type(landing_result) == "table" and landing_result.waiting == true,
    "strong card staging should pause on rent prompt after landing")

  local rent_prompt = _get_choice(g)
  assert(rent_prompt and rent_prompt.kind == "rent_card_prompt", "strong card staging should expose rent prompt")

  return g, state, player, target_tile, rent_prompt
end

local function _test_monster_startup_profile_runs_choice_to_action_anim()
  local g, state = _new_profile_game("monster")
  local dispatched = {}
  local player = g.players[1]
  local target_tile = assert(g.board:get_tile_by_id(12), "monster staging target tile should exist")

  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local res = support.executor.use_item(g, player, item_ids.monster, { by_ai = false })
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
  local g, state = _new_profile_game("missile")
  local dispatched = {}
  local player = g.players[1]
  local target_tile = assert(g.board:get_tile_by_id(11), "missile staging target tile should exist")
  local target_index = assert(g.board:index_of_tile_id(11), "missile staging target tile should exist in board path")

  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local res = support.executor.use_item(g, player, item_ids.missile, { by_ai = false })
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
  assert(choice_result.after_action_anim.next_args.log_entries[1] == player.name .. " 发射导弹轰炸 " .. target_tile.name .. "，建筑被摧毁，1 名玩家送医",
    "missile staging should defer strike log into move followup")
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

local function _test_mine_startup_profile_other_player_triggers_immediately_after_placement()
  local g, _ = _new_profile_game("mine")
  local p1 = g.players[1]
  local p2 = g.players[2]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "mine startup tile should exist")

  local use_res = support.executor.use_item(g, p1, item_ids.mine, { by_ai = false })
  assert(use_res ~= nil, "mine startup profile should allow mine use")
  assert(g.board:has_mine(mine_index), "mine startup profile should place mine on owner tile")
  local mine_state = assert(g.board:get_mine(mine_index), "mine startup profile should keep mine payload")
  assert(mine_state.armed == true, "mine startup profile should place the mine as active")
  assert(
    mine_state.owner_turn_started_count_at_placement == (p1.status.own_turn_started_count or 0),
    "mine startup profile should snapshot owner own-turn count"
  )

  local owner_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not (owner_res and owner_res.waiting == true and owner_res.next_state == "move_followup"),
    "owner should stay immune on the placement turn")
  assert((p1.status.stay_turns or 0) == 0, "owner should not be hospitalized on the placement turn")

  g:update_player_position(p2, mine_index)
  local trigger_res = _resolve_landing(g, p2, mine_tile, {})
  assert(trigger_res and trigger_res.waiting == true, "other player should trigger the mine immediately")
  assert(trigger_res.next_state == "move_followup", "other player mine trigger should resume through move_followup")
  assert((p2.status.stay_turns or 0) == 0, "mine hospital stay should be deferred until followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "end_turn", "other player mine trigger should end the turn after hospital followup")
  assert((p2.status.stay_turns or 0) > 0, "other player should be hospitalized after mine followup")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after detonation")
end

local function _test_mine_startup_profile_owner_triggers_on_third_own_turn()
  local g, _ = _new_profile_game("mine")
  local p1 = g.players[1]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "mine startup tile should exist")

  local use_res = support.executor.use_item(g, p1, item_ids.mine, { by_ai = false })
  assert(use_res ~= nil, "mine startup profile should allow mine use")
  assert(g.board:has_mine(mine_index), "mine startup profile should place mine on owner tile")
  local mine_state = assert(g.board:get_mine(mine_index), "mine should keep placement payload")
  local placement_turn_started_count = mine_state.owner_turn_started_count_at_placement

  g:set_player_status(p1, "own_turn_started_count", placement_turn_started_count + 1)
  local next_turn_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not (next_turn_res and next_turn_res.waiting == true and next_turn_res.next_state == "move_followup"),
    "owner should stay immune on the next own turn")
  assert((p1.status.stay_turns or 0) == 0, "owner next own turn should still be safe")
  assert(g.board:has_mine(mine_index), "mine should remain after the second immunity pass")

  g:set_player_status(p1, "own_turn_started_count", placement_turn_started_count + 2)

  local trigger_res = _resolve_landing(g, p1, mine_tile, {})
  assert(trigger_res and trigger_res.waiting == true, "owner should be hit by own mine on the third own turn")
  assert(trigger_res.next_state == "move_followup", "owner mine trigger should resume through move_followup")
  assert((p1.status.stay_turns or 0) == 0, "owner hospital stay should still be deferred until followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "end_turn", "owner mine trigger should end the turn after hospital followup")
  assert((p1.status.stay_turns or 0) > 0, "owner should be hospitalized on the third own turn")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after owner self-trigger")
end

local function _test_strong_card_startup_profile_transfers_target_tile_on_use()
  local g, _, player, target_tile, rent_prompt = _advance_strong_card_staging_to_rent_prompt()
  local owner = g.players[2]
  local target_state_before = _tile_state(g, target_tile)
  local strong_amount = board_utils.total_invested(target_tile, target_state_before.level)
  local player_cash_before = g:player_balance(player, "金币")
  local owner_cash_before = g:player_balance(owner, "金币")

  assert(rent_prompt.title == "是否使用强征卡", "strong card staging should prompt strong card first")
  assert(rent_prompt.route_key == "secondary_confirm", "strong card staging should route strong prompt to secondary confirm")
  assert(rent_prompt.requires_confirm == true, "strong card staging should require confirm before using strong card")
  assert(rent_prompt.confirm_title == "强征卡", "strong card staging should expose short strong-card confirm title")
  assert(rent_prompt.confirm_body == "支付 " .. tostring(strong_amount) .. " 强制购入 " .. target_tile.name,
    "strong card staging should expose explicit confirm body")
  local result = choice_resolver.resolve(g, rent_prompt, { option_id = "use" })

  assert(result and result.stay == false, "using strong card should resolve rent prompt")
  assert(_get_choice(g) == nil, "using strong card should clear pending choice")
  assert(g:player_balance(player, "金币") == player_cash_before - strong_amount,
    "using strong card should deduct total invested amount from player")
  assert(g:player_balance(owner, "金币") == owner_cash_before + strong_amount,
    "using strong card should transfer total invested amount to owner")

  local target_state_after = _tile_state(g, target_tile)
  assert(target_state_after.owner_id == player.id, "using strong card should transfer target tile ownership")
  assert(target_state_after.level == target_state_before.level, "using strong card should keep target tile level")
end

local function _test_strong_card_startup_profile_allows_free_rent_after_skipping_strong()
  local g, _, player, target_tile, rent_prompt = _advance_strong_card_staging_to_rent_prompt()
  local owner = g.players[2]
  local target_state_before = _tile_state(g, target_tile)
  local player_cash_before = g:player_balance(player, "金币")
  local owner_cash_before = g:player_balance(owner, "金币")

  local skip_result = choice_resolver.resolve(g, rent_prompt, { option_id = "skip" })
  assert(skip_result and skip_result.stay == true, "skipping strong card should keep flow open for free rent prompt")

  local free_prompt = _get_choice(g)
  assert(free_prompt and free_prompt.kind == "rent_card_prompt", "skipping strong card should expose free rent prompt")
  assert(free_prompt.title == "是否使用免费卡", "skipping strong card should prompt free rent next")
  assert(free_prompt.route_key == "secondary_confirm", "free rent prompt should route to secondary confirm")
  assert(free_prompt.requires_confirm == true, "free rent prompt should require confirm before using")
  assert(free_prompt.confirm_title == "免费卡", "free rent prompt should expose short confirm title")
  assert(free_prompt.confirm_body == "这次要用免费卡吗？", "free rent prompt should expose explicit confirm body")

  local use_result = choice_resolver.resolve(g, free_prompt, { option_id = "use" })
  assert(use_result and use_result.stay == false, "using free rent should resolve prompt")
  assert(_get_choice(g) == nil, "using free rent should clear pending choice")
  assert(g:player_balance(player, "金币") == player_cash_before, "using free rent should not change player cash")
  assert(g:player_balance(owner, "金币") == owner_cash_before, "using free rent should not change owner cash")

  local target_state_after = _tile_state(g, target_tile)
  assert(target_state_after.owner_id == target_state_before.owner_id, "using free rent should keep target tile owner")
  assert(target_state_after.level == target_state_before.level, "using free rent should keep target tile level")
end

local function _test_strong_card_startup_profile_falls_back_to_direct_rent_after_skipping_both_cards()
  local g, _, player, target_tile, rent_prompt = _advance_strong_card_staging_to_rent_prompt()
  local owner = g.players[2]
  local target_state_before = _tile_state(g, target_tile)
  local target_index = assert(g.board:index_of_tile_id(target_tile.id), "strong card staging target index should exist")
  local rent_amount = land_rules.contiguous_rent(g, g.board, target_index, owner.id)
  local player_cash_before = g:player_balance(player, "金币")
  local owner_cash_before = g:player_balance(owner, "金币")

  local skip_strong_result = choice_resolver.resolve(g, rent_prompt, { option_id = "skip" })
  assert(skip_strong_result and skip_strong_result.stay == true,
    "skipping strong card should keep flow open for direct rent fallback")

  local free_prompt = _get_choice(g)
  assert(free_prompt and free_prompt.title == "是否使用免费卡", "direct rent fallback should pass through free rent prompt")

  local skip_free_result = choice_resolver.resolve(g, free_prompt, { option_id = "skip" })
  assert(skip_free_result and skip_free_result.stay == false, "skipping both rent cards should resolve prompt")
  assert(_get_choice(g) == nil, "skipping both rent cards should clear pending choice")
  assert(g:player_balance(player, "金币") == player_cash_before - rent_amount,
    "skipping both rent cards should pay normal rent")
  assert(g:player_balance(owner, "金币") == owner_cash_before + rent_amount,
    "skipping both rent cards should credit normal rent to owner")

  local target_state_after = _tile_state(g, target_tile)
  assert(target_state_after.owner_id == target_state_before.owner_id,
    "skipping both rent cards should keep target tile owner")
  assert(target_state_after.level == target_state_before.level,
    "skipping both rent cards should keep target tile level")
end

local function _test_post_action_item_phase_keeps_reactive_rent_cards_out_after_skipping_strong()
  local g, _, player, target_tile, rent_prompt = _advance_strong_card_staging_to_rent_prompt()
  local phases = phase_registry.build_default_phases()
  local owner = g.players[2]
  local target_state_before = _tile_state(g, target_tile)
  local player_cash_before = g:player_balance(player, "金币")
  local owner_cash_before = g:player_balance(owner, "金币")
  player.inventory:add({ id = item_ids.rich })
  g.auto_play_port.is_auto_player = function()
    return false
  end

  local skip_result = choice_resolver.resolve(g, rent_prompt, { option_id = "skip" })
  assert(skip_result and skip_result.stay == true, "skipping strong card should keep flow open")

  local post_action_choice = assert(item_phase.build_choice_spec(g, player, "post_action"),
    "post_action item phase should still offer active cards after skipping strong card")
  _open_choice(g, post_action_choice)

  local pending = _get_choice(g)
  assert(pending and pending.kind == "item_phase_choice", "post_action item phase should expose item phase choice")
  assert(_find_option_id_by_label(pending, "免费卡") == nil,
    "post_action item phase should keep reactive free rent out of active item windows")
  assert(_find_option_id_by_label(pending, "财神卡") ~= nil,
    "post_action item phase should keep explicit post_action active cards available")
  assert(g:player_balance(player, "金币") == player_cash_before,
    "post_action item phase should not change player cash before choosing an active card")
  assert(g:player_balance(owner, "金币") == owner_cash_before,
    "post_action item phase should not change owner cash before choosing an active card")

  local target_state_after = _tile_state(g, target_tile)
  assert(target_state_after.owner_id == target_state_before.owner_id,
    "post_action item phase should keep target tile owner before choosing an active card")
  assert(target_state_after.level == target_state_before.level,
    "post_action item phase should keep target tile level before choosing an active card")

  local next_state, _ = phases.post_action({ game = g }, { player = player })
  assert(next_state == "wait_choice", "post_action should reopen while explicit active cards remain usable")
  pending = _get_choice(g)
  assert(pending and pending.kind == "item_phase_choice", "post_action should reopen item phase choice")
  assert(_find_option_id_by_label(pending, "财神卡") ~= nil, "reopened post_action should expose rich card")

  local rich_result = choice_resolver.resolve(g, pending, { option_id = item_ids.rich })
  assert(rich_result and rich_result.stay == false, "using second post_action card should resolve current choice")
  assert(_count_item(player, item_ids.rich) == 0, "using second post_action card should consume rich card")
end

local function _test_post_action_auto_phase_waits_for_action_anim_followup()
  local g, _ = _new_profile_game("strong_card")
  local player = g.players[1]
  local phases = phase_registry.build_default_phases()
  local original_auto_pre_action = item_strategy.auto_pre_action

  g.auto_play_port.is_auto_player = function()
    return true
  end
  g.turn.action_anim = { seq = 99, kind = "item_use" }
  item_strategy.auto_pre_action = function(_, _, phase)
    assert(phase == "post_action", "auto post_action should pass explicit phase to strategy")
    return {
      after_action_anim = {
        next_state = "move_followup",
        next_args = {
          mode = "resume_turn_post_action",
        },
      },
    }
  end

  local ok, wait_state, wait_args = pcall(function()
    return phases.post_action({ game = g }, { player = player })
  end)
  item_strategy.auto_pre_action = original_auto_pre_action

  assert(ok, wait_state)
  assert(wait_state == "wait_action_anim", "auto post_action should wait for action anim followup")
  assert(wait_args.next_state == "move_followup", "auto post_action should keep move_followup next state")
  assert(wait_args.next_args.mode == "resume_turn_post_action", "auto post_action should keep custom resume payload")
  assert(wait_args.next_args.next_state == "post_action", "auto post_action should patch default next_state")
  assert(wait_args.next_args.next_args.player == player, "auto post_action should patch default next_args")
end

local function _test_pre_action_item_phase_remote_dice_then_mine_reopens_before_roll()
  local g, _ = _new_profile_game("strong_card")
  local player = g.players[1]
  g.auto_play_port.is_auto_player = function()
    return false
  end
  player.inventory:add({ id = item_ids.mine })

  local next_state, next_args = turn_start({ game = g })
  assert(next_state == "wait_action", "pre_action item phase should run during turn start")
  assert(next_args and next_args.next_state == "wait_choice", "turn start should wait on pre_action choice")

  local pending = _get_choice(g)
  assert(pending and pending.kind == "item_phase_choice", "turn start should open item_phase_choice")

  local remote_select = choice_resolver.resolve(g, pending, { option_id = item_ids.remote_dice })
  assert(remote_select and remote_select.stay == true, "selecting remote dice should enter follow-up choice")

  pending = _get_choice(g)
  assert(pending and pending.kind == "remote_dice_value", "pre_action should open remote dice follow-up")

  local remote_confirm = choice_resolver.resolve(g, pending, { option_id = 1 })
  assert(remote_confirm and remote_confirm.stay == true, "confirming remote dice should reopen pre_action choice when mine remains")

  pending = _get_choice(g)
  assert(pending and pending.kind == "item_phase_choice", "pre_action should reopen item phase choice after first card")
  assert(_find_option_id_by_label(pending, "地雷卡") ~= nil, "reopened pre_action should expose remaining mine card")
end

local function _test_combo_roadblock_mine_profile_exposes_both_cards_in_pre_action()
  local g, _ = _new_profile_game("combo_roadblock_mine")
  local player = g.players[1]

  local pending = assert(item_phase.build_choice_spec(g, player, "pre_action"),
    "combo_roadblock_mine should expose pre_action item choice")
  assert(_find_option_id_by_label(pending, "路障卡") ~= nil, "pre_action should expose roadblock")
  assert(_find_option_id_by_label(pending, "地雷卡") ~= nil, "pre_action should expose mine")
end

local function _test_roll_phase_no_longer_opens_active_item_window()
  local g, _ = _new_profile_game("dice_multiplier")
  local player = g.players[1]

  g.last_turn = {}
  g.turn.pending_choice = nil
  local next_state, next_args = turn_roll._phase_roll({ game = g }, {
    player = player,
    rolls = { 2 },
    raw_total = 2,
    total = 2,
    skip_anim = true,
  })

  assert(next_state == "move", "roll should move directly without opening active item window")
  assert(next_args and next_args.total == 2, "roll should preserve total without pre_action card state")
  assert(_get_choice(g) == nil, "roll should not open an item choice")
end

local function _test_dice_multiplier_used_in_pre_action_changes_same_turn_roll_total()
  local g, _ = _new_profile_game("dice_multiplier")
  local player = g.players[1]
  g.last_turn = {}
  g.rng = {
    next_int = function()
      return 3
    end,
  }

  local use_result = support.executor.use_item(g, player, item_ids.dice_multiplier, { by_ai = false })
  assert(use_result ~= nil, "dice_multiplier should be usable in pre_action")
  assert(player.status.pending_dice_multiplier == 2, "dice_multiplier should arm multiplier before rolling")

  local next_state, next_args = turn_roll._phase_roll({ game = g }, {
    player = player,
    skip_anim = true,
  })

  assert(next_state == "move", "dice_multiplier pre_action should still continue to move")
  assert(next_args and next_args.total == 6, "dice_multiplier should double the same-turn roll total")
  assert(next_args.raw_total == 3, "dice_multiplier should preserve raw total for downstream flow")
end

local function _test_steal_startup_profile_multi_item_choice_resumes_to_chance()
  local g, _ = _new_profile_game("steal")
  local player = g.players[1]
  local target = g.players[2]
  local _, interrupt = _start_steal_interrupt(g, player)

  assert(interrupt.position == assert(g.board:index_of_tile_id(8)), "steal interrupt should stop on tile 8 occupant")
  local pending = _open_steal_prompt_from_interrupt(g, player, interrupt)
  assert(pending.meta and pending.meta.target_id == target.id, "steal prompt should target p2")
  assert(pending.confirm_title == "偷窃卡", "steal prompt should expose short confirm title")
  assert(pending.confirm_body == "目标：" .. target.name, "steal prompt should expose explicit confirm body")

  local prompt_result = choice_resolver.resolve(g, pending, { option_id = "use" })
  assert(prompt_result and prompt_result.stay == true, "multi-item steal should open item picker")

  pending = _get_choice(g)
  assert(pending and pending.kind == "steal_item", "multi-item steal should expose steal_item choice")
  assert(pending.route_key == "player", "multi-item steal should route item picker to player screen")
  local tax_free_option_id = assert(_find_option_id_by_label(pending, "免税卡"), "steal item choice should expose 免税卡")
  local choice_result = choice_resolver.resolve(g, pending, { option_id = tax_free_option_id })

  assert(choice_result and choice_result.status == "resolved", "steal item selection should resolve")
  assert(_count_item(player, item_ids.steal) == 0, "steal card should be consumed after success")
  assert(_count_item(player, item_ids.tax_free) == 1, "p1 should receive stolen tax_free")
  assert(_count_item(target, item_ids.tax_free) == 0, "p2 should lose stolen tax_free")
  assert(_count_item(target, item_ids.free_rent) == 1, "p2 should keep the unstolen item")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "item_target_player",
    "steal success should queue target-player action anim")

  _resume_after_steal_interrupt(g, player, interrupt)
end

local function _test_steal_startup_profile_single_item_auto_steal_resumes_to_chance()
  local g, _ = _new_profile_game("steal_one")
  local player = g.players[1]
  local target = g.players[2]
  local _, interrupt = _start_steal_interrupt(g, player)

  local pending = _open_steal_prompt_from_interrupt(g, player, interrupt)
  local prompt_result = choice_resolver.resolve(g, pending, { option_id = "use" })

  assert(prompt_result and prompt_result.status == "resolved", "single-item steal should resolve directly")
  assert(_get_choice(g) == nil, "single-item steal should not open steal_item picker")
  assert(_count_item(player, item_ids.steal) == 0, "single-item steal should consume steal card")
  assert(_count_item(player, item_ids.free_rent) == 1, "p1 should receive the only target item")
  assert(_count_item(target, item_ids.free_rent) == 0, "p2 should lose the only target item")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "item_target_player",
    "single-item steal should queue target-player action anim")

  _resume_after_steal_interrupt(g, player, interrupt)
end

local function _test_steal_queue_startup_profile_skip_opens_next_target_and_resumes()
  local g, _ = _new_profile_game("steal_queue")
  local player = g.players[1]
  local second_target = g.players[3]
  local _, interrupt = _start_steal_interrupt(g, player)
  local queue = { g.players[2].id, second_target.id }
  local pending = _open_choice(g, steal.build_prompt_spec(g, player, queue, 1))

  assert(pending and pending.kind == "steal_prompt", "queue steal should start from prompt choice")
  local skip_result = choice_resolver.resolve(g, pending, { option_id = "skip" })
  assert(skip_result and skip_result.stay == true, "skip should open the next queued steal target")

  pending = _get_choice(g)
  assert(pending and pending.kind == "steal_prompt", "skip should keep steal prompt open for next target")
  assert(pending.meta and pending.meta.target_id == second_target.id, "skip should advance queue to p3")
  assert(pending.route_key == "secondary_confirm", "skip followup should keep secondary confirm route")

  local use_result = choice_resolver.resolve(g, pending, { option_id = "use" })
  assert(use_result and use_result.status == "resolved", "single-item queued target should resolve directly")
  assert(_count_item(player, item_ids.steal) == 0, "queued steal success should consume steal card")
  assert(_count_item(player, item_ids.tax_free) == 1, "queued steal should transfer p3 tax_free to p1")
  assert(_count_item(second_target, item_ids.tax_free) == 0, "queued steal should remove p3 tax_free")
  assert(_get_choice(g) == nil, "queued steal success should clear pending choice")

  _resume_after_steal_interrupt(g, player, interrupt)
end

local function _test_steal_startup_profile_cancel_item_picker_keeps_state_and_resumes()
  local g, _ = _new_profile_game("steal")
  local player = g.players[1]
  local target = g.players[2]
  local _, interrupt = _start_steal_interrupt(g, player)

  local pending = _open_steal_prompt_from_interrupt(g, player, interrupt)
  local prompt_result = choice_resolver.resolve(g, pending, { option_id = "use" })
  assert(prompt_result and prompt_result.stay == true, "cancel path should first open item picker")

  pending = _get_choice(g)
  assert(pending and pending.kind == "steal_item", "cancel path should enter steal_item picker")
  assert(pending.route_key == "player", "cancel path should keep player route for item picker")
  local cancel_result = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
  })

  assert(cancel_result and cancel_result.status == "resolved", "cancel should resolve steal_item picker")
  assert(_get_choice(g) == nil, "cancel should clear pending choice without reopening another prompt")
  assert(_count_item(player, item_ids.steal) == 1, "cancel should keep steal card on p1")
  assert(_count_item(player, item_ids.tax_free) == 0, "cancel should not transfer any item to p1")
  assert(_count_item(target, item_ids.tax_free) == 1, "cancel should keep target inventory unchanged")
  assert(_count_item(target, item_ids.free_rent) == 1, "cancel should keep all target items intact")

  _resume_after_steal_interrupt(g, player, interrupt)
end

local function _test_choice_builders_reserve_base_inline_for_item_slots_only()
  local g, _ = _new_profile_game("steal")
  local player = g.players[1]
  local land_choice_specs = require("src.rules.land.choice_specs")
  local purchase_policy = require("src.rules.market.purchase.policy")
  player.inventory:add({ id = item_ids.remote_dice })

  local item_phase_choice = item_phase.build_choice_spec(g, player, "pre_action")
  assert(item_phase_choice and item_phase_choice.route_key == "base_inline",
    "item phase should keep explicit base_inline route")
  assert(item_phase_choice and item_phase_choice.uses_item_slots == true,
    "base_inline contract should stay limited to item slot flows")

  local steal_prompt = steal.build_prompt_spec(g, player, { g.players[2].id }, 1)
  assert(steal_prompt.route_key == "secondary_confirm", "steal prompt should no longer use base_inline")
  assert(steal_prompt.requires_confirm == true, "steal prompt should require confirm")
  assert(steal_prompt.confirm_title == "偷窃卡", "steal prompt should expose explicit confirm title")
  assert(steal_prompt.confirm_body == "目标：" .. g.players[2].name, "steal prompt should expose explicit confirm body")

  local free_rent_prompt = land_choice_specs.rent_prompt(player.id, 1, "free")
  assert(free_rent_prompt.route_key == "secondary_confirm", "free rent prompt should no longer use base_inline")
  assert(free_rent_prompt.requires_confirm == true, "free rent prompt should require confirm")
  assert(free_rent_prompt.allow_cancel == true, "free rent prompt should expose skip through cancel")
  assert(free_rent_prompt.cancel_label == "不用", "free rent prompt should keep skip wording on cancel")
  assert(free_rent_prompt.confirm_title == "免费卡", "free rent prompt should expose confirm title")
  assert(free_rent_prompt.confirm_body == "这次要用免费卡吗？", "free rent prompt should expose confirm body")

  assert(purchase_policy.build_vehicle_replace_intent == nil,
    "legacy market replace confirm flow should be removed after vehicle retirement")
end

local function _test_circle_startup_profile_second_remote_roll_reaches_chance45_after_market_resume()
  local g, _ = _new_profile_game("circle")
  local player = g.players[1]
  local remote_dice_id = item_ids.remote_dice
  g.last_turn = {}
  g.anim_gate_port.wait_action_anim = false
  g.anim_gate_port.wait_move_anim = false

  local first_use_result = support.executor.use_item(g, player, remote_dice_id, { by_ai = false })
  assert(type(first_use_result) == "table" and first_use_result.waiting == true,
    "circle first turn should open remote dice choice")
  _open_choice(g, first_use_result.intent.choice_spec)
  local first_pending = assert(_get_choice(g), "circle first turn should expose remote dice choice")
  local first_choice_result = choice_resolver.resolve(g, first_pending, { option_id = 4 })
  assert(first_choice_result and first_choice_result.stay == false,
    "circle first turn remote dice choice should resolve")

  local first_roll_state, first_roll_args = turn_roll._phase_roll({ game = g }, { player = player, skip_anim = true })
  assert(first_roll_state == "move", "circle first turn should continue from roll to move")
  local first_move_state, _ = _turn_move({ game = g }, first_roll_args)
  assert(first_move_state == "landing", "circle first turn should land directly")
  assert(player.position == assert(g.board:index_of_tile_id(28)), "circle first turn should land on taiyuan")

  g:clear_player_temporal_flags(player)
  g:stop_all_players_movement()
  g.last_turn = {}

  local second_use_result = support.executor.use_item(g, player, remote_dice_id, { by_ai = false })
  assert(type(second_use_result) == "table" and second_use_result.waiting == true,
    "circle second turn should open remote dice choice")
  _open_choice(g, second_use_result.intent.choice_spec)
  local second_pending = assert(_get_choice(g), "circle second turn should expose remote dice choice")
  local second_choice_result = choice_resolver.resolve(g, second_pending, { option_id = 4 })
  assert(second_choice_result and second_choice_result.stay == false,
    "circle second turn remote dice choice should resolve")

  local second_roll_state, second_roll_args = turn_roll._phase_roll({ game = g }, { player = player, skip_anim = true })
  assert(second_roll_state == "move", "circle second turn should continue from roll to move")
  local second_move_state, second_move_args = _turn_move({ game = g }, second_roll_args)
  assert(second_move_state == "wait_choice", "circle second turn should pause at market interrupt")
  local second_move_result = assert(g.last_turn and g.last_turn.move_result, "circle second turn should keep move result")
  local second_interrupt = assert(second_move_result.market_interrupt, "circle second turn should include market interrupt")

  local visited_tile_ids = {}
  for _, idx in ipairs(second_move_result.visited or {}) do
    local tile_ref = assert(g.board:get_tile(idx), "circle second turn visited tile should exist")
    visited_tile_ids[#visited_tile_ids + 1] = tile_ref.id
  end
  assert(visited_tile_ids[1] == 39, "circle second turn should hit market first")
  assert(second_interrupt.remaining_steps == 3, "circle second turn should leave three resumable steps after market")

  g.turn.pending_choice = nil

  local final_move_state, _ = _turn_move({ game = g }, second_move_args.next_args)
  assert(final_move_state == "landing", "circle second turn should land after market resume")
  assert(player.position == assert(g.board:index_of_tile_id(45)), "circle second turn should land on chance 45")
end

local function _test_circle_market_bought_roadblock_then_mine_can_chain_in_post_action()
  local g, player, roadblock_id, mine_id = _setup_circle_market_bought_roadblock_and_mine()
  local phases, reopen_wait_args, pending = _reopen_circle_post_action_after_roadblock(g, player, roadblock_id)

  assert(_find_option_by_id(pending, mine_id), "reopened post_action should still offer mine")
  assert(_find_option_by_id(pending, roadblock_id) == nil, "reopened post_action should not offer consumed roadblock")

  local mine_use_result = choice_resolver.resolve(g, pending, { option_id = mine_id })
  assert(mine_use_result and mine_use_result.stay == false, "reopened post_action should allow using mine")
  assert(g.board:has_mine(player.position), "mine should be placed in the same turn after roadblock use")
  assert(_count_item(player, mine_id) == 0, "mine should be consumed after same-turn use")
  assert(g.turn.action_anim and g.turn.action_anim.kind == "mine",
    "same-turn mine use should queue mine action anim")

  local mine_anim_seq = g.turn.action_anim.seq
  local after_mine = await.action_anim(_new_await_session(g, {
    type = "action_anim_done",
    seq = mine_anim_seq,
  }), {
    next_state = reopen_wait_args.next_state,
    next_args = reopen_wait_args.next_args,
  })
  assert(after_mine and after_mine.next_state == "post_action",
    "mine action anim should keep post_action continuation contract")

  local final_state, final_args = phases.post_action({ game = g }, after_mine.next_args)
  assert(final_state == "end_turn", "post_action should end turn after roadblock and mine both resolve")
  assert(final_args and final_args.player == player, "end_turn should keep current player context")
end

local function _test_circle_market_bought_mine_remains_available_next_turn_after_skipping_reopened_post_action()
  local g, player, roadblock_id, mine_id = _setup_circle_market_bought_roadblock_and_mine()
  local _, _, pending = _reopen_circle_post_action_after_roadblock(g, player, roadblock_id)

  assert(_find_option_by_id(pending, mine_id), "reopened post_action should still offer mine before skip")

  local skip_result = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
  })
  assert(skip_result and skip_result.status == "resolved", "skipping reopened post_action should resolve the choice")
  assert(_count_item(player, mine_id) == 1, "skipping reopened post_action should keep mine in inventory")

  g:clear_player_temporal_flags(player)
  g:stop_all_players_movement()
  g.last_turn = {}

  local next_pre_action_choice = assert(item_phase.build_choice_spec(g, player, "pre_action"),
    "next turn pre_action should reopen with skipped mine")
  assert(_find_option_by_id(next_pre_action_choice, mine_id), "next turn pre_action should still offer skipped mine")
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
    {
      name = "mine_startup_profile_other_player_triggers_immediately_after_placement",
      run = _test_mine_startup_profile_other_player_triggers_immediately_after_placement,
    },
    {
      name = "mine_startup_profile_owner_triggers_on_third_own_turn",
      run = _test_mine_startup_profile_owner_triggers_on_third_own_turn,
    },
    {
      name = "strong_card_startup_profile_transfers_target_tile_on_use",
      run = _test_strong_card_startup_profile_transfers_target_tile_on_use,
    },
    {
      name = "strong_card_startup_profile_allows_free_rent_after_skipping_strong",
      run = _test_strong_card_startup_profile_allows_free_rent_after_skipping_strong,
    },
    {
      name = "strong_card_startup_profile_falls_back_to_direct_rent_after_skipping_both_cards",
      run = _test_strong_card_startup_profile_falls_back_to_direct_rent_after_skipping_both_cards,
    },
    {
      name = "post_action_item_phase_keeps_reactive_rent_cards_out_after_skipping_strong",
      run = _test_post_action_item_phase_keeps_reactive_rent_cards_out_after_skipping_strong,
    },
    {
      name = "post_action_auto_phase_waits_for_action_anim_followup",
      run = _test_post_action_auto_phase_waits_for_action_anim_followup,
    },
    {
      name = "pre_action_item_phase_remote_dice_then_mine_reopens_before_roll",
      run = _test_pre_action_item_phase_remote_dice_then_mine_reopens_before_roll,
    },
    {
      name = "combo_roadblock_mine_profile_exposes_both_cards_in_pre_action",
      run = _test_combo_roadblock_mine_profile_exposes_both_cards_in_pre_action,
    },
    {
      name = "roll_phase_no_longer_opens_active_item_window",
      run = _test_roll_phase_no_longer_opens_active_item_window,
    },
    {
      name = "dice_multiplier_used_in_pre_action_changes_same_turn_roll_total",
      run = _test_dice_multiplier_used_in_pre_action_changes_same_turn_roll_total,
    },
    {
      name = "steal_startup_profile_multi_item_choice_resumes_to_chance",
      run = _test_steal_startup_profile_multi_item_choice_resumes_to_chance,
    },
    {
      name = "steal_startup_profile_single_item_auto_steal_resumes_to_chance",
      run = _test_steal_startup_profile_single_item_auto_steal_resumes_to_chance,
    },
    {
      name = "steal_queue_startup_profile_skip_opens_next_target_and_resumes",
      run = _test_steal_queue_startup_profile_skip_opens_next_target_and_resumes,
    },
    {
      name = "steal_startup_profile_cancel_item_picker_keeps_state_and_resumes",
      run = _test_steal_startup_profile_cancel_item_picker_keeps_state_and_resumes,
    },
    {
      name = "choice_builders_reserve_base_inline_for_item_slots_only",
      run = _test_choice_builders_reserve_base_inline_for_item_slots_only,
    },
    {
      name = "circle_startup_profile_second_remote_roll_reaches_chance45_after_market_resume",
      run = _test_circle_startup_profile_second_remote_roll_reaches_chance45_after_market_resume,
    },
    {
      name = "circle_market_bought_roadblock_then_mine_can_chain_in_post_action",
      run = _test_circle_market_bought_roadblock_then_mine_can_chain_in_post_action,
    },
    {
      name = "circle_market_bought_mine_remains_available_next_turn_after_skipping_reopened_post_action",
      run = _test_circle_market_bought_mine_remains_available_next_turn_after_skipping_reopened_post_action,
    },
  },
}
