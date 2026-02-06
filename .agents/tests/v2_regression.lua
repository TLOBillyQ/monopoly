local match_service = require("src.v2.application.MatchService")
local commands = require("src.v2.domain.Commands")
local state_mod = require("src.v2.domain.State")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")

Enums = Enums or { ArchiveType = { Str = "Str" } }

local function _assert(condition, message)
  if not condition then
    error(message or "assert failed")
  end
end

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_eq failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
  end
end

local function _role(role_id, name)
  local archive = {}
  return {
    get_roleid = function()
      return role_id
    end,
    get_name = function()
      return name
    end,
    set_archive_by_type = function(_, key, value)
      archive[key] = value
    end,
    get_archive_by_type = function(_, key)
      return archive[key]
    end,
  }
end

local function _runtime_stub()
  local roles = {
    _role(101, "玩家1"),
    _role(102, "玩家2"),
  }
  local rt = {
    _roles = roles,
    _online = { 101, 102 },
  }

  function rt:get_all_roles()
    return self._roles
  end

  function rt:get_online_role_ids()
    local out = {}
    for i, rid in ipairs(self._online) do
      out[i] = rid
    end
    return out
  end

  function rt:find_role_by_id(role_id)
    for _, role in ipairs(self._roles) do
      if role.get_roleid() == role_id then
        return role
      end
    end
    return nil
  end

  function rt:set_online(list)
    self._online = list
  end

  return rt
end

local function _build_service(runtime)
  return match_service.new({
    runtime = runtime,
    map = map_cfg,
    tiles = tiles_cfg,
    players = {
      { name = "玩家1", role_id = 101, is_ai = false, auto = false },
      { name = "玩家2", role_id = 102, is_ai = false, auto = false },
      { name = "AI3", role_id = nil, is_ai = true, auto = true },
      { name = "AI4", role_id = nil, is_ai = true, auto = true },
    },
    rules = {
      action_timeout_seconds = 3,
      reconnect = {
        freeze_on_disconnect = true,
        grace_seconds = 2,
        offline_auto_host_seconds = 1,
        snapshot_interval_events = 2,
        replay_max_events = 200,
      },
    },
    starting_cash = 20000,
    rng_seed = 42,
  })
end

local pass = 0

local function _test_command_dedup()
  local runtime = _runtime_stub()
  local service = _build_service(runtime)
  service:bootstrap_online(0)

  local command = commands.new(commands.types.next_turn, {
    seat_id = 1,
    client_seq = 7,
    issued_at = 0,
    payload = { dice = 3 },
  })
  local first = service:dispatch_command(command)
  _assert(first.duplicate == false, "first command should not be duplicate")
  _assert(#first.events > 0, "first command should emit events")

  local second = service:dispatch_command(command)
  _assert(second.duplicate == true, "second command should be duplicate")
  _assert_eq(#second.events, 0, "duplicate command should emit no events")

  pass = pass + 1
end

local function _test_snapshot_replay_consistency()
  local runtime = _runtime_stub()
  local service = _build_service(runtime)
  service:bootstrap_online(0)

  service:dispatch_command(commands.new(commands.types.next_turn, {
    seat_id = 1,
    issued_at = 0,
    payload = { dice = 2 },
  }))

  local move = service:state().turn.move_anim
  _assert(move ~= nil, "move anim should exist")
  service:dispatch_command(commands.new(commands.types.move_anim_done, {
    seat_id = 1,
    issued_at = 0.1,
    payload = { seq = move.seq },
  }))

  local state = service:state()
  if state.turn.phase == "wait_choice" then
    local choice = state.turn.pending_interaction
    _assert(choice ~= nil, "choice should exist")
    local first = choice.options[1]
    service:dispatch_command(commands.new(commands.types.choice_select, {
      seat_id = 1,
      issued_at = 0.2,
      payload = { option_id = first.id or first },
    }))
    state = service:state()
  end

  if state.turn.phase == "wait_action_anim" then
    local action = state.turn.action_anim
    service:dispatch_command(commands.new(commands.types.action_anim_done, {
      seat_id = 1,
      issued_at = 0.3,
      payload = { seq = action.seq },
    }))
  end

  _assert(#service.snapshots > 0, "should create snapshots")

  local before = state_mod.deep_copy(service:state())
  local rebuilt = service:recover_from_latest_snapshot()
  _assert(rebuilt ~= nil, "recover should rebuild state")
  local after = service:state()

  _assert_eq(after.turn.phase, before.turn.phase, "phase mismatch after replay")
  _assert_eq(after.turn.current_seat, before.turn.current_seat, "seat mismatch after replay")
  _assert_eq(after.players[1].position, before.players[1].position, "position mismatch after replay")
  _assert_eq(after.players[1].cash, before.players[1].cash, "cash mismatch after replay")

  pass = pass + 1
end

local function _test_reconnect_freeze_resume()
  local runtime = _runtime_stub()
  local service = _build_service(runtime)
  service:bootstrap_online(0)

  service:dispatch_command(commands.new(commands.types.next_turn, {
    seat_id = 1,
    issued_at = 0,
    payload = { dice = 1 },
  }))

  _assert_eq(service:state().turn.phase, "wait_move_anim", "phase should wait_move_anim")

  runtime:set_online({ 102 })
  service:tick(0.2)
  _assert(service:state().turn.frozen == true, "should freeze when current role offline")

  runtime:set_online({ 101, 102 })
  service:tick(0.2)
  _assert(service:state().turn.frozen == false, "should unfreeze after reconnect")

  pass = pass + 1
end

local function _test_offline_auto_host_unfreeze()
  local runtime = _runtime_stub()
  local service = _build_service(runtime)
  service:bootstrap_online(0)

  service:dispatch_command(commands.new(commands.types.next_turn, {
    seat_id = 1,
    issued_at = 0,
    payload = { dice = 1 },
  }))

  runtime:set_online({ 102 })
  service:tick(0.1)
  _assert(service:state().turn.frozen == true, "should freeze after offline")

  service:tick(1.2)
  local player = service:state().players[1]
  _assert(player.auto == true, "offline timeout should enable auto")
  _assert(service:state().turn.frozen == false, "auto host should unfreeze turn")

  pass = pass + 1
end

_test_command_dedup()
_test_snapshot_replay_consistency()
_test_reconnect_freeze_resume()
_test_offline_auto_host_unfreeze()

print("V2 regression passed (" .. tostring(pass) .. ")")
