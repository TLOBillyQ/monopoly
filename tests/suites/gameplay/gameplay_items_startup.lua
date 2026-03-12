local support = require("support.gameplay_support")
local gameplay_loop = support.gameplay_loop
local gameplay_rules = require("src.core.config.gameplay_rules")
local game_startup = require("src.app.bootstrap.game_startup")
local turn_roll = require("src.game.flow.turn.roll")
local move_followup = require("src.game.flow.turn.move_followup")
local board_utils = require("src.game.systems.land.board_utils")
local land_rules = require("src.game.systems.land.rules")
local item_phase = require("src.game.systems.items.phase")
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

  local use_result = support.executor.use_item(g, player, gameplay_rules.item_ids.remote_dice, { by_ai = false })
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

  local res = support.executor.use_item(g, player, gameplay_rules.item_ids.monster, { by_ai = false })
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

  local res = support.executor.use_item(g, player, gameplay_rules.item_ids.missile, { by_ai = false })
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

local function _test_mine_startup_profile_owner_arms_and_other_player_triggers_after_followup()
  local g, _ = _new_profile_game("mine")
  local p1 = g.players[1]
  local p2 = g.players[2]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "mine startup tile should exist")

  local use_res = support.executor.use_item(g, p1, gameplay_rules.item_ids.mine, { by_ai = false })
  assert(use_res ~= nil, "mine startup profile should allow mine use")
  assert(g.board:has_mine(mine_index), "mine startup profile should place mine on owner tile")

  local owner_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not (owner_res and owner_res.waiting == true and owner_res.next_state == "move_followup"),
    "owner should not trigger mine followup before mine is armed")
  assert((p1.status.stay_turns or 0) == 0, "owner should not be hospitalized before leaving mine tile")

  local move_res = movement.move(g, p1, 1, { branch_parity = 1, skip_market_check = true })
  assert(move_res and move_res.landing_tile, "owner should move away and arm the mine")
  local mine_state = assert(g.board:get_mine(mine_index), "armed mine should still exist")
  assert(mine_state.armed == true, "mine should arm after owner leaves tile")
  assert(mine_state.placed_turn_count == g.turn.turn_count, "mine should keep placement turn count")

  g:update_player_position(p1, mine_index)
  local owner_return_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not (owner_return_res and owner_return_res.waiting == true and owner_return_res.next_state == "move_followup"),
    "owner should stay immune when returning in placement turn")
  assert((p1.status.stay_turns or 0) == 0, "owner return should not hospitalize in placement turn")

  g:update_player_position(p2, mine_index)
  local trigger_res = _resolve_landing(g, p2, mine_tile, {})
  assert(trigger_res and trigger_res.waiting == true, "other player mine trigger should wait for move followup")
  assert(trigger_res.next_state == "move_followup", "other player mine trigger should resume through move_followup")
  assert((p2.status.stay_turns or 0) == 0, "mine hospital stay should be deferred until followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "post_action", "other player mine trigger should resume into post_action")
  assert((p2.status.stay_turns or 0) > 0, "other player should be hospitalized after mine followup")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after detonation")
end

local function _test_mine_startup_profile_owner_triggers_on_later_turn_after_arming()
  local g, _ = _new_profile_game("mine")
  local p1 = g.players[1]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "mine startup tile should exist")

  local use_res = support.executor.use_item(g, p1, gameplay_rules.item_ids.mine, { by_ai = false })
  assert(use_res ~= nil, "mine startup profile should allow mine use")
  assert(g.board:has_mine(mine_index), "mine startup profile should place mine on owner tile")

  local move_res = movement.move(g, p1, 1, { branch_parity = 1, skip_market_check = true })
  assert(move_res and move_res.landing_tile, "owner should move away and arm the mine")
  local mine_state = assert(g.board:get_mine(mine_index), "armed mine should still exist after owner leaves tile")
  assert(mine_state.armed == true, "mine should arm after owner leaves tile")

  g.turn.turn_count = g.turn.turn_count + 1
  g:update_player_position(p1, mine_index)

  local trigger_res = _resolve_landing(g, p1, mine_tile, {})
  assert(trigger_res and trigger_res.waiting == true, "owner should be hit by own mine after placement turn ends")
  assert(trigger_res.next_state == "move_followup", "owner mine trigger should resume through move_followup")
  assert((p1.status.stay_turns or 0) == 0, "owner hospital stay should still be deferred until followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "post_action", "owner mine trigger should resume into post_action")
  assert((p1.status.stay_turns or 0) > 0, "owner should be hospitalized on later turn self-trigger")
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

local function _test_post_action_item_phase_free_rent_resolves_after_skipping_strong()
  local g, _, player, target_tile, rent_prompt = _advance_strong_card_staging_to_rent_prompt()
  local owner = g.players[2]
  local target_state_before = _tile_state(g, target_tile)
  local player_cash_before = g:player_balance(player, "金币")
  local owner_cash_before = g:player_balance(owner, "金币")

  local skip_result = choice_resolver.resolve(g, rent_prompt, { option_id = "skip" })
  assert(skip_result and skip_result.stay == true, "skipping strong card should keep flow open")

  local post_action_choice = assert(item_phase.build_choice_spec(g, player, "post_action"),
    "post_action item phase should offer free rent after skipping strong card")
  _open_choice(g, post_action_choice)

  local pending = _get_choice(g)
  assert(pending and pending.kind == "item_phase_choice", "post_action item phase should expose item phase choice")
  local use_result = choice_resolver.resolve(g, pending, { option_id = gameplay_rules.item_ids.free_rent })

  assert(use_result and use_result.stay == false, "using free rent from item phase should resolve")
  assert(_get_choice(g) == nil, "using free rent from item phase should clear pending choice")
  assert(g.turn.item_phase_active == "", "using free rent from item phase should finish active item phase")
  assert(g.turn.item_phase and g.turn.item_phase.post_action and g.turn.item_phase.post_action.done == true,
    "using free rent from item phase should mark post_action done")
  assert(g:player_balance(player, "金币") == player_cash_before,
    "using free rent from item phase should not change player cash")
  assert(g:player_balance(owner, "金币") == owner_cash_before,
    "using free rent from item phase should not change owner cash")

  local target_state_after = _tile_state(g, target_tile)
  assert(target_state_after.owner_id == target_state_before.owner_id,
    "using free rent from item phase should keep target tile owner")
  assert(target_state_after.level == target_state_before.level,
    "using free rent from item phase should keep target tile level")
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
  assert(_count_item(player, gameplay_rules.item_ids.steal) == 0, "steal card should be consumed after success")
  assert(_count_item(player, gameplay_rules.item_ids.tax_free) == 1, "p1 should receive stolen tax_free")
  assert(_count_item(target, gameplay_rules.item_ids.tax_free) == 0, "p2 should lose stolen tax_free")
  assert(_count_item(target, gameplay_rules.item_ids.free_rent) == 1, "p2 should keep the unstolen item")
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
  assert(_count_item(player, gameplay_rules.item_ids.steal) == 0, "single-item steal should consume steal card")
  assert(_count_item(player, gameplay_rules.item_ids.free_rent) == 1, "p1 should receive the only target item")
  assert(_count_item(target, gameplay_rules.item_ids.free_rent) == 0, "p2 should lose the only target item")
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
  assert(_count_item(player, gameplay_rules.item_ids.steal) == 0, "queued steal success should consume steal card")
  assert(_count_item(player, gameplay_rules.item_ids.tax_free) == 1, "queued steal should transfer p3 tax_free to p1")
  assert(_count_item(second_target, gameplay_rules.item_ids.tax_free) == 0, "queued steal should remove p3 tax_free")
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
  assert(_count_item(player, gameplay_rules.item_ids.steal) == 1, "cancel should keep steal card on p1")
  assert(_count_item(player, gameplay_rules.item_ids.tax_free) == 0, "cancel should not transfer any item to p1")
  assert(_count_item(target, gameplay_rules.item_ids.tax_free) == 1, "cancel should keep target inventory unchanged")
  assert(_count_item(target, gameplay_rules.item_ids.free_rent) == 1, "cancel should keep all target items intact")

  _resume_after_steal_interrupt(g, player, interrupt)
end

local function _test_choice_builders_reserve_base_inline_for_item_slots_only()
  local g, _ = _new_profile_game("steal")
  local player = g.players[1]
  local land_choice_specs = require("src.game.systems.land.choice_specs")
  local purchase_policy = require("src.game.systems.market.application.purchase_policy")
  player.inventory:add({ id = gameplay_rules.item_ids.remote_dice })

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

  local vehicle_intent = purchase_policy.build_vehicle_replace_intent(player, {
    product_id = 9001,
    name = "筋斗云",
  }, 1200, "金币")
  local vehicle_choice = vehicle_intent and vehicle_intent.choice_spec or nil
  assert(vehicle_choice and vehicle_choice.route_key == "secondary_confirm",
    "market vehicle replace should no longer use base_inline")
  assert(vehicle_choice and vehicle_choice.requires_confirm == true,
    "market vehicle replace should require confirm")
  assert(vehicle_choice and vehicle_choice.cancel_label == "算了",
    "market vehicle replace should expose skip wording")
  assert(vehicle_choice and vehicle_choice.confirm_title == "更换座驾",
    "market vehicle replace should expose confirm title")
  assert(vehicle_choice and string.find(vehicle_choice.confirm_body, "当前座驾：", 1, true) ~= nil,
    "market vehicle replace should expose a descriptive confirm body")
end

local function _test_circle_startup_profile_second_remote_roll_reaches_nanchang_after_market_resume()
  local g, _ = _new_profile_game("circle")
  local player = g.players[1]
  local remote_dice_id = gameplay_rules.item_ids.remote_dice
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
  assert(player.position == assert(g.board:index_of_tile_id(25)), "circle second turn should land on nanchang")
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
      name = "mine_startup_profile_owner_arms_and_other_player_triggers_after_followup",
      run = _test_mine_startup_profile_owner_arms_and_other_player_triggers_after_followup,
    },
    {
      name = "mine_startup_profile_owner_triggers_on_later_turn_after_arming",
      run = _test_mine_startup_profile_owner_triggers_on_later_turn_after_arming,
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
      name = "post_action_item_phase_free_rent_resolves_after_skipping_strong",
      run = _test_post_action_item_phase_free_rent_resolves_after_skipping_strong,
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
      name = "circle_startup_profile_second_remote_roll_reaches_nanchang_after_market_resume",
      run = _test_circle_startup_profile_second_remote_roll_reaches_nanchang_after_market_resume,
    },
  },
}
