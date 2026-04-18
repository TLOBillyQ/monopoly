local board_scene = require("src.ui.render.board_scene")
local ui_view = require("src.ui.ctl.ui_runtime")
local canvas_event_router = require("src.ui.ctl.canvas_event_router")
local base_nodes = require("src.ui.schema.base")
local always_show_nodes = require("src.ui.schema.always_show")
local always_show_contract = require("src.ui.schema.always_show_contract")
local player_choice_nodes = require("src.ui.schema.player_choice")
local target_choice_nodes = require("src.ui.schema.target_choice")
local remote_choice_nodes = require("src.ui.schema.remote_choice")
local secondary_confirm_nodes = require("src.ui.schema.secondary_confirm")
local market_ui = require("src.ui.schema.market_layout")
local ui_events = require("src.ui.ctl.ui_events")
local runtime_ports = require("src.core.ports.runtime_ports")
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

local function _required_click_nodes(opts)
  local required = {
    base_nodes.action_button,
    always_show_nodes.auto_button,
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
  _append_click_nodes(required, base_nodes.card_outlines)
  _append_click_nodes(required, always_show_contract.action_log.toggle_targets)

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

    runtime_ports.schedule(1.0, function()
      ui_events.send_to_all(ui_events.hide["加载屏"], {})
      ui_events.send_to_all(ui_events.show["基础屏"], {})
      local always_show_event = ui_events.show[always_show_nodes.canvas]
      if always_show_event then
        ui_events.send_to_all(always_show_event, {})
      end
    end)
  end)
end

return M
