local board_scene = require("src.presentation.view.render.board_scene")
local ui_view = require("src.presentation.runtime.view")
local canvas_event_router = require("src.presentation.runtime.canvas_event_router")
local base_nodes = require("src.presentation.view.canvas.base.nodes")
local always_show_nodes = require("src.presentation.view.canvas.always_show.nodes")
local always_show_contract = require("src.presentation.view.canvas.always_show.contract")
local player_choice_nodes = require("src.presentation.view.canvas.player_choice.nodes")
local target_choice_nodes = require("src.presentation.view.canvas.target_choice.nodes")
local remote_choice_nodes = require("src.presentation.view.canvas.remote_choice.nodes")
local secondary_confirm_nodes = require("src.presentation.view.canvas.secondary_confirm.nodes")
local market_ui = require("src.presentation.view.support.market_layout")
local ui_events = require("src.presentation.runtime.events")
local runtime_ports = require("src.core.ports.runtime_ports")
local role_globals = require("src.core.state_access.ui_role_globals")

local M = {}

local function _required_click_nodes(opts)
  local required = {
    base_nodes.action_button,
    always_show_nodes.auto_button,
    target_choice_nodes.confirm,
    target_choice_nodes.cancel,
    secondary_confirm_nodes.confirm,
    secondary_confirm_nodes.cancel,
  }
  for _, name in ipairs(player_choice_nodes.slots) do
    required[#required + 1] = name
  end
  for _, name in ipairs(remote_choice_nodes.options) do
    required[#required + 1] = name
  end
  for _, name in ipairs(base_nodes.card_outlines or {}) do
    required[#required + 1] = name
  end
  for _, name in ipairs(always_show_contract.action_log.toggle_targets or {}) do
    required[#required + 1] = name
  end

  local extra = opts and opts.extra or nil
  if type(extra) == "table" then
    for _, name in ipairs(extra) do
      required[#required + 1] = name
    end
  end
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
    local roles = role_globals.install(runtime_ports.resolve_roles())
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

    local required_nodes = _required_click_nodes({
      extra = market_ui.item_buttons or {},
    })
    local missing = _validate_required_nodes(ui_manager_nodes, required_nodes)
    if #missing > 0 then
      error("UI 节点缺失: " .. table.concat(missing, ", "))
    end

    ui_events.send_to_all(ui_events.show["加载屏"], {})
    local board_map = current_game and current_game.board and current_game.board.map or nil
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
