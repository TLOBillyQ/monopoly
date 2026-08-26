local achievement_progress = require("src.rules.ports.achievement_progress")
local gain_reveal = require("src.rules.items.gain_reveal")

local asset_handlers = {}

function asset_handlers.register(handlers, common)
  local deps = common.dependencies()

  local function _has_building(t)
    return t.type == "land" and (t.level or 0) > 0
  end

  local function _resolve_owner(game, st)
    if st and st.owner_id then
      return game:find_player_by_id(st.owner_id)
    end
    return nil
  end

  local function _destroy_building_on_path_index(game, idx)
    local t = game.board:get_tile(idx)
    assert(t ~= nil, "missing tile: " .. tostring(idx))
    if not _has_building(t) then
      return
    end
    local st = deps.tile_state and deps.tile_state(game, t) or t
    local owner = _resolve_owner(game, st)
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
      local item = deps.inventory.remove_nth_occupied(player, rng:next_int(1, item_count))
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
version=4
projectHash=69a79661edb3a6cd
scope.0.id=chunk:src/rules/chance/asset_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=185
scope.0.semanticHash=c09099b615f26fcd
scope.1.id=function:asset_handlers.register
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=182
scope.1.semanticHash=9b90ce57310e3cf9
scope.2.id=function:_has_building
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=70ff0afdb975d75a
scope.3.id=function:_resolve_owner
scope.3.kind=function
scope.3.startLine=13
scope.3.endLine=18
scope.3.semanticHash=ce7b632d478013ec
scope.4.id=function:_destroy_building_on_path_index
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=38
scope.4.semanticHash=dbdb883f3ab8ea2e
scope.5.id=function:handlers.destroy_buildings_on_path
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=45
scope.5.semanticHash=e6337cc5a7317ecb
scope.6.id=function:_reset_tile_on_path_index
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=66
scope.6.semanticHash=383c876bb6b6de2b
scope.7.id=function:handlers.reset_tiles_on_path
scope.7.kind=function
scope.7.startLine=68
scope.7.endLine=73
scope.7.semanticHash=e6337cc5a7317ecb
scope.8.id=function:handlers.grant_item
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=80
scope.8.semanticHash=178880327db6fff2
scope.9.id=function:_discard_count
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=88
scope.9.semanticHash=198f87b9190b8aa5
scope.10.id=function:_discard_random_items
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=103
scope.10.semanticHash=0cdada6d0edf1678
scope.11.id=function:_discard_items_text
scope.11.kind=function
scope.11.startLine=105
scope.11.endLine=111
scope.11.semanticHash=ceed17ffc0fe22df
scope.12.id=function:handlers.discard_items
scope.12.kind=function
scope.12.startLine=113
scope.12.endLine=122
scope.12.semanticHash=f880bc629b0d040a
scope.13.id=function:_sorted_property_ids
scope.13.kind=function
scope.13.startLine=124
scope.13.endLine=138
scope.13.semanticHash=13b8e0c64902147d
scope.14.id=function:<anonymous>
scope.14.kind=function
scope.14.startLine=129
scope.14.endLine=136
scope.14.semanticHash=1e0bd63309b63eeb
scope.15.id=function:_resolve_drop_rng
scope.15.kind=function
scope.15.startLine=140
scope.15.endLine=147
scope.15.semanticHash=ab0f7449a0ae876b
scope.16.id=function:_pick_property_index
scope.16.kind=function
scope.16.startLine=149
scope.16.endLine=154
scope.16.semanticHash=43682141871d4cdd
scope.17.id=function:handlers.discard_properties
scope.17.kind=function
scope.17.startLine=156
scope.17.endLine=181
scope.17.semanticHash=d4306e970a8b0496
]]
