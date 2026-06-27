local tile_renderer = require("src.ui.render.tile")
local tiles_cfg = require("src.config.content.tiles")

local function _make_unit(captured)
  return {
    get_child_by_name = function(name)
      if name == "name" then
        return {
          set_billboard_text = function(text)
            captured.name = text
          end,
        }
      end
      if name == "price" then
        return {
          set_billboard_text = function(text)
            captured.price = text
          end,
        }
      end
      if name == "color" then
        return {
          set_paint_area_color = function(_, color)
            captured.color = color
          end,
        }
      end
      return nil
    end,
  }
end

local function _make_unit_without_price_node(captured)
  return {
    get_child_by_name = function(name)
      if name == "name" then
        return {
          set_billboard_text = function(text)
            captured.name = text
          end,
        }
      end
      if name == "color" then
        return {
          set_paint_area_color = function(_, color)
            captured.color = color
          end,
        }
      end
      return nil
    end,
  }
end

local function _find_tile_by_type(typ)
  for _, cfg in ipairs(tiles_cfg) do
    if cfg.type == typ then
      return cfg
    end
  end
  return nil
end

local function _land_tile_id()
  local cfg = _find_tile_by_type("land")
  return cfg and cfg.id or 1
end

local function _assert_start_cfg(cfg)
  assert(cfg ~= nil, "start tile must exist in config")
  return cfg
end

describe("tile_renderer", function()
  describe("_rent_for_level via render_tile", function()
    it("calculates base rent (50% of price) at level 0", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, 2, "owner", 0)
      local expected_rent = math.floor(cfg.price * 0.5)
      local expected_text = "owner\n租 " .. tostring(expected_rent)
      assert(captured.price == expected_text,
        "level 0 rent should be 50% of price, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
    end)

    it("calculates 2x rent at level 1", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, 2, "owner", 1)
      local expected_rent = math.floor(cfg.price * 1.0)
      local expected_text = "owner\n租 " .. tostring(expected_rent)
      assert(captured.price == expected_text,
        "level 1 rent should equal price, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
    end)

    it("calculates 4x rent at level 2", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, 2, "owner", 2)
      local expected_rent = math.floor(cfg.price * 2.0)
      local expected_text = "owner\n租 " .. tostring(expected_rent)
      assert(captured.price == expected_text,
        "level 2 rent should be 2x price, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
    end)

    it("clamps rent at max level when level exceeds upgrade_costs count", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      local max_level = #(cfg.upgrade_costs or {})
      tile_renderer.render_tile(unit, tile_id, 2, "owner", max_level + 5)
      local expected_rent = math.floor(cfg.price * (2 ^ max_level) * 0.5)
      local expected_text = "owner\n租 " .. tostring(expected_rent)
      assert(captured.price == expected_text,
        "rent should be clamped at max level " .. max_level .. ", expected: " .. expected_text .. ", got: " .. tostring(captured.price))
    end)

    it("clamps negative level to 0", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, 2, "owner", -3)
      local expected_rent = math.floor(cfg.price * 0.5)
      local expected_text = "owner\n租 " .. tostring(expected_rent)
      assert(captured.price == expected_text,
        "negative level should be clamped to 0, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
    end)

    it("treats nil level as level 0", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, 2, "owner", nil)
      local expected_rent = math.floor(cfg.price * 0.5)
      local expected_text = "owner\n租 " .. tostring(expected_rent)
      assert(captured.price == expected_text,
        "nil level should default to 0, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
    end)

    it("returns nil rent for tile with zero price (rent is 0, not displayed as rent)", function()
      local captured = {}
      local unit = _make_unit(captured)
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      tile_renderer.render_tile(unit, start_cfg.id, nil, "owner", 0)
      assert(captured.price == "owner",
        "zero-price tile should show only owner name, got: " .. tostring(captured.price))
    end)
  end)

  describe("_render_price branching", function()
    it("shows sale price when owner_name is nil", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, nil, nil, 0)
      local expected = "售 " .. tostring(cfg.price)
      assert(captured.price == expected,
        "no-owner tile should show sale price, expected: " .. expected .. ", got: " .. tostring(captured.price))
    end)

    it("shows contiguous rent total when provided", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      tile_renderer.render_tile(unit, tile_id, 2, "P1", 0, 300)
      local expected = "P1\n租 300"
      assert(captured.price == expected,
        "contiguous rent should show the final total, expected: " .. expected .. ", got: " .. tostring(captured.price))
    end)

    it("uses single tile rent when contiguous rent is nil", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      local cfg = tiles_cfg[tile_id]
      tile_renderer.render_tile(unit, tile_id, 2, "P1", 0, nil)
      local expected_rent = math.floor(cfg.price * 0.5)
      local expected = "P1\n租 " .. tostring(expected_rent)
      assert(captured.price == expected,
        "nil contiguous rent should use single tile rent, expected: " .. expected .. ", got: " .. tostring(captured.price))
    end)

    it("uses explicit contiguous rent without suffix", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      tile_renderer.render_tile(unit, tile_id, 2, "P1", 0, 1)
      local expected = "P1\n租 1"
      assert(captured.price == expected,
        "explicit contiguous rent should not append a suffix, expected: " .. expected .. ", got: " .. tostring(captured.price))
    end)
  end)

  describe("non-land tile rendering", function()
    it("renders non-land tile without asserting on price node", function()
      local captured = {}
      local unit = _make_unit_without_price_node(captured)
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      local ok, err = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
      assert(ok, "non-land tile without price node should not assert: " .. tostring(err))
      assert(captured.name == start_cfg.name,
        "non-land tile should still render name, got: " .. tostring(captured.name))
    end)

    it("non-land tile with owner shows owner name without rent", function()
      local captured = {}
      local unit = _make_unit(captured)
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      tile_renderer.render_tile(unit, start_cfg.id, nil, "P1", 0)
      assert(captured.price == "P1",
        "non-land owned tile should show only owner name, got: " .. tostring(captured.price))
    end)

    it("non-land tile without billboard node skips assert and survives", function()
      local unit = {
        get_child_by_name = function() return nil end,
      }
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      local ok, err = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
      assert(ok,
        "non-land tile with no nodes at all should not assert: " .. tostring(err))
    end)

    it("non-land tile with name node lacking set_billboard_text survives", function()
      local unit = {
        get_child_by_name = function(name)
          if name == "name" then
            return {}  -- node exists but no set_billboard_text
          end
          if name == "price" then
            return { set_billboard_text = function() end }
          end
          return nil
        end,
      }
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      local ok = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
      assert(ok, "non-land tile with name node lacking method should not crash")
    end)

    it("non-land tile with price node lacking set_billboard_text survives", function()
      local unit = {
        get_child_by_name = function(name)
          if name == "name" then
            return { set_billboard_text = function() end }
          end
          if name == "price" then
            return {}  -- node exists but no set_billboard_text
          end
          return nil
        end,
      }
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      local ok = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
      assert(ok, "non-land tile with price node lacking method should not crash")
    end)

    it("non-land tile with color node lacking set_paint_area_color survives", function()
      local unit = {
        get_child_by_name = function(name)
          if name == "name" then
            return { set_billboard_text = function() end }
          end
          if name == "price" then
            return { set_billboard_text = function() end }
          end
          if name == "color" then
            return {}  -- node exists but no set_paint_area_color
          end
          return nil
        end,
      }
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      local ok = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
      assert(ok, "non-land tile with color node lacking method should not crash")
    end)
  end)

  describe("land tile asserts", function()
    it("asserts when land tile price node is missing", function()
      local captured = {}
      local unit = _make_unit_without_price_node(captured)
      local tile_id = _land_tile_id()
      local ok = pcall(tile_renderer.render_tile, unit, tile_id, 2, "owner", 0)
      assert(not ok, "land tile missing price node should assert")
    end)

    it("asserts when land tile name node is missing", function()
      local unit = {
        get_child_by_name = function(name)
          if name == "price" then
            return { set_billboard_text = function() end }
          end
          if name == "color" then
            return { set_paint_area_color = function() end }
          end
          return nil
        end,
      }
      local tile_id = _land_tile_id()
      local ok = pcall(tile_renderer.render_tile, unit, tile_id, 2, "owner", 0)
      assert(not ok, "land tile missing name node should assert")
    end)

    it("asserts when tile_id is not in config", function()
      local captured = {}
      local unit = _make_unit(captured)
      local ok = pcall(tile_renderer.render_tile, unit, 99999, nil, nil, 0)
      assert(not ok, "unknown tile_id should assert")
    end)
  end)

  describe("color rendering", function()
    it("renders owner color for owned land tile", function()
      local captured = {}
      local unit = _make_unit(captured)
      local tile_id = _land_tile_id()
      tile_renderer.render_tile(unit, tile_id, 3, "owner", 0)
      assert(captured.color ~= nil,
        "owned land tile should render owner color")
    end)

    it("skips color silently on non-land tile without color node", function()
      local unit = {
        get_child_by_name = function(name)
          if name == "name" then
            return { set_billboard_text = function() end }
          end
          if name == "price" then
            return { set_billboard_text = function() end }
          end
          return nil
        end,
      }
      local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
      local ok, err = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
      assert(ok,
        "non-land tile without color node should not assert: " .. tostring(err))
    end)

    it("asserts when land tile color node is missing", function()
      local unit = {
        get_child_by_name = function(name)
          if name == "name" then
            return { set_billboard_text = function() end }
          end
          if name == "price" then
            return { set_billboard_text = function() end }
          end
          return nil
        end,
      }
      local tile_id = _land_tile_id()
      local ok = pcall(tile_renderer.render_tile, unit, tile_id, 2, "owner", 0)
      assert(not ok, "land tile missing color node should assert")
    end)
  end)
end)
