local logger = require("src.util.logger")
local roles_cfg = require("src.config.roles")
local vehicles_cfg = require("src.config.vehicles")

local vehicle_name_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_name_by_id[cfg.id] = cfg.name
end

local PanelRenderer = {}

local function draw_panel_background(ui, panel)
  love.graphics.setColor(ui.palette.panel)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 10, 10)
  love.graphics.setColor(ui.palette.panel_border)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 10, 10)
end

local function draw_button(ui, btn, active)
  local bg = active and { 0.3, 0.5, 0.35 } or { 0.2, 0.22, 0.24 }
  love.graphics.setColor(bg)
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
  love.graphics.setColor(ui.palette.panel_border)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf(btn.label, btn.x, btn.y + 8, btn.w, "center")
end

local function draw_wrapped(text, x, y, width, font)
  love.graphics.setFont(font)
  local _, lines = font:getWrap(text, width)
  love.graphics.printf(text, x, y, width, "left")
  return #lines
end

local function player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  return player.name .. " $" .. player.cash
end

local function get_player_details_text(player, view, item_name_by_id)
  if player.eliminated then return nil end
  local parts = {}
  
  -- Status / Location
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

  -- Deity
  if status.deity then
    table.insert(parts, status.deity.type .. "(" .. status.deity.remaining .. ")")
  end

  -- Vehicle
  if player.seat_id then
    local vname = vehicle_name_by_id[player.seat_id] or ("车" .. player.seat_id)
    table.insert(parts, vname)
  end

  -- Items
  local inv = player.inventory or {}
  if inv.items and #inv.items > 0 then
    local names = {}
    for _, item in ipairs(inv.items) do
       table.insert(names, item_name_by_id[item.id] or tostring(item.id))
    end
    table.insert(parts, "{" .. table.concat(names, ",") .. "}")
  end

  if #parts == 0 then return nil end
  return table.concat(parts, " ")
end

local function draw_current_player(ui, view, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("当前玩家", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 18

  local state = view and view.state
  if not state then
    return y
  end

  local turn = state.turn or {}
  local players = state.players or {}
  local idx = turn.current_player_index or 1
  local current = players[idx]
  if not current then
    return y
  end
  love.graphics.setFont(ui.fonts.body)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf(current.name .. " 现金 " .. current.cash, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 20

  local role_id = current.role_id or current.id
  local role = roles_cfg[((role_id - 1) % #roles_cfg) + 1]
  love.graphics.setFont(ui.fonts.tiny)
  love.graphics.setColor(ui.palette.muted)
  love.graphics.printf("角色: " .. (role and role.name or "-"), panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  local status = current.status or {}
  if status.deity then
    love.graphics.printf("附身: " .. status.deity.type .. " (" .. status.deity.remaining .. ")", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
    y = y + 16
  end

  local phase = turn.item_phase_active
  if phase then
    local phase_label = phase == "pre_action" and "行动前"
      or phase == "pre_move" and "投骰后"
      or phase == "post_action" and "行动后"
      or phase
    love.graphics.setColor(ui.palette.muted)
    love.graphics.printf("阶段: " .. phase_label, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
    y = y + 16
  end

  if view.last_turn and view.last_turn.player_id == current.id then
    if view.last_turn.rolls then
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(
        "骰子: " .. table.concat(view.last_turn.rolls, ",") .. " => " .. view.last_turn.total,
        panel.x + ui.margin,
        y,
        panel.w - ui.margin * 2,
        "left"
      )
      y = y + 18
    elseif view.last_turn.note then
      love.graphics.setColor(ui.palette.muted)
      love.graphics.printf(view.last_turn.note, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 18
    end
  end

  return y
end

local function draw_player_status(ui, view, panel, y, item_name_by_id)
  love.graphics.setFont(ui.fonts.body)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("玩家状态", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 20

  local state = view and view.state
  if state then
    local players = state.players or {}
    for pid = 1, #players do
      local player = players[pid]
      if player then
        -- Name line
        love.graphics.setFont(ui.fonts.small)
        local color = ui.palette.player[pid] or ui.palette.text
        love.graphics.setColor(color)
        love.graphics.circle("fill", panel.x + ui.margin + 6, y + 8, 4)
        love.graphics.setColor(ui.palette.text)
        love.graphics.printf(player_label(player), panel.x + ui.margin + 16, y, panel.w - ui.margin * 2 - 16, "left")
        y = y + 18

        -- Details line
        local details = get_player_details_text(player, view, item_name_by_id)
        if details then
          love.graphics.setColor(ui.palette.muted)
          local _, lines = ui.fonts.small:getWrap(details, panel.w - ui.margin * 2 - 16)
          love.graphics.printf(details, panel.x + ui.margin + 16, y, panel.w - ui.margin * 2 - 16, "left")
          y = y + (#lines * 18)
        end
        
        -- Spacer
        y = y + 6
      end
    end
  end
  return y
end

local function draw_tile_detail(ui, view, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("格子详情", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  local state = view and view.state
  if state and (ui.selected_tile or ui.hover_tile) then
    local idx = ui.selected_tile or ui.hover_tile
    local tile = view.board and view.board.tiles and view.board.tiles[idx]
    if tile then
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(tile.name .. " (" .. tile.type .. ")", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 14
      if tile.type == "land" then
        local tile_state = state.board and state.board.tiles and state.board.tiles[tile.id] or nil
        local owner_id = tile_state and tile_state.owner_id or nil
        local level = tile_state and tile_state.level or 0
        local owner = owner_id and state.players and state.players[owner_id]
        love.graphics.printf("价格: " .. tostring(tile.price or "-"), panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
        love.graphics.printf("等级: " .. tostring(level or 0), panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
        if owner then
          love.graphics.printf("归属: " .. owner.name, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
          y = y + 14
        end
      end
      local overlays = (view.board and view.board.overlays) or (state.board and state.board.overlays) or {}
      if overlays.roadblocks and overlays.roadblocks[idx] then
        love.graphics.printf("路障: 有", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
      end
      if overlays.mines and overlays.mines[idx] then
        love.graphics.printf("地雷: 有", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
      end
    end
  end

  return y
end

local function draw_log(ui, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("事件记录", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 18

  if logger.entries then
    love.graphics.setFont(ui.fonts.tiny)
    local max_lines = math.floor((panel.y + panel.h - y - ui.margin) / (ui.fonts.tiny:getHeight() + 2))
    local start = math.max(1, #logger.entries - max_lines)
    for i = start, #logger.entries do
      local entry = logger.entries[i]
      love.graphics.setColor(ui.palette.log[entry.level] or ui.palette.text)
      local lines = draw_wrapped(entry.text, panel.x + ui.margin, y, panel.w - ui.margin * 2, ui.fonts.tiny)
      y = y + (ui.fonts.tiny:getHeight() + 2) * math.max(1, lines)
    end
  end
end

function PanelRenderer.draw(ui, view, buttons, item_name_by_id)
  local panel = ui.panel
  draw_panel_background(ui, panel)

  love.graphics.setFont(ui.fonts.title)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("蛋仔大富翁", panel.x + ui.margin, panel.y + 18, panel.w - ui.margin * 2, "left")

  love.graphics.setFont(ui.fonts.small)
  local turn_label = "回合: -"
  local tc = view and view.state and view.state.turn and view.state.turn.turn_count
  if tc ~= nil then
    turn_label = "回合: " .. tostring(tc)
  end
  love.graphics.setColor(ui.palette.muted)
  love.graphics.printf(turn_label, panel.x + ui.margin, panel.y + 42, panel.w - ui.margin * 2, "left")

  for _, btn in ipairs(buttons) do
    draw_button(ui, btn, btn.id == "auto" and ui.auto_play)
  end
  local info_y = panel.y + 200
  info_y = draw_current_player(ui, view, panel, info_y)
  info_y = draw_player_status(ui, view, panel, info_y + 10, item_name_by_id)
  info_y = draw_tile_detail(ui, view, panel, info_y + 10)
  info_y = math.max(info_y + 6, panel.y + panel.h * 0.68)
  draw_log(ui, panel, info_y)
end

return PanelRenderer
