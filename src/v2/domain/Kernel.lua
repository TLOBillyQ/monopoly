local commands = require("src.v2.domain.Commands")
local events = require("src.v2.domain.Events")
local state_mod = require("src.v2.domain.State")
local reducers = require("src.v2.domain.Reducers.Index")

local movement_service = require("src.v2.domain.services.MovementService")
local landing_service = require("src.v2.domain.services.LandingService")
local land_service = require("src.v2.domain.services.LandService")
local item_service = require("src.v2.domain.services.ItemService")
local market_service = require("src.v2.domain.services.MarketService")
local auto_agent_service = require("src.v2.domain.services.AutoAgentService")
local bankruptcy_service = require("src.v2.domain.services.BankruptcyService")
local victory_service = require("src.v2.domain.services.VictoryService")
local common = require("src.v2.domain.services.Common")

local kernel = {}
kernel.__index = kernel

local command_types = commands.types
local event_types = events.types

local function _clone(value)
  return state_mod.deep_copy(value)
end

local function _copy_path(path)
  local out = {}
  for i, key in ipairs(path or {}) do
    out[i] = key
  end
  return out
end

local function _table_equal(a, b)
  if a == b then
    return true
  end
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return false
  end
  for key, value_a in pairs(a) do
    if not _table_equal(value_a, b[key]) then
      return false
    end
  end
  for key in pairs(b) do
    if a[key] == nil then
      return false
    end
  end
  return true
end

local function _diff_state(before, after, path, out)
  if type(before) ~= "table" or type(after) ~= "table" then
    if not _table_equal(before, after) then
      out[#out + 1] = events.patch(_copy_path(path), _clone(after))
    end
    return
  end

  local seen = {}
  for key, value_after in pairs(after) do
    seen[key] = true
    local next_path = _copy_path(path)
    next_path[#next_path + 1] = key
    _diff_state(before[key], value_after, next_path, out)
  end
  for key in pairs(before) do
    if not seen[key] then
      local next_path = _copy_path(path)
      next_path[#next_path + 1] = key
      out[#out + 1] = events.patch(next_path, nil)
    end
  end
end

local function _resolve_seat(state, command)
  if command.seat_id ~= nil then
    return command.seat_id
  end
  if command.role_id ~= nil then
    local seat = state_mod.resolve_seat_by_role_id(state, command.role_id)
    if seat ~= nil then
      return seat
    end
  end
  return nil
end

local function _lcg_next(seed)
  local value = (1103515245 * seed + 12345) % 2147483647
  if value <= 0 then
    value = 1
  end
  return value
end

local function _roll_dice(state, player)
  local dice_count = common.default_dice_count(player)
  local rolls = {}
  local total = 0
  local next_seed = state.rng_seed
  if player.status.pending_remote_dice and type(player.status.pending_remote_dice.values) == "table" then
    local values = player.status.pending_remote_dice.values
    for index = 1, dice_count do
      local value = values[index] or values[#values] or 1
      if value < 1 then
        value = 1
      end
      if value > 6 then
        value = 6
      end
      rolls[#rolls + 1] = value
      total = total + value
    end
  else
    for _ = 1, dice_count do
      next_seed = _lcg_next(next_seed)
      local value = (next_seed % 6) + 1
      rolls[#rolls + 1] = value
      total = total + value
    end
  end
  local multiplier = player.status.pending_dice_multiplier or 1
  if multiplier > 1 then
    total = total * multiplier
  end
  return rolls, total, next_seed
end

local function _build_choice(state, choice)
  if not choice then
    return nil
  end
  local seq = state.turn.seq.choice + 1
  state.turn.seq.choice = seq
  choice.id = seq
  return choice
end

local function _open_choice(state, choice, now, semantic_events)
  local ready = _build_choice(state, choice)
  if not ready then
    return
  end
  state.turn.pending_interaction = ready
  state.turn.phase = "wait_choice"
  local timeout = state.rules.action_timeout_seconds or 10
  state.turn.choice_deadline = (now or state.clock.now or 0) + timeout
  state.turn.choice_remaining = nil
  semantic_events[#semantic_events + 1] = events.new(event_types.choice_opened, {
    choice = ready,
    deadline = state.turn.choice_deadline,
  })
end

local function _clear_choice(state, semantic_events, choice_id, action, option_id)
  state.turn.pending_interaction = nil
  state.turn.choice_deadline = nil
  state.turn.choice_remaining = nil
  semantic_events[#semantic_events + 1] = events.new(event_types.choice_resolved, {
    choice_id = choice_id,
    action = action,
    option_id = option_id,
  })
end

local function _queue_move_anim(state, seat, move_result, semantic_events)
  state.turn.seq.move = state.turn.seq.move + 1
  state.turn.move_anim = {
    seq = state.turn.seq.move,
    player_seat = seat,
    from_index = move_result.from_index,
    to_index = move_result.to_index,
    steps = move_result.steps,
    visited = move_result.visited,
  }
  state.turn.move_result = move_result
  state.turn.phase = "wait_move_anim"
  semantic_events[#semantic_events + 1] = events.new(event_types.move_anim_queued, state.turn.move_anim)
end

local function _queue_action_anim(state, seat, kind, tile_id, semantic_events)
  state.turn.seq.action = state.turn.seq.action + 1
  state.turn.action_anim = {
    seq = state.turn.seq.action,
    player_seat = seat,
    kind = kind,
    tile_id = tile_id,
  }
  state.turn.phase = "wait_action_anim"
  semantic_events[#semantic_events + 1] = events.new(event_types.action_anim_queued, state.turn.action_anim)
end

local function _finish_turn(state, semantic_events)
  local current = state.turn.current_seat
  local player = state.players[current]
  if player then
    if player.status and player.status.deity and (player.status.deity.remaining or 0) > 0 then
      player.status.deity.remaining = player.status.deity.remaining - 1
      if player.status.deity.remaining <= 0 then
        player.status.deity.type = ""
        player.status.deity.remaining = 0
      end
    end
    common.clear_temporal_flags(player)
  end
  local next_seat = state_mod.next_alive_seat(state, current)
  state.turn.current_seat = next_seat
  state.turn.phase = "idle"
  state.turn.move_anim = nil
  state.turn.action_anim = nil
  state.turn.move_result = nil
  state.turn.pending_interaction = nil
  state.turn.choice_deadline = nil
  state.turn.choice_remaining = nil
  state.turn.countdown_active = false
  state.turn.countdown_seconds = 0
  semantic_events[#semantic_events + 1] = events.new(event_types.turn_finished, {
    prev_seat = current,
    next_seat = next_seat,
  })
end

local function _continue_move_after_interrupt(state, seat, meta, semantic_events)
  local remaining_steps = tonumber(meta.remaining_steps) or 0
  if remaining_steps <= 0 then
    local landing = landing_service.resolve(state, seat, state.turn.move_result)
    if landing.waiting then
      _open_choice(state, landing.choice, state.clock.now, semantic_events)
      return
    end
    _queue_action_anim(state, seat, landing.action_kind or "landing_done", landing.tile_id, semantic_events)
    return
  end

  local move_result = movement_service.move(state, seat, remaining_steps, {
    direction = meta.facing,
    branch_parity = meta.branch_parity,
    skip_steal_check = true,
  })
  local player = state.players[seat]
  player.position = move_result.to_index
  player.move_dir = move_result.facing
  if move_result.passed_start and move_result.passed_start > 0 then
    player.cash = player.cash + (state.rules.pass_start_bonus or 0) * move_result.passed_start
  end
  semantic_events[#semantic_events + 1] = events.new(event_types.player_moved, {
    seat = seat,
    from_index = move_result.from_index,
    to_index = move_result.to_index,
    steps = move_result.steps,
  })
  _queue_move_anim(state, seat, move_result, semantic_events)
end

local function _option_exists(choice, option_id)
  for _, option in ipairs(choice.options or {}) do
    local id = option.id or option
    if tostring(id) == tostring(option_id) then
      return true
    end
  end
  return false
end

local function _resolve_choice_option(choice, command)
  if command.type == command_types.choice_cancel then
    return "cancel"
  end
  local option_id = command.payload and command.payload.option_id
  if option_id ~= nil and _option_exists(choice, option_id) then
    return option_id
  end
  local first = choice.options and choice.options[1]
  return first and (first.id or first) or "cancel"
end

local function _apply_manual_item_choice(state, choice, option_id, semantic_events)
  local owner_seat = choice.meta and choice.meta.owner_seat or state.turn.current_seat
  if choice.kind == "remote_dice_value" then
    item_service.resolve_remote_dice(state, owner_seat, option_id)
    _queue_action_anim(state, owner_seat, "remote_dice", nil, semantic_events)
    return
  end
  if choice.kind == "roadblock_target" then
    item_service.resolve_roadblock(state, owner_seat, option_id)
    _queue_action_anim(state, owner_seat, "roadblock", tonumber(option_id), semantic_events)
    return
  end
  if choice.kind == "demolish_target" then
    local item_id = choice.meta and choice.meta.item_id
    local res = item_service.resolve_demolish(state, owner_seat, item_id, option_id)
    _queue_action_anim(state, owner_seat, res.effect or "demolish", res.tile_id, semantic_events)
    return
  end
  if choice.kind == "item_target_player" then
    local item_id = choice.meta and choice.meta.item_id
    item_service.resolve_item_target(state, owner_seat, item_id, tonumber(option_id))
    _queue_action_anim(state, owner_seat, "item_target", nil, semantic_events)
    return
  end
  if choice.kind == "item_phase_choice" then
    local phase = choice.meta and choice.meta.phase
    local res = item_service.resolve_item_phase_choice(state, owner_seat, option_id, phase)
    if res.waiting and res.choice then
      _open_choice(state, res.choice, state.clock.now, semantic_events)
      return
    end
    _queue_action_anim(state, owner_seat, "item_phase", nil, semantic_events)
  end
end

local function _decide_after_move(state, semantic_events)
  local seat = state.turn.current_seat
  local move_result = state.turn.move_result or {}

  if move_result.steal_interrupt then
    local interrupt = move_result.steal_interrupt
    local queue = {}
    for _, other_seat in ipairs(interrupt.encountered_ids or {}) do
      local target = state.players[other_seat]
      if target and not target.eliminated and not common.has_deity(target, "angel") then
        queue[#queue + 1] = other_seat
      end
    end
    if #queue > 0 and common.has_item(state.players[seat], common.item_ids.steal) then
      _open_choice(state, {
        kind = "steal_prompt",
        title = "是否使用偷窃卡",
        body_lines = { "目标：" .. tostring(state.players[queue[1]].name) },
        options = {
          { id = "use", label = "使用" },
          { id = "skip", label = "跳过" },
        },
        allow_cancel = false,
        cancel_label = "跳过",
        meta = {
          owner_seat = seat,
          queue = queue,
          index = 1,
          remaining_steps = interrupt.remaining_steps,
          facing = interrupt.facing,
          branch_parity = interrupt.branch_parity,
        },
      }, state.clock.now, semantic_events)
      return
    end
    _continue_move_after_interrupt(state, seat, interrupt, semantic_events)
    return
  end

  if move_result.market_interrupt then
    local choice = market_service.build_choice(state, seat)
    if choice then
      choice.meta.remaining_steps = move_result.market_interrupt.remaining_steps
      choice.meta.facing = move_result.market_interrupt.facing
      choice.meta.branch_parity = move_result.market_interrupt.branch_parity
      _open_choice(state, choice, state.clock.now, semantic_events)
      return
    end
    _continue_move_after_interrupt(state, seat, move_result.market_interrupt, semantic_events)
    return
  end

  local landing = landing_service.resolve(state, seat, move_result)
  if landing.waiting then
    _open_choice(state, landing.choice, state.clock.now, semantic_events)
    return
  end
  _queue_action_anim(state, seat, landing.action_kind or "landing_done", landing.tile_id, semantic_events)
end

local function _handle_next_turn(state, command, semantic_events)
  if state.turn.phase ~= "idle" or state.turn.frozen then
    return
  end
  local seat = state.turn.current_seat
  local player = state.players[seat]
  if not player then
    return
  end

  state.turn.turn_no = state.turn.turn_no + 1
  if player.eliminated then
    semantic_events[#semantic_events + 1] = events.new(event_types.turn_began, {
      turn_no = state.turn.turn_no,
      seat = seat,
      dice = 0,
      rolls = {},
      next_seed = state.rng_seed,
    })
    _finish_turn(state, semantic_events)
    return
  end

  if (player.status.stay_turns or 0) > 0 then
    player.status.stay_turns = player.status.stay_turns - 1
    semantic_events[#semantic_events + 1] = events.new(event_types.turn_began, {
      turn_no = state.turn.turn_no,
      seat = seat,
      dice = 0,
      rolls = {},
      next_seed = state.rng_seed,
    })
    _finish_turn(state, semantic_events)
    return
  end

  local rolls, total, next_seed = _roll_dice(state, player)
  state.rng_seed = next_seed
  player.status.pending_remote_dice = nil
  player.status.pending_dice_multiplier = 1

  local move_result = movement_service.move(state, seat, total, {
    branch_parity = total,
  })
  local from_index = player.position
  player.position = move_result.to_index
  player.move_dir = move_result.facing
  if move_result.passed_start and move_result.passed_start > 0 then
    player.cash = player.cash + (state.rules.pass_start_bonus or 0) * move_result.passed_start
  end
  if move_result.stopped_on_roadblock then
    state.board.overlays.roadblocks[move_result.to_index] = nil
    if (player.status.stay_turns or 0) < 1 then
      player.status.stay_turns = 1
    end
  end

  state.turn.last_dice = total
  state.turn.last_rolls = rolls
  state.turn.last_turn = {
    seat = seat,
    player_name = player.name,
    rolls = rolls,
    total = total,
    from_index = from_index,
    to_index = move_result.to_index,
  }

  semantic_events[#semantic_events + 1] = events.new(event_types.turn_began, {
    turn_no = state.turn.turn_no,
    seat = seat,
    dice = total,
    rolls = rolls,
    next_seed = next_seed,
  })
  semantic_events[#semantic_events + 1] = events.new(event_types.player_moved, {
    seat = seat,
    from_index = move_result.from_index,
    to_index = move_result.to_index,
    steps = move_result.steps,
  })
  _queue_move_anim(state, seat, move_result, semantic_events)
end

local function _handle_choice(state, command, semantic_events)
  if state.turn.phase ~= "wait_choice" then
    return
  end
  local choice = state.turn.pending_interaction
  if not choice then
    return
  end
  local option_id = _resolve_choice_option(choice, command)
  _clear_choice(state, semantic_events, choice.id, command.type, option_id)

  local owner_seat = choice.meta and choice.meta.owner_seat or state.turn.current_seat

  if choice.kind == "landing_optional_effect" then
    local tile_id = choice.meta and choice.meta.tile_id
    if option_id == "buy_land" and tile_id and land_service.can_buy(state, owner_seat, tile_id) then
      local player = state.players[owner_seat]
      local cost = land_service.buy_cost(state, tile_id)
      player.cash = player.cash - cost
      state.board.tile_states[tile_id].owner_id = owner_seat
      state.board.tile_states[tile_id].level = 1
      player.properties[tile_id] = true
      semantic_events[#semantic_events + 1] = events.new(event_types.land_bought, {
        owner_seat = owner_seat,
        tile_id = tile_id,
        cost = cost,
        level = 1,
      })
    elseif option_id == "upgrade_land" and tile_id and land_service.can_upgrade(state, owner_seat, tile_id) then
      local player = state.players[owner_seat]
      local st = state.board.tile_states[tile_id]
      local cost = land_service.upgrade_cost(state, tile_id, st.level or 0)
      player.cash = player.cash - cost
      st.level = (st.level or 0) + 1
      semantic_events[#semantic_events + 1] = events.new(event_types.land_upgraded, {
        owner_seat = owner_seat,
        tile_id = tile_id,
        cost = cost,
        level = st.level,
      })
    end
    _queue_action_anim(state, owner_seat, "landing_optional_effect", choice.meta and choice.meta.tile_id, semantic_events)
    return
  end

  if choice.kind == "market_buy" then
    if option_id ~= "cancel" then
      local product_id = tonumber(option_id)
      local entry = product_id and market_service.entry(product_id) or nil
      if entry and market_service.can_buy_entry(state, owner_seat, entry) then
        local player = state.players[owner_seat]
        local price = market_service.entry_price(product_id)
        local currency = market_service.entry_currency(product_id)
        common.change_balance(player, currency, -price)
        if entry.kind == "item" then
          common.give_item(player, product_id)
        else
          player.seat_vehicle_id = product_id
        end
        state.market.global_limits[product_id] = (state.market.global_limits[product_id] or 0) - 1
      end
    end
    _continue_move_after_interrupt(state, owner_seat, choice.meta or {}, semantic_events)
    return
  end

  if choice.kind == "steal_prompt" then
    if option_id == "use" then
      local queue = choice.meta and choice.meta.queue or {}
      local index = choice.meta and choice.meta.index or 1
      local target_seat = queue[index]
      local target = target_seat and state.players[target_seat] or nil
      if target and #target.inventory.items > 0 then
        local options = {}
        for idx, item in ipairs(target.inventory.items) do
          options[#options + 1] = { id = idx, label = item_service.item_name(item.id) }
        end
        _open_choice(state, {
          kind = "steal_item",
          title = "偷窃卡：选择道具",
          body_lines = { "目标：" .. tostring(target.name) },
          options = options,
          allow_cancel = true,
          cancel_label = "取消",
          meta = choice.meta,
        }, state.clock.now, semantic_events)
        return
      end
    end
    _continue_move_after_interrupt(state, owner_seat, choice.meta or {}, semantic_events)
    return
  end

  if choice.kind == "steal_item" then
    local queue = choice.meta and choice.meta.queue or {}
    local target_seat = queue[choice.meta and choice.meta.index or 1]
    item_service.resolve_steal(state, owner_seat, target_seat, tonumber(option_id))
    _continue_move_after_interrupt(state, owner_seat, choice.meta or {}, semantic_events)
    return
  end

  if choice.kind == "rent_card_prompt" then
    local tile_id = choice.meta and choice.meta.tile_id
    local player = state.players[owner_seat]
    if option_id == "use" then
      if choice.meta and choice.meta.card_kind == "free" then
        if player.status.pending_free_rent then
          player.status.pending_free_rent = false
        else
          common.consume_item(player, common.item_ids.free_rent)
        end
      elseif choice.meta and choice.meta.card_kind == "strong" then
        local total_value = choice.meta.total_value or 0
        local owner_target_seat = choice.meta.owner_target_seat
        local owner_target = owner_target_seat and state.players[owner_target_seat] or nil
        if owner_target and player.cash >= total_value then
          common.consume_item(player, common.item_ids.strong)
          player.cash = player.cash - total_value
          owner_target.cash = owner_target.cash + total_value
          state.board.tile_states[tile_id].owner_id = owner_seat
          state.players[owner_target_seat].properties[tile_id] = nil
          player.properties[tile_id] = true
        end
      end
    else
      local rent, owner_target_seat = land_service.rent_amount(state, tile_id, owner_seat)
      local payer = state.players[owner_seat]
      local receiver = owner_target_seat and state.players[owner_target_seat] or nil
      if receiver and rent > 0 then
        if payer.cash >= rent then
          payer.cash = payer.cash - rent
          receiver.cash = receiver.cash + rent
        else
          local paid = math.max(payer.cash, 0)
          payer.cash = 0
          receiver.cash = receiver.cash + paid
          bankruptcy_service.eliminate(state, owner_seat)
        end
      end
    end
    _queue_action_anim(state, owner_seat, "rent", tile_id, semantic_events)
    return
  end

  if choice.kind == "tax_card_prompt" then
    local player = state.players[owner_seat]
    if option_id == "use" then
      if player.status.pending_tax_free then
        player.status.pending_tax_free = false
      else
        common.consume_item(player, common.item_ids.tax_free)
      end
    else
      local fee = land_service.tax_amount(state, owner_seat)
      player.cash = player.cash - fee
      if player.cash <= 0 then
        bankruptcy_service.eliminate(state, owner_seat)
      end
    end
    _queue_action_anim(state, owner_seat, "tax", nil, semantic_events)
    return
  end

  if choice.kind == "remote_dice_value"
      or choice.kind == "roadblock_target"
      or choice.kind == "demolish_target"
      or choice.kind == "item_target_player"
      or choice.kind == "item_phase_choice" then
    _apply_manual_item_choice(state, choice, option_id, semantic_events)
    return
  end

  _queue_action_anim(state, owner_seat, "choice_skip", nil, semantic_events)
end

local function _handle_move_anim_done(state, command, semantic_events)
  if state.turn.phase ~= "wait_move_anim" or not state.turn.move_anim then
    return
  end
  local seq = command.payload and command.payload.seq
  if seq ~= nil and seq ~= state.turn.move_anim.seq then
    return
  end
  semantic_events[#semantic_events + 1] = events.new(event_types.move_anim_confirmed, {
    seq = state.turn.move_anim.seq,
  })
  state.turn.move_anim = nil
  state.turn.phase = "post_move"
  _decide_after_move(state, semantic_events)
end

local function _handle_action_anim_done(state, command, semantic_events)
  if state.turn.phase ~= "wait_action_anim" or not state.turn.action_anim then
    return
  end
  local seq = command.payload and command.payload.seq
  if seq ~= nil and seq ~= state.turn.action_anim.seq then
    return
  end
  semantic_events[#semantic_events + 1] = events.new(event_types.action_anim_confirmed, {
    seq = state.turn.action_anim.seq,
  })
  state.turn.action_anim = nil
  state.turn.phase = "post_action"
  _finish_turn(state, semantic_events)
end

local function _handle_role_offline(state, seat, issued_at, semantic_events)
  local player = seat and state.players[seat] or nil
  if not player or player.online == false then
    return
  end
  player.online = false
  player.offline_since = issued_at
  semantic_events[#semantic_events + 1] = events.new(event_types.player_offline, { seat = seat, at = issued_at })
  if state.rules.reconnect.freeze_on_disconnect and state.turn.current_seat == seat then
    state.turn.frozen = true
    state.turn.frozen_reason = "offline"
    state.turn.frozen_seat = seat
    semantic_events[#semantic_events + 1] = events.new(event_types.match_frozen, {
      reason = "offline",
      seat = seat,
    })
  end
end

local function _handle_role_online(state, seat, issued_at, semantic_events)
  local player = seat and state.players[seat] or nil
  if not player then
    return
  end
  player.online = true
  player.offline_since = nil
  player.last_seen_at = issued_at
  semantic_events[#semantic_events + 1] = events.new(event_types.player_online, { seat = seat, at = issued_at })

  local grace = state.rules.reconnect.grace_seconds or 20
  state.reconnect.grace_until[seat] = issued_at + grace
  semantic_events[#semantic_events + 1] = events.new(event_types.reconnect_grace_set, {
    seat = seat,
    expires_at = issued_at + grace,
  })

  if state.turn.frozen and state.turn.current_seat == seat then
    state.turn.frozen = false
    state.turn.frozen_reason = nil
    state.turn.frozen_seat = nil
    semantic_events[#semantic_events + 1] = events.new(event_types.match_unfrozen, {
      reason = "reconnect",
      seat = seat,
    })
  end
end

local function _handle_tick(state, command, semantic_events)
  local now = command.issued_at or state.clock.now
  local old = state.clock.now
  state.clock.dt = now - old
  if state.clock.dt < 0 then
    state.clock.dt = 0
  end
  state.clock.now = now
  semantic_events[#semantic_events + 1] = events.new(event_types.clock_tick, { now = now })

  for seat, player in ipairs(state.players) do
    if player.online == false and player.offline_since ~= nil and not player.auto then
      local elapsed = now - player.offline_since
      if elapsed >= (state.rules.reconnect.offline_auto_host_seconds or 90) then
        player.auto = true
        semantic_events[#semantic_events + 1] = events.new(event_types.player_auto_set, {
          seat = seat,
          enabled = true,
        })
        if state.turn.frozen and state.turn.current_seat == seat then
          state.turn.frozen = false
          state.turn.frozen_reason = nil
          state.turn.frozen_seat = nil
          semantic_events[#semantic_events + 1] = events.new(event_types.match_unfrozen, {
            reason = "auto_host",
            seat = seat,
          })
        end
      end
    end
  end

  if state.turn.pending_interaction and not state.turn.frozen and state.turn.choice_deadline then
    local remaining = state.turn.choice_deadline - now
    if remaining < 0 then
      remaining = 0
    end
    state.turn.countdown_active = true
    state.turn.countdown_seconds = math.ceil(remaining)
  else
    state.turn.countdown_active = false
    state.turn.countdown_seconds = 0
  end
end

local function _handle_set_auto(state, seat, command, semantic_events)
  if not seat then
    seat = state.turn.current_seat
  end
  local player = state.players[seat]
  if not player then
    return
  end
  local enabled = command.payload and command.payload.enabled
  if enabled == nil then
    enabled = not player.auto
  end
  player.auto = enabled == true
  semantic_events[#semantic_events + 1] = events.new(event_types.player_auto_set, {
    seat = seat,
    enabled = player.auto,
  })
  if state.turn.frozen and state.turn.current_seat == seat and player.auto then
    state.turn.frozen = false
    state.turn.frozen_reason = nil
    state.turn.frozen_seat = nil
    semantic_events[#semantic_events + 1] = events.new(event_types.match_unfrozen, {
      reason = "auto_host",
      seat = seat,
    })
  end
end

local function _handle_use_item(state, command, semantic_events)
  local seat = _resolve_seat(state, command)
  if not seat then
    seat = state.turn.current_seat
  end
  local item_id = command.payload and command.payload.item_id
  if not item_id then
    return
  end
  local res = item_service.apply_manual_item(state, seat, item_id)
  if res and res.waiting and res.choice then
    _open_choice(state, res.choice, state.clock.now, semantic_events)
    return
  end
  if res and res.ok then
    _queue_action_anim(state, seat, res.effect or "use_item", res.tile_id, semantic_events)
  end
end

local function _handle_market_buy(state, command, semantic_events)
  if state.turn.pending_interaction and state.turn.pending_interaction.kind == "market_buy" then
    command.type = command_types.choice_select
    command.payload = command.payload or {}
    command.payload.option_id = command.payload.option_id or command.payload.product_id
    _handle_choice(state, command, semantic_events)
  end
end

local function _handle_restart_match(state, semantic_events)
  state.status = "running"
  state.match.finished = false
  state.match.winner_ids = {}
  state.match.winner_names = {}
  state.match.reason = nil
  state.turn.phase = "idle"
  state.turn.pending_interaction = nil
  state.turn.move_anim = nil
  state.turn.action_anim = nil
  state.turn.move_result = nil
  state.turn.choice_deadline = nil
  state.turn.choice_remaining = nil
  semantic_events[#semantic_events + 1] = events.new(event_types.phase_changed, { phase = "idle" })
end

local function _check_victory(state, semantic_events)
  local res = victory_service.check(state)
  if not res or not res.finished then
    return
  end
  state.match.finished = true
  state.match.winner_ids = res.winner_ids or {}
  state.match.winner_names = res.winner_names or {}
  state.match.reason = res.reason
  state.status = "finished"
  semantic_events[#semantic_events + 1] = events.new(event_types.match_finished, {
    winner_ids = state.match.winner_ids,
    winner_names = state.match.winner_names,
    reason = state.match.reason,
  })
end

local function _decide_events(state, command)
  local semantic_events = {}
  local actor_seat = _resolve_seat(state, command)

  if command.type == command_types.next_turn then
    _handle_next_turn(state, command, semantic_events)
  elseif command.type == command_types.move_anim_done then
    _handle_move_anim_done(state, command, semantic_events)
  elseif command.type == command_types.choice_select or command.type == command_types.choice_cancel then
    _handle_choice(state, command, semantic_events)
  elseif command.type == command_types.action_anim_done then
    _handle_action_anim_done(state, command, semantic_events)
  elseif command.type == command_types.role_offline then
    _handle_role_offline(state, actor_seat, command.issued_at, semantic_events)
  elseif command.type == command_types.role_online then
    _handle_role_online(state, actor_seat, command.issued_at, semantic_events)
  elseif command.type == command_types.tick then
    _handle_tick(state, command, semantic_events)
  elseif command.type == command_types.set_auto then
    _handle_set_auto(state, actor_seat, command, semantic_events)
  elseif command.type == command_types.use_item then
    _handle_use_item(state, command, semantic_events)
  elseif command.type == command_types.market_buy then
    _handle_market_buy(state, command, semantic_events)
  elseif command.type == command_types.restart_match then
    _handle_restart_match(state, semantic_events)
  end

  if command.type == command_types.tick and state.turn.phase == "wait_choice" and state.turn.pending_interaction then
    local now = state.clock.now
    local deadline = state.turn.choice_deadline
    if deadline and now >= deadline and not state.turn.frozen then
      local auto_action = auto_agent_service.auto_choice_action(state, state.turn.pending_interaction)
      local auto_command_type = command_types.choice_cancel
      local option_id = nil
      if auto_action and auto_action.type == "choice_select" then
        auto_command_type = command_types.choice_select
        option_id = auto_action.option_id
      end
      _handle_choice(state, {
        type = auto_command_type,
        payload = { option_id = option_id },
      }, semantic_events)
    end
  end

  _check_victory(state, semantic_events)

  return semantic_events
end

local function _normalize_command(state, command)
  local normalized = {
    id = command.id,
    type = command.type,
    role_id = command.role_id,
    seat_id = command.seat_id,
    client_seq = command.client_seq,
    issued_at = command.issued_at,
    payload = command.payload or {},
  }
  if normalized.id == nil then
    normalized.id = "cmd-" .. tostring(state.next_command_id)
    state.next_command_id = state.next_command_id + 1
  end
  if normalized.issued_at == nil then
    normalized.issued_at = state.clock.now or 0
  end
  return normalized
end

local function _is_duplicate(state, command, seat)
  if seat == nil or command.client_seq == nil then
    return false
  end
  local seat_map = state.command_dedup[seat]
  if seat_map == nil then
    seat_map = {}
    state.command_dedup[seat] = seat_map
  end
  return seat_map[command.client_seq] ~= nil
end

local function _mark_dedup(state, command, seat)
  if seat == nil or command.client_seq == nil then
    return
  end
  local seat_map = state.command_dedup[seat]
  if seat_map == nil then
    seat_map = {}
    state.command_dedup[seat] = seat_map
  end
  seat_map[command.client_seq] = state.event_index
end

local function _tag_event(state, event, command, actor_seat)
  state.event_index = state.event_index + 1
  state.version = state.version + 1
  event.index = state.event_index
  event.turn_no = state.turn.turn_no
  event.actor_seat = actor_seat
  event.created_at = command.issued_at or state.clock.now or 0
end

function kernel.new(opts)
  local instance = {
    state = state_mod.create(opts),
  }
  setmetatable(instance, kernel)
  return instance
end

function kernel:dispatch(raw_command)
  local normalized = _normalize_command(self.state, raw_command)
  local actor_seat = _resolve_seat(self.state, normalized)
  if _is_duplicate(self.state, normalized, actor_seat) then
    return {
      events = {},
      new_state = self.state,
      effects = {},
      duplicate = true,
    }
  end

  local before = _clone(self.state)
  local working = _clone(self.state)
  local semantic_events = _decide_events(working, normalized)
  local patch_events = {}
  _diff_state(before, working, {}, patch_events)

  local out = {}
  for _, event in ipairs(semantic_events) do
    out[#out + 1] = event
  end
  for _, event in ipairs(patch_events) do
    out[#out + 1] = event
  end

  for _, event in ipairs(out) do
    _tag_event(self.state, event, normalized, actor_seat)
    reducers.apply(self.state, event)
  end

  _mark_dedup(self.state, normalized, actor_seat)

  return {
    events = out,
    new_state = self.state,
    effects = {},
    duplicate = false,
  }
end

function kernel:replay(events_list, base_state)
  local state = state_mod.deep_copy(base_state)
  for _, event in ipairs(events_list or {}) do
    reducers.apply(state, event)
    state.event_index = event.index or state.event_index + 1
    state.version = state.version + 1
  end
  return state
end

return kernel
