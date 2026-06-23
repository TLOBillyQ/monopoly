local achievement_progress = require("src.rules.ports.achievement_progress")
local gain_reveal = require("src.rules.items.gain_reveal")

local asset_handlers = {}

function asset_handlers.register(handlers, common)
  local deps = common.dependencies()

  local function _destroy_building_on_path_index(game, idx)
    local t = game.board:get_tile(idx)
    assert(t ~= nil, "missing tile: " .. tostring(idx))
    if not (t.type == "land" and (t.level or 0) > 0) then
      return
    end
    local st = deps.tile_state and deps.tile_state(game, t) or t
    local owner = st and st.owner_id and game:find_player_by_id(st.owner_id) or nil
    game:set_tile_level(t, 0)
    if owner then
      achievement_progress.typhoon_demolished_building(game, owner)
    end
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      card = { effect = "destroy_buildings_on_path" },
      effect = "destroy_buildings_on_path",
      tile = t,
      text = "台风摧毁 " .. t.name .. " 上的建筑",
    })
  end

  handlers.destroy_buildings_on_path = function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      _destroy_building_on_path_index(game, idx)
    end
  end

  local function _reset_tile_on_path_index(game, idx)
    local t = game.board:get_tile(idx)
    assert(t ~= nil, "missing tile: " .. tostring(idx))
    if t.type ~= "land" then
      return
    end
    local st = deps.tile_state(game, t)
    assert(st ~= nil, "missing tile state: " .. tostring(t.id))
    if st.owner_id then
      local owner = assert(game:find_player_by_id(st.owner_id), "missing owner: " .. tostring(st.owner_id))
      game:set_player_property(owner, t.id, false)
    end
    game:reset_tile(t)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      card = { effect = "reset_tiles_on_path" },
      effect = "reset_tiles_on_path",
      tile = t,
      text = "强制征地重置 " .. t.name,
    })
  end

  handlers.reset_tiles_on_path = function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      _reset_tile_on_path_index(game, idx)
    end
  end

  handlers.grant_item = function(game, player, card)
    local ok = deps.inventory.give(player, card.item_id, { game = game })
    if ok == true then
      gain_reveal.queue(game, player, card.item_id, { source = "chance" })
    end
  end

  local function _discard_count(player, card)
    local to_drop = card.count
    if to_drop == 0 then
      to_drop = deps.inventory.count(player)
    end
    return to_drop
  end

  local function _discard_random_items(game, player, to_drop)
    local dropped_names = {}
    local rng = assert(game and game.rng, "missing game.rng for discard_items")
    assert(type(rng.next_int) == "function", "missing game.rng.next_int for discard_items")
    for _ = 1, to_drop do
      local item_count = deps.inventory.count(player)
      if item_count == 0 then
        break
      end
      local item = deps.inventory.remove_by_index(player, rng:next_int(1, item_count))
      table.insert(dropped_names, deps.inventory.item_name(item.id))
    end
    return dropped_names
  end

  local function _discard_items_text(player, dropped_names)
    local text = player.name .. " 丢弃道具 " .. #dropped_names .. " 张"
    if #dropped_names > 0 then
      text = text .. ": " .. table.concat(dropped_names, "、")
    end
    return text
  end

  handlers.discard_items = function(game, player, card)
    local dropped_names = _discard_random_items(game, player, _discard_count(player, card))
    local text = _discard_items_text(player, dropped_names)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = text,
    })
  end

  local function _sorted_property_ids(player)
    local ids = {}
    for tile_id in pairs(player.properties or {}) do
      ids[#ids + 1] = tile_id
    end
    table.sort(ids, function(a, b)
      local ai = deps.number_utils.to_integer(a)
      local bi = deps.number_utils.to_integer(b)
      if ai ~= nil and bi ~= nil then
        return ai < bi
      end
      return tostring(a) < tostring(b)
    end)
    return ids
  end

  local function _resolve_drop_rng(game, to_drop, count)
    if to_drop >= count then
      return nil
    end
    local rng = assert(game and game.rng, "missing game.rng for discard_properties")
    assert(type(rng.next_int) == "function", "missing game.rng.next_int for discard_properties")
    return rng
  end

  local function _pick_property_index(ids, rng)
    if rng then
      return rng:next_int(1, #ids)
    end
    return 1
  end

  handlers.discard_properties = function(game, player, card)
    local property_ids = _sorted_property_ids(player)
    local to_drop = card.count
    if to_drop == 0 then
      to_drop = #property_ids
    end
    local rng = _resolve_drop_rng(game, to_drop, #property_ids)

    for _ = 1, to_drop do
      if #property_ids == 0 then
        break
      end
      local tile_id = table.remove(property_ids, _pick_property_index(property_ids, rng))
      local t = game.board:get_tile_by_id(tile_id)
      assert(t ~= nil, "missing tile: " .. tostring(tile_id))
      game:reset_tile(t)
      common.emit_event(game, deps.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        tile = t,
        text = player.name .. " 丢失地块 " .. t.name,
      })
      game:set_player_property(player, tile_id, false)
    end
  end
end

return asset_handlers

--[[ mutate4lua-manifest
version=2
projectHash=d20d4ee7211ef04a
scope.0.id=chunk:src/rules/chance/asset_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=174
scope.0.semanticHash=ea4fee6642a133f9
scope.0.lastMutatedAt=2026-06-23T14:02:49Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=21
scope.0.lastMutationKilled=21
scope.1.id=function:_destroy_building_on_path_index:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=27
scope.1.semanticHash=95a5b0d38ce61acf
scope.1.lastMutatedAt=2026-06-23T14:02:49Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=20
scope.1.lastMutationKilled=20
scope.2.id=function:_reset_tile_on_path_index:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=55
scope.2.semanticHash=abedc61f6d836c08
scope.2.lastMutatedAt=2026-06-23T14:02:49Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=10
scope.2.lastMutationKilled=10
scope.3.id=function:anonymous@64:64
scope.3.kind=function
scope.3.startLine=64
scope.3.endLine=69
scope.3.semanticHash=770b07ef4d9009df
scope.3.lastMutatedAt=2026-06-23T14:02:49Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_discard_count:71
scope.4.kind=function
scope.4.startLine=71
scope.4.endLine=77
scope.4.semanticHash=7a918985b06d4319
scope.4.lastMutatedAt=2026-06-23T14:02:49Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:_discard_items_text:94
scope.5.kind=function
scope.5.startLine=94
scope.5.endLine=100
scope.5.semanticHash=69fc718c28a3a4e8
scope.5.lastMutatedAt=2026-06-23T14:02:49Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:anonymous@102:102
scope.6.kind=function
scope.6.startLine=102
scope.6.endLine=111
scope.6.semanticHash=15458aa30ea1d75f
scope.6.lastMutatedAt=2026-06-23T14:02:49Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:anonymous@118:118
scope.7.kind=function
scope.7.startLine=118
scope.7.endLine=125
scope.7.semanticHash=3cb10b96dddc41c7
scope.7.lastMutatedAt=2026-06-23T13:54:22Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:_resolve_drop_rng:129
scope.8.kind=function
scope.8.startLine=129
scope.8.endLine=136
scope.8.semanticHash=35625969cf2d1bad
scope.8.lastMutatedAt=2026-06-23T14:02:49Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
scope.9.id=function:_pick_property_index:138
scope.9.kind=function
scope.9.startLine=138
scope.9.endLine=143
scope.9.semanticHash=53cb6d4b963a86d5
scope.9.lastMutatedAt=2026-06-23T14:02:49Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=2
scope.9.lastMutationKilled=2
scope.10.id=function:anonymous@145:145
scope.10.kind=function
scope.10.startLine=145
scope.10.endLine=171
scope.10.semanticHash=f4452049b1d4d1ee
scope.10.lastMutatedAt=2026-06-23T14:02:49Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=13
scope.10.lastMutationKilled=13
]]
