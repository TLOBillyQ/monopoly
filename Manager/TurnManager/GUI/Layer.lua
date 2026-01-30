local logger = require("Library.Monopoly.Logger")
local AutoRunner = require("Manager.TurnManager.GUI.AutoRunner")
local Presenter = require("Manager.TurnManager.GUI.Presenter")
local MainView = require("Manager.TurnManager.GUI.MainView")
local MainController = require("Manager.TurnManager.GUI.MainController")
local Agent = require("Manager.GameManager.Agent")
local constants = require("Config.Constants")
local items_cfg = require("Config.Items")
local map_cfg = require("Config.Map")
local IntentDispatcher = require("Library.Monopoly.IntentDispatcher")
local EventHandlers = require("Manager.System.EventHandlers")

---@class EggyLayer
---蛋仔编辑器的游戏适配层，处理UI和动画同步
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
  local tip_duration = duration
  if type(duration) == "number" and math and math.tofixed then
    tip_duration = math.tofixed(duration)
  end
  if GlobalAPI and GlobalAPI.show_tips then
    GlobalAPI.show_tips(text, tip_duration)
    return true
  end
  local role = Role
  if role and role.show_tips then
    role.show_tips(text, tip_duration)
    return true
  end
  return false
end

function EggyLayer.new(opts)
  opts = opts or {}
  local ui = opts.ui or MainView.build_ui_state()
  local self = setmetatable({
    ui = ui,
    game = nil,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    wait_move_anim = true,
    move_anim_seq = nil,
    wait_action_anim = true,
    action_anim_seq = nil,
    item_name_by_id = {},
    game_factory = opts.game_factory,
    auto_runner = opts.auto_runner or AutoRunner.new({ interval = ui.auto_interval }),
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    board_last_positions = nil,
    board_sync_pending = false,
    board_last_phase = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
    camera_follow_player_id = nil,
    _log_once = {},
  }, EggyLayer)

  local on_need_choice = opts.on_need_choice
  if not on_need_choice then
    on_need_choice = function(layer, choice)
      layer:_open_choice_modal(choice)
    end
  end
  IntentDispatcher.on("need_choice", function(payload)
    if payload and payload.game == self.game then
      self.pending_choice = payload.choice
      self.pending_choice_elapsed = 0
      self.pending_choice_id = payload.choice.id
      on_need_choice(self, payload.choice)
    end
  end)
  logger.set_adapter({
    level = "event",
    on_log = function(entry)
      show_tips(entry.text, 2)
    end,
  })

  return self
end

---设置当前游戏实例
---@param self EggyLayer
---@param g Game 游戏对象
function EggyLayer:set_game(g)
  self.game = g
  if self.game then
    self.game.ui_port = self
    EventHandlers.install(self.game, logger, self)
  end
  local pending = nil
  if self.game and self.game.pending_choice then
    pending = self.game:pending_choice()
  end
  self.pending_choice = pending
  if pending then
    self.pending_choice_elapsed = 0
    self.pending_choice_id = pending.id
    self:_open_choice_modal(pending)
  end
  self.player_units = nil
  self.player_units_missing = false
end

---构建物品索引（用于UI查询）
---@param self EggyLayer
function EggyLayer:build_item_index()
  self.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    self.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

---创建新游戏
---@param self EggyLayer
---@return Game? 新游戏实例
function EggyLayer:new_game()
  logger.clear()
  assert(self.game_factory, "game_factory not set")
  local g = self.game_factory()
  self:build_item_index()
  if self.auto_runner and self.auto_runner.reset_timer then
    self.auto_runner:reset_timer()
  end
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)

  return g
end

function EggyLayer:clear_choice(opts)
  self.pending_choice = nil
  self.pending_choice_elapsed = 0
  self.pending_choice_id = nil
  if opts and opts.on_close_choice then
    opts.on_close_choice(self)
  end
end

function EggyLayer:step_auto_runner(dt, context)
  if not (self.game and self.auto_runner) then
    return nil
  end
  local ctx = context or {}
  if ctx.game_finished == nil then
    ctx.game_finished = self.game and self.game.finished
  end
  local auto_action = self.auto_runner:next_action(dt, ctx)
  if auto_action then
    self:dispatch_action(auto_action)
  end
  return auto_action
end

function EggyLayer:step_choice_timeout(dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    self.pending_choice_elapsed = 0
    self.pending_choice_id = nil
    return
  end

  if self.game and self.game.store then
    local pending = self.game.store:get({ "turn", "pending_choice" })
    if pending and (not self.pending_choice or self.pending_choice.id ~= pending.id) then
      self.pending_choice = pending
      self.pending_choice_elapsed = 0
      self.pending_choice_id = pending.id
      if opts and opts.on_pending_choice then
        opts.on_pending_choice(self, pending)
      end
    elseif not pending then
      self.pending_choice = nil
      self.pending_choice_elapsed = 0
      self.pending_choice_id = nil
    end
  end

  local active = false
  if opts and opts.is_choice_active then
    active = opts.is_choice_active(self)
  else
    active = self.pending_choice ~= nil
  end

  if not (active and self.pending_choice) then
    self.pending_choice_elapsed = 0
    self.pending_choice_id = nil
    return
  end

  if self.pending_choice_id ~= self.pending_choice.id then
    self.pending_choice_elapsed = 0
    self.pending_choice_id = self.pending_choice.id
  end

  self.pending_choice_elapsed = self.pending_choice_elapsed + dt
  if self.pending_choice_elapsed >= timeout then
    local choice = self.pending_choice
    self.pending_choice_elapsed = 0
    local action
    if opts and opts.build_action then
      action = opts.build_action(self, choice)
    else
      local first = choice.options and choice.options[1]
      if first then
        action = { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
      elseif choice.allow_cancel ~= false then
        action = { type = "choice_cancel", choice_id = choice.id }
      end
    end
    if action then
      self:dispatch_action(action)
    end
  end
end

function EggyLayer:step_modal_timeout(dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    self.ui_modal_elapsed = 0
    self.ui_modal_ref = nil
    return
  end
  if not (opts and opts.is_active and opts.on_timeout) then
    return
  end
  if not opts.is_active(self) then
    self.ui_modal_elapsed = 0
    self.ui_modal_ref = nil
    return
  end
  local ref = opts.get_ref and opts.get_ref(self) or true
  if self.ui_modal_ref ~= ref then
    self.ui_modal_ref = ref
    self.ui_modal_elapsed = 0
  end
  self.ui_modal_elapsed = self.ui_modal_elapsed + (dt or 0)
  if self.ui_modal_elapsed >= timeout then
    self.ui_modal_elapsed = 0
    opts.on_timeout(self)
  end
end

function EggyLayer:step_move_anim(opts)
  if not (self.wait_move_anim and self.game and self.game.store) then
    return
  end

  local anim = self.game.store:get({ "turn", "move_anim" })
  local phase = self.game.store:get({ "turn", "phase" })
  if not anim or not anim.seq then
    self.move_anim_seq = nil
    return
  end

  if phase ~= "wait_move_anim" then
    self.move_anim_seq = nil
    return
  end

  if self.move_anim_seq == anim.seq then
    return
  end

  self.move_anim_seq = anim.seq
  if opts and opts.on_move_anim then
    local ok, delay = pcall(opts.on_move_anim, self, anim)
    if ok and delay and delay > 0 then
      LuaAPI.call_delay_time(delay, function()
        if self.game and self.game.dispatch_action then
          self.game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
        end
      end)
      return
    end
  end
  if self.game and self.game.dispatch_action then
    self.game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
  end
end

function EggyLayer:step_action_anim(opts)
  if not (self.wait_action_anim and self.game and self.game.store) then
    return
  end

  local anim = self.game.store:get({ "turn", "action_anim" })
  local phase = self.game.store:get({ "turn", "phase" })
  if not anim or not anim.seq then
    self.action_anim_seq = nil
    return
  end

  if phase ~= "wait_action_anim" then
    self.action_anim_seq = nil
    return
  end

  if self.action_anim_seq == anim.seq then
    return
  end

  self.action_anim_seq = anim.seq
  if opts and opts.on_action_anim then
    local ok, delay = pcall(opts.on_action_anim, self, anim)
    if ok and delay and delay > 0 then
      LuaAPI.call_delay_time(delay, function()
        if self.game and self.game.dispatch_action then
          self.game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
        end
      end)
      return
    end
  end
  if self.game and self.game.dispatch_action then
    self.game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
  end
end

function EggyLayer:install_game_init()
  LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
    require "UIManager.Utils"
    UIManager.Builder(require "Data.UIManagerNodes")
    require "Globals.ECA"
    UIManager.forward_eca_event(ECA_EVENT.UI.open_loading_screen)
    G = {
      tiles = {},
      buildings = {},
      refs = require "Globals.Refs",
      lvs = {},
      role = {
        GameAPI.get_role(1),
        GameAPI.get_role(2),
        GameAPI.get_role(3),
        GameAPI.get_role(4),
      },
      unit = {
        GameAPI.get_role(1).get_ctrl_unit(),
        GameAPI.get_role(2).get_ctrl_unit(),
        GameAPI.get_role(3).get_ctrl_unit(),
        GameAPI.get_role(4).get_ctrl_unit(),
      },
    }
    self:set_game(self:new_game())
    MainController.bind(self)

    local refs = G.refs
    local role = GameAPI.get_role(1)
    local unit = role.get_ctrl_unit()

    local tile_names = {}
    local building_names = {}
    local tile_ids = map_cfg.path or {}
    if #tile_ids == 0 then
      for i = 1, 45 do
        tile_ids[i] = i
      end
    end
    for i, tile_id in ipairs(tile_ids) do
      tile_names[i] = "t" .. tostring(tile_id)
      building_names[i] = "b" .. tostring(tile_id)
    end
    G.tiles = LuaAPI.query_units(tile_names)
    G.buildings = LuaAPI.query_units(building_names)

    G.ground = LuaAPI.query_unit("ground")
    G.ground.set_model_visible(false)

    local function set_item_slot_image(slot_name, image_key)
      if not (slot_name and image_key) then
        return
      end
      local nodes = UIManager.query_nodes_by_name(slot_name) or {}
      for _, node in ipairs(nodes) do
        if node and node.image_texture ~= nil then
          node.image_texture = image_key
        end
      end
    end

    for _, r in ipairs(GameAPI.get_all_valid_roles()) do
      UIManager.client_role = r
      for i = 1, 5 do
        set_item_slot_image("item_slot_" .. tostring(i), refs["空"])
      end

      unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end
    UIManager.client_role = nil

    LuaAPI.call_delay_time(0.1, function()
      UIManager.forward_eca_event(ECA_EVENT.UI.close_loading_screen)
      UIManager.forward_eca_event(ECA_EVENT.UI.open_base_screen)
    end)
  end)
end

function EggyLayer:start_tick_loop(interval)
  require "Utils.Frameout"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    self:tick(tick_seconds)
  end, -1)
end

---打印玩家状态日志
---@param self EggyLayer
---@param view table 呈现视图
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

---每帧更新（处理UI、动画和自动运行）
---@param self EggyLayer
---@param dt number 增量时间（秒）
function EggyLayer:tick(dt)
  if not self.game then
    return
  end

  self:step_auto_runner(dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = self.game and self.game.finished,
  })

  self:step_choice_timeout(dt, {
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

  self:step_modal_timeout(dt, {
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

  self:step_move_anim({
    on_move_anim = function(_, anim)
      if not anim then
        return nil
      end
      local player_id = anim.player_id
      local from_index = anim.from_index
      local to_index = anim.to_index
      if not (player_id and from_index and to_index) then
        return nil
      end
      local dir = anim.direction
      if not dir and anim.steps then
        if anim.steps < 0 then
          dir = V3_RIGHT
        elseif anim.steps > 0 then
          dir = V3_LEFT
        end
      end
      local MoveAnim = require("Manager.BoardManager.GUI.MoveAnim")
      return MoveAnim.one_step(player_id, dir, from_index, to_index)
    end,
  })

  self:step_action_anim({
    on_action_anim = function(layer, anim)
      local ActionAnim = require("Manager.BoardManager.GUI.ActionAnim")
      return ActionAnim.play(layer, anim)
    end,
  })

  local store = self.game and self.game.store
  if store and store.get then
    local phase = store:get({ "turn", "phase" })
    if self.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
      self.board_sync_pending = true
    end
    if self.next_turn_locked and self.next_turn_lock_phase and phase and phase ~= self.next_turn_lock_phase then
      self.next_turn_locked = false
      self.next_turn_lock_phase = phase
    end
    self.board_last_phase = phase
  end

  if self.pending_choice then
    self:_open_choice_modal(self.pending_choice)
  end

  self:refresh_view()

  self:_log_status(self:build_view())
end

---选择市场选项
---@param self EggyLayer
---@param option_id string|number 选项ID
function EggyLayer:select_market_option(option_id)
  MainView.select_market_option(self, option_id)
end

---打开市场面板
---@param self EggyLayer
---@param pending table? 待选项
---@return boolean? 打开是否成功
function EggyLayer:_open_market_panel(pending)
  return MainView.open_market_panel(self, pending)
end

---关闭市场面板
---@param self EggyLayer
function EggyLayer:_close_market_panel()
  MainView.close_market_panel(self)
end

---打开选择项对话框
---@param self EggyLayer
---@param pending table? 待选项
function EggyLayer:_open_choice_modal(pending)
  MainView.open_choice_modal(self, pending)
end

---关闭选择项对话框
---@param self EggyLayer
function EggyLayer:_close_choice_modal()
  MainView.close_choice_modal(self)
end

---构建UI呈现视图
---@param self EggyLayer
---@return table UI视图表
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

---刷新UI视图（同步面板和棋盘）
---@param self EggyLayer
function EggyLayer:refresh_view()
  local view = self:build_view()
  self:refresh_panel(view)
  self:refresh_board(view)

  local players = view and view.state and view.state.players or nil
  local turn = view and view.state and view.state.turn or nil
  local current_index = turn and turn.current_player_index or nil
  if players and current_index then
    local current = players[current_index]
    local current_id = current and (current.id or current_index) or nil
    if current_id then
      if self.camera_follow_player_id ~= current_id then
        self.camera_follow_player_id = current_id
        local role = GameAPI.get_role(current_id);
        role.set_camera_bind_mode(Enums.CameraBindMode.TRACK)
      end

      local target_pos = nil
      local unit = self.player_units and self.player_units[current_id] or nil
      if unit and unit.get_position then
        target_pos = unit.get_position()
      else
        local pos_idx = current and current.position or nil
        if pos_idx and self.tile_positions then
          target_pos = self.tile_positions[pos_idx]
        end
      end

      if target_pos and role and role.set_camera_lock_position then
        role.set_camera_lock_position(target_pos)
      end
    end
  end
end

---刷新面板UI
---@param self EggyLayer
---@param view table UI视图
function EggyLayer:refresh_panel(view)
  MainView.refresh_panel(self, view)
end

---刷新物品栏
---@param self EggyLayer
---@param view table UI视图
function EggyLayer:refresh_item_slots(view)
  MainView.refresh_item_slots(self, view)
end

---刷新棋盘UI（地块所有者、等级等）
---@param self EggyLayer
---@param view table UI视图
function EggyLayer:refresh_board(view)
  MainView.refresh_board(self, view, log_once, build_log_prefix)
end

function EggyLayer:on_tile_upgraded(tile_id, level)
  MainView.on_tile_upgraded(self, tile_id, level)
end

---处理地块所有者变化
---@param self EggyLayer
---@param tile_id string|number 地块ID
---@param owner_id number? 新所有者ID
function EggyLayer:on_tile_owner_changed(tile_id, owner_id)
  MainView.on_tile_owner_changed(self, tile_id, owner_id)
end

---推进游戏回合
---@param self EggyLayer
function EggyLayer:step_turn()
  if not self.game or self.game.finished then
    return
  end
  print("[debug] step_turn: advance_turn")
  self.game:advance_turn()
end

---分发UI行动到游戏
---@param self EggyLayer
---@param action table 行动对象
function EggyLayer:dispatch_action(action)
  MainController.dispatch_action(self, action)
end

function EggyLayer:push_popup(payload)
  return MainView.push_popup(self, payload)
end

function EggyLayer:close_popup()
  MainView.close_popup(self)
end

function EggyLayer:tick_once(dt)
  self:tick(dt)
end

return EggyLayer

