local AutoRunner = require("Manager.TurnManager.GUI.AutoRunner")
local IntentDispatcher = require("Library.Monopoly.IntentDispatcher")
local MainView = require("Manager.TurnManager.GUI.MainView")
local RuntimeLoop = require("Manager.System.RuntimeLoop")
local RuntimeUI = require("Manager.System.RuntimeUI")
local UIEventRouter = require("Manager.TurnManager.GUI.UIEventRouter")
local map_cfg = require("Config.Map")
local logger = require("Library.Monopoly.Logger")

local Runtime = {}

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

local function build_runtime(opts)
  opts = opts or {}
  local ui = opts.ui or MainView.build_ui_state()
  local runtime = {
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
    market_choice_option_ids = nil,
    pending_choice_selected_option_id = nil,
    _log_once = {},
  }

  runtime.push_popup = function(_, payload)
    return RuntimeUI.push_popup(runtime, payload)
  end
  runtime.on_tile_upgraded = function(_, tile_id, level)
    RuntimeUI.on_tile_upgraded(runtime, tile_id, level)
  end
  runtime.on_tile_owner_changed = function(_, tile_id, owner_id)
    RuntimeUI.on_tile_owner_changed(runtime, tile_id, owner_id)
  end

  local on_need_choice = opts.on_need_choice
  if not on_need_choice then
    on_need_choice = function(ctx, choice)
      RuntimeUI.open_choice_modal(ctx, choice)
    end
  end
  IntentDispatcher.on("need_choice", function(payload)
    if payload and payload.game == runtime.game then
      runtime.pending_choice = payload.choice
      runtime.pending_choice_elapsed = 0
      runtime.pending_choice_id = payload.choice.id
      on_need_choice(runtime, payload.choice)
    end
  end)
  logger.set_adapter({
    level = "event",
    on_log = function(entry)
      show_tips(entry.text, 2)
    end,
  })

  return runtime
end

function Runtime.install_game_init(runtime)
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
    RuntimeLoop.set_game(runtime, RuntimeLoop.new_game(runtime))
    UIEventRouter.bind(runtime)

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

function Runtime.start_tick_loop(runtime, interval)
  require "Utils.Frameout"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    RuntimeLoop.tick(runtime, tick_seconds)
  end, -1)
end

function Runtime.install(opts)
  local runtime = build_runtime(opts)
  Runtime.install_game_init(runtime)
  Runtime.start_tick_loop(runtime)
  return runtime
end

return Runtime
