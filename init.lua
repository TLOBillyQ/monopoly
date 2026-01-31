require "Globals.__init"
require "Manager.__init"

local AutoRunner = require("Manager.TurnManager.GUI.AutoRunner")
local Game = require("Manager.GameManager.Game")
local GameplayLoop = require("Manager.GameManager.GameplayLoop")
local IntentDispatcher = require("Library.Monopoly.IntentDispatcher")
local MainView = require("Manager.TurnManager.GUI.MainView")
local UIEventRouter = require("Manager.TurnManager.GUI.UIEventRouter")
local map_cfg = require("Config.Map")
local logger = require("Library.Monopoly.Logger")

logger.configure_game_time()

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    seed = GameAPI.get_timestamp(),
  })
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

local function build_state()
  local ui = MainView.build_ui_state()
  local state = {
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
    game_factory = create_game,
    auto_runner = AutoRunner.new({ interval = ui.auto_interval }),
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
    market_choice_option_ids = nil,
    pending_choice_selected_option_id = nil,
    _log_once = {},
  }

  state.push_popup = function(_, payload)
    return MainView.push_popup(state, payload)
  end
  state.on_tile_upgraded = function(_, tile_id, level)
    MainView.on_tile_upgraded(state, tile_id, level)
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    MainView.on_tile_owner_changed(state, tile_id, owner_id)
  end

  IntentDispatcher.on("need_choice", function(payload)
    if payload and payload.game == state.game then
      state.pending_choice = payload.choice
      state.pending_choice_elapsed = 0
      state.pending_choice_id = payload.choice.id
      MainView.open_choice_modal(state, payload.choice)
    end
  end)
  logger.set_adapter({
    level = "event",
    on_log = function(entry)
      show_tips(entry.text, 2)
    end,
  })

  return state
end

local function install_game_init(state)
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
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
    GameplayLoop.set_game(state, GameplayLoop.new_game(state))
    UIEventRouter.bind(state)

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

    for _, r in ipairs(ALLROLES) do
      UIManager.client_role = r
      for i = 1, 5 do
        set_item_slot_image("item_slot_" .. tostring(i), refs["空"])
      end

      unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end
    UIManager.client_role = nil

    SetTimeOut(0.1, function()
      UIManager.forward_eca_event(ECA_EVENT.UI.close_loading_screen)
      UIManager.forward_eca_event(ECA_EVENT.UI.open_base_screen)
    end)
  end)
end

local function start_tick_loop(state, interval)
  require "Utils.Frameout"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    GameplayLoop.tick(state, tick_seconds)
  end, -1)
end

local state = build_state()
install_game_init(state)
start_tick_loop(state)
