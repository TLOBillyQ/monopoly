local logger = require("src.util.logger")
local vehicles_cfg = require("src.config.vehicles")
local PanelView = require("src.adapters.core.ui_panel")
local TileView = require("src.adapters.core.ui_tile")
local LogView = require("src.adapters.core.ui_log")

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
  local bg = { 0.2, 0.22, 0.24 }
  if active then
    bg = { 0.3, 0.5, 0.35 }
  end
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

local function draw_current_player(ui, view, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("当前玩家", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 18

  local current_view = PanelView.build_current_player_view(view)
  if not current_view then
    return y
  end
  love.graphics.setFont(ui.fonts.body)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf(current_view.name_text, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 20

  love.graphics.setFont(ui.fonts.tiny)
  love.graphics.setColor(ui.palette.muted)
  love.graphics.printf(current_view.role_text, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  if current_view.deity_text then
    love.graphics.printf(current_view.deity_text, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
    y = y + 16
  end

  if current_view.phase_text then
    love.graphics.setColor(ui.palette.muted)
    love.graphics.printf(current_view.phase_text, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
    y = y + 16
  end

  if current_view.dice_text then
    if current_view.dice_is_note then
      love.graphics.setColor(ui.palette.muted)
    else
      love.graphics.setColor(ui.palette.text)
    end
    love.graphics.printf(current_view.dice_text, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
    y = y + 18
  end

  return y
end

local function draw_player_status(ui, view, panel, y, item_name_by_id)
  love.graphics.setFont(ui.fonts.body)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("玩家状态", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 20

  local player_rows = PanelView.build_player_statuses(view, item_name_by_id, vehicle_name_by_id)
  for pid, row in ipairs(player_rows) do
    love.graphics.setFont(ui.fonts.small)
    local color = ui.palette.player[pid] or ui.palette.text
    love.graphics.setColor(color)
    love.graphics.circle("fill", panel.x + ui.margin + 6, y + 8, 4)
    love.graphics.setColor(ui.palette.text)
    love.graphics.printf(row.label, panel.x + ui.margin + 16, y, panel.w - ui.margin * 2 - 16, "left")
    y = y + 18

    local details = row.detail
    if details then
      love.graphics.setColor(ui.palette.muted)
      local _, lines = ui.fonts.small:getWrap(details, panel.w - ui.margin * 2 - 16)
      love.graphics.printf(details, panel.x + ui.margin + 16, y, panel.w - ui.margin * 2 - 16, "left")
      y = y + (#lines * 18)
    end

    y = y + 6
  end
  return y
end

local function draw_tile_detail(ui, view, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("格子详情", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  if ui.selected_tile or ui.hover_tile then
    local idx = ui.selected_tile or ui.hover_tile
    local detail = TileView.build_tile_detail_view(view, idx)
    if detail then
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(detail.name, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 14
      if detail.price then
        love.graphics.printf(detail.price, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
        love.graphics.printf(detail.level, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
        if detail.has_owner then
          love.graphics.printf(detail.owner_label, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
          y = y + 14
        end
      end
      if detail.has_roadblock then
        love.graphics.printf(detail.roadblock, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
      end
      if detail.has_mine then
        love.graphics.printf(detail.mine, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
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
    local entries = LogView.build_log_entries(logger.entries, max_lines)
    for _, entry in ipairs(entries) do
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
  local tc = view.state.turn.turn_count
  local turn_label = PanelView.build_turn_label(tc)
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
