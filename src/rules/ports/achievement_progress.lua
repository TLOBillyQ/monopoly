local achievement_progress = {}

local configured_port = nil

local function _resolve_port(game)
  if game and type(game.achievement_progress_port) == "table" then
    return game.achievement_progress_port
  end
  return configured_port
end

local function _call(game, method_name, ...)
  local port = _resolve_port(game)
  local fn = port and port[method_name] or nil
  if type(fn) ~= "function" then
    return false
  end
  local ok, result = pcall(fn, game, ...)
  if not ok then
    return false
  end
  return result == true
end

function achievement_progress.configure(port)
  assert(port == nil or type(port) == "table", "invalid achievement progress port")
  configured_port = port
end

function achievement_progress.reset_for_tests()
  configured_port = nil
end

function achievement_progress.game_won(game, player)
  return _call(game, "game_won", player)
end

function achievement_progress.land_purchased(game, player)
  return _call(game, "land_purchased", player)
end

function achievement_progress.cash_received(game, player, amount)
  return _call(game, "cash_received", player, amount)
end

function achievement_progress.tax_paid(game, player, amount)
  return _call(game, "tax_paid", player, amount)
end

function achievement_progress.item_used(game, player)
  return _call(game, "item_used", player)
end

function achievement_progress.chance_card_drawn(game, player)
  return _call(game, "chance_card_drawn", player)
end

function achievement_progress.market_item_bought(game, player)
  return _call(game, "market_item_bought", player)
end

function achievement_progress.building_upgraded(game, player, level)
  return _call(game, "building_upgraded", player, level)
end

function achievement_progress.deity_attached(game, player, deity_type)
  return _call(game, "deity_attached", player, deity_type)
end

function achievement_progress.location_effect(game, player, effect)
  return _call(game, "location_effect", player, effect)
end

function achievement_progress.contiguous_lands(game, player)
  return _call(game, "contiguous_lands", player)
end

function achievement_progress.monster_demolished_building(game, player)
  return _call(game, "monster_demolished_building", player)
end

function achievement_progress.typhoon_demolished_building(game, player)
  return _call(game, "typhoon_demolished_building", player)
end

function achievement_progress.skin_equipped(game, role_id, skin)
  return _call(game, "skin_equipped", role_id, skin)
end

return achievement_progress

--[[ mutate4lua-manifest
version=2
projectHash=ef5fee66cb6048da
scope.0.id=chunk:src/rules/ports/achievement_progress.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=98384d94d12f5ce9
scope.0.lastMutatedAt=2026-06-21T06:19:02Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=no_sites
scope.0.lastMutationSites=0
scope.0.lastMutationKilled=0
scope.1.id=function:_resolve_port:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=0746d7f3eea0e70d
scope.1.lastMutatedAt=2026-06-21T06:20:48Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_call:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=23
scope.2.semanticHash=6228ed76a2227b3a
scope.2.lastMutatedAt=2026-06-21T06:20:48Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=12
scope.2.lastMutationKilled=12
scope.3.id=function:achievement_progress.configure:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=28
scope.3.semanticHash=edf1412f0e1cbad1
scope.3.lastMutatedAt=2026-06-21T06:20:48Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:achievement_progress.reset_for_tests:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=7c410c8535a167cb
scope.4.lastMutatedAt=2026-06-21T06:19:02Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:achievement_progress.game_won:34
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=36
scope.5.semanticHash=a7dc3c2ebeb25206
scope.5.lastMutatedAt=2026-06-21T06:20:48Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:achievement_progress.land_purchased:38
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=f58df3789b79888a
scope.6.lastMutatedAt=2026-06-21T06:20:48Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:achievement_progress.cash_received:42
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=44
scope.7.semanticHash=1cec3785599cdf1e
scope.7.lastMutatedAt=2026-06-21T06:20:48Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:achievement_progress.tax_paid:46
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=48
scope.8.semanticHash=beb4528271411cc4
scope.8.lastMutatedAt=2026-06-21T06:20:48Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:achievement_progress.item_used:50
scope.9.kind=function
scope.9.startLine=50
scope.9.endLine=52
scope.9.semanticHash=08eb923a573c8fee
scope.9.lastMutatedAt=2026-06-21T06:20:48Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:achievement_progress.chance_card_drawn:54
scope.10.kind=function
scope.10.startLine=54
scope.10.endLine=56
scope.10.semanticHash=5076b3344dd85e08
scope.10.lastMutatedAt=2026-06-21T06:20:48Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:achievement_progress.market_item_bought:58
scope.11.kind=function
scope.11.startLine=58
scope.11.endLine=60
scope.11.semanticHash=a5e4e1deb907f0ae
scope.11.lastMutatedAt=2026-06-21T06:20:48Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:achievement_progress.building_upgraded:62
scope.12.kind=function
scope.12.startLine=62
scope.12.endLine=64
scope.12.semanticHash=8e6747b9bb3e6956
scope.12.lastMutatedAt=2026-06-21T06:20:48Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:achievement_progress.deity_attached:66
scope.13.kind=function
scope.13.startLine=66
scope.13.endLine=68
scope.13.semanticHash=d621060aef0cd35c
scope.13.lastMutatedAt=2026-06-21T06:20:48Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:achievement_progress.location_effect:70
scope.14.kind=function
scope.14.startLine=70
scope.14.endLine=72
scope.14.semanticHash=64df76e8d919d0ce
scope.14.lastMutatedAt=2026-06-21T06:20:48Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:achievement_progress.contiguous_lands:74
scope.15.kind=function
scope.15.startLine=74
scope.15.endLine=76
scope.15.semanticHash=6846fc773220f65e
scope.15.lastMutatedAt=2026-06-21T06:20:48Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=1
scope.15.lastMutationKilled=1
scope.16.id=function:achievement_progress.monster_demolished_building:78
scope.16.kind=function
scope.16.startLine=78
scope.16.endLine=80
scope.16.semanticHash=643111aa95e2d5b8
scope.16.lastMutatedAt=2026-06-21T06:20:48Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
scope.17.id=function:achievement_progress.typhoon_demolished_building:82
scope.17.kind=function
scope.17.startLine=82
scope.17.endLine=84
scope.17.semanticHash=fd8d8a13cab23706
scope.17.lastMutatedAt=2026-06-21T06:20:48Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:achievement_progress.skin_equipped:86
scope.18.kind=function
scope.18.startLine=86
scope.18.endLine=88
scope.18.semanticHash=98c67c00aad46cf6
scope.18.lastMutatedAt=2026-06-21T06:20:48Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=1
scope.18.lastMutationKilled=1
]]
