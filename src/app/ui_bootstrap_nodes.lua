local base_nodes = require("src.ui.schema.base")
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
    -- 道具使用后续选择的唯一取消出口:节点缺失必须开局 fail-fast,
    -- 否则取消链全断且只弹一次 tip、日志无痕。
    base_nodes.cancel_button,
    base_nodes.auto_button,
    base_nodes.share_button,
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

local function _extra_nodes(opts)
  local extra = opts and opts.extra or nil
  return type(extra) == "table" and extra or nil
end

function bootstrap_nodes.build_required_click_nodes(opts)
  local required = _required_click_nodes()
  for _, name in ipairs(player_choice_nodes.slots) do
    required[#required + 1] = name
  end
  for _, name in ipairs(remote_choice_nodes.options) do
    required[#required + 1] = name
  end
  _append_click_nodes(required, base_contract.action_log.toggle_targets)
  _append_click_nodes(required, _extra_nodes(opts))
  return required
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

local function _index_known_nodes(ui_manager_nodes)
  local known = {}
  for _, entry in pairs(ui_manager_nodes) do
    local name = _node_name_from_entry(entry)
    if name ~= nil then
      known[name] = true
    end
  end
  return known
end

local function _missing_node(name, known, seen)
  return type(name) == "string" and name ~= "" and not known[name] and not seen[name]
end

local function _missing_required(required_nodes, known)
  local missing = {}
  local seen = {}
  for _, name in ipairs(required_nodes or {}) do
    if _missing_node(name, known, seen) then
      missing[#missing + 1] = name
      seen[name] = true
    end
  end
  return missing
end

function bootstrap_nodes.validate_required_nodes(ui_manager_nodes, required_nodes)
  if type(ui_manager_nodes.validate) == "function" then
    return ui_manager_nodes.validate(required_nodes)
  end
  return _missing_required(required_nodes, _index_known_nodes(ui_manager_nodes))
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
version=4
projectHash=7b9fd47880321dde
scope.0.id=chunk:src/app/ui_bootstrap_nodes.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=d77f0cae8ac4f95a
scope.1.id=function:_required_click_nodes
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=25
scope.1.semanticHash=237a3b36aacf718e
scope.2.id=function:_append_click_nodes
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=31
scope.2.semanticHash=416be15a177afa1b
scope.3.id=function:_extra_nodes
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=36
scope.3.semanticHash=03e3059cb0c7ec87
scope.4.id=function:bootstrap_nodes.build_required_click_nodes
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=49
scope.4.semanticHash=43f6d113b97b99b0
scope.5.id=function:_node_name_from_entry
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=60
scope.5.semanticHash=4b4a9ab48949a89e
scope.6.id=function:_index_known_nodes
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=71
scope.6.semanticHash=a110cdd70e942dc5
scope.7.id=function:_missing_node
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=75
scope.7.semanticHash=a8d5199ab30785d7
scope.8.id=function:_missing_required
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=87
scope.8.semanticHash=0ae1e6f4553f4fd0
scope.9.id=function:bootstrap_nodes.validate_required_nodes
scope.9.kind=function
scope.9.startLine=89
scope.9.endLine=94
scope.9.semanticHash=675eff0ac6abc615
scope.10.id=function:bootstrap_nodes.assert_required_nodes
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=102
scope.10.semanticHash=6ebf4761a904d4ff
]]
