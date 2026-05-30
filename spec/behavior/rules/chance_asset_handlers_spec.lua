local asset_handlers = require("src.rules.chance.handlers")._asset
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")

local function _common_with_collectors(events, reset_tiles)
  return {
    emit_event = function(_, _, payload)
      events[#events + 1] = payload
    end,
    dependencies = function()
      return {
        monopoly_event = monopoly_event,
        number_utils = number_utils,
      }
    end,
  }, function(_, tile)
    reset_tiles[#reset_tiles + 1] = tile.id
  end
end

local function _new_handlers(common)
  local handlers = {}
  asset_handlers.register(handlers, common)
  return handlers
end

local function _player_with_properties(property_ids)
  local properties = {}
  for _, id in ipairs(property_ids) do
    properties[id] = true
  end
  return { name = "TestPlayer", properties = properties }
end

local function _board_with_named_tiles()
  return {
    get_tile_by_id = function(_, id)
      return { id = id, name = "Tile" .. tostring(id) }
    end,
  }
end

describe("chance asset handlers", function()
  it("destroy_buildings_on_path emits chance.applied for tile with buildings", function()
    local events = {}
    local common = {
      emit_event = function(_, _, payload)
        events[#events + 1] = payload
      end,
      dependencies = function()
        return { monopoly_event = monopoly_event }
      end,
    }
    local handlers = _new_handlers(common)
    local game = {
      board = {
        get_tile = function(_, idx)
          if idx == 1 then return { type = "land", level = 2, name = "Tile1" } end
          if idx == 2 then return { type = "land", level = 0, name = "Tile2" } end
          if idx == 3 then return { type = "chance", name = "Chance" } end
          return nil
        end,
      },
      set_tile_level = function(_, tile, level)
        tile.level = level
      end,
    }

    handlers.destroy_buildings_on_path(game, {}, {}, { visited = { 1, 2, 3 } })

    assert(#events == 1, "only the land tile with buildings should emit")
    assert(events[1].effect == "destroy_buildings_on_path", "event effect mismatch")
  end)

  it("reset_tiles_on_path resets owned and unowned land tiles, skips non-land", function()
    local events = {}
    local reset_tiles = {}
    local owner_writes = {}
    local common = {
      emit_event = function(_, _, payload)
        events[#events + 1] = payload
      end,
      dependencies = function()
        return {
          monopoly_event = monopoly_event,
          tile_state = function(_, tile)
            return { owner_id = tile.mock_owner }
          end,
        }
      end,
    }
    local handlers = _new_handlers(common)
    local game = {
      board = {
        get_tile = function(_, idx)
          if idx == 1 then return { type = "land", id = "t1", mock_owner = "p1", name = "Tile1" } end
          if idx == 2 then return { type = "land", id = "t2", mock_owner = nil, name = "Tile2" } end
          if idx == 3 then return { type = "chance", id = "t3", name = "Chance" } end
          return nil
        end,
      },
      find_player_by_id = function(_, id)
        return { id = id, properties = { t1 = true } }
      end,
      set_player_property = function(_, _, tile_id, owned)
        owner_writes[tile_id] = owned
      end,
      reset_tile = function(_, tile)
        reset_tiles[#reset_tiles + 1] = tile.id
      end,
    }

    handlers.reset_tiles_on_path(game, {}, {}, { visited = { 1, 2, 3 } })

    assert(#events == 2, "only the two land tiles should emit")
    assert(events[1].effect == "reset_tiles_on_path", "event effect mismatch")
    assert(reset_tiles[1] == "t1" and reset_tiles[2] == "t2", "both land tiles should reset in order")
    assert(owner_writes["t1"] == false, "owned land should clear its owner")
  end)

  it("discard_properties with count 0 drops every property the player owns", function()
    local events = {}
    local reset_tiles = {}
    local common, reset_tile = _common_with_collectors(events, reset_tiles)
    local handlers = _new_handlers(common)
    local game = {
      board = _board_with_named_tiles(),
      reset_tile = reset_tile,
      set_player_property = function() end,
    }
    local player = _player_with_properties({ "t1", "t2", "t3" })
    local card = { count = 0 }

    handlers.discard_properties(game, player, card)

    assert(#reset_tiles == 3, "count=0 should drop all three properties")
    assert(#events == 3, "one chance.applied event per dropped tile")
  end)

  it("discard_properties stops when properties run out before count", function()
    local events = {}
    local reset_tiles = {}
    local common, reset_tile = _common_with_collectors(events, reset_tiles)
    local handlers = _new_handlers(common)
    local game = {
      board = _board_with_named_tiles(),
      reset_tile = reset_tile,
      set_player_property = function() end,
    }
    local player = _player_with_properties({ "t1" })
    local card = { count = 5 }

    handlers.discard_properties(game, player, card)

    assert(#reset_tiles == 1, "loop should break after the only property is dropped")
    assert(#events == 1, "only one event when only one property exists")
  end)

  it("discard_properties is a no-op when the player owns nothing", function()
    local events = {}
    local reset_tiles = {}
    local common, reset_tile = _common_with_collectors(events, reset_tiles)
    local handlers = _new_handlers(common)
    local game = {
      board = { get_tile_by_id = function() return nil end },
      reset_tile = reset_tile,
      set_player_property = function() end,
    }
    local player = _player_with_properties({})
    local card = { count = 2 }

    handlers.discard_properties(game, player, card)

    assert(#reset_tiles == 0, "no properties means no resets")
    assert(#events == 0, "no events should fire")
  end)
end)
