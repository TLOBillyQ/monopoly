local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local host_runtime_ports = require("src.ui.host_bridge")
local logger = require("src.foundation.log")

local policy = {}

local ACTOR_BOUND_TYPES = {
  toggle_action_log = true, open_skin_panel = true, open_gallery_panel = true,
  skin_panel_action = true, item_atlas_action = true, skin_gallery_action = true,
  choice_select = true, choice_cancel = true,
  complete_optional_action_phase = true,
  market_confirm = true, market_page_prev = true, market_page_next = true, market_tab_select = true,
}

local OPTIONAL_EVENT_ACTOR_TYPES = {
  open_skin_panel = true,
  open_gallery_panel = true,
}

local LOCAL_ONLY_ACTOR_TYPES = {
  toggle_action_log = true,
  open_skin_panel = true,
  open_gallery_panel = true,
  skin_panel_action = true,
  item_atlas_action = true,
  skin_gallery_action = true,
}

function policy.is_actor_bound_ui_button(action_id)
  if action_id == "next" or action_id == "auto" then
    return true
  end
  return type(action_id) == "string" and string.match(action_id, "^item_slot_(%d+)$") ~= nil
end

function policy.requires_event_actor(intent)
  if type(intent) ~= "table" then return false end
  if ACTOR_BOUND_TYPES[intent.type] then return true end
  return intent.type == "ui_button" and policy.is_actor_bound_ui_button(intent.id)
end

function policy.uses_local_actor(intent)
  if type(intent) ~= "table" then
    return false
  end
  if LOCAL_ONLY_ACTOR_TYPES[intent.type] then
    return true
  end
  return intent.type == "ui_button" and intent.id == "auto"
end

function policy.is_optional_event_actor(intent)
  return type(intent) == "table" and OPTIONAL_EVENT_ACTOR_TYPES[intent.type] == true
end

function policy.resolve_actor_role_id(state, intent, data)
  if policy.uses_local_actor(intent) then
    return local_actor_resolver.resolve_from_event(state, data)
  end
  return local_actor_resolver.resolve_turn_bound(state, data)
end

function policy.reject_missing_actor(intent)
  host_runtime_ports.enqueue_tip({
    text = "当前操作缺少玩家上下文，已忽略",
    duration = 2.0,
    dedupe_key = "missing_actor:" .. tostring(intent.type) .. ":" .. tostring(intent.id),
    blocks_inter_turn = false,
    source = "ui.missing_actor",
  })
  logger.warn("ui intent rejected: missing actor_role_id", tostring(intent.type), tostring(intent.id))
end

function policy.attach_event_actor(state, intent, data)
  if not policy.requires_event_actor(intent) or intent.actor_role_id ~= nil then
    return true
  end
  local actor_role_id = policy.resolve_actor_role_id(state, intent, data)
  if actor_role_id == nil then
    if policy.is_optional_event_actor(intent) then
      return true
    end
    policy.reject_missing_actor(intent)
    return false
  end
  intent.actor_role_id = actor_role_id
  return true
end

return policy

--[[ mutate4lua-manifest
version=2
projectHash=4635505ba696f294
scope.0.id=chunk:src/ui/coord/event_actor_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=25da73f0c15bf640
scope.0.lastMutatedAt=2026-05-25T13:21:57Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=23
scope.0.lastMutationKilled=23
scope.1.id=function:policy.is_actor_bound_ui_button:28
scope.1.kind=function
scope.1.startLine=28
scope.1.endLine=33
scope.1.semanticHash=ca1d920a08a7110e
scope.1.lastMutatedAt=2026-05-25T13:21:57Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=12
scope.1.lastMutationKilled=12
scope.2.id=function:policy.requires_event_actor:35
scope.2.kind=function
scope.2.startLine=35
scope.2.endLine=39
scope.2.semanticHash=f5f081d71bb685c6
scope.2.lastMutatedAt=2026-05-25T13:21:57Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=9
scope.2.lastMutationKilled=9
scope.3.id=function:policy.uses_local_actor:41
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=49
scope.3.semanticHash=6c022014374a2f8e
scope.3.lastMutatedAt=2026-05-25T13:21:57Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=10
scope.4.id=function:policy.is_optional_event_actor:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=53
scope.4.semanticHash=d8f2c963f2c3f778
scope.4.lastMutatedAt=2026-05-25T13:21:57Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
scope.5.id=function:policy.resolve_actor_role_id:55
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=60
scope.5.semanticHash=3ff34c17f775af92
scope.5.lastMutatedAt=2026-05-25T13:21:57Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:policy.reject_missing_actor:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=71
scope.6.semanticHash=a692d426e9997ae9
scope.6.lastMutatedAt=2026-05-25T13:21:57Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:policy.attach_event_actor:73
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=87
scope.7.semanticHash=8b938f7a2fde872b
scope.7.lastMutatedAt=2026-05-25T13:21:57Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=12
scope.7.lastMutationKilled=12
]]
