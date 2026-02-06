require "vendor.third_party.Utils"

local kernel_mod = require("src.v2.domain.Kernel")
local commands = require("src.v2.domain.Commands")
local state_mod = require("src.v2.domain.State")
local reconnect_service_mod = require("src.v2.application.ReconnectService")
local projection_service_mod = require("src.v2.application.ProjectionService")
local archive_repository_mod = require("src.v2.infrastructure.ArchiveRepository")
local session_clock_mod = require("src.v2.infrastructure.SessionClock")
local auto_agent_service = require("src.v2.domain.services.AutoAgentService")

local deep_copy = Utils.deep_copy

local match_service = {}
match_service.__index = match_service

local command_types = commands.types

local function _default_snapshot_interval(rules)
  local reconnect = rules and rules.reconnect or {}
  return reconnect.snapshot_interval_events or 20
end

local function _default_replay_max(rules)
  local reconnect = rules and rules.reconnect or {}
  return reconnect.replay_max_events or 400
end

function match_service.new(opts)
  opts = opts or {}
  local kernel = kernel_mod.new({
    map = assert(opts.map, "missing map"),
    tiles = assert(opts.tiles, "missing tiles"),
    players = assert(opts.players, "missing players"),
    rules = opts.rules,
    reconnect = opts.rules and opts.rules.reconnect,
    starting_cash = opts.starting_cash,
    rng_seed = opts.rng_seed,
    now = 0,
  })

  local instance = {
    kernel = kernel,
    runtime = assert(opts.runtime, "missing runtime"),
    clock = session_clock_mod.new({ start_seconds = 0 }),
    archive_repo = archive_repository_mod.new({ runtime = opts.runtime }),
    projection_service = projection_service_mod.new({
      map = opts.map,
      tiles = opts.tiles,
    }),
    intent_mapper = opts.intent_mapper,
    event_log = {},
    snapshots = {},
    snapshot_interval = _default_snapshot_interval(opts.rules),
    replay_max_events = _default_replay_max(opts.rules),
    auto_interval = 0.8,
    auto_elapsed = 0,
    move_anim_due = nil,
    move_anim_seq = nil,
    action_anim_due = nil,
    action_anim_seq = nil,
  }
  setmetatable(instance, match_service)

  instance.reconnect_service = reconnect_service_mod.new({
    runtime = opts.runtime,
    dispatch = function(command)
      instance:dispatch_command(command)
    end,
  })

  return instance
end

function match_service:state()
  return self.kernel.state
end

function match_service:_append_events(events_list)
  for _, event in ipairs(events_list or {}) do
    self.event_log[#self.event_log + 1] = event
  end
  if #self.event_log > self.replay_max_events then
    local remove_count = #self.event_log - self.replay_max_events
    for _ = 1, remove_count do
      table.remove(self.event_log, 1)
    end
  end
end

function match_service:_events_after(index)
  local out = {}
  for _, event in ipairs(self.event_log) do
    if (event.index or 0) > index then
      out[#out + 1] = event
    end
  end
  return out
end

function match_service:_persist_checkpoint(snapshot)
  local state = self:state()
  for _, player in ipairs(state.players) do
    if player.role_id ~= nil then
      self.archive_repo:save_role_checkpoint(player.role_id, {
        match_id = state.match_id,
        snapshot_id = snapshot.id,
        event_index = snapshot.event_index,
        updated_at = snapshot.created_at,
      })
    end
  end
end

function match_service:_try_snapshot()
  local state = self:state()
  if state.event_index <= 0 then
    return
  end
  if self.snapshot_interval <= 0 then
    return
  end
  if state.event_index % self.snapshot_interval ~= 0 then
    return
  end

  local snapshot = {
    id = "snap-" .. tostring(state.event_index),
    event_index = state.event_index,
    created_at = state.clock.now,
    state_blob = deep_copy(state),
  }
  self.snapshots[#self.snapshots + 1] = snapshot
  while #self.snapshots > 20 do
    table.remove(self.snapshots, 1)
  end
  self:_persist_checkpoint(snapshot)
end

function match_service:recover_from_latest_snapshot()
  local snapshot = self.snapshots[#self.snapshots]
  if not snapshot then
    return nil
  end
  local events_after = self:_events_after(snapshot.event_index)
  local rebuilt = self.kernel:replay(events_after, snapshot.state_blob)
  self.kernel.state = rebuilt
  return rebuilt
end

function match_service:dispatch_command(command)
  local result = self.kernel:dispatch(command)
  if result and result.events and #result.events > 0 then
    self:_append_events(result.events)
    self:_try_snapshot()
    if command.type == command_types.role_online then
      self:recover_from_latest_snapshot()
    end
  end
  return result
end

function match_service:bootstrap_online(now)
  self.reconnect_service:bootstrap_online(now)
end

function match_service:_step_auto_turn(dt, now)
  local state = self:state()
  if state.turn.phase ~= "idle" or state.turn.frozen then
    self.auto_elapsed = 0
    return
  end

  local current = state.players[state.turn.current_seat]
  if not current or not current.auto then
    self.auto_elapsed = 0
    return
  end

  self.auto_elapsed = self.auto_elapsed + (dt or 0)
  if self.auto_elapsed < self.auto_interval then
    return
  end
  self.auto_elapsed = 0

  self:dispatch_command(commands.new(command_types.next_turn, {
    seat_id = current.seat_id,
    issued_at = now,
  }))
end

function match_service:_step_choice_timeout(now)
  local state = self:state()
  if state.turn.phase ~= "wait_choice" then
    return
  end
  if state.turn.frozen then
    return
  end
  local choice = state.turn.pending_interaction
  if not choice then
    return
  end
  local deadline = state.turn.choice_deadline
  if not deadline or now < deadline then
    return
  end

  local owner_seat = choice.meta and choice.meta.owner_seat or state.turn.current_seat
  local owner = state.players[owner_seat]
  local command_type = command_types.choice_cancel
  local payload = {}
  if owner and owner.auto then
    local auto_action = auto_agent_service.auto_choice_action(state, choice)
    if auto_action and auto_action.type == "choice_select" then
      command_type = command_types.choice_select
      payload.option_id = auto_action.option_id
    end
  end

  self:dispatch_command(commands.new(command_type, {
    seat_id = owner_seat,
    issued_at = now,
    payload = payload,
  }))
end

function match_service:_step_animations(now)
  local state = self:state()
  if state.turn.frozen then
    return
  end

  if state.turn.phase == "wait_move_anim" and state.turn.move_anim then
    local seq = state.turn.move_anim.seq
    if self.move_anim_seq ~= seq then
      self.move_anim_seq = seq
      self.move_anim_due = now + 0.6
    end
    if self.move_anim_due and now >= self.move_anim_due then
      self.move_anim_due = nil
      self:dispatch_command(commands.new(command_types.move_anim_done, {
        seat_id = state.turn.current_seat,
        issued_at = now,
        payload = { seq = seq },
      }))
    end
  else
    self.move_anim_due = nil
    self.move_anim_seq = nil
  end

  if state.turn.phase == "wait_action_anim" and state.turn.action_anim then
    local seq = state.turn.action_anim.seq
    if self.action_anim_seq ~= seq then
      self.action_anim_seq = seq
      self.action_anim_due = now + 0.4
    end
    if self.action_anim_due and now >= self.action_anim_due then
      self.action_anim_due = nil
      self:dispatch_command(commands.new(command_types.action_anim_done, {
        seat_id = state.turn.current_seat,
        issued_at = now,
        payload = { seq = seq },
      }))
    end
  else
    self.action_anim_due = nil
    self.action_anim_seq = nil
  end
end

function match_service:tick(dt)
  local now = self.clock:step(dt)

  self:dispatch_command(commands.new(command_types.tick, {
    issued_at = now,
  }))

  self.reconnect_service:refresh(now)
  self:_step_choice_timeout(now)
  self:_step_animations(now)
  self:_step_auto_turn(dt, now)

  return now
end

function match_service:projection()
  return self.projection_service:build(self:state())
end

function match_service:handle_intent(intent, role_id)
  if not self.intent_mapper then
    return nil
  end
  local command = self.intent_mapper:to_command(intent, role_id, self:state())
  if not command then
    return nil
  end
  return self:dispatch_command(command)
end

function match_service:resolve_seat_by_role_id(role_id)
  return state_mod.resolve_seat_by_role_id(self:state(), role_id)
end

return match_service
