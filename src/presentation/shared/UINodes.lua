local base_nodes = require("src.presentation.canvas.base.nodes")
local always_show_nodes = require("src.presentation.canvas.always_show.nodes")
local always_show_contract = require("src.presentation.canvas.always_show.contract")
local player_choice_nodes = require("src.presentation.canvas.player_choice.nodes")
local target_choice_nodes = require("src.presentation.canvas.target_choice.nodes")
local remote_choice_nodes = require("src.presentation.canvas.remote_choice.nodes")
local building_choice_nodes = require("src.presentation.canvas.building_choice.nodes")
local market_nodes = require("src.presentation.canvas.market.nodes")
local popup_nodes = require("src.presentation.canvas.popup.nodes")
local bankruptcy_nodes = require("src.presentation.canvas.bankruptcy.nodes")
local dice_nodes = require("src.presentation.canvas.dice.nodes")
local loading_nodes = require("src.presentation.canvas.loading.nodes")
local debug_nodes = require("src.presentation.canvas.debug.nodes")

local nodes = {}

-- Deprecated compatibility export.
nodes.base = base_nodes
nodes.always_show = always_show_nodes
nodes.player_choice = player_choice_nodes
nodes.target_choice = target_choice_nodes
nodes.remote_choice = remote_choice_nodes
nodes.building_choice = building_choice_nodes
nodes.market = market_nodes
nodes.popup = popup_nodes
nodes.bankruptcy = bankruptcy_nodes
nodes.dice = dice_nodes
nodes.loading = loading_nodes
nodes.debug = debug_nodes

nodes.canvas = {
  base = nodes.base.canvas,
  always_show = nodes.always_show.canvas,
  player_choice = nodes.player_choice.canvas,
  target_choice = nodes.target_choice.canvas,
  remote_choice = nodes.remote_choice.canvas,
  building_choice = nodes.building_choice.canvas,
  market = nodes.market.canvas,
  popup = nodes.popup.canvas,
  bankruptcy = nodes.bankruptcy.canvas,
  dice = nodes.dice.canvas,
  loading = nodes.loading.canvas,
  debug = nodes.debug.canvas,
}

function nodes.required_click_nodes(opts)
  local required = {
    nodes.base.action_button,
    nodes.always_show.auto_button,
    nodes.building_choice.confirm,
    nodes.building_choice.cancel,
    nodes.remote_choice.cancel,
  }
  for _, name in ipairs(nodes.player_choice.slots) do
    required[#required + 1] = name
  end
  for _, name in ipairs(nodes.target_choice.slots) do
    required[#required + 1] = name
  end
  required[#required + 1] = nodes.target_choice.under
  for _, name in ipairs(nodes.remote_choice.options) do
    required[#required + 1] = name
  end
  for _, name in ipairs(nodes.base.card_outlines or {}) do
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

return nodes
