local EggyLayer = require("Manager.TurnManager.GUI.Layer")
local MainController = require("Manager.TurnManager.GUI.MainController")
local Game = require("Manager.GameManager.Game")
local logger = require("Library.Monopoly.Logger")
local map_cfg = require("Config.Map")

require "Utils.Frameout"
require "Globals.Macro"

local EggyRuntime = {}

local function pad2(value)
  if value < 10 then
    return "0" .. tostring(value)
  end
  return tostring(value)
end

local function format_timestamp(timestamp)
  if timestamp == nil then
    return "0"
  end
  local year = GameAPI.get_year(timestamp)
  local month = GameAPI.get_month(timestamp)
  local day = GameAPI.get_day(timestamp)
  local hour = GameAPI.get_hour(timestamp)
  local minute = GameAPI.get_minute(timestamp)
  local second = GameAPI.get_second(timestamp)
  return tostring(year) .. "-" .. pad2(month) .. "-" .. pad2(day)
    .. " " .. pad2(hour) .. ":" .. pad2(minute) .. ":" .. pad2(second)
end

local function create_game()
  return Game.new({
    players = { "玩家1", "AI2", "AI3", "AI4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    seed = GameAPI.get_timestamp(),
  })
end


function EggyRuntime.install()
  logger.set_timestamp_provider(function()
    return GameAPI.get_timestamp()
  end)
  logger.set_time_formatter(format_timestamp)

  local layer = EggyLayer.new({ game_factory = create_game })

  LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
    require "UIManager.Utils"
    UIManager.Builder(require "Data.UIManagerNodes")
    require "Manager.System.ECA"
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
    layer:set_game(layer:new_game())
    MainController.bind(layer)

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

  local tick_interval = 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    layer:tick(tick_seconds)
  end, -1)

  return layer
end

return EggyRuntime

