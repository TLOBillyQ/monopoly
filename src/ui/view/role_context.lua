local logger = require("src.foundation.log")
local role_id_utils = require("src.foundation.identity")

local role_context = {}

local warned_unmapped_role_ids = {}
local _cached_ctx = {}

local function _resolve_unmapped_role_context(role_id, current_player_id, ui_model)
  if role_id ~= nil and ui_model ~= nil and not warned_unmapped_role_ids[role_id] then
    warned_unmapped_role_ids[role_id] = true
    logger.warn(
      "role->player 映射失败，按观战回退:",
      "role_id=" .. tostring(role_id),
      "current_player_id=" .. tostring(current_player_id)
    )
  end
  _cached_ctx.role_id = role_id
  _cached_ctx.display_player_id = current_player_id
  _cached_ctx.can_operate = false
  _cached_ctx.is_player_role = false
  return _cached_ctx
end

local function _resolve_mapped_role_context(role_id, current_player_id)
  _cached_ctx.role_id = role_id
  _cached_ctx.display_player_id = role_id
  _cached_ctx.can_operate = role_id_utils.equals(role_id, current_player_id)
  _cached_ctx.is_player_role = true
  return _cached_ctx
end

local function _require_runtime(deps)
  local runtime = deps and deps.runtime or nil
  assert(runtime ~= nil and runtime.resolve_role_id ~= nil, "missing runtime.resolve_role_id")
  return runtime
end

local function _current_player_id(ui_model)
  return role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
end

local function _item_slots_by_player(ui_model)
  return ui_model and (ui_model.item_slots_by_player_id or ui_model.item_slots_by_player) or nil
end

local function _resolve_self_role_context(current_player_id)
  _cached_ctx.role_id = nil
  _cached_ctx.display_player_id = current_player_id
  _cached_ctx.can_operate = true
  _cached_ctx.is_player_role = true
  return _cached_ctx
end

function role_context.resolve(role, ui_model, deps)
  local runtime = _require_runtime(deps)
  local current_player_id = _current_player_id(ui_model)
  local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
  local mapped = role_id ~= nil and role_id_utils.read(_item_slots_by_player(ui_model), role_id) ~= nil

  if role_id == nil and role == nil then
    return _resolve_self_role_context(current_player_id)
  end

  if mapped then
    return _resolve_mapped_role_context(role_id, current_player_id)
  end

  return _resolve_unmapped_role_context(role_id, current_player_id, ui_model)
end

return role_context

--[[ mutate4lua-manifest
version=2
projectHash=c029ab29976ddc64
scope.0.id=chunk:src/ui/view/role_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=73
scope.0.semanticHash=e2a1c69ae9e7cf59
scope.1.id=function:_resolve_unmapped_role_context:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=23
scope.1.semanticHash=a98ddd1b73cc2d6f
scope.2.id=function:_resolve_mapped_role_context:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=31
scope.2.semanticHash=1bbde7ee059e0a1e
scope.3.id=function:_require_runtime:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=37
scope.3.semanticHash=5dfdf3b26c849dab
scope.4.id=function:_current_player_id:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=41
scope.4.semanticHash=351b4963fc6270cb
scope.5.id=function:_item_slots_by_player:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=45
scope.5.semanticHash=7d08d9390f6f68e0
scope.6.id=function:_resolve_self_role_context:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=53
scope.6.semanticHash=31e2c85c7c0eb54a
scope.7.id=function:role_context.resolve:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=70
scope.7.semanticHash=4d523854cc3bbd37
]]
