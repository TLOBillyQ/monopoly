local achievement = require("src.app.host_integrations.achievement")
local number_utils = require("src.foundation.number")
local role_resolver = require("src.host.role_resolver")

local achievement_runtime = {}

local events = {
  game_win = "游戏胜利",
  land_purchase = "买下地块",
  cash_received = "收取金币",
  tax_paid = "支付税金",
  item_used = "使用道具卡",
  chance_card = "抽到机会卡",
  market_item_bought = "黑市购买道具",
  contiguous_lands = "获得三个连续地块",
  monster_demolish = "被怪兽拆除房屋",
  typhoon_demolish = "被台风拆除房屋",
  building_upgraded = {
    [1] = "加盖1级建筑",
    [2] = "加盖2级建筑",
    [3] = "加盖3级建筑",
  },
  deity_attached = {
    angel = "被福神附身",
    rich = "被财神附身",
    poor = "被穷神附身",
  },
  location_effect = {
    hospital = "被送进医院",
    mountain = "被送进深山",
  },
}

local function _can_write_progress(role)
  return type(role) == "table" and type(role.add_achievement_progress) == "function"
end

local function _resolve_player_id(subject)
  if type(subject) == "table" then
    return subject.role_id or subject.id
  end
  return subject
end

local function _resolve_role(subject)
  if _can_write_progress(subject) then
    return subject
  end
  local player_id = _resolve_player_id(subject)
  if player_id == nil then
    return nil
  end
  return role_resolver.resolve_role_with(player_id, _can_write_progress)
end

local function _positive_amount(amount)
  local value = number_utils.to_integer(amount)
  if value == nil or value <= 0 then
    return nil
  end
  return value
end

local function _record(subject, event_name, amount)
  if event_name == nil then
    return false
  end
  local role = _resolve_role(subject)
  if role == nil then
    return false
  end
  return achievement.record_gameplay_event(event_name, amount, role)
end

local function _record_positive_amount(player, event_name, amount)
  local value = _positive_amount(amount)
  if value == nil then
    return false
  end
  return _record(player, event_name, value)
end

function achievement_runtime.record_event(subject, event_name, amount)
  return _record(subject, event_name, amount)
end

function achievement_runtime.game_won(_, player)
  return _record(player, events.game_win)
end

function achievement_runtime.land_purchased(_, player)
  return _record(player, events.land_purchase)
end

function achievement_runtime.cash_received(_, player, amount)
  return _record_positive_amount(player, events.cash_received, amount)
end

function achievement_runtime.tax_paid(_, player, amount)
  return _record_positive_amount(player, events.tax_paid, amount)
end

function achievement_runtime.item_used(_, player)
  return _record(player, events.item_used)
end

function achievement_runtime.chance_card_drawn(_, player)
  return _record(player, events.chance_card)
end

function achievement_runtime.market_item_bought(_, player)
  return _record(player, events.market_item_bought)
end

function achievement_runtime.building_upgraded(_, player, level)
  return _record(player, events.building_upgraded[number_utils.to_integer(level)])
end

function achievement_runtime.deity_attached(_, player, deity_type)
  return _record(player, events.deity_attached[deity_type])
end

function achievement_runtime.location_effect(_, player, effect)
  return _record(player, events.location_effect[effect])
end

function achievement_runtime.contiguous_lands(_, player)
  return _record(player, events.contiguous_lands)
end

function achievement_runtime.monster_demolished_building(_, player)
  return _record(player, events.monster_demolish)
end

function achievement_runtime.typhoon_demolished_building(_, player)
  return _record(player, events.typhoon_demolish)
end

function achievement_runtime.skin_equipped(_, role_id, skin)
  if type(skin) ~= "table" or type(skin.name) ~= "string" or skin.name == "" then
    return false
  end
  return _record(role_id, "使用" .. skin.name .. "皮肤")
end

function achievement_runtime.build_port()
  return {
    game_won = achievement_runtime.game_won,
    land_purchased = achievement_runtime.land_purchased,
    cash_received = achievement_runtime.cash_received,
    tax_paid = achievement_runtime.tax_paid,
    item_used = achievement_runtime.item_used,
    chance_card_drawn = achievement_runtime.chance_card_drawn,
    market_item_bought = achievement_runtime.market_item_bought,
    building_upgraded = achievement_runtime.building_upgraded,
    deity_attached = achievement_runtime.deity_attached,
    location_effect = achievement_runtime.location_effect,
    contiguous_lands = achievement_runtime.contiguous_lands,
    monster_demolished_building = achievement_runtime.monster_demolished_building,
    typhoon_demolished_building = achievement_runtime.typhoon_demolished_building,
    skin_equipped = achievement_runtime.skin_equipped,
  }
end

return achievement_runtime

--[[ mutate4lua-manifest
version=2
projectHash=61d0bbc23968233f
scope.0.id=chunk:src/app/host_integrations/achievement_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=166
scope.0.semanticHash=a4088b2476e4d520
scope.0.lastMutatedAt=2026-06-21T06:22:55Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=22
scope.0.lastMutationKilled=22
scope.1.id=function:_can_write_progress:34
scope.1.kind=function
scope.1.startLine=34
scope.1.endLine=36
scope.1.semanticHash=2a09167488313d2c
scope.1.lastMutatedAt=2026-06-21T06:22:55Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_resolve_player_id:38
scope.2.kind=function
scope.2.startLine=38
scope.2.endLine=43
scope.2.semanticHash=107a51cb27af039c
scope.2.lastMutatedAt=2026-06-21T06:22:55Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_resolve_role:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=54
scope.3.semanticHash=e7c303c312db3797
scope.3.lastMutatedAt=2026-06-21T06:22:55Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_positive_amount:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=62
scope.4.semanticHash=7d09bbde502fb105
scope.4.lastMutatedAt=2026-06-21T06:22:55Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:_record:64
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=73
scope.5.semanticHash=2f233822c87093ab
scope.5.lastMutatedAt=2026-06-21T06:22:55Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:_record_positive_amount:75
scope.6.kind=function
scope.6.startLine=75
scope.6.endLine=81
scope.6.semanticHash=cda904d0434b8575
scope.6.lastMutatedAt=2026-06-21T06:22:55Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:achievement_runtime.record_event:83
scope.7.kind=function
scope.7.startLine=83
scope.7.endLine=85
scope.7.semanticHash=b95e2d64222f28ec
scope.7.lastMutatedAt=2026-06-21T06:22:55Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:achievement_runtime.game_won:87
scope.8.kind=function
scope.8.startLine=87
scope.8.endLine=89
scope.8.semanticHash=f81f04be6c5d0c1a
scope.8.lastMutatedAt=2026-06-21T06:22:55Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:achievement_runtime.land_purchased:91
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=93
scope.9.semanticHash=1e4cb065e4fb716c
scope.9.lastMutatedAt=2026-06-21T06:22:55Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:achievement_runtime.cash_received:95
scope.10.kind=function
scope.10.startLine=95
scope.10.endLine=97
scope.10.semanticHash=7c3d52c5694103b5
scope.10.lastMutatedAt=2026-06-21T06:22:55Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:achievement_runtime.tax_paid:99
scope.11.kind=function
scope.11.startLine=99
scope.11.endLine=101
scope.11.semanticHash=bf2f0ded4ca3fd6b
scope.11.lastMutatedAt=2026-06-21T06:22:55Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:achievement_runtime.item_used:103
scope.12.kind=function
scope.12.startLine=103
scope.12.endLine=105
scope.12.semanticHash=82305afe0ca67b14
scope.12.lastMutatedAt=2026-06-21T06:22:55Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:achievement_runtime.chance_card_drawn:107
scope.13.kind=function
scope.13.startLine=107
scope.13.endLine=109
scope.13.semanticHash=92f53b041d4defaf
scope.13.lastMutatedAt=2026-06-21T06:22:55Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:achievement_runtime.market_item_bought:111
scope.14.kind=function
scope.14.startLine=111
scope.14.endLine=113
scope.14.semanticHash=372f243dd2b0fa32
scope.14.lastMutatedAt=2026-06-21T06:22:55Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:achievement_runtime.building_upgraded:115
scope.15.kind=function
scope.15.startLine=115
scope.15.endLine=117
scope.15.semanticHash=b5698663c2942b8e
scope.15.lastMutatedAt=2026-06-21T06:22:55Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=1
scope.15.lastMutationKilled=1
scope.16.id=function:achievement_runtime.deity_attached:119
scope.16.kind=function
scope.16.startLine=119
scope.16.endLine=121
scope.16.semanticHash=c80e1ee44cb21bfc
scope.16.lastMutatedAt=2026-06-21T06:22:55Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
scope.17.id=function:achievement_runtime.location_effect:123
scope.17.kind=function
scope.17.startLine=123
scope.17.endLine=125
scope.17.semanticHash=d932720fe194a24c
scope.17.lastMutatedAt=2026-06-21T06:22:55Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:achievement_runtime.contiguous_lands:127
scope.18.kind=function
scope.18.startLine=127
scope.18.endLine=129
scope.18.semanticHash=0e5b75c9692025a4
scope.18.lastMutatedAt=2026-06-21T06:22:55Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=1
scope.18.lastMutationKilled=1
scope.19.id=function:achievement_runtime.monster_demolished_building:131
scope.19.kind=function
scope.19.startLine=131
scope.19.endLine=133
scope.19.semanticHash=60cb5e7bb9cb36de
scope.19.lastMutatedAt=2026-06-21T06:22:55Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=1
scope.19.lastMutationKilled=1
scope.20.id=function:achievement_runtime.typhoon_demolished_building:135
scope.20.kind=function
scope.20.startLine=135
scope.20.endLine=137
scope.20.semanticHash=4b4dfadc5b17b252
scope.20.lastMutatedAt=2026-06-21T06:22:55Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:achievement_runtime.skin_equipped:139
scope.21.kind=function
scope.21.startLine=139
scope.21.endLine=144
scope.21.semanticHash=7983571f59459809
scope.21.lastMutatedAt=2026-06-21T06:22:55Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=12
scope.21.lastMutationKilled=12
scope.22.id=function:achievement_runtime.build_port:146
scope.22.kind=function
scope.22.startLine=146
scope.22.endLine=163
scope.22.semanticHash=7878054f9fed9b5f
scope.22.lastMutatedAt=2026-06-21T06:22:55Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=no_sites
scope.22.lastMutationSites=0
scope.22.lastMutationKilled=0
]]
