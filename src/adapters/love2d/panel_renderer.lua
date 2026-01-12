local logger = require("src.util.logger")
local roles_cfg = require("src.config.roles")

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
  local suffix = ""
  local status = player.status or {}
  if status.stay_turns and status.stay_turns > 0 then
    suffix = " 停留" .. status.stay_turns
  end
  return player.name .. " $" .. player.cash .. suffix
end

local function get_store_state(game)
  if not game or not game.store or not game.store.get then
    return nil
  end
  local players = game.store:get({ "players" }) or {}
  local turn = game.store:get({ "turn" }) or {}
  local board = game.store:get({ "board" }) or {}
  local overlays = (board and board.overlays) or game.store:get({ "board", "overlays" }) or {}
  local tiles = (board and board.tiles) or game.store:get({ "board", "tiles" }) or {}
  return { players = players, turn = turn, overlays = overlays, tiles = tiles }
end

local function draw_current_player(ui, game, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("当前玩家", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 18

  if not game then
    return y
  end

  local st = get_store_state(game)
  local idx = (st and st.turn and st.turn.current_player_index) or (game and game.store and game.store:get({ "turn", "current_player_index" })) or 1
  local current = st and st.players and st.players[idx] or nil
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

  if game.last_turn and game.last_turn.player_id == current.id then
    if game.last_turn.rolls then
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf("骰子: " .. table.concat(game.last_turn.rolls, ",") .. " => " .. game.last_turn.total, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 18
    elseif game.last_turn.note then
      love.graphics.setColor(ui.palette.muted)
      love.graphics.printf(game.last_turn.note, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 18
    end
  end

  return y
end

local function draw_player_status(ui, game, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("玩家状态", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  local st = get_store_state(game)
  if game and st then
    love.graphics.setFont(ui.fonts.tiny)
    local count = (game.players and #game.players) or 0
    for pid = 1, count do
      local player = st.players[pid]
      if player then
        local color = ui.palette.player[pid] or ui.palette.text
      love.graphics.setColor(color)
      love.graphics.circle("fill", panel.x + ui.margin + 6, y + 6, 4)
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(player_label(player), panel.x + ui.margin + 16, y, panel.w - ui.margin * 2 - 16, "left")
      y = y + 16
      end
    end
  end
  return y
end

local function draw_inventory(ui, game, panel, y, item_name_by_id)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("当前背包", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  local st = get_store_state(game)
  if game and st then
    local idx = st.turn.current_player_index or 1
    local current = st.players[idx]
    if not current then
      return y
    end
    love.graphics.setFont(ui.fonts.tiny)
    local inv = current.inventory or { items = {} }
    if not inv.items or #inv.items == 0 then
      love.graphics.setColor(ui.palette.muted)
      love.graphics.printf("暂无道具", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 16
    else
      for _, item in ipairs(inv.items) do
        love.graphics.setColor(ui.palette.text)
        love.graphics.printf(item_name_by_id[item.id] or tostring(item.id), panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
      end
    end
  end
  return y
end

local function draw_tile_detail(ui, game, panel, y)
  love.graphics.setFont(ui.fonts.small)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("格子详情", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
  y = y + 16

  local st = get_store_state(game)
  if game and st and (ui.selected_tile or ui.hover_tile) then
    local idx = ui.selected_tile or ui.hover_tile
    local tile = game.board:get_tile(idx)
    if tile then
      love.graphics.setFont(ui.fonts.tiny)
      love.graphics.setColor(ui.palette.text)
      love.graphics.printf(tile.name .. " (" .. tile.type .. ")", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
      y = y + 14
      if tile.type == "land" then
        local tile_state = st.tiles and st.tiles[tile.id] or nil
        local owner_id = tile_state and tile_state.owner_id or nil
        local level = tile_state and tile_state.level or 0
        local owner = owner_id and st.players and st.players[owner_id]
        love.graphics.printf("价格: " .. tile.price, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
        love.graphics.printf("等级: " .. tostring(level or 0), panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
        if owner then
          love.graphics.printf("归属: " .. owner.name, panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
          y = y + 14
        end
      end
      if st.overlays and st.overlays.roadblocks and st.overlays.roadblocks[idx] then
        love.graphics.printf("路障: 有", panel.x + ui.margin, y, panel.w - ui.margin * 2, "left")
        y = y + 14
      end
      if st.overlays and st.overlays.mines and st.overlays.mines[idx] then
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

function PanelRenderer.draw(ui, game, buttons, item_name_by_id)
  local panel = ui.panel
  draw_panel_background(ui, panel)

  love.graphics.setFont(ui.fonts.title)
  love.graphics.setColor(ui.palette.text)
  love.graphics.printf("蛋仔大富翁", panel.x + ui.margin, panel.y + 18, panel.w - ui.margin * 2, "left")

  love.graphics.setFont(ui.fonts.small)
  local turn_label = "回合: -"
  if game and game.store and game.store.get then
    local tc = game.store:get({ "turn", "turn_count" })
    if tc ~= nil then
      turn_label = "回合: " .. tostring(tc)
    end
  end
  love.graphics.setColor(ui.palette.muted)
  love.graphics.printf(turn_label, panel.x + ui.margin, panel.y + 42, panel.w - ui.margin * 2, "left")

  for _, btn in ipairs(buttons) do
    draw_button(ui, btn, btn.id == "auto" and ui.auto_play)
  end

  local info_y = panel.y + 200
  info_y = draw_current_player(ui, game, panel, info_y)
  info_y = draw_player_status(ui, game, panel, info_y + 10)
  info_y = draw_inventory(ui, game, panel, info_y + 10, item_name_by_id)
  info_y = draw_tile_detail(ui, game, panel, info_y + 10)
  info_y = math.max(info_y + 6, panel.y + panel.h * 0.68)
  draw_log(ui, panel, info_y)
end

return PanelRenderer
