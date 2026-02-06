require "Config.RuntimeGlobals"

local runtime_mod = require("src.v2.infrastructure.EggyRuntime")
local match_service_mod = require("src.v2.application.MatchService")
local intent_mapper_mod = require("src.v2.presentation.IntentMapper")
local ui_bridge_mod = require("src.v2.presentation.UIBridge")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local gameplay_rules = require("Config.GameplayRules")
local constants = require("Config.Generated.Constants")
local logger = require("src.core.Logger")

local app = {}
app.__index = app

local function _board_adapter(map, tiles)
  local by_id = {}
  for _, tile in ipairs(tiles or {}) do
    by_id[tile.id] = tile
  end
  local index = {}
  for i, tile_id in ipairs(map.path or {}) do
    if index[tile_id] == nil then
      index[tile_id] = i
    end
  end
  return {
    path = map.path,
    get_tile_by_id = function(_, tile_id)
      return by_id[tile_id]
    end,
    index_of_tile_id = function(_, tile_id)
      return index[tile_id]
    end,
    length = function(_)
      return #map.path
    end,
  }
end

local function _build_players(runtime)
  local players = {}
  local roles = runtime:get_all_roles() or {}

  for _, role in ipairs(roles) do
    local role_id = runtime:get_role_id(role)
    if role_id ~= nil then
      players[#players + 1] = {
        name = runtime:get_role_name(role),
        role_id = role_id,
        is_ai = false,
        auto = false,
      }
    end
    if #players >= 4 then
      break
    end
  end

  while #players < 4 do
    local seat = #players + 1
    players[seat] = {
      name = "AI" .. tostring(seat),
      role_id = nil,
      is_ai = true,
      auto = true,
    }
  end

  return players
end

local function _build_rules()
  local reconnect = gameplay_rules.reconnect or {}
  return {
    action_timeout_seconds = constants.action_timeout_seconds or 15,
    reconnect = {
      freeze_on_disconnect = reconnect.freeze_on_disconnect ~= false,
      grace_seconds = reconnect.grace_seconds or 20,
      offline_auto_host_seconds = reconnect.offline_auto_host_seconds or 90,
      snapshot_interval_events = reconnect.snapshot_interval_events or 20,
      replay_max_events = reconnect.replay_max_events or 400,
    },
  }
end

function app.new()
  local instance = {
    runtime = runtime_mod.new(),
    intent_mapper = intent_mapper_mod.new(),
    ui_bridge = ui_bridge_mod.new({ map_cfg = map_cfg }),
    board_adapter = _board_adapter(map_cfg, tiles_cfg),
    match_service = nil,
    started = false,
  }
  setmetatable(instance, app)
  return instance
end

function app:_on_init()
  if self.started then
    return
  end
  self.started = true

  self.ui_bridge:initialize()
  self.ui_bridge:set_board_adapter(self.board_adapter)

  self.match_service = match_service_mod.new({
    runtime = self.runtime,
    map = map_cfg,
    tiles = tiles_cfg,
    players = _build_players(self.runtime),
    rules = _build_rules(),
    intent_mapper = self.intent_mapper,
    starting_cash = constants.starting_cash,
  })

  self.match_service:bootstrap_online(0)

  self.ui_bridge:bind_inputs(function(intent)
    self.match_service:handle_intent(intent, nil)
  end)

  self.ui_bridge:render(self.match_service:projection())

  self.runtime:start_tick(1, function(dt)
    self.match_service:tick(dt)
    self.ui_bridge:render(self.match_service:projection())
  end)
end

function app:start()
  logger.configure_game_time()
  self.runtime:register_game_init(function()
    self:_on_init()
  end)
end

return app
