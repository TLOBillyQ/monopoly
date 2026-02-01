require "Globals.__init"
require "Manager.__init"

local AutoRunner = require("Manager.TurnManager.GUI.AutoRunner")
local Game = require("Manager.GameManager.Game")
local GameplayLoop = require("Manager.TurnManager.GameplayLoop")
local MainView = require("Manager.TurnManager.GUI.MainView")
local UIEventRouter = require("Manager.TurnManager.GUI.UIEventRouter")
local map_cfg = require("Config.Map")
local logger = require("Components.Logger")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

logger.configure_game_time()

local current_game = nil

local function create_game()
  return Game:new({
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
    auto_runner = AutoRunner:new({ interval = ui.auto_interval }),
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

  local function normalize_payload(data)
    if type(data) ~= "table" then
      return data
    end
    if data.text ~= nil or data.popup ~= nil then
      return data
    end
    if data["1"] ~= nil then
      return data["1"]
    end
    return data
  end

  local function register_intent_listener(kind, fn)
    if not kind or not fn then
      return
    end
    if not RegisterCustomEvent then
      return
    end
    local intent = MONOPOLY_EVENT and MONOPOLY_EVENT.intent
    local event_name = (intent and intent[kind]) or kind
    if not event_name then
      return
    end
    RegisterCustomEvent(event_name, function(_, _, data)
      fn(normalize_payload(data))
    end)
  end

  state.push_popup = function(_, payload)
    return MainView.push_popup(state, payload)
  end
  state.on_tile_upgraded = function(_, tile_id, level)
    MainView.on_tile_upgraded(state, tile_id, level)
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    MainView.on_tile_owner_changed(state, tile_id, owner_id)
  end

  register_intent_listener("need_choice", function(payload)
    if payload and payload.game == current_game then
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
    require "Library.UIManager.Utils"
    UIManager.Builder:new(require "Data.UIManagerNodes")
    require "Globals.ECA"
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
    current_game = GameplayLoop.new_game(state)
    GameplayLoop.set_game(state, current_game)
    UIEventRouter.bind(state, function()
      return current_game
    end, {
      on_game_changed = function(new_game)
        current_game = new_game
      end,
    })

    local refs = G.refs
    local role = GameAPI.get_role(1)
    local unit = role.get_ctrl_unit()
    role.send_ui_custom_event("显示加载屏", {});
    
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
        local num = 3000 + i
        set_item_slot_image("道具槽位" .. tostring(i), refs[tostring(num)])
      end

      unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end
    UIManager.client_role = nil

    SetTimeOut(1.0, function()
      role.send_ui_custom_event("隐藏加载屏", {});
      role.send_ui_custom_event("显示基础屏", {});
    end)
  end)
end

local function start_tick_loop(state, interval)
  require "Library.Utils"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    GameplayLoop.tick(current_game, state, tick_seconds)
  end, -1)
end

local state = build_state()
install_game_init(state)
start_tick_loop(state)


