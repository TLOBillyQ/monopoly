local commands = {}

commands.types = {
  next_turn = "next_turn",
  use_item = "use_item",
  market_buy = "market_buy",
  choice_select = "choice_select",
  choice_cancel = "choice_cancel",
  move_anim_done = "move_anim_done",
  action_anim_done = "action_anim_done",
  role_offline = "role_offline",
  role_online = "role_online",
  tick = "tick",
  set_auto = "set_auto",
  restart_match = "restart_match",
}

local function _normalize_payload(payload)
  if type(payload) == "table" then
    return payload
  end
  return {}
end

function commands.new(command_type, fields)
  fields = fields or {}
  return {
    id = fields.id,
    type = command_type,
    role_id = fields.role_id,
    seat_id = fields.seat_id,
    client_seq = fields.client_seq,
    issued_at = fields.issued_at,
    payload = _normalize_payload(fields.payload),
  }
end

return commands
