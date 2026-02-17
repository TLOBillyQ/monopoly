local utils = require("chance.utils")

local property_effects = {}

function property_effects.register(registry)
  registry:register("destroy_buildings_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" and (t.level or 0) > 0 then
        game:set_tile_level(t, 0)
        utils.emit_event(utils.monopoly_event.chance.applied, {
          card = { effect = "destroy_buildings_on_path" },
          effect = "destroy_buildings_on_path",
          tile = t,
          text = "台风摧毁 " .. t.name .. " 上的建筑",
        })
      end
    end
  end)

  registry:register("reset_tiles_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" then
        local st = utils.tile_state(game, t)
        assert(st ~= nil, "missing tile state: " .. tostring(t.id))
        if st.owner_id then
          local owner = assert(game:find_player_by_id(st.owner_id), "missing owner: " .. tostring(st.owner_id))
          game:set_player_property(owner, t.id, false)
        end
        game:reset_tile(t)
        utils.emit_event(utils.monopoly_event.chance.applied, {
          card = { effect = "reset_tiles_on_path" },
          effect = "reset_tiles_on_path",
          tile = t,
          text = "强制征地重置 " .. t.name,
        })
      end
    end
  end)

  registry:register("discard_properties", function(game, player, card)
    local to_drop = card.count
    local property_ids = {}
    for tile_id in pairs(player.properties or {}) do
      property_ids[#property_ids + 1] = tile_id
    end
    table.sort(property_ids, function(a, b)
      local ai = utils.number_utils.to_integer(a)
      local bi = utils.number_utils.to_integer(b)
      if ai ~= nil and bi ~= nil then
        return ai < bi
      end
      return tostring(a) < tostring(b)
    end)
    for _, tile_id in ipairs(property_ids) do
      local tile = game.board:get_tile_by_id(tile_id)
      assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
      game:reset_tile(tile)
      utils.emit_event(utils.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        tile = tile,
        text = player.name .. " 丢失地块 " .. tile.name,
      })
      game:set_player_property(player, tile_id, false)
      to_drop = to_drop - 1
      if to_drop == 0 then
        break
      end
    end
  end)
end

return property_effects
