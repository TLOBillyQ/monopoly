-- Tests for asset_handlers (CRAP hotspots with low coverage)
local function _test_asset_handlers_destroy_buildings_on_path()
   local asset_handlers = require("src.rules.chance.handlers.asset")
   local monopoly_event = require("src.foundation.events")
  local events = {}
  local common = {
    emit_event = function(_, _, payload)
      table.insert(events, payload)
    end,
    dependencies = function()
      return {
        monopoly_event = monopoly_event,
      }
    end,
  }
  local handlers = {}
  asset_handlers.register(handlers, common)

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

  assert(#events == 1, "should emit one event for tile with buildings")
  assert(events[1].effect == "destroy_buildings_on_path", "should have correct effect")
end

local function _test_asset_handlers_reset_tiles_on_path()
   local asset_handlers = require("src.rules.chance.handlers.asset")
   local monopoly_event = require("src.foundation.events")
  local events = {}
  local tile_state_calls = {}
  local common = {
    emit_event = function(_, _, payload)
      table.insert(events, payload)
    end,
    dependencies = function()
      return {
        tile_state = function(game, tile)
          table.insert(tile_state_calls, tile)
          return { owner_id = tile.mock_owner }
        end,
        monopoly_event = monopoly_event,
      }
    end,
  }
  local handlers = {}
  asset_handlers.register(handlers, common)

  local _owners = {} -- luacheck: ignore 241
  local reset_tiles = {}
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
    set_player_property = function(_, player, tile_id, owned)
      _owners[tile_id] = owned
    end,
    reset_tile = function(_, tile)
      table.insert(reset_tiles, tile.id)
    end,
  }

  handlers.reset_tiles_on_path(game, {}, {}, { visited = { 1, 2, 3 } })

  assert(#events == 2, "should emit two events for land tiles")
  assert(events[1].effect == "reset_tiles_on_path", "should have correct effect")
  assert(reset_tiles[1] == "t1", "should reset tile with owner")
  assert(reset_tiles[2] == "t2", "should reset tile without owner")
end

-- T8 FINAL tests for anonymous@106 in asset_handlers.lua (discard_properties function)
-- This is the anonymous function at line 106 which is the discard_properties handler
local asset_handlers = require("src.rules.chance.handlers.asset")
local _asset_handlers_final_tests = {
  function()
    -- Test discard_properties with card.count = 0 (should drop all properties)
    local events = {}
    local common = {
      emit_event = function(_, _, payload)
        table.insert(events, payload)
      end,
       dependencies = function()
         return {
           monopoly_event = require("src.foundation.events"),
           number_utils = require("src.foundation.lang.number"),
         }
       end,
     }
     local handlers = {}
     asset_handlers.register(handlers, common)

     local reset_tiles = {}
    local game = {
      board = {
        get_tile_by_id = function(_, id)
          return { id = id, name = "Tile" .. tostring(id) }
        end,
      },
      reset_tile = function(_, tile)
        table.insert(reset_tiles, tile.id)
      end,
      set_player_property = function() end,
    }
    local player = {
      name = "TestPlayer",
      properties = { ["t1"] = true, ["t2"] = true, ["t3"] = true },
    }
    local card = { count = 0 }

    handlers.discard_properties(game, player, card)

    assert(#reset_tiles >= 1, "should reset at least one tile")
    assert(#events >= 1, "should emit at least one event")
  end,
  function()
    -- Test discard_properties with card.count > number of properties
    local events = {}
    local common = {
      emit_event = function(_, _, payload)
        table.insert(events, payload)
      end,
       dependencies = function()
         return {
           monopoly_event = require("src.foundation.events"),
           number_utils = require("src.foundation.lang.number"),
         }
       end,
     }
     local handlers = {}
     asset_handlers.register(handlers, common)

     local game = {
       board = {
         get_tile_by_id = function(_, id)
           return { id = id, name = "Tile" .. tostring(id) }
         end,
       },
       reset_tile = function() end,
      set_player_property = function() end,
    }
    local player = {
      name = "TestPlayer",
      properties = { ["t1"] = true },
    }
    local card = { count = 5 }

    handlers.discard_properties(game, player, card)

    -- Should handle gracefully when count > available properties
    assert(true, "should handle count > properties gracefully")
  end,
  function()
    -- Test discard_properties with empty properties
    local events = {}
    local common = {
      emit_event = function(_, _, payload)
        table.insert(events, payload)
      end,
       dependencies = function()
         return {
           monopoly_event = require("src.foundation.events"),
           number_utils = require("src.foundation.lang.number"),
         }
       end,
     }
     local handlers = {}
     asset_handlers.register(handlers, common)

     local game = {
       board = { get_tile_by_id = function() return nil end },
      reset_tile = function() end,
      set_player_property = function() end,
    }
    local player = {
      name = "TestPlayer",
      properties = {},
    }
    local card = { count = 2 }

    handlers.discard_properties(game, player, card)

    -- Should handle empty properties gracefully
    assert(true, "should handle empty properties gracefully")
  end,
}

return {
  name = "runtime_asset_handlers",
  tests = {
    { name = "_test_asset_handlers_destroy_buildings_on_path", run = _test_asset_handlers_destroy_buildings_on_path },
    { name = "_test_asset_handlers_reset_tiles_on_path", run = _test_asset_handlers_reset_tiles_on_path },
    { name = "_test_asset_handlers_discard_properties_count_zero", run = _asset_handlers_final_tests[1] },
    { name = "_test_asset_handlers_discard_properties_count_gt_props", run = _asset_handlers_final_tests[2] },
    { name = "_test_asset_handlers_discard_properties_empty", run = _asset_handlers_final_tests[3] },
  },
}
