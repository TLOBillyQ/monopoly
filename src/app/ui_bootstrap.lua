local board_scene = require("src.ui.render.board.scene")
local ui_view = require("src.ui.coord.ui_runtime")
local canvas_event_router = require("src.ui.coord.canvas_event_router")
local canvas_coordinator = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local bootstrap_nodes = require("src.app.ui_bootstrap_nodes")
local market_ui = require("src.ui.schema.market_layout")
local ui_events = require("src.ui.coord.ui_events")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_globals = require("src.state.ui_role_globals")
local runtime_context = require("src.host.context")

local M = {}

function M.spawn_startup_synthetic_actors(current_game)
  local runtime_ctx = runtime_context.current()
  local registry = runtime_ctx and runtime_ctx.synthetic_actor_registry or nil
  if not (registry and type(registry.register_specs) == "function" and type(registry.spawn_pending) == "function") then
    return
  end
  local specs = current_game and current_game.startup_synthetic_players or nil
  registry.register_specs(specs)
  local map_cfg = current_game and current_game.board and current_game.board.map or nil
  registry.spawn_pending(map_cfg)
end

local function _install_role_globals()
  role_globals.install(runtime_ports.resolve_roles())
end

local function _build_ui_manager_nodes()
  require "vendor.third_party.UIManager.Utils"
  local ui_manager_nodes = require("Data.UIManagerNodes")
  UIManager.Builder:new(ui_manager_nodes)
  return ui_manager_nodes
end

local function _resolve_current_game(state, current_game_ref, opts)
  local current_game = current_game_ref[1]
  if not current_game and type(opts.start_runtime) == "function" then
    current_game = opts.start_runtime(state, current_game_ref)
  end
  assert(current_game ~= nil, "missing current_game")
  return current_game
end

local function _bind_current_game(state, current_game_ref)
  canvas_event_router.bind(state, function()
    return current_game_ref[1]
  end)
end

local function _sync_ui_event_roles()
  if ui_events.set_roles then
    ui_events.set_roles(runtime_ports.resolve_roles())
  end
end

local function _assert_required_ui_nodes(ui_manager_nodes)
  bootstrap_nodes.assert_required_nodes(ui_manager_nodes, {
    extra = market_ui.item_buttons or {},
  })
end

local function _initialize_game_ui(state, current_game)
  ui_events.send_to_all(ui_events.show["加载屏"], {})
  local board_map = current_game and current_game.board and current_game.board.map or nil
  M.spawn_startup_synthetic_actors(current_game)
  board_scene.init(state, board_map, current_game)
  ui_view.init_ui_assets(state)
  ui_view.capture_player_colors(state, current_game)
end

local function _schedule_loading_transition(state)
  runtime_ports.schedule(timing.loading_to_game_transition_seconds, function()
    ui_events.send_to_all(ui_events.hide["加载屏"], {})
    canvas_coordinator.switch(state.ui, base_nodes.canvas)
  end)
end

-- current_game_ref 是一个单元素数组 { nil }，供 set/get 当前 game 使用
function M.install(state, current_game_ref, opts)
  opts = opts or {}
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    -- UIManager modules cache role globals during require.
    _install_role_globals()
    local ui_manager_nodes = _build_ui_manager_nodes()
    local current_game = _resolve_current_game(state, current_game_ref, opts)
    _bind_current_game(state, current_game_ref)
    _sync_ui_event_roles()
    _assert_required_ui_nodes(ui_manager_nodes)
    _initialize_game_ui(state, current_game)
    _schedule_loading_transition(state)
  end)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=7b1a4c3918d31cdb
scope.0.id=chunk:src/app/ui_bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=136
scope.0.semanticHash=3b5340d935f6afb1
scope.1.id=function:M.spawn_startup_synthetic_actors:21
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=31
scope.1.semanticHash=bbb35f727b18b2d0
scope.2.id=function:_required_click_nodes:33
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=43
scope.2.semanticHash=a8eae88f4a6c66c5
scope.3.id=function:anonymous@105:105
scope.3.kind=function
scope.3.startLine=105
scope.3.endLine=107
scope.3.semanticHash=c9f720fc309e2af6
scope.4.id=function:anonymous@128:128
scope.4.kind=function
scope.4.startLine=128
scope.4.endLine=131
scope.4.semanticHash=61d4e3a9bb9ba4e8
scope.5.id=function:anonymous@93:93
scope.5.kind=function
scope.5.startLine=93
scope.5.endLine=132
scope.5.semanticHash=04f9a3eb6be29f02
scope.6.id=function:M.install:91
scope.6.kind=function
scope.6.startLine=91
scope.6.endLine=133
scope.6.semanticHash=55cbe9155811b50e
]]
