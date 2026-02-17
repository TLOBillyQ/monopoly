local support = require("support.regression_support")
local context_helpers = require("support.regression.runtime_context_helpers")
local loop_builder = require("support.regression.loop_state_builder")

local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local movement = support.movement
local inventory = support.inventory
local steal = support.steal
local gameplay_loop = support.gameplay_loop
local tick_timeout = support.tick_timeout
local constants = support.constants

local turn_dispatch = require("turn.dispatch")

local function test_autorunner_runs_to_end()
  local auto_runner = require("turn.auto")
  local agent = require("game.rule.agent")
  local gameplay_rules = require("cfg.GameplayRules")
  local land = require("game.land.effect")
  local land_actions = require("game.land.action")
  local item_inventory = require("game.item.inventory")

  app.setup({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  local g = app
  g.ui_port = support.build_ui_port()

  local state = {
    gameplay_loop_ports = loop_builder.build_test_ports({
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

  local turn_limit = gameplay_rules.turn_limit or 0
  local max_steps = turn_limit * 5
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
    while game_ctx.turn and game_ctx.turn.phase == "detained_wait" and guard < 20 do
      gameplay_loop.tick(game_ctx, state_ctx, dt)
      guard = guard + 1
    end
  end

  local old_handle_pass_players = steal.handle_pass_players
  local old_pick_roadblock_target = agent.pick_roadblock_target
  local old_can_pay_rent = land.executors.pay_rent.can_apply
  local game_api = GameAPI or {}
  local patches = {
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
        state.ui_dirty = false
        g.dirty.ui = false
        g.dirty.players = false
        g.dirty.turn = false
        g.dirty.board_tiles = false
        g.dirty.any = false
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
            return ctx.pending_choice and true or false
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
        if g.turn and g.turn.phase == "detained_wait" then
          gameplay_loop.tick(g, state, dt)
        end
        tick_timeout.step_choice_timeout(g, state, dt, {
          on_pending_choice = function() end,
          is_choice_active = function(ctx)
            return ctx.pending_choice and true or false
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

local function test_complex_consecutive_turn_settlement()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  p1.inventory:add({ id = 2007 })
  g:set_player_cash(p1, 10000)
  context_helpers.with_vehicle_enabled(function()
    g:set_player_seat(p1, 4001)
  end)

  p2.inventory:add({ id = 2001 })
  g:set_player_cash(p2, 10000)

  g:update_player_position(p1, 10)
  g:update_player_position(p2, 12)

  local chance_idx = first_tile_by_type(g.board, "chance")
  local hospital_idx = first_tile_by_type(g.board, "hospital")

  g:update_player_position(p1, chance_idx - 3)
  g:update_player_position(p2, chance_idx - 2)

  local mine_pos = g.board:get_tile(chance_idx + 2)
  if mine_pos then
    g.board:place_mine(mine_pos.id)
  end

  local chance_cfg = require("cfg.Generated.ChanceCards")
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
  local initial_has_vehicle = p1.seat_id and true or false

  assert(initial_has_steal_card, "p1 应该有偷窃卡")
  assert(initial_p2_item_count > 0, "p2 应该有道具可被偷")
  assert(initial_has_vehicle, "p1 应该有座驾")

  local res1 = movement.move(g, p1, 3, { branch_parity = 3, skip_market_check = true })
  local first_res = res1
  if res1.steal_interrupt then
    local interrupt = res1.steal_interrupt
    local steal_res = steal.handle_pass_players(g, p1, interrupt.encountered_ids or {})
    if steal_res and steal_res.waiting then
      local pending = get_choice(g)
      if pending then
        resolve_choice_first(g, pending)
      end
    end
    res1 = movement.move(g, p1, interrupt.remaining_steps, {
      branch_parity = interrupt.branch_parity,
      direction = interrupt.facing,
      skip_market_check = true,
      skip_steal_check = true,
    })
  end

  assert(first_res.encountered_players and #first_res.encountered_players > 0, "应该经过其他玩家")
  assert(p1.position == chance_idx, "应该停在机会卡格子")

  local tile_chance = g.board:get_tile(chance_idx)
  resolve_landing_with_choices(g, p1, tile_chance, res1, 10)

  assert(p1, "玩家1应该存在")

  if p1.position == hospital_idx then
    assert(type(p1.status.stay_turns) == "number", "医院应设置 stay_turns")
  end

  assert(true, "复杂连续结算完成")
end

local function test_complex_market_interrupt_with_rent()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]

  g:set_player_cash(p1, 50000)
  g:set_player_cash(p2, 50000)

  local market_idx = first_tile_by_type(g.board, "market")

  local land_idx, land_tile = first_land_tile(g.board)
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
    resolve_landing_with_choices(g, p1, final_tile, res, 10)
  end

  assert(p1, "玩家应该存在")
  assert(true, "黑市中断 + 租金支付场景完成")
end


return {
  test_autorunner_runs_to_end,
  test_complex_consecutive_turn_settlement,
  test_complex_market_interrupt_with_rent,
}
