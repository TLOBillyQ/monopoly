local match_service = require("src.v2.application.MatchService")
local commands = require("src.v2.domain.Commands")
local movement_service = require("src.v2.domain.services.MovementService")
local land_service = require("src.v2.domain.services.LandService")
local landing_service = require("src.v2.domain.services.LandingService")
local item_service = require("src.v2.domain.services.ItemService")
local chance_service = require("src.v2.domain.services.ChanceService")
local market_service = require("src.v2.domain.services.MarketService")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")

Enums = Enums or { ArchiveType = { Str = "Str" } }

local testkit = {}

local function _role(role_id, name)
  local archive = {}
  return {
    get_roleid = function()
      return role_id
    end,
    get_name = function()
      return name
    end,
    set_archive_by_type = function(_, _, key, value)
      archive[key] = value
    end,
    get_archive_by_type = function(_, _, key)
      return archive[key]
    end,
    _archive = archive,
  }
end

function testkit.assert_true(condition, message)
  if not condition then
    error(message or "assert_true failed")
  end
end

function testkit.assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_eq failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
  end
end

function testkit.build_runtime(role_count)
  local count = role_count or 2
  local roles = {}
  for idx = 1, count do
    roles[idx] = _role(100 + idx, "玩家" .. tostring(idx))
  end
  local runtime = {
    _roles = roles,
    _online = {},
  }

  for _, role in ipairs(roles) do
    runtime._online[#runtime._online + 1] = role.get_roleid()
  end

  function runtime:get_all_roles()
    return self._roles
  end

  function runtime:get_online_role_ids()
    local list = {}
    for i, role_id in ipairs(self._online) do
      list[i] = role_id
    end
    return list
  end

  function runtime:find_role_by_id(role_id)
    for _, role in ipairs(self._roles) do
      if role.get_roleid() == role_id then
        return role
      end
    end
    return nil
  end

  function runtime:set_online(role_ids)
    self._online = role_ids
  end

  return runtime
end

local function _build_players(runtime)
  local players = {}
  local roles = runtime:get_all_roles()
  for seat = 1, 4 do
    local role = roles[seat]
    if role then
      players[seat] = {
        name = role.get_name(),
        role_id = role.get_roleid(),
        is_ai = false,
        auto = false,
      }
    else
      players[seat] = {
        name = "AI" .. tostring(seat),
        role_id = nil,
        is_ai = true,
        auto = true,
      }
    end
  end
  return players
end

function testkit.new_service(opts)
  opts = opts or {}
  local runtime = opts.runtime or testkit.build_runtime(opts.role_count or 2)
  local service = match_service.new({
    runtime = runtime,
    map = map_cfg,
    tiles = tiles_cfg,
    players = _build_players(runtime),
    rules = opts.rules or {
      action_timeout_seconds = 1,
      turn_limit = opts.turn_limit or 0,
      reconnect = {
        freeze_on_disconnect = true,
        grace_seconds = 2,
        offline_auto_host_seconds = 1,
        snapshot_interval_events = 2,
        replay_max_events = 200,
      },
    },
    starting_cash = opts.starting_cash or 20000,
    rng_seed = opts.rng_seed or 42,
  })
  service:bootstrap_online(0)
  return service, runtime
end

function testkit.dispatch(service, command_type, fields)
  return service:dispatch_command(commands.new(command_type, fields))
end

function testkit.first_option_id(choice)
  if not choice or not choice.options or #choice.options == 0 then
    return nil
  end
  local first = choice.options[1]
  return first.id or first
end

function testkit.resolve_choice(service, action)
  local state = service:state()
  local choice = state.turn.pending_interaction
  if not choice then
    return nil
  end
  local owner_seat = choice.meta and choice.meta.owner_seat or state.turn.current_seat
  local final_action = action or {}
  local command_type = final_action.type or "choice_select"
  if command_type == "choice_select" then
    local option_id = final_action.option_id
    if option_id == nil then
      option_id = testkit.first_option_id(choice)
    end
    if option_id == nil then
      command_type = "choice_cancel"
    else
      return testkit.dispatch(service, command_type, {
        seat_id = owner_seat,
        issued_at = state.clock.now,
        payload = {
          choice_id = choice.id,
          option_id = option_id,
        },
      })
    end
  end
  return testkit.dispatch(service, command_type, {
    seat_id = owner_seat,
    issued_at = state.clock.now,
    payload = {
      choice_id = choice.id,
    },
  })
end

function testkit.progress_until_idle(service, opts)
  opts = opts or {}
  local max_steps = opts.max_steps or 80
  local chooser = opts.choose
  for step = 1, max_steps do
    local state = service:state()
    if state.turn.phase == "idle" then
      return
    end

    if state.turn.phase == "wait_move_anim" and state.turn.move_anim then
      testkit.dispatch(service, commands.types.move_anim_done, {
        seat_id = state.turn.current_seat,
        issued_at = state.clock.now + 0.01,
        payload = { seq = state.turn.move_anim.seq },
      })
    elseif state.turn.phase == "wait_action_anim" and state.turn.action_anim then
      testkit.dispatch(service, commands.types.action_anim_done, {
        seat_id = state.turn.current_seat,
        issued_at = state.clock.now + 0.01,
        payload = { seq = state.turn.action_anim.seq },
      })
    elseif state.turn.phase == "wait_choice" and state.turn.pending_interaction then
      local action = chooser and chooser(state.turn.pending_interaction, state, step) or nil
      testkit.resolve_choice(service, action)
    else
      service:tick(0.2)
    end
  end
  error("progress_until_idle exceeded max_steps")
end

function testkit.force_idle(state)
  state.turn.phase = "idle"
  state.turn.pending_interaction = nil
  state.turn.move_anim = nil
  state.turn.action_anim = nil
  state.turn.move_result = nil
  state.turn.choice_deadline = nil
  state.turn.choice_remaining = nil
end

function testkit.find_tile_index_by_type(state, tile_type)
  for index, tile_id in ipairs(state.board.path or {}) do
    local tile = state.board.tile_defs[tile_id]
    if tile and tile.type == tile_type then
      return index, tile_id
    end
  end
  return nil, nil
end

function testkit.find_first_land(state)
  return testkit.find_tile_index_by_type(state, "land")
end

function testkit.give_item(state, seat, item_id)
  local player = state.players[seat]
  player.inventory.items[#player.inventory.items + 1] = { id = item_id }
end

function testkit.set_land_owner(state, tile_id, owner_seat, level)
  local tile_state = state.board.tile_states[tile_id]
  if not tile_state then
    tile_state = { owner_id = nil, level = 0 }
    state.board.tile_states[tile_id] = tile_state
  end
  local old_owner = tile_state.owner_id
  if old_owner and state.players[old_owner] then
    state.players[old_owner].properties[tile_id] = nil
  end
  tile_state.owner_id = owner_seat
  tile_state.level = level or 1
  if owner_seat and state.players[owner_seat] then
    state.players[owner_seat].properties[tile_id] = true
  end
end

function testkit.begin_turn(service, seat, dice_value)
  local state = service:state()
  local target_seat = seat or state.turn.current_seat
  local player = state.players[target_seat]
  player.status.pending_remote_dice = { values = { dice_value or 1 } }
  return testkit.dispatch(service, commands.types.next_turn, {
    seat_id = target_seat,
    issued_at = state.clock.now,
  })
end

testkit.commands = commands
testkit.services = {
  movement = movement_service,
  land = land_service,
  landing = landing_service,
  item = item_service,
  chance = chance_service,
  market = market_service,
}

return testkit
