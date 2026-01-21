local logger = require("src.util.logger")
local UIState = require("src.adapters.eggy.ui_state")
local AutoRunner = require("src.adapters.love2d.auto_runner")
local Presenter = require("src.adapters.eggy.presenter")
local AdapterLayer = require("src.adapters.core.adapter_layer")
local Agent = require("src.gameplay.agent")
local roles_cfg = require("src.config.roles")
local vehicles_cfg = require("src.config.vehicles")

local EggyLayer = {}
EggyLayer.__index = EggyLayer

local function build_log_prefix()
  return "[EggyAdapter]"
end

local function build_phase_label(phase)
  if phase == "pre_action" then
    return "行动前"
  end
  if phase == "pre_move" then
    return "投骰后"
  end
  if phase == "post_action" then
    return "行动后"
  end
  return phase
end

local function join_lines(lines)
  if not lines then
    return ""
  end
  return table.concat(lines, "\n")
end

local function map_vehicle_names()
  local out = {}
  for _, cfg in ipairs(vehicles_cfg) do
    out[cfg.id] = cfg.name
  end
  return out
end

function EggyLayer.new(opts)
  opts = opts or {}
  local ui = UIState.create()
  local self = setmetatable({
    ui = ui,
    vehicle_name_by_id = map_vehicle_names(),
  }, EggyLayer)
  AdapterLayer.attach(self, {
    ui = ui,
    game_factory = opts.game_factory,
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
    on_need_choice = function(layer, choice)
      layer:_open_choice_modal(choice)
    end,
  })

  return self
end

function EggyLayer:set_game(g)
  AdapterLayer.set_game(self, g, {
    on_pending_choice = function(layer, pending)
      layer:_open_choice_modal(pending)
    end,
  })
end

function EggyLayer:build_item_index()
  AdapterLayer.build_item_index(self)
end

function EggyLayer:new_game()
  return AdapterLayer.new_game(self)
end

function EggyLayer:_log_status(view)
  if not view then
    return
  end
  logger.info(
    build_log_prefix(),
    "玩家:",
    tostring(view.current_player_name),
    "现金:",
    tostring(view.current_player_cash),
    "回合:",
    tostring(view.turn_count)
  )
end

function EggyLayer:tick(dt)
  if not self.game then
    return
  end

  if self.pending_choice then
    self:_open_choice_modal(self.pending_choice)
  end

  AdapterLayer.step_auto_runner(self, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = self.game.finished,
  })

  self:refresh_view()

  AdapterLayer.step_choice_timeout(self, dt, {
    build_action = function(layer, choice)
      local auto_choice = Agent.auto_action_for_choice(layer.game, choice)
      if auto_choice then
        return auto_choice
      end
      local first = choice.options and choice.options[1]
      if first then
        return {
          type = "choice_select",
          choice_id = choice.id,
          option_id = first.id or first,
        }
      end
      if choice.allow_cancel ~= false then
        return { type = "choice_cancel", choice_id = choice.id }
      end
      return nil
    end,
  })

  self:_log_status(self:build_view())
end

local function build_phase_title(game, base_title)
  if not (game and game.store) then
    return base_title
  end
  local phase = game.store:get({ "turn", "item_phase_active" })
  if not phase then
    return base_title
  end
  local label = phase == "pre_action" and "行动前"
    or phase == "pre_move" and "投骰后"
    or phase == "post_action" and "行动后"
    or phase
  return "[" .. label .. "] " .. (base_title or "请选择")
end

function EggyLayer:_open_choice_modal(pending)
  if not pending then
    return
  end
  if self.pending_choice_id == pending.id and self.ui.choice_active then
    return
  end

  local title = build_phase_title(self.game, pending.title or "请选择")
  local body = ""
  if pending.body_lines then
    body = join_lines(pending.body_lines)
  elseif pending.body then
    body = pending.body
  end

  self.ui:set_label(self.ui.choice.title, title)
  self.ui:set_label(self.ui.choice.body, body)
  self.ui:set_visible(self.ui.choice.root, true)

  local option_nodes = self.ui.choice.option_buttons or {}
  for idx, name in ipairs(option_nodes) do
    local opt = pending.options and pending.options[idx]
    if opt then
      self.ui:set_button(name, opt.label or tostring(opt.id or opt))
      self.ui:set_visible(name, true)
      self.ui:set_touch_enabled(name, true)
    else
      self.ui:set_visible(name, false)
      self.ui:set_touch_enabled(name, false)
    end
  end

  if pending.allow_cancel == false then
    self.ui:set_visible(self.ui.choice.cancel, false)
    self.ui:set_touch_enabled(self.ui.choice.cancel, false)
  else
    self.ui:set_button(self.ui.choice.cancel, pending.cancel_label or "取消")
    self.ui:set_visible(self.ui.choice.cancel, true)
    self.ui:set_touch_enabled(self.ui.choice.cancel, true)
  end

  self.ui.choice_active = true
  self.pending_choice_elapsed = 0
  self.pending_choice_id = pending.id
end

function EggyLayer:_close_choice_modal()
  if not self.ui.choice_active then
    return
  end
  self.ui:set_visible(self.ui.choice.root, false)
  self.ui.choice_active = false
end

function EggyLayer:build_view()
  local store_state = self.game.store.state
  local winner_name = self.game.winner_names
  if not winner_name and self.game.winner then
    winner_name = self.game.winner.name
  end
  return Presenter.present(store_state, {
    game = self.game,
    last_turn = self.game.last_turn,
    finished = self.game.finished,
    winner_name = winner_name,
  })
end

function EggyLayer:refresh_view()
  local view = self:build_view()
  self:refresh_panel(view)
  self:refresh_board(view)
end

local function player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  return player.name .. " $" .. player.cash
end

local function get_player_details_text(player, view, item_name_by_id, vehicle_name_by_id)
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
    local vname = vehicle_name_by_id[player.seat_id] or ("车" .. player.seat_id)
    table.insert(parts, vname)
  end

  local inv = player.inventory or {}
  if inv.items and #inv.items > 0 then
    local names = {}
    for _, item in ipairs(inv.items) do
      table.insert(names, item_name_by_id[item.id] or tostring(item.id))
    end
    table.insert(parts, "{" .. table.concat(names, ",") .. "}")
  end

  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

function EggyLayer:refresh_panel(view)
  local state = view.state
  local turn = state.turn
  local players = state.players
  local idx = turn.current_player_index
  local current = players[idx]
  local role_id = current.role_id or current.id
  local role = roles_cfg[((role_id - 1) % #roles_cfg) + 1]

  local turn_label = "回合: " .. turn.turn_count

  self.ui:set_label("panel_title", "蛋仔大富翁")
  self.ui:set_label("panel_turn", turn_label)
  self.ui:set_label("panel_current_title", "当前玩家")

  self.ui:set_label("panel_current_name", current.name .. " 现金 " .. current.cash)

  self.ui:set_label("panel_current_role", "角色: " .. role.name)

  local phase = turn.item_phase_active
  if phase then
    self.ui:set_label("panel_current_phase", "阶段: " .. build_phase_label(phase))
  else
    self.ui:set_label("panel_current_phase", "")
  end

  local dice_text = ""
  if view and view.last_turn and current and view.last_turn.player_id == current.id then
    if view.last_turn.rolls then
      dice_text = "骰子: " .. table.concat(view.last_turn.rolls, ",") .. " => " .. view.last_turn.total
    elseif view.last_turn.note then
      dice_text = view.last_turn.note
    end
  end
  self.ui:set_label("panel_current_dice", dice_text)

  self.ui:set_label("panel_players_title", "玩家状态")
  for i = 1, 4 do
    local player = players[i]
    local label = player_label(player)
    self.ui:set_label("panel_player_" .. tostring(i), label)
    local detail = get_player_details_text(player, view, self.item_name_by_id, self.vehicle_name_by_id) or ""
    self.ui:set_label("panel_player_" .. tostring(i) .. "_detail", detail)
  end

  self.ui:set_label("panel_tile_title", "格子详情")
  self:refresh_tile_detail(view)

  self.ui:set_button("btn_next", "下一回合")
  local auto_label = "自动运行:关"
  if self.ui.auto_play then
    auto_label = "自动运行:开"
  end
  self.ui:set_button("btn_auto", auto_label)
  self.ui:set_button("btn_restart", "重新开始")

  local entries = logger.entries or {}
  local start = math.max(1, #entries - 8)
  local log_lines = {}
  for i = start, #entries do
    local entry = entries[i]
    table.insert(log_lines, entry.text)
  end
  self.ui:set_label("panel_log_title", "事件记录")
  self.ui:set_label("panel_log_body", table.concat(log_lines, "\n"))
end

function EggyLayer:refresh_tile_detail(view)
  local state = view.state
  local idx = self.ui.selected_tile
  local tile = view.board.tiles[idx]
  if not tile then
    self.ui:set_label("tile_detail_name", "")
    self.ui:set_label("tile_detail_price", "")
    self.ui:set_label("tile_detail_level", "")
    self.ui:set_label("tile_detail_owner", "")
    self.ui:set_label("tile_detail_roadblock", "")
    self.ui:set_label("tile_detail_mine", "")
    return
  end

  self.ui:set_label("tile_detail_name", tile.name .. " (" .. tile.type .. ")")

  if tile.type == "land" then
    local tile_state = state.board.tiles[tile.id]
    local owner_id = tile_state.owner_id
    local level = tile_state.level
    local owner = state.players[owner_id]
    self.ui:set_label("tile_detail_price", "价格: " .. tostring(tile.price or "-"))
    self.ui:set_label("tile_detail_level", "等级: " .. tostring(level))
    if owner then
      self.ui:set_label("tile_detail_owner", "归属: " .. owner.name)
    else
      self.ui:set_label("tile_detail_owner", "归属: -")
    end
  else
    self.ui:set_label("tile_detail_price", "")
    self.ui:set_label("tile_detail_level", "")
    self.ui:set_label("tile_detail_owner", "")
  end

  local overlays = view.board.overlays
  local roadblock_text = "路障: 无"
  if overlays.roadblocks[idx] then
    roadblock_text = "路障: 有"
  end
  local mine_text = "地雷: 无"
  if overlays.mines[idx] then
    mine_text = "地雷: 有"
  end
  self.ui:set_label("tile_detail_roadblock", roadblock_text)
  self.ui:set_label("tile_detail_mine", mine_text)
end

function EggyLayer:refresh_board(view)
  local st = view.state
  local overlays = view.board.overlays
  for idx, tile in ipairs(view.board.tiles) do
    local tile_state = st.board.tiles[tile.id]
    local owner_id = tile_state.owner_id
    local level = tile_state.level
    local node = "tile_" .. tostring(idx)
    local label = tile.name
    if tile.type == "land" and owner_id then
      label = label .. " Lv" .. tostring(level)
    end
    if overlays.roadblocks and overlays.roadblocks[idx] then
      label = label .. " 路障"
    elseif overlays.mines and overlays.mines[idx] then
      label = label .. " 地雷"
    end
    self.ui:set_label(node, label)
  end
end

function EggyLayer:step_turn()
  if not self.game or self.game.finished then
    return
  end
  self.game:advance_turn()
end

function EggyLayer:dispatch_action(action)
  if not action then
    return
  end
  if action.type == "ui_button" then
    if action.id == "next" then
      self:step_turn()
    elseif action.id == "auto" then
      self.ui.auto_play = not self.ui.auto_play
      self.auto_runner:set_enabled(self.ui.auto_play)
      self.auto_runner:reset_timer()
    elseif action.id == "restart" then
      local was_auto = self.ui.auto_play
      self:set_game(self:new_game())
      self.auto_runner:set_enabled(was_auto)
    end
  elseif action.type == "ui_tile_select" then
    self.ui.selected_tile = action.index
    self:refresh_tile_detail(self:build_view())
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    AdapterLayer.clear_choice(self, {
      on_close_choice = function(layer)
        layer:_close_choice_modal()
      end,
    })
    if self.game then
      self.game:dispatch_action(action)
    end
  end
end

function EggyLayer:push_popup(payload)
  if not payload then
    return false
  end
  self.ui:set_label(self.ui.popup.title, payload.title or "提示")
  self.ui:set_label(self.ui.popup.body, payload.body or "")
  self.ui:set_button(self.ui.popup.confirm, payload.button_text or "知道了")
  self.ui:set_visible(self.ui.popup.root, true)
  self.ui.popup_active = true
  return true
end

function EggyLayer:close_popup()
  if not self.ui.popup_active then
    return
  end
  self.ui:set_visible(self.ui.popup.root, false)
  self.ui.popup_active = false
end

function EggyLayer:tick_once(dt)
  self:tick(dt)
end

return EggyLayer
