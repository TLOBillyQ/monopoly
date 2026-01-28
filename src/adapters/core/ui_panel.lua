local roles_cfg = require("src.config.roles")
local Phase = require("src.adapters.core.ui_phase")
local Pricing = require("src.gameplay.land_pricing")

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

  return out
end

function Panel.build_player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  return player.name .. " $" .. player.cash
end

function Panel.build_player_statuses(view, game, max_players)
  local players = view and view.state and view.state.players or {}
  local count = max_players or #players
  local out = {}
  local board = game and game.board or nil
  local board_state = view and view.state and view.state.board and view.state.board.tiles or {}
  for i = 1, count do
    local player = players[i]
    if player then
      local cash = player.cash or 0
      local land_count = 0
      local total = cash
      for tile_id in pairs(player.properties or {}) do
        land_count = land_count + 1
        local tile = board and board.get_tile_by_id and board:get_tile_by_id(tile_id) or nil
        if tile and tile.type == "land" then
          local level = 0
          local st = board_state and board_state[tile_id]
          if st and type(st) == "table" then
            level = st.level or 0
          end
          total = total + Pricing.total_invested(tile, level)
        end
      end
      out[i] = {
        name = Panel.build_player_label(player),
        cash = "现金: " .. tostring(cash),
        land_count = "地块: " .. tostring(land_count),
        total_assets = "总资产: " .. tostring(total),
      }
    else
      out[i] = { name = "", cash = "", land_count = "", total_assets = "" }
    end
  end
  return out
end

function Panel.build_auto_label(auto_play)
  if auto_play then
    return "自动控制:开"
  end
  return "自动控制:关"
end

return Panel
