local base_nodes = require("src.ui.schema.base")
local permanent_nodes = require("src.ui.schema.permanent")
local base_contract = require("src.ui.schema.base_contract")
local player_choice_nodes = require("src.ui.schema.player_choice")
local target_choice_nodes = require("src.ui.schema.target_choice")
local remote_choice_nodes = require("src.ui.schema.remote_choice")
local secondary_confirm_nodes = require("src.ui.schema.secondary_confirm")

local bootstrap_nodes = {}

local function _required_click_nodes()
  local required = {
    base_nodes.action_button,
    base_nodes.end_button,
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

function bootstrap_nodes.build_required_click_nodes(opts)
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

function bootstrap_nodes.validate_required_nodes(ui_manager_nodes, required_nodes)
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

function bootstrap_nodes.assert_required_nodes(ui_manager_nodes, opts)
  local required_nodes = bootstrap_nodes.build_required_click_nodes(opts)
  local missing = bootstrap_nodes.validate_required_nodes(ui_manager_nodes, required_nodes)
  if #missing > 0 then
    error("UI 节点缺失: " .. table.concat(missing, ", "))
  end
end

return bootstrap_nodes
