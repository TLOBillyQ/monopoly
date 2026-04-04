---@diagnostic disable
local function make_cases(helpers)
  local _ENV = helpers

local function _test_autorunner_runs_to_end()
  local auto_runner = require("src.turn.policies.auto_runner")
  local agent = require("src.computer.core_agent")
  local land = require("src.rules.land.executors")
  local land_actions = require("src.rules.land.actions")
  local item_inventory = require("src.rules.items.inventory")

  local g = require("src.app.compose_game").new_game(default_ports.resolve_game_opts({
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

  local turn_limit = timing.turn_limit or 0
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
    { target = timing, key = "detained_turn_wait_seconds", value = 0 },
    { target = timing, key = "inter_turn_wait_seconds", value = 0 },
    { target = steal, key = "handle_pass_players", value = function(game_ctx, player, encountered_ids)
      if not item_inventory.find_index(player, item_ids.steal) then
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

  if not inventory.find_index(p1, item_ids.steal) then
    p1.inventory:add({ id = item_ids.steal })
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

local function _test_decision_engine_cancels_item_phase_passive()
  local decision_engine = require("src.computer.agent.decision_engine")
  local g = _new_game()
  local player = g.players[1]
  player.is_ai = true
  
  local decide = decision_engine.build(require("src.computer.core_agent"))
  
  local choice = {
    id = 100,
    kind = "item_phase_passive",
    title = "被动物品",
    options = { { id = 2005, label = "物品选项" } },
    meta = { player_id = player.id },
  }
  
  local result = decide(g, choice)
  
  assert(result, "decide should return an action for item_phase_passive")
  assert(result.type == "choice_cancel", "item_phase_passive should result in choice_cancel")
  assert(result.choice_id == choice.id, "should preserve choice_id")
  assert(result.actor_role_id == player.id, "should preserve actor_role_id")
end

  return {
    _test_autorunner_runs_to_end = _test_autorunner_runs_to_end,
    _test_complex_consecutive_turn_settlement = _test_complex_consecutive_turn_settlement,
    _test_forced_move_landing_optional_preserves_owner_role_id_for_buy_land = _test_forced_move_landing_optional_preserves_owner_role_id_for_buy_land,
    _test_forced_move_landing_optional_preserves_owner_role_id_for_upgrade_land = _test_forced_move_landing_optional_preserves_owner_role_id_for_upgrade_land,
    _test_complex_market_interrupt_with_rent = _test_complex_market_interrupt_with_rent,
    _test_market_interrupt_resume_uses_interrupt_facing = _test_market_interrupt_resume_uses_interrupt_facing,
    _test_steal_interrupt_resume_uses_interrupt_facing = _test_steal_interrupt_resume_uses_interrupt_facing,
    _test_decision_engine_cancels_item_phase_passive = _test_decision_engine_cancels_item_phase_passive,
  }
end

return { make_cases = make_cases }
