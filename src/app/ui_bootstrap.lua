local board_scene = require("src.ui.render.board.scene")
local ui_view = require("src.ui.coord.ui_runtime")
local canvas_event_router = require("src.ui.coord.canvas_event_router")
local canvas_coordinator = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local permanent_nodes = require("src.ui.schema.permanent")
local base_contract = require("src.ui.schema.base_contract")
local player_choice_nodes = require("src.ui.schema.player_choice")
local target_choice_nodes = require("src.ui.schema.target_choice")
local remote_choice_nodes = require("src.ui.schema.remote_choice")
local secondary_confirm_nodes = require("src.ui.schema.secondary_confirm")
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

local function _required_click_nodes()
  local required = {
    base_nodes.action_button,
    base_nodes.auto_button,
    target_choice_nodes.confirm,
    target_choice_nodes.cancel,
    secondary_confirm_nodes.confirm,
    secondary_confirm_nodes.cancel,
  }
  return required
end

local function _append_click_nodes(required, names)
  for _, name in ipairs(names or {}) do
    required[#required + 1] = name
  end
end

local function _build_required_click_nodes(opts)
  local required = _required_click_nodes()
  for _, name in ipairs(player_choice_nodes.slots) do
    required[#required + 1] = name
  end
  for _, name in ipairs(remote_choice_nodes.options) do
    required[#required + 1] = name
  end
  _append_click_nodes(required, permanent_nodes.card_outlines)
  _append_click_nodes(required, base_contract.action_log.toggle_targets)

  local extra = opts and opts.extra or nil
  _append_click_nodes(required, type(extra) == "table" and extra or nil)
  return required
end

local function _validate_required_nodes(ui_manager_nodes, required_nodes)
  if type(ui_manager_nodes.validate) == "function" then
    return ui_manager_nodes.validate(required_nodes)
  end

  local known = {}
  for _, entry in pairs(ui_manager_nodes) do
    if type(entry) == "table" and type(entry[1]) == "string" and entry[1] ~= "" then
      known[entry[1]] = true
    end
  end

  local missing = {}
  local seen = {}
  for _, name in ipairs(required_nodes or {}) do
    if type(name) == "string" and name ~= "" and not known[name] and not seen[name] then
      missing[#missing + 1] = name
      seen[name] = true
    end
  end
  return missing
end

-- current_game_ref 是一个单元素数组 { nil }，供 set/get 当前 game 使用
function M.install(state, current_game_ref, opts)
  opts = opts or {}
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    -- UIManager modules cache role globals during require.
    role_globals.install(runtime_ports.resolve_roles())
    require "vendor.third_party.UIManager.Utils"
    local ui_manager_nodes = require("Data.UIManagerNodes")
    UIManager.Builder:new(ui_manager_nodes)
    local current_game = current_game_ref[1]
    if not current_game and type(opts.start_runtime) == "function" then
      current_game = opts.start_runtime(state, current_game_ref)
    end
    assert(current_game ~= nil, "missing current_game")

    canvas_event_router.bind(state, function()
      return current_game_ref[1]
    end)

    if ui_events.set_roles then
      ui_events.set_roles(runtime_ports.resolve_roles())
    end

    local required_nodes = _build_required_click_nodes({
      extra = market_ui.item_buttons or {},
    })
    local missing = _validate_required_nodes(ui_manager_nodes, required_nodes)
    if #missing > 0 then
      error("UI 节点缺失: " .. table.concat(missing, ", "))
    end

    ui_events.send_to_all(ui_events.show["加载屏"], {})
    local board_map = current_game and current_game.board and current_game.board.map or nil
    M.spawn_startup_synthetic_actors(current_game)
    board_scene.init(state, board_map, current_game)
    ui_view.init_ui_assets(state)
    ui_view.capture_player_colors(state, current_game)

    runtime_ports.schedule(timing.loading_to_game_transition_seconds, function()
      ui_events.send_to_all(ui_events.hide["加载屏"], {})
      canvas_coordinator.switch(state.ui, base_nodes.canvas)
    end)
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
