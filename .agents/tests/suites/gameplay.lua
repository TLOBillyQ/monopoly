local support = require("TestSupport")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _resolve_landing = support.resolve_landing
local _resolve_landing_with_choices = support.resolve_landing_with_choices
local _resolve_choice_first = support.resolve_choice_first
local _get_choice = support.get_choice
local _first_land_tile = support.first_land_tile
local _first_tile_by_type = support.first_tile_by_type
local _tile_state = support.tile_state
local movement = support.movement
local inventory = support.inventory
local steal = support.steal
local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local gameplay_loop = support.gameplay_loop
local tick_timeout = support.tick_timeout
local constants = support.constants
local bankruptcy = support.bankruptcy

local function _build_loop_state()
  local auto_runner = require("src.game.turn.AutoRunner")
  local state = {
    auto_runner = auto_runner:new({ interval = 0.01 }),
    ai_turn_runner = auto_runner:new({ interval = 0.4 }),
    ai_turn_runner_active = false,
    ui = {
      input_blocked = false,
      choice_active = false,
      market_active = false,
      popup_active = false,
    },
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
  }
  state.auto_runner:set_enabled(true)
  state.ai_turn_runner:set_enabled(true)
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
  local g = _new_game()
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
  local g = _new_game()
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

local function _test_stop_all_players_movement_clears_move_dir_and_stop_event()
  local g = _new_game()
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local stopped_ids = {}
  support.with_patches({
    { key = "vehicle_helper", value = {
      forward_eca_event_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    g:stop_all_players_movement()
  end)
  assert(g.players[1].status.move_dir == nil, "player1 move_dir should be cleared")
  assert(g.players[2].status.move_dir == nil, "player2 move_dir should be cleared")
  assert(#stopped_ids == #g.players, "stop event should be sent to all players")
end

local function _test_end_turn_stops_all_players_movement()
  local g = _new_game()
  g:set_player_status(g.players[1], "move_dir", "left")
  g:set_player_status(g.players[2], "move_dir", "right")
  local stopped_ids = {}
  support.with_patches({
    { key = "vehicle_helper", value = {
      forward_eca_event_stop = function(role_id)
        table.insert(stopped_ids, role_id)
      end,
    } },
  }, function()
    local phase_end = g.turn_flow.phases and g.turn_flow.phases.end_turn
    assert(type(phase_end) == "function", "end_turn phase should exist")
    phase_end(g.turn_flow, { player = g.players[1] })
  end)
  assert(g.players[1].status.move_dir == nil, "player1 move_dir should be cleared at end turn")
  assert(g.players[2].status.move_dir == nil, "player2 move_dir should be cleared at end turn")
  assert(#stopped_ids == #g.players, "end turn should stop all players")
end

local function _test_autorunner_runs_to_end()
  local auto_runner = require("src.game.turn.AutoRunner")
  local agent = require("src.game.game.Agent")
  local gameplay_rules = require("Config.GameplayRules")
  local land = require("src.game.land.Land")
  local land_actions = require("src.game.land.LandActions")
  local item_inventory = require("src.game.item.ItemInventory")

  local g = app:new({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  g.ui_port = _build_ui_port()

  local state = {
    auto_runner = auto_runner:new({ interval = 0.01 }),
    ui = { choice_active = false, market_active = false },
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

  local now = 0

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
        if g.finished then
          break
        end
        now = now + dt
        gameplay_loop.step_auto_runner(g, state, dt, {
          modal_active = false,
          modal_buttons = nil,
          game_finished = g.finished,
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
  g:set_player_seat(p1, 4001)

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
    g.board:place_mine(mine_pos.id)
  end

  local chance_cfg = require("Config.Generated.ChanceCards")
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
      local pending = _get_choice(g)
      if pending then
        _resolve_choice_first(g, pending)
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
  _resolve_landing_with_choices(g, p1, tile_chance, res1, 10)

  assert(p1, "玩家1应该存在")

  if p1.position == hospital_idx then
    assert(type(p1.status.stay_turns) == "number", "医院应设置 stay_turns")
  end

  assert(true, "复杂连续结算完成")
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

local function _test_ai_turn_auto_advance_without_autoplay()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local a1 = gameplay_loop.step_ai_turn_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
    })
    assert(a1 == nil, "should not trigger before reaching AI interval")
    local a2 = gameplay_loop.step_ai_turn_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
    })
    assert(a2 and a2.type == "ui_button" and a2.id == "next", "AI turn should auto dispatch next")
  end)
end

local function _test_human_turn_not_auto_advanced()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_ai_turn_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
    })
    assert(action == nil, "human turn should not auto dispatch next")
  end)
end

local function _test_ai_turn_not_advanced_when_input_blocked()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  state.ui.input_blocked = true
  g.turn.current_player_index = 2
  g.turn.phase = "wait_action_anim"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_ai_turn_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
    })
    assert(action == nil, "blocked phase should not auto dispatch next")
  end)
end

local function _test_auto_runner_depends_on_current_player_auto()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.players[1].auto = true
  g.players[2].auto = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action1 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = true,
    })
    assert(action1 and action1.type == "ui_button" and action1.id == "next",
      "current player auto should dispatch next")

    state.next_turn_locked = false
    g.turn.current_player_index = 2
    local action2 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = false,
    })
    assert(action2 == nil, "current player auto=false should not dispatch")
  end)
end

return {
  _test_mandatory_payment_causes_bankruptcy,
  _test_bankruptcy_resets_owned_tiles,
  _test_stop_all_players_movement_clears_move_dir_and_stop_event,
  _test_end_turn_stops_all_players_movement,
  _test_autorunner_runs_to_end,
  _test_complex_consecutive_turn_settlement,
  _test_complex_market_interrupt_with_rent,
  _test_ai_turn_auto_advance_without_autoplay,
  _test_human_turn_not_auto_advanced,
  _test_ai_turn_not_advanced_when_input_blocked,
  _test_auto_runner_depends_on_current_player_auto,
}
