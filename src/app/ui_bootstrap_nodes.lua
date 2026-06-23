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

  local function _node_name_from_entry(entry)
    if type(entry) ~= "table" then
      return nil
    end
    local name = entry[1]
    if type(name) ~= "string" then
      return nil
    end
    return name
  end

  local known = {}
  for _, entry in pairs(ui_manager_nodes) do
    local name = _node_name_from_entry(entry)
    if name ~= nil then
      known[name] = true
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

--[[ mutate4lua-manifest
version=2
projectHash=63185adeeba729ea
scope.0.id=chunk:src/app/ui_bootstrap_nodes.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=9e34e2806fb2f75a
scope.0.lastMutatedAt=2026-06-23T03:19:07Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=44
scope.0.lastMutationKilled=44
scope.1.id=function:_required_click_nodes:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=22
scope.1.semanticHash=c6df1bc6a2948436
scope.1.lastMutatedAt=2026-06-23T03:17:32Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=no_sites
scope.1.lastMutationSites=0
scope.1.lastMutationKilled=0
scope.2.id=function:_node_name_from_entry:51
scope.2.kind=function
scope.2.startLine=51
scope.2.endLine=60
scope.2.semanticHash=2ddf7c92ee666f99
scope.2.lastMutatedAt=2026-06-23T03:19:07Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:bootstrap_nodes.assert_required_nodes:81
scope.3.kind=function
scope.3.startLine=81
scope.3.endLine=87
scope.3.semanticHash=bef3d9984ddf06a7
scope.3.lastMutatedAt=2026-06-23T03:19:07Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
]]
