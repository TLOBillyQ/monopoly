local board_scene = require("src.presentation.render.BoardScene")
local ui_view = require("src.presentation.api.UIViewService")
local ui_event_router = require("src.presentation.interaction.UIEventRouter")
local base_nodes = require("src.presentation.canvas.base.nodes")
local always_show_nodes = require("src.presentation.canvas.always_show.nodes")
local always_show_contract = require("src.presentation.canvas.always_show.contract")
local player_choice_nodes = require("src.presentation.canvas.player_choice.nodes")
local target_choice_nodes = require("src.presentation.canvas.target_choice.nodes")
local remote_choice_nodes = require("src.presentation.canvas.remote_choice.nodes")
local building_choice_nodes = require("src.presentation.canvas.building_choice.nodes")
local market_ui = require("src.presentation.shared.MarketLayout")
local map_cfg = require("Config.Map")
local ui_events = require("src.presentation.shared.UIEvents")

local M = {}

local function _required_click_nodes(opts)
  local required = {
    base_nodes.action_button,
    always_show_nodes.auto_button,
    building_choice_nodes.confirm,
    building_choice_nodes.cancel,
    remote_choice_nodes.cancel,
  }
  for _, name in ipairs(player_choice_nodes.slots) do
    required[#required + 1] = name
  end
  for _, name in ipairs(target_choice_nodes.slots) do
    required[#required + 1] = name
  end
  required[#required + 1] = target_choice_nodes.under
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
    require "vendor.third_party.UIManager.Utils"
    local ui_manager_nodes = require("Data.UIManagerNodes")
    UIManager.Builder:new(ui_manager_nodes)
    local current_game = current_game_ref[1]
    if not current_game and type(opts.start_runtime) == "function" then
      current_game = opts.start_runtime(state, current_game_ref)
    end
    assert(current_game ~= nil, "missing current_game")

    ui_event_router.bind(state, function()
      return current_game_ref[1]
    end)

    if ui_events.set_roles then
      ui_events.set_roles(all_roles)
    end

    local required_nodes = _required_click_nodes({
      extra = market_ui.item_buttons or {},
    })
    local missing = _validate_required_nodes(ui_manager_nodes, required_nodes)
    if #missing > 0 then
      error("UI 节点缺失: " .. table.concat(missing, ", "))
    end

    ui_events.send_to_all(ui_events.show["加载屏"], {})
    board_scene.init(state, map_cfg, current_game)
    ui_view.init_ui_assets(state)
    ui_view.capture_player_colors(state, current_game)

    SetTimeOut(1.0, function()
      ui_events.send_to_all(ui_events.hide["加载屏"], {})
      ui_events.send_to_all(ui_events.show["基础屏"], {})
    end)
  end)
end

return M
