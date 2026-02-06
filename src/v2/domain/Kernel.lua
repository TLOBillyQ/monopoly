local commands = require("src.v2.domain.Commands")
local events = require("src.v2.domain.Events")
local state_mod = require("src.v2.domain.State")
local reducers = require("src.v2.domain.Reducers.Index")

local kernel = {}
kernel.__index = kernel

local command_types = commands.types
local event_types = events.types

local function _contains_option(options, option_id)
  if type(options) ~= "table" then
    return false
  end
  for _, option in ipairs(options) do
    local id = option.id or option
    if tostring(id) == tostring(option_id) then
      return true
    end
  end
  return false
end

local function _lcg_next(seed)
  local value = (1103515245 * seed + 12345) % 2147483647
  if value <= 0 then
    value = 1
  end
  return value
end

local function _next_dice(state, payload)
  if payload and type(payload.dice) == "number" then
    local dice = math.floor(payload.dice)
    if dice < 1 then
      dice = 1
    end
    if dice > 12 then
      dice = 12
    end
    return dice, state.rng_seed
  end
  local next_seed = _lcg_next(state.rng_seed)
  local dice = (next_seed % 6) + 1
  return dice, next_seed
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

local function _current_tile_id(state, player)
  local index = player.position
  local path = state.board.path
  return path[index]
end

local function _queue_action_anim(state, out, seat, kind, tile_id)
  out[#out + 1] = events.new(event_types.action_anim_queued, {
    seq = state.turn.seq.action + 1,
    kind = kind,
    tile_id = tile_id,
    player_seat = seat,
  })
end

local function _emit_turn_finish(state, out)
  local current = state.turn.current_seat
  local next_seat = state_mod.next_alive_seat(state, current)
  out[#out + 1] = events.new(event_types.turn_finished, {
    prev_seat = current,
    next_seat = next_seat,
  })
end

local function _build_land_choice(state, seat, tile_id, kind)
  local choice_id = state.turn.seq.choice + 1
  local title = "请选择"
  local body = {}
  local options
  if kind == "land_buy" then
    title = "是否购买地块"
    body = { "你可以购买当前地块，或选择跳过" }
    options = {
      { id = "buy", label = "购买" },
      { id = "skip", label = "跳过" },
    }
  else
    title = "是否升级地块"
    body = { "你可以升级当前地块，或选择跳过" }
    options = {
      { id = "upgrade", label = "升级" },
      { id = "skip", label = "跳过" },
    }
  end
  local timeout = state.rules.action_timeout_seconds or 15
  local now = state.clock.now or 0
  return events.new(event_types.choice_opened, {
    choice = {
      id = choice_id,
      kind = kind,
      title = title,
      body_lines = body,
      options = options,
      allow_cancel = true,
      cancel_label = "取消",
      meta = {
        tile_id = tile_id,
        owner_seat = seat,
      },
    },
    deadline = now + timeout,
  })
end

local function _decide_after_move(state, out)
  local seat = state.turn.current_seat
  local player = state.players[seat]
  if not player then
    _queue_action_anim(state, out, seat, "noop", nil)
    return
  end

  local tile_id = _current_tile_id(state, player)
  local tile_def = state.board.tile_defs[tile_id] or {}
  local tile_state = state.board.tile_states[tile_id]
  if tile_def.type ~= "land" then
    _queue_action_anim(state, out, seat, "land_none", tile_id)
    return
  end

  local owner_seat = tile_state and tile_state.owner_id or nil
  local level = tile_state and tile_state.level or 0
  local price = tile_def.price or 0
  local upgrade_price = tile_def.upgrade_price or 1000

  if owner_seat == nil then
    if price > 0 and player.cash >= price then
      out[#out + 1] = _build_land_choice(state, seat, tile_id, "land_buy")
      return
    end
    _queue_action_anim(state, out, seat, "land_skip", tile_id)
    return
  end

  if owner_seat == seat then
    if level < 3 and player.cash >= upgrade_price then
      out[#out + 1] = _build_land_choice(state, seat, tile_id, "land_upgrade")
      return
    end
    _queue_action_anim(state, out, seat, "land_self", tile_id)
    return
  end

  local rent_base = tile_def.rent_base or 200
  local multiplier = level > 0 and level or 1
  local rent = rent_base * multiplier
  out[#out + 1] = events.new(event_types.rent_paid, {
    from_seat = seat,
    to_seat = owner_seat,
    tile_id = tile_id,
    amount = rent,
  })
  _queue_action_anim(state, out, seat, "rent", tile_id)
end

local function _decide_next_turn(state, command)
  local out = {}
  local seat = state.turn.current_seat
  local actor = state.players[seat]
  if not actor then
    return out
  end
  if actor.eliminated then
    _emit_turn_finish(state, out)
    return out
  end
  if state.turn.phase ~= "idle" then
    return out
  end
  if state.turn.frozen then
    return out
  end

  local dice, next_seed = _next_dice(state, command.payload)
  local from_index = actor.position
  local path_len = #state.board.path
  local to_index = ((from_index - 1 + dice) % path_len) + 1

  out[#out + 1] = events.new(event_types.turn_began, {
    turn_no = state.turn.turn_no + 1,
    seat = seat,
    dice = dice,
    next_seed = next_seed,
  })
  out[#out + 1] = events.new(event_types.player_moved, {
    seat = seat,
    from_index = from_index,
    to_index = to_index,
    steps = dice,
  })
  out[#out + 1] = events.new(event_types.move_anim_queued, {
    seq = state.turn.seq.move + 1,
    player_seat = seat,
    from_index = from_index,
    to_index = to_index,
    steps = dice,
  })

  return out
end

local function _decide_move_anim_done(state, command)
  local out = {}
  if state.turn.phase ~= "wait_move_anim" then
    return out
  end
  local anim = state.turn.move_anim
  if anim == nil then
    return out
  end
  local seq = command.payload and command.payload.seq
  if seq ~= nil and anim.seq ~= nil and seq ~= anim.seq then
    return out
  end

  out[#out + 1] = events.new(event_types.move_anim_confirmed, {
    seq = anim.seq,
  })
  _decide_after_move(state, out)
  return out
end

local function _resolve_choice_option(choice, command)
  if command.type == command_types.choice_cancel then
    return "cancel"
  end
  local option_id = command.payload and command.payload.option_id
  if option_id ~= nil and _contains_option(choice.options, option_id) then
    return tostring(option_id)
  end
  local first = choice.options and choice.options[1]
  if first then
    return tostring(first.id or first)
  end
  return "cancel"
end

local function _decide_choice(state, command)
  local out = {}
  if state.turn.phase ~= "wait_choice" then
    return out
  end
  local choice = state.turn.pending_interaction
  if not choice then
    return out
  end

  local resolved = _resolve_choice_option(choice, command)
  out[#out + 1] = events.new(event_types.choice_resolved, {
    choice_id = choice.id,
    action = command.type == command_types.choice_cancel and "cancel" or "select",
    option_id = resolved,
  })

  local meta = choice.meta or {}
  local tile_id = meta.tile_id
  local seat = state.turn.current_seat
  local tile_def = tile_id and state.board.tile_defs[tile_id] or nil
  local tile_state = tile_id and state.board.tile_states[tile_id] or nil

  if choice.kind == "land_buy" and resolved == "buy" and tile_id ~= nil then
    out[#out + 1] = events.new(event_types.tile_bought, {
      tile_id = tile_id,
      owner_seat = seat,
      cost = tile_def and tile_def.price or 0,
      level = 1,
    })
    _queue_action_anim(state, out, seat, "buy_land", tile_id)
    return out
  end

  if choice.kind == "land_upgrade" and resolved == "upgrade" and tile_id ~= nil and tile_state ~= nil then
    out[#out + 1] = events.new(event_types.tile_upgraded, {
      tile_id = tile_id,
      owner_seat = seat,
      cost = tile_def and tile_def.upgrade_price or 0,
      level = (tile_state.level or 0) + 1,
    })
    _queue_action_anim(state, out, seat, "upgrade_land", tile_id)
    return out
  end

  _queue_action_anim(state, out, seat, "choice_skip", tile_id)
  return out
end

local function _decide_action_anim_done(state, command)
  local out = {}
  if state.turn.phase ~= "wait_action_anim" then
    return out
  end
  local anim = state.turn.action_anim
  if anim == nil then
    return out
  end
  local seq = command.payload and command.payload.seq
  if seq ~= nil and anim.seq ~= nil and seq ~= anim.seq then
    return out
  end

  out[#out + 1] = events.new(event_types.action_anim_confirmed, {
    seq = anim.seq,
  })
  _emit_turn_finish(state, out)
  return out
end

local function _decide_role_offline(state, command)
  local out = {}
  local seat = _resolve_seat(state, command)
  if seat == nil then
    return out
  end
  local player = state.players[seat]
  if not player or player.online == false then
    return out
  end
  local now = command.issued_at or state.clock.now or 0
  out[#out + 1] = events.new(event_types.player_offline, {
    seat = seat,
    at = now,
  })

  local freeze_on_disconnect = state.rules.reconnect.freeze_on_disconnect == true
  if freeze_on_disconnect and state.turn.current_seat == seat and not state.turn.frozen then
    out[#out + 1] = events.new(event_types.match_frozen, {
      reason = "offline",
      seat = seat,
    })
  end
  return out
end

local function _decide_role_online(state, command)
  local out = {}
  local seat = _resolve_seat(state, command)
  if seat == nil then
    return out
  end
  local player = state.players[seat]
  if not player then
    return out
  end
  local now = command.issued_at or state.clock.now or 0
  out[#out + 1] = events.new(event_types.player_online, {
    seat = seat,
    at = now,
  })

  local grace = state.rules.reconnect.grace_seconds or 20
  out[#out + 1] = events.new(event_types.reconnect_grace_set, {
    seat = seat,
    expires_at = now + grace,
  })

  if state.turn.frozen and state.turn.current_seat == seat then
    out[#out + 1] = events.new(event_types.match_unfrozen, {
      reason = "reconnect",
      seat = seat,
    })
  end
  return out
end

local function _decide_set_auto(state, command)
  local out = {}
  local seat = _resolve_seat(state, command)
  if seat == nil then
    seat = state.turn.current_seat
  end
  local player = state.players[seat]
  if not player then
    return out
  end
  local enabled = command.payload and command.payload.enabled
  if enabled == nil then
    enabled = not player.auto
  end
  out[#out + 1] = events.new(event_types.player_auto_set, {
    seat = seat,
    enabled = enabled == true,
  })
  if state.turn.frozen and state.turn.current_seat == seat and enabled == true then
    out[#out + 1] = events.new(event_types.match_unfrozen, {
      reason = "auto_host",
      seat = seat,
    })
  end
  return out
end

local function _decide_tick(state, command)
  local out = {}
  local now = command.issued_at or state.clock.now or 0
  out[#out + 1] = events.new(event_types.clock_tick, { now = now })

  local offline_limit = state.rules.reconnect.offline_auto_host_seconds or 90
  for seat, player in ipairs(state.players) do
    if player.online == false and player.offline_since ~= nil then
      local offline_seconds = now - player.offline_since
      if offline_seconds >= offline_limit and not player.auto then
        out[#out + 1] = events.new(event_types.player_auto_set, {
          seat = seat,
          enabled = true,
        })
        if state.turn.frozen and state.turn.current_seat == seat then
          out[#out + 1] = events.new(event_types.match_unfrozen, {
            reason = "auto_host",
            seat = seat,
          })
        end
      end
    end
  end

  if state.turn.frozen then
    local current = state.players[state.turn.current_seat]
    if current and (current.online or current.auto) then
      out[#out + 1] = events.new(event_types.match_unfrozen, {
        reason = "tick_recover",
        seat = state.turn.current_seat,
      })
    end
  end
  return out
end

local function _tag_event(state, event, command, actor_seat)
  state.event_index = state.event_index + 1
  state.version = state.version + 1
  event.index = state.event_index
  event.turn_no = state.turn.turn_no
  event.actor_seat = actor_seat
  event.created_at = command.issued_at or state.clock.now or 0
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

local function _decide_events(state, command)
  if command.type == command_types.next_turn then
    return _decide_next_turn(state, command)
  end
  if command.type == command_types.move_anim_done then
    return _decide_move_anim_done(state, command)
  end
  if command.type == command_types.choice_select or command.type == command_types.choice_cancel then
    return _decide_choice(state, command)
  end
  if command.type == command_types.action_anim_done then
    return _decide_action_anim_done(state, command)
  end
  if command.type == command_types.role_offline then
    return _decide_role_offline(state, command)
  end
  if command.type == command_types.role_online then
    return _decide_role_online(state, command)
  end
  if command.type == command_types.tick then
    return _decide_tick(state, command)
  end
  if command.type == command_types.set_auto then
    return _decide_set_auto(state, command)
  end
  return {}
end

function kernel.new(opts)
  local instance = {
    state = state_mod.create(opts),
  }
  setmetatable(instance, kernel)
  return instance
end

function kernel:dispatch(raw_command)
  local command = _normalize_command(self.state, raw_command)
  local actor_seat = _resolve_seat(self.state, command)
  if _is_duplicate(self.state, command, actor_seat) then
    return {
      events = {},
      new_state = self.state,
      effects = {},
      duplicate = true,
    }
  end

  local out = _decide_events(self.state, command)
  for _, event in ipairs(out) do
    _tag_event(self.state, event, command, actor_seat)
    reducers.apply(self.state, event)
  end

  _mark_dedup(self.state, command, actor_seat)

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
