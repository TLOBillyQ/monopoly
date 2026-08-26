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
version=4
projectHash=eac61528270caa3f
scope.0.id=chunk:src/rules/ports/achievement_progress.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=9e7eb77bd977bf89
scope.1.id=function:_resolve_port
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=098676f10b238105
scope.2.id=function:_call
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=23
scope.2.semanticHash=f5300f7fc6d2df05
scope.3.id=function:achievement_progress.configure
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=28
scope.3.semanticHash=aa7924a6161503b0
scope.4.id=function:achievement_progress.reset_for_tests
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=f308d8708726be18
scope.5.id=function:achievement_progress.game_won
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=36
scope.5.semanticHash=9ae0d7098f2d7ecb
scope.6.id=function:achievement_progress.land_purchased
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=9ae0d7098f2d7ecb
scope.7.id=function:achievement_progress.cash_received
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=44
scope.7.semanticHash=7c75d9437e0a07d7
scope.8.id=function:achievement_progress.tax_paid
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=48
scope.8.semanticHash=7c75d9437e0a07d7
scope.9.id=function:achievement_progress.item_used
scope.9.kind=function
scope.9.startLine=50
scope.9.endLine=52
scope.9.semanticHash=9ae0d7098f2d7ecb
scope.10.id=function:achievement_progress.chance_card_drawn
scope.10.kind=function
scope.10.startLine=54
scope.10.endLine=56
scope.10.semanticHash=9ae0d7098f2d7ecb
scope.11.id=function:achievement_progress.market_item_bought
scope.11.kind=function
scope.11.startLine=58
scope.11.endLine=60
scope.11.semanticHash=9ae0d7098f2d7ecb
scope.12.id=function:achievement_progress.building_upgraded
scope.12.kind=function
scope.12.startLine=62
scope.12.endLine=64
scope.12.semanticHash=7c75d9437e0a07d7
scope.13.id=function:achievement_progress.deity_attached
scope.13.kind=function
scope.13.startLine=66
scope.13.endLine=68
scope.13.semanticHash=7c75d9437e0a07d7
scope.14.id=function:achievement_progress.location_effect
scope.14.kind=function
scope.14.startLine=70
scope.14.endLine=72
scope.14.semanticHash=7c75d9437e0a07d7
scope.15.id=function:achievement_progress.contiguous_lands
scope.15.kind=function
scope.15.startLine=74
scope.15.endLine=76
scope.15.semanticHash=9ae0d7098f2d7ecb
scope.16.id=function:achievement_progress.monster_demolished_building
scope.16.kind=function
scope.16.startLine=78
scope.16.endLine=80
scope.16.semanticHash=9ae0d7098f2d7ecb
scope.17.id=function:achievement_progress.typhoon_demolished_building
scope.17.kind=function
scope.17.startLine=82
scope.17.endLine=84
scope.17.semanticHash=9ae0d7098f2d7ecb
scope.18.id=function:achievement_progress.skin_equipped
scope.18.kind=function
scope.18.startLine=86
scope.18.endLine=88
scope.18.semanticHash=7c75d9437e0a07d7
]]
