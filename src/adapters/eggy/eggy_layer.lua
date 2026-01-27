local logger = require("src.util.logger")
local UIState = require("src.adapters.eggy.ui_state")
local AutoRunner = require("src.adapters.core.auto_runner")
local Presenter = require("src.adapters.core.presenter")
local AdapterLayer = require("src.adapters.core.adapter_layer")
local ChoiceView = require("src.adapters.core.ui_choice")
local PanelView = require("src.adapters.core.ui_panel")
local TileView = require("src.adapters.core.ui_tile")
local LogView = require("src.adapters.core.ui_log")
local MarketUI = require("src.adapters.eggy.market_ui")
local Agent = require("src.gameplay.agent")
local items_cfg = require("src.config.items")
local market_cfg = require("src.config.market")
local vehicles_cfg = require("src.config.vehicles")

local EggyLayer = {}
EggyLayer.__index = EggyLayer

local function build_log_prefix()
  return "[EggyAdapter]"
end

local function log_once(self, level, key, ...)
  if not self or not self._log_once or self._log_once[key] then
    return
  end
  self._log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

local function show_tips(message, duration)
  local text = message and tostring(message) or ""
  if text == "" then
    return false
  end
  if GlobalAPI and GlobalAPI.show_tips then
    GlobalAPI.show_tips(text, duration)
    return true
  end
  local role = rawget(_G, "Role")
  if role and role.show_tips then
    role.show_tips(text, duration)
    return true
  end
  return false
end

local vehicles_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicles_by_id[cfg.id] = cfg
end

local function map_vehicle_names()
  local out = {}
  for id, cfg in pairs(vehicles_by_id) do
    out[id] = cfg.name
  end
  return out
end

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local market_by_id = {}
for _, entry in ipairs(market_cfg) do
  market_by_id[entry.product_id] = entry
end


function EggyLayer.new(opts)
  opts = opts or {}
  local ui = UIState.create()
  local self = setmetatable({
    ui = ui,
    vehicle_name_by_id = map_vehicle_names(),
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    _log_once = {},
  }, EggyLayer)
  AdapterLayer.attach(self, {
    ui = ui,
    game_factory = opts.game_factory,
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
    on_need_choice = function(layer, choice)
      layer:_open_choice_modal(choice)
    end,
  })
  logger.set_adapter({
    on_log = function(entry)
      if entry and entry.level == "event" then
        show_tips(entry.text, 2)
      end
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
  self.player_units = nil
  self.player_units_missing = false
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

  AdapterLayer.step_auto_runner(self, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = self.game and self.game.finished,
  })

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

  AdapterLayer.step_modal_timeout(self, dt, {
    is_active = function(layer)
      return layer.ui and layer.ui.popup_active
    end,
    get_ref = function(layer)
      return layer.ui and layer.ui.popup_active and layer.ui.popup_seq or nil
    end,
    on_timeout = function(layer)
      layer:close_popup()
    end,
  })

  AdapterLayer.step_move_anim(self)

  if self.pending_choice then
    self:_open_choice_modal(self.pending_choice)
  end

  self:refresh_view()

  self:_log_status(self:build_view())
end

function EggyLayer:_open_choice_modal(pending)
  if not pending then
    return
  end
  if self.pending_choice_id == pending.id and (self.ui.choice_active or self.ui.choose_option_active) then
    return
  end

  if pending.kind == "market_buy"
    and pending.options
    and #pending.options > 0
    and #pending.options <= 3
    and MarketUI.is_ready
    and MarketUI.is_ready() then
    local ok, choose = pcall(require, "src.adapters.eggy.lib.eggy_choose_option.ChooseOption.__init")
    if not ok then
      ok, choose = pcall(require, "src.adapters.eggy.lib.eggy_choose_option.ChooseOption")
    end
    if ok and choose then
      if self.ui.choice_active then
        self.ui:set_visible(self.ui.choice.root, false)
        self.ui.choice_active = false
      end

      local cards = {}
      local option_ids = {}
      for idx, opt in ipairs(pending.options) do
        local opt_id = opt.id or opt
        option_ids[idx] = opt_id
        local entry = market_by_id[opt_id]
        local cfg = nil
        if entry and entry.kind == "vehicle" then
          cfg = vehicles_by_id[opt_id]
        else
          cfg = items_by_id[opt_id]
        end
        local name = (entry and entry.name)
          or (cfg and cfg.name)
          or (opt.label)
          or tostring(opt_id)
        local price = entry and entry.price or 0
        local currency = entry and entry.currency or nil
        if currency == nil or currency == "" then
          currency = "金币"
        end
        local level = cfg and cfg.tier or 1
        if level < 1 then
          level = 1
        elseif level > 3 then
          level = 3
        end
        local card = {
          title = name,
          description = "价格: " .. tostring(price) .. " " .. currency,
          level = level,
          icon = MarketUI.icon_placeholder or "icon_placeholder",
        }
        if entry and entry.page then
          card.label = entry.page
        end
        cards[idx] = card
      end

      local payload = {
        container = MarketUI.container,
        title = pending.title or MarketUI.title or "黑市",
        choose_event = MarketUI.choose_event,
        confirm_event = MarketUI.confirm_event,
        confirm_button = MarketUI.confirm_button,
        cancel_button = MarketUI.cancel_button,
        cards = cards,
      }

      local container = self.choose_option_container
      if choose.build and type(choose.build) == "function" then
        local built = choose.build(payload)
        if built then
          container = built
        end
      end
      if container then
        if container.set_data then
          container:set_data(payload)
        elseif container.refresh then
          container:refresh(payload)
        elseif container.update then
          container:update(payload)
        end
        if container.show then
          container:show()
        elseif container.set_visible then
          container:set_visible(true)
        end
      end

      self.choose_option_container = container
      self.ui.choose_option_active = true
      self.market_choice_option_ids = option_ids
      self.pending_choice_selected_option_id = nil
      self.pending_choice_elapsed = 0
      self.pending_choice_id = pending.id
      return
    end
  end

  if self.ui.choose_option_active then
    local container = self.choose_option_container
    if container then
      if container.hide then
        container:hide()
      elseif container.set_visible then
        container:set_visible(false)
      end
    end
    self.ui.choose_option_active = false
    self.market_choice_option_ids = nil
    self.pending_choice_selected_option_id = nil
  end

  local view = ChoiceView.build_choice_view(pending, { game = self.game })
  if not view then
    return
  end

  self.ui:set_label(self.ui.choice.title, view.title)
  self.ui:set_label(self.ui.choice.body, view.body)
  self.ui:set_visible(self.ui.choice.root, true)

  local option_nodes = self.ui.choice.option_buttons or {}
  for idx, name in ipairs(option_nodes) do
    local opt = view.options and view.options[idx]
    if opt then
      self.ui:set_button(name, opt.label)
      self.ui:set_visible(name, true)
      self.ui:set_touch_enabled(name, true)
    else
      self.ui:set_visible(name, false)
      self.ui:set_touch_enabled(name, false)
    end
  end

  if not view.allow_cancel then
    self.ui:set_visible(self.ui.choice.cancel, false)
    self.ui:set_touch_enabled(self.ui.choice.cancel, false)
  else
    self.ui:set_button(self.ui.choice.cancel, view.cancel_label)
    self.ui:set_visible(self.ui.choice.cancel, true)
    self.ui:set_touch_enabled(self.ui.choice.cancel, true)
  end

  self.ui.choice_active = true
  self.pending_choice_elapsed = 0
  self.pending_choice_id = pending.id
end

function EggyLayer:_close_choice_modal()
  if self.ui.choice_active then
    self.ui:set_visible(self.ui.choice.root, false)
    self.ui.choice_active = false
  end
  if self.ui.choose_option_active then
    local container = self.choose_option_container
    if container then
      if container.hide then
        container:hide()
      elseif container.set_visible then
        container:set_visible(false)
      end
    end
    self.ui.choose_option_active = false
  end
  self.market_choice_option_ids = nil
  self.pending_choice_selected_option_id = nil
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

function EggyLayer:refresh_panel(view)
  local turn_label = PanelView.build_turn_label(view.state.turn.turn_count)
  local current_view = PanelView.build_current_player_view(view)

  self.ui:set_label("panel_title", "蛋仔大富翁")
  self.ui:set_label("panel_turn", turn_label)
  self.ui:set_label("panel_current_title", "当前玩家")

  self.ui:set_label("panel_current_name", current_view and current_view.name_text or "")
  self.ui:set_label("panel_current_role", current_view and current_view.role_text or "")

  self.ui:set_label("panel_current_phase", current_view and current_view.phase_text or "")
  self.ui:set_label("panel_current_dice", current_view and current_view.dice_text or "")

  self.ui:set_label("panel_players_title", "玩家状态")
  local player_rows = PanelView.build_player_statuses(view, self.item_name_by_id, self.vehicle_name_by_id, 4)
  for i = 1, 4 do
    local row = player_rows[i]
    self.ui:set_label("panel_player_" .. tostring(i), row and row.label or "")
    self.ui:set_label("panel_player_" .. tostring(i) .. "_detail", row and row.detail or "")
  end

  self.ui:set_label("panel_tile_title", "格子详情")
  self:refresh_tile_detail(view)

  self.ui:set_button("btn_next", "下一回合")
  self.ui:set_button("btn_auto", PanelView.build_auto_label(self.ui.auto_play))
  self.ui:set_button("btn_restart", "重新开始")

  local entries = logger.entries or {}
  local log_entries = LogView.build_log_entries(entries, 8)
  local log_lines = {}
  for _, entry in ipairs(log_entries) do
    log_lines[#log_lines + 1] = entry.text
  end
  self.ui:set_label("panel_log_title", "事件记录")
  self.ui:set_label("panel_log_body", table.concat(log_lines, "\n"))
end

function EggyLayer:refresh_tile_detail(view)
  local idx = self.ui.selected_tile
  local detail = TileView.build_tile_detail_view(view, idx)
  if not detail then
    self.ui:set_label("tile_detail_name", "")
    self.ui:set_label("tile_detail_price", "")
    self.ui:set_label("tile_detail_level", "")
    self.ui:set_label("tile_detail_owner", "")
    self.ui:set_label("tile_detail_roadblock", "")
    self.ui:set_label("tile_detail_mine", "")
    return
  end

  self.ui:set_label("tile_detail_name", detail.name)
  if detail.price then
    self.ui:set_label("tile_detail_price", detail.price)
    self.ui:set_label("tile_detail_level", detail.level or "")
    self.ui:set_label("tile_detail_owner", detail.owner_label or "")
  else
    self.ui:set_label("tile_detail_price", "")
    self.ui:set_label("tile_detail_level", "")
    self.ui:set_label("tile_detail_owner", "")
  end
  self.ui:set_label("tile_detail_roadblock", detail.roadblock or "")
  self.ui:set_label("tile_detail_mine", detail.mine or "")
end

function EggyLayer:refresh_board(view)
  for idx in ipairs(view.board.tiles) do
    local node = "tile_" .. tostring(idx)
    self.ui:set_label(node, TileView.build_tile_label(view, idx))
  end

  local players = view and view.state and view.state.players or nil
  if not players then
    return
  end

  local tile_count = view.board_tile_count or (view.board and #view.board.tiles) or 0
  if tile_count <= 0 then
    return
  end

  if not self.tile_positions or #self.tile_positions < tile_count then
    local tiles = nil
    if G and type(G.tiles) == "table" and #G.tiles >= tile_count then
      tiles = G.tiles
    else
      local tile_names = {}
      for i = 1, tile_count do
        tile_names[i] = "t" .. tostring(i)
      end
      tiles = LuaAPI.query_units(tile_names)
    end

    local positions = {}
    local missing = 0
    for i = 1, tile_count do
      local unit = tiles and tiles[i] or nil
      if unit and unit.get_position then
        positions[i] = unit.get_position()
      else
        missing = missing + 1
      end
    end

    self.tile_units = tiles
    self.tile_positions = positions

    local spacing = 0
    local spacing_count = 0
    for i = 1, tile_count - 1 do
      local a = positions[i]
      local b = positions[i + 1]
      if a and b and a.x and b.x then
        local dx = b.x - a.x
        local dy = (b.y or 0) - (a.y or 0)
        local dz = (b.z or 0) - (a.z or 0)
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist > 0 then
          spacing = spacing + dist
          spacing_count = spacing_count + 1
        end
      end
    end
    if spacing_count > 0 then
      self.tile_spacing = (spacing / spacing_count) * 0.28
    end

    log_once(self, "info", "tiles_ready", build_log_prefix(), "tile anchors ready:", tostring(tile_count))
    if missing > 0 then
      log_once(
        self,
        "warn",
        "tiles_missing",
        build_log_prefix(),
        "tile anchors missing:",
        tostring(missing)
      )
    end
  end

  if not self.player_units or self.player_units_missing then
    local roles = GameAPI.get_all_valid_roles() or {}
    local name_to_unit = {}
    local role_units = {}
    for i, role in ipairs(roles) do
      local unit = role and role.get_ctrl_unit and role.get_ctrl_unit() or nil
      role_units[i] = unit
      if role and role.get_name then
        local name = role.get_name()
        if name then
          name_to_unit[name] = unit
        end
      end
    end

    local mapped = {}
    local mapped_count = 0
    local missing = {}
    for i, player in ipairs(players) do
      if player then
        local pid = player.id or i
        local unit = nil
        if player.name then
          unit = name_to_unit[player.name]
        end
        if not unit then
          unit = role_units[pid] or role_units[i]
        end
        if unit then
          mapped[pid] = unit
          mapped_count = mapped_count + 1
        else
          missing[#missing + 1] = player.name or tostring(pid)
        end
      end
    end

    self.player_units = mapped
    self.player_units_missing = #missing > 0
    log_once(
      self,
      "info",
      "player_units_ready",
      build_log_prefix(),
      "player->unit mapped:",
      tostring(mapped_count),
      "(missing:",
      tostring(#missing) .. ")"
    )
    if #missing > 0 then
      log_once(
        self,
        "warn",
        "player_units_missing",
        build_log_prefix(),
        "player unit missing:",
        table.concat(missing, ", ")
      )
    end
  end

  local occupants = {}
  for i, player in ipairs(players) do
    if player and not player.eliminated and player.position then
      local idx = player.position
      if self.tile_positions and self.tile_positions[idx] then
        local pid = player.id or i
        local list = occupants[idx]
        if not list then
          list = {}
          occupants[idx] = list
        end
        list[#list + 1] = pid
      end
    end
  end

  local spacing = self.tile_spacing or 0
  for i, player in ipairs(players) do
    if player and not player.eliminated and player.position then
      local idx = player.position
      local base = self.tile_positions and self.tile_positions[idx] or nil
      local pid = player.id or i
      local unit = self.player_units and self.player_units[pid] or nil
      if base and unit and unit.set_position then
        local list = occupants[idx]
        local count = list and #list or 1
        local slot = 1
        if list and count > 1 then
          for s = 1, count do
            if list[s] == pid then
              slot = s
              break
            end
          end
        end
        if count > 1 and spacing > 0 then
          local per_row = math.ceil(math.sqrt(count))
          local row = math.floor((slot - 1) / per_row)
          local col = (slot - 1) % per_row
          local start = -(per_row - 1) * spacing * 0.5
          local ox = start + col * spacing
          local oz = start + row * spacing
          unit.set_position(base + math.Vector3(ox, 0, oz))
        else
          unit.set_position(base)
        end
      end
    end
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
  self.ui.popup_seq = (self.ui.popup_seq or 0) + 1
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
