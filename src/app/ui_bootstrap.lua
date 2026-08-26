local board_scene = require("src.ui.render.board.scene")
local ui_view = require("src.ui.coord.ui_runtime")
local canvas_event_router = require("src.ui.coord.canvas_event_router")
local canvas_coordinator = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local bootstrap_nodes = require("src.app.ui_bootstrap_nodes")
local market_ui = require("src.ui.schema.market_layout")
local item_atlas_view = require("src.ui.render.widgets.item_atlas")
local ui_events = require("src.ui.coord.ui_events")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_globals = require("src.state.ui_role_globals")
local runtime_context = require("src.host.context")
local like_collect_subscribe = require("src.host.like_collect_subscribe")

local M = {}

local function _synthetic_registry()
  local runtime_ctx = runtime_context.current()
  return runtime_ctx and runtime_ctx.synthetic_actor_registry or nil
end

local function _registry_ready(registry)
  return registry ~= nil and type(registry.register_specs) == "function" and type(registry.spawn_pending) == "function"
end

local function _startup_specs(current_game)
  return current_game and current_game.startup_synthetic_players or nil
end

local function _board_map(current_game)
  return current_game and current_game.board and current_game.board.map or nil
end

function M.spawn_startup_synthetic_actors(current_game)
  local registry = _synthetic_registry()
  if not _registry_ready(registry) then
    return
  end
  registry.register_specs(_startup_specs(current_game))
  registry.spawn_pending(_board_map(current_game))
end

local function _install_role_globals()
  role_globals.install(runtime_ports.resolve_roles())
end

local function _node_label(id, entry)
  local name = type(entry) == "table" and entry[1] or nil
  if type(name) == "string" and name ~= "" then
    return name .. "(" .. tostring(id) .. ")"
  end
  return tostring(id)
end

-- Records every child of `id` that is not itself a configured node. `seen` keeps
-- each missing child reported once across the whole sweep.
local function _missing_child(child_id, ui_manager_nodes, seen)
  return child_id ~= nil and ui_manager_nodes[child_id] == nil and not seen[child_id]
end

local function _assert_children_read(ok, children, id, entry)
  if not ok then
    error("UI 节点子节点读取失败: " .. _node_label(id, entry) .. ": " .. tostring(children))
  end
end

local function _collect_missing_children(ui_manager_nodes, id, entry, missing, seen)
  local ok, children = pcall(GameAPI.get_eui_children, id)
  _assert_children_read(ok, children, id, entry)
  if type(children) ~= "table" then
    return
  end
  for _, child_id in ipairs(children) do
    if _missing_child(child_id, ui_manager_nodes, seen) then
      missing[#missing + 1] = _node_label(id, entry) .. " -> " .. tostring(child_id)
      seen[child_id] = true
    end
  end
end

-- 宿主未装载 GameAPI 或未提供子节点查询时,校验整体跳过(返回空)。
local function _has_children_lookup()
  return GameAPI and type(GameAPI.get_eui_children) == "function"
end

local function _validate_configured_child_nodes(ui_manager_nodes)
  if not _has_children_lookup() then
    return {}
  end

  local missing = {}
  local seen = {}
  for id, entry in pairs(ui_manager_nodes or {}) do
    if type(entry) == "table" then
      _collect_missing_children(ui_manager_nodes, id, entry, missing, seen)
    end
  end
  return missing
end

local function _build_ui_manager_nodes()
  require("src.ui.manager.utils")
  local ui_manager_nodes = require("Data.UIManagerNodes")
  local missing_child_nodes = _validate_configured_child_nodes(ui_manager_nodes)
  if #missing_child_nodes > 0 then
    error("UI 节点配置缺失: " .. table.concat(missing_child_nodes, ", "))
  end
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
  -- 放大卡覆盖层编辑器默认可见性不可靠,开局统一压灭,展示时再按 role 点亮
  -- （#544:覆盖层住图鉴 canvas,显隐走 per-role 路径,只推浏览者客户端）。
  item_atlas_view.hide_enlarged(state)
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
    -- #466:点赞/收藏/订阅事件链路开局接线——setup 幂等注册三个 UI 自定义事件
    -- 监听并调度进图 0.1s 订阅检测。真机无需编辑器侧开局触发器,参考伪人检查站
    -- 守卫蛋仔岛 Person.lua 的开局直注册模式。
    like_collect_subscribe.setup(current_game)
    _schedule_loading_transition(state)
  end)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=5f4d37747f41f374
scope.0.id=chunk:src/app/ui_bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=180
scope.0.semanticHash=f7d6f564213697c6
scope.1.id=function:_synthetic_registry
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=21
scope.1.semanticHash=9a1ad770e91fcd33
scope.2.id=function:_registry_ready
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=522abfbe127d6663
scope.3.id=function:_startup_specs
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=29
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_board_map
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=33
scope.4.semanticHash=c250138038aa193a
scope.5.id=function:M.spawn_startup_synthetic_actors
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=42
scope.5.semanticHash=2745176cbebf4dcf
scope.6.id=function:_install_role_globals
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=46
scope.6.semanticHash=fb4e3bd40ff22274
scope.7.id=function:_node_label
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=54
scope.7.semanticHash=e2149746f0a629bd
scope.8.id=function:_missing_child
scope.8.kind=function
scope.8.startLine=58
scope.8.endLine=60
scope.8.semanticHash=3a45f1253cb5bc1c
scope.9.id=function:_assert_children_read
scope.9.kind=function
scope.9.startLine=62
scope.9.endLine=66
scope.9.semanticHash=2a4853304418a002
scope.10.id=function:_collect_missing_children
scope.10.kind=function
scope.10.startLine=68
scope.10.endLine=80
scope.10.semanticHash=b42bb191beabc50e
scope.11.id=function:_has_children_lookup
scope.11.kind=function
scope.11.startLine=83
scope.11.endLine=85
scope.11.semanticHash=a8dc6f51993f12dd
scope.12.id=function:_validate_configured_child_nodes
scope.12.kind=function
scope.12.startLine=87
scope.12.endLine=100
scope.12.semanticHash=26486187a3ce6f2c
scope.13.id=function:_build_ui_manager_nodes
scope.13.kind=function
scope.13.startLine=102
scope.13.endLine=111
scope.13.semanticHash=e1c30b858af4c65f
scope.14.id=function:_resolve_current_game
scope.14.kind=function
scope.14.startLine=113
scope.14.endLine=120
scope.14.semanticHash=a080d6698490a798
scope.15.id=function:_bind_current_game
scope.15.kind=function
scope.15.startLine=122
scope.15.endLine=126
scope.15.semanticHash=97c8c84482f41ef1
scope.16.id=function:<anonymous>
scope.16.kind=function
scope.16.startLine=123
scope.16.endLine=125
scope.16.semanticHash=d825a8f0d7ed6353
scope.17.id=function:_sync_ui_event_roles
scope.17.kind=function
scope.17.startLine=128
scope.17.endLine=132
scope.17.semanticHash=2779ba513478a6a3
scope.18.id=function:_assert_required_ui_nodes
scope.18.kind=function
scope.18.startLine=134
scope.18.endLine=138
scope.18.semanticHash=a125d84ebd54fa5f
scope.19.id=function:_initialize_game_ui
scope.19.kind=function
scope.19.startLine=140
scope.19.endLine=150
scope.19.semanticHash=6ec4e919bba3e2c1
scope.20.id=function:_schedule_loading_transition
scope.20.kind=function
scope.20.startLine=152
scope.20.endLine=157
scope.20.semanticHash=22f10a1a9c23a9f2
scope.21.id=function:<anonymous>#2
scope.21.kind=function
scope.21.startLine=153
scope.21.endLine=156
scope.21.semanticHash=86dd3920f22d94fa
scope.22.id=function:M.install
scope.22.kind=function
scope.22.startLine=160
scope.22.endLine=177
scope.22.semanticHash=4889a6b5357b0b7d
scope.23.id=function:<anonymous>#3
scope.23.kind=function
scope.23.startLine=162
scope.23.endLine=176
scope.23.semanticHash=7c147bb55ee657d0
]]
