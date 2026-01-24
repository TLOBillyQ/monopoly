local roles_cfg = require("src.config.roles")
local Phase = require("src.adapters.core.ui_phase")

local Panel = {}

function Panel.build_turn_label(turn_count)
  return "回合: " .. tostring(turn_count)
end

function Panel.build_current_player_view(view)
  if not view then
    return nil
  end
  local state = view.state
  local turn = state.turn
  local players = state.players
  local idx = turn.current_player_index
  local current = players[idx]
  if not current then
    return nil
  end

  local role_id = current.role_id or current.id
  local role = roles_cfg[((role_id - 1) % #roles_cfg) + 1]
  local out = {
    name_text = current.name .. " 现金 " .. current.cash,
    role_text = "角色: " .. role.name,
  }

  local status = current.status or {}
  if status.deity then
    out.deity_text = "附身: " .. status.deity.type .. " (" .. status.deity.remaining .. ")"
  end

  local phase = turn.item_phase_active
  if phase then
    out.phase_text = "阶段: " .. Phase.build_phase_label(phase)
  end

  if view.last_turn and view.last_turn.player_id == current.id then
    if view.last_turn.rolls then
      out.dice_text = "骰子: " .. table.concat(view.last_turn.rolls, ",") .. " => " .. view.last_turn.total
    elseif view.last_turn.note then
      out.dice_text = view.last_turn.note
      out.dice_is_note = true
    end
  end

  return out
end

function Panel.build_player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  return player.name .. " $" .. player.cash
end

function Panel.build_player_details_text(player, view, item_name_by_id, vehicle_name_by_id)
  if player.eliminated then
    return nil
  end
  local parts = {}

  local status = player.status or {}
  if status.stay_turns and status.stay_turns > 0 then
    local pos = player.position
    local tile = view and view.board and view.board.tiles and view.board.tiles[pos]
    local t_type = tile and tile.type
    local days = status.stay_turns
    if t_type == "hospital" then
      table.insert(parts, "医院(" .. days .. ")")
    elseif t_type == "mountain" then
      table.insert(parts, "深山(" .. days .. ")")
    else
      table.insert(parts, "停留(" .. days .. ")")
    end
  end

  if status.deity then
    table.insert(parts, status.deity.type .. "(" .. status.deity.remaining .. ")")
  end

  if player.seat_id then
    local vname = (vehicle_name_by_id and vehicle_name_by_id[player.seat_id]) or ("车" .. player.seat_id)
    table.insert(parts, vname)
  end

  local inv = player.inventory or {}
  if inv.items and #inv.items > 0 then
    local names = {}
    for _, item in ipairs(inv.items) do
      table.insert(names, (item_name_by_id and item_name_by_id[item.id]) or tostring(item.id))
    end
    table.insert(parts, "{" .. table.concat(names, ",") .. "}")
  end

  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

function Panel.build_player_statuses(view, item_name_by_id, vehicle_name_by_id, max_players)
  local players = view and view.state and view.state.players or {}
  local count = max_players or #players
  local out = {}
  for i = 1, count do
    local player = players[i]
    if player then
      out[i] = {
        label = Panel.build_player_label(player),
        detail = Panel.build_player_details_text(player, view, item_name_by_id, vehicle_name_by_id),
      }
    else
      out[i] = { label = "", detail = nil }
    end
  end
  return out
end

function Panel.build_auto_label(auto_play)
  if auto_play then
    return "自动运行:开"
  end
  return "自动运行:关"
end

return Panel
