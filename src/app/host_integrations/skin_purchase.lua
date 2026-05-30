local logger = require("src.foundation.log")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

local skin_purchase = {}

local function _warn(reason, context)
  logger.warn("skin_purchase: " .. tostring(reason), context or "")
end

local function _resolve_game(state)
  local game = state and state.game or nil
  if game == nil then
    _warn("missing game")
    return nil
  end
  return game
end

local function _resolve_player(game, role_id)
  if type(game.find_player_by_id) ~= "function" then
    _warn("game missing find_player_by_id", "role_id=" .. tostring(role_id))
    return nil
  end
  local player = game:find_player_by_id(role_id)
  if player == nil then
    _warn("player missing", "role_id=" .. tostring(role_id))
    return nil
  end
  return player
end

local function _on_purchase_success(on_success, skin)
  return function()
    local ok, err = pcall(on_success)
    if not ok then
      logger.warn(
        "skin_purchase: fulfillment failed",
        "product_id=" .. tostring(skin and skin.product_id or nil),
        tostring(err)
      )
      return false
    end
    return true
  end
end

local function _entry_for_skin(skin, on_success)
  return {
    kind = "skin",
    product_id = skin.product_id,
    name = skin.name,
    currency = skin.currency,
    price = skin.price,
    on_purchase = _on_purchase_success(on_success, skin),
  }
end

local function _has_success_callback(role_id, on_success)
  if type(on_success) == "function" then
    return true
  end
  _warn("missing success callback", "role_id=" .. tostring(role_id))
  return false
end

local function _is_purchase_skin(role_id, skin)
  if type(skin) == "table" and skin.unlock == "purchase" and skin.product_id ~= nil then
    return true
  end
  _warn("invalid skin", "role_id=" .. tostring(role_id))
  return false
end

local function _resolve_purchase_context(state, role_id)
  local game = _resolve_game(state)
  if game == nil then
    return nil, nil
  end
  local player = _resolve_player(game, role_id)
  if player == nil then
    return nil, nil
  end
  return game, player
end

local function _warn_start_result(role_id, skin, ok, started, reason)
  if not ok then
    logger.warn("skin_purchase: start failed", "role_id=" .. tostring(role_id), tostring(started))
    return
  end
  logger.warn(
    "skin_purchase: start rejected",
    "product_id=" .. tostring(skin.product_id),
    "reason=" .. tostring(reason or "unknown")
  )
end

function skin_purchase.start(state, role_id, skin, on_success)
  if not _has_success_callback(role_id, on_success) or not _is_purchase_skin(role_id, skin) then
    return false
  end

  local game, player = _resolve_purchase_context(state, role_id)
  if game == nil then
    return false
  end

  local ok, started, reason = pcall(paid_purchase_port.start, game, player, _entry_for_skin(skin, on_success))
  if ok and started == true then
    return true
  end
  _warn_start_result(role_id, skin, ok, started, reason)
  return false
end

function skin_purchase.configure(skin_panel)
  skin_panel.configure_purchase(function(role_id, skin, on_success, state)
    return skin_purchase.start(state, role_id, skin, on_success)
  end)
end

return skin_purchase

--[[ mutate4lua-manifest
version=2
projectHash=b087d171e5a5edc3
scope.0.id=chunk:src/app/host_integrations/skin_purchase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=123
scope.0.semanticHash=2c3b59978adddf5e
scope.0.lastMutatedAt=2026-05-29T06:48:25Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:_warn:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=9a657b244c6e4238
scope.1.lastMutatedAt=2026-05-29T06:48:25Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_resolve_game:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=17
scope.2.semanticHash=42fc1f08e4def034
scope.2.lastMutatedAt=2026-05-29T06:48:25Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_resolve_player:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=30
scope.3.semanticHash=788956a260778b27
scope.3.lastMutatedAt=2026-05-29T06:48:25Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:anonymous@33:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=44
scope.4.semanticHash=35baa62bd5fa1755
scope.4.lastMutatedAt=2026-05-29T06:48:25Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:_on_purchase_success:32
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=45
scope.5.semanticHash=029cd02049cb8235
scope.5.lastMutatedAt=2026-05-29T06:48:25Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=no_sites
scope.5.lastMutationSites=0
scope.5.lastMutationKilled=0
scope.6.id=function:_entry_for_skin:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=56
scope.6.semanticHash=de711386c24db361
scope.6.lastMutatedAt=2026-05-29T06:48:25Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:_has_success_callback:58
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=64
scope.7.semanticHash=aa109e5e7fb68a45
scope.7.lastMutatedAt=2026-05-29T06:48:25Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=6
scope.7.lastMutationKilled=6
scope.8.id=function:_is_purchase_skin:66
scope.8.kind=function
scope.8.startLine=66
scope.8.endLine=72
scope.8.semanticHash=57ff9a4d4f074103
scope.8.lastMutatedAt=2026-05-29T06:48:25Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=11
scope.8.lastMutationKilled=11
scope.9.id=function:_resolve_purchase_context:74
scope.9.kind=function
scope.9.startLine=74
scope.9.endLine=84
scope.9.semanticHash=5559687f767ff744
scope.9.lastMutatedAt=2026-05-29T06:48:25Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=4
scope.9.lastMutationKilled=4
scope.10.id=function:_warn_start_result:86
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=96
scope.10.semanticHash=47a50fab402e0046
scope.10.lastMutatedAt=2026-05-29T06:48:25Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=3
scope.10.lastMutationKilled=3
scope.11.id=function:skin_purchase.start:98
scope.11.kind=function
scope.11.startLine=98
scope.11.endLine=114
scope.11.semanticHash=12a383594069c285
scope.11.lastMutatedAt=2026-05-29T06:48:25Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=16
scope.11.lastMutationKilled=16
scope.12.id=function:anonymous@117:117
scope.12.kind=function
scope.12.startLine=117
scope.12.endLine=119
scope.12.semanticHash=a35e4898df2982e3
scope.12.lastMutatedAt=2026-05-29T06:48:25Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=no_sites
scope.12.lastMutationSites=0
scope.12.lastMutationKilled=0
scope.13.id=function:skin_purchase.configure:116
scope.13.kind=function
scope.13.startLine=116
scope.13.endLine=120
scope.13.semanticHash=d33002ef7b425c13
scope.13.lastMutatedAt=2026-05-29T06:48:25Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
]]
