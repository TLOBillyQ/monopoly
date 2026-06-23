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
projectHash=4e8f88e5c172bcc6
scope.0.id=chunk:src/app/ui_bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=99
scope.0.semanticHash=ce026573d7d460de
scope.0.lastMutatedAt=2026-06-23T03:21:55Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=12
scope.0.lastMutationKilled=12
scope.1.id=function:M.spawn_startup_synthetic_actors:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=26
scope.1.semanticHash=bbb35f727b18b2d0
scope.1.lastMutatedAt=2026-06-23T03:21:55Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=19
scope.1.lastMutationKilled=19
scope.2.id=function:_install_role_globals:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=30
scope.2.semanticHash=4f94b5c26af2b6fc
scope.2.lastMutatedAt=2026-06-23T03:21:55Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_build_ui_manager_nodes:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=37
scope.3.semanticHash=e4a440a58837a133
scope.3.lastMutatedAt=2026-06-23T03:21:55Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_resolve_current_game:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=46
scope.4.semanticHash=9911f550292ccc9b
scope.4.lastMutatedAt=2026-06-23T03:21:55Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=8
scope.4.lastMutationKilled=8
scope.5.id=function:anonymous@49:49
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=51
scope.5.semanticHash=c9f720fc309e2af6
scope.5.lastMutatedAt=2026-06-23T03:21:55Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=no_sites
scope.5.lastMutationSites=0
scope.5.lastMutationKilled=0
scope.6.id=function:_bind_current_game:48
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=52
scope.6.semanticHash=735d36fd53d4bbf6
scope.6.lastMutatedAt=2026-06-23T03:21:55Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:_sync_ui_event_roles:54
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=58
scope.7.semanticHash=824826a73243f355
scope.7.lastMutatedAt=2026-06-23T03:21:55Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:_assert_required_ui_nodes:60
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=64
scope.8.semanticHash=a56e920be96bc638
scope.8.lastMutatedAt=2026-06-23T03:21:55Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:_initialize_game_ui:66
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=73
scope.9.semanticHash=b94ec6ea4aae4230
scope.9.lastMutatedAt=2026-06-23T03:21:55Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=8
scope.9.lastMutationKilled=8
scope.10.id=function:anonymous@76:76
scope.10.kind=function
scope.10.startLine=76
scope.10.endLine=79
scope.10.semanticHash=61d4e3a9bb9ba4e8
scope.10.lastMutatedAt=2026-06-23T03:21:55Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=no_sites
scope.10.lastMutationSites=0
scope.10.lastMutationKilled=0
scope.11.id=function:_schedule_loading_transition:75
scope.11.kind=function
scope.11.startLine=75
scope.11.endLine=80
scope.11.semanticHash=959221f0c2cb6ad8
scope.11.lastMutatedAt=2026-06-23T03:21:55Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:anonymous@85:85
scope.12.kind=function
scope.12.startLine=85
scope.12.endLine=95
scope.12.semanticHash=38aceb4bb202ecfa
scope.12.lastMutatedAt=2026-06-23T03:21:55Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=no_sites
scope.12.lastMutationSites=0
scope.12.lastMutationKilled=0
scope.13.id=function:M.install:83
scope.13.kind=function
scope.13.startLine=83
scope.13.endLine=96
scope.13.semanticHash=b04be469865cfb12
scope.13.lastMutatedAt=2026-06-23T03:21:55Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=2
scope.13.lastMutationKilled=2
]]
