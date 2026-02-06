local commands = require("src.v2.domain.Commands")

local intent_mapper = {}
intent_mapper.__index = intent_mapper

local command_types = commands.types

function intent_mapper.new()
  local instance = {}
  setmetatable(instance, intent_mapper)
  return instance
end

local function _resolve_seat(state, role_id)
  if role_id ~= nil then
    local seat = state.seat_by_role_id[role_id]
    if seat ~= nil then
      return seat
    end
  end
  return state.turn.current_seat
end

function intent_mapper:to_command(intent, role_id, state)
  if not intent or not intent.type then
    return nil
  end

  local seat = _resolve_seat(state, role_id)

  if intent.type == "next" then
    return commands.new(command_types.next_turn, {
      role_id = role_id,
      seat_id = seat,
      client_seq = intent.client_seq,
    })
  end

  if intent.type == "choice_select" then
    return commands.new(command_types.choice_select, {
      role_id = role_id,
      seat_id = seat,
      client_seq = intent.client_seq,
      payload = {
        option_id = intent.option_id,
      },
    })
  end

  if intent.type == "choice_cancel" then
    return commands.new(command_types.choice_cancel, {
      role_id = role_id,
      seat_id = seat,
      client_seq = intent.client_seq,
      payload = {
        choice_id = intent.choice_id,
      },
    })
  end

  if intent.type == "auto_toggle" then
    return commands.new(command_types.set_auto, {
      role_id = role_id,
      seat_id = seat,
      client_seq = intent.client_seq,
      payload = {
        enabled = intent.enabled,
      },
    })
  end

  if intent.type == "market_confirm" then
    return commands.new(command_types.choice_select, {
      role_id = role_id,
      seat_id = seat,
      client_seq = intent.client_seq,
      payload = {
        option_id = intent.option_id,
      },
    })
  end

  if intent.type == "market_cancel" then
    return commands.new(command_types.choice_cancel, {
      role_id = role_id,
      seat_id = seat,
      client_seq = intent.client_seq,
    })
  end

  return nil
end

return intent_mapper
