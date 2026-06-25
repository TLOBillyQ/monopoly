local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local host_runtime_ports = require("src.ui.host_bridge")
local logger = require("src.foundation.log")
local command_policy = require("src.ui.input.command_policy")

local policy = {}

function policy.is_actor_bound_ui_button(action_id)
  return command_policy.requires_event_actor({ type = "ui_button", id = action_id })
end

function policy.requires_event_actor(intent)
  return command_policy.requires_event_actor(intent)
end

function policy.uses_local_actor(intent)
  return command_policy.uses_local_actor(intent)
end

function policy.is_optional_event_actor(intent)
  return command_policy.is_optional_event_actor(intent)
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
projectHash=dd0e2b720f8a7503
scope.0.id=chunk:src/ui/coord/event_actor_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=0da96e896978ad28
scope.1.id=function:policy.is_actor_bound_ui_button:29
scope.1.kind=function
scope.1.startLine=29
scope.1.endLine=34
scope.1.semanticHash=ca1d920a08a7110e
scope.2.id=function:policy.requires_event_actor:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=40
scope.2.semanticHash=f5f081d71bb685c6
scope.3.id=function:policy.uses_local_actor:42
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=50
scope.3.semanticHash=6c022014374a2f8e
scope.4.id=function:policy.is_optional_event_actor:52
scope.4.kind=function
scope.4.startLine=52
scope.4.endLine=54
scope.4.semanticHash=d8f2c963f2c3f778
scope.5.id=function:policy.resolve_actor_role_id:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=61
scope.5.semanticHash=3ff34c17f775af92
scope.6.id=function:policy.reject_missing_actor:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=72
scope.6.semanticHash=a692d426e9997ae9
scope.7.id=function:policy.attach_event_actor:74
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=88
scope.7.semanticHash=8b938f7a2fde872b
]]
