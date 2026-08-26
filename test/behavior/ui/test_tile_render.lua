-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):describe/it 拍平为文件级 Test*
-- 类,断言从 luassert 兼容层切到 lu.assertXxx,用例数与改写前一一对应(24 例)。
local lu = require("luaunit")
local tile_renderer = require("src.ui.render.board.tile")
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

TestTileRender = {}

function TestTileRender:test_calculates_base_rent_50_of_price_at_level_0()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, 2, "owner", 0)
  local expected_rent = math.floor(cfg.price * 0.5)
  local expected_text = "owner\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected_text,
    "level 0 rent should be 50% of price, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_calculates_2x_rent_at_level_1()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, 2, "owner", 1)
  local expected_rent = math.floor(cfg.price * 1.0)
  local expected_text = "owner\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected_text,
    "level 1 rent should equal price, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_calculates_4x_rent_at_level_2()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, 2, "owner", 2)
  local expected_rent = math.floor(cfg.price * 2.0)
  local expected_text = "owner\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected_text,
    "level 2 rent should be 2x price, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_clamps_rent_at_max_level_when_level_exceeds_upgrade_costs_count()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  local max_level = #(cfg.upgrade_costs or {})
  tile_renderer.render_tile(unit, tile_id, 2, "owner", max_level + 5)
  local expected_rent = math.floor(cfg.price * (2 ^ max_level) * 0.5)
  local expected_text = "owner\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected_text,
    "rent should be clamped at max level " .. max_level .. ", expected: " .. expected_text .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_clamps_negative_level_to_0()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, 2, "owner", -3)
  local expected_rent = math.floor(cfg.price * 0.5)
  local expected_text = "owner\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected_text,
    "negative level should be clamped to 0, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_treats_nil_level_as_level_0()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, 2, "owner", nil)
  local expected_rent = math.floor(cfg.price * 0.5)
  local expected_text = "owner\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected_text,
    "nil level should default to 0, expected: " .. expected_text .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_returns_nil_rent_for_tile_with_zero_price()
  local captured = {}
  local unit = _make_unit(captured)
  local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
  tile_renderer.render_tile(unit, start_cfg.id, nil, "owner", 0)
  lu.assertEvalToTrue(captured.price == "owner",
    "zero-price tile should show only owner name, got: " .. tostring(captured.price))
end

function TestTileRender:test_shows_sale_price_when_owner_name_is_nil()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, nil, nil, 0)
  local expected = "售 " .. tostring(cfg.price)
  lu.assertEvalToTrue(captured.price == expected,
    "no-owner tile should show sale price, expected: " .. expected .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_shows_sale_price_without_decimal_suffix_for_float_input()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  local old_price = cfg.price
  cfg.price = 1000.0
  local ok, err = xpcall(function()
    tile_renderer.render_tile(unit, tile_id, nil, nil, 0)
    lu.assertEvalToTrue(captured.price == "售 1000",
      "float sale price should render as integer text, got: " .. tostring(captured.price))
  end, debug.traceback or function(e) return e end)
  cfg.price = old_price
  if not ok then
    error(err)
  end
end

function TestTileRender:test_shows_contiguous_rent_total_when_provided()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  tile_renderer.render_tile(unit, tile_id, 2, "P1", 0, 300.0)
  local expected = "P1\n租 300"
  lu.assertEvalToTrue(captured.price == expected,
    "contiguous rent should show the final total, expected: " .. expected .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_uses_single_tile_rent_when_contiguous_rent_is_nil()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  local cfg = tiles_cfg[tile_id]
  tile_renderer.render_tile(unit, tile_id, 2, "P1", 0, nil)
  local expected_rent = math.floor(cfg.price * 0.5)
  local expected = "P1\n租 " .. tostring(expected_rent)
  lu.assertEvalToTrue(captured.price == expected,
    "nil contiguous rent should use single tile rent, expected: " .. expected .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_uses_explicit_contiguous_rent_without_suffix()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  tile_renderer.render_tile(unit, tile_id, 2, "P1", 0, 1)
  local expected = "P1\n租 1"
  lu.assertEvalToTrue(captured.price == expected,
    "explicit contiguous rent should not append a suffix, expected: " .. expected .. ", got: " .. tostring(captured.price))
end

function TestTileRender:test_renders_non_land_tile_without_asserting_on_price_node()
  local captured = {}
  local unit = _make_unit_without_price_node(captured)
  local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
  local ok, err = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
  lu.assertEvalToTrue(ok, "non-land tile without price node should not assert: " .. tostring(err))
  lu.assertEvalToTrue(captured.name == start_cfg.name,
    "non-land tile should still render name, got: " .. tostring(captured.name))
end

function TestTileRender:test_non_land_tile_with_owner_shows_owner_name_without_rent()
  local captured = {}
  local unit = _make_unit(captured)
  local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
  tile_renderer.render_tile(unit, start_cfg.id, nil, "P1", 0)
  lu.assertEvalToTrue(captured.price == "P1",
    "non-land owned tile should show only owner name, got: " .. tostring(captured.price))
end

function TestTileRender:test_non_land_tile_without_billboard_node_skips_assert_and_survives()
  local unit = {
    get_child_by_name = function() return nil end,
  }
  local start_cfg = _assert_start_cfg(_find_tile_by_type("start"))
  local ok, err = pcall(tile_renderer.render_tile, unit, start_cfg.id, nil, nil, 0)
  lu.assertEvalToTrue(ok,
    "non-land tile with no nodes at all should not assert: " .. tostring(err))
end

function TestTileRender:test_non_land_tile_with_name_node_lacking_set_billboard_text_survives()
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
  lu.assertEvalToTrue(ok, "non-land tile with name node lacking method should not crash")
end

function TestTileRender:test_non_land_tile_with_price_node_lacking_set_billboard_text_survives()
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
  lu.assertEvalToTrue(ok, "non-land tile with price node lacking method should not crash")
end

function TestTileRender:test_non_land_tile_with_color_node_lacking_set_paint_area_color_survives()
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
  lu.assertEvalToTrue(ok, "non-land tile with color node lacking method should not crash")
end

function TestTileRender:test_asserts_when_land_tile_price_node_is_missing()
  local captured = {}
  local unit = _make_unit_without_price_node(captured)
  local tile_id = _land_tile_id()
  local ok = pcall(tile_renderer.render_tile, unit, tile_id, 2, "owner", 0)
  lu.assertEvalToTrue(not ok, "land tile missing price node should assert")
end

function TestTileRender:test_asserts_when_land_tile_name_node_is_missing()
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
  lu.assertEvalToTrue(not ok, "land tile missing name node should assert")
end

function TestTileRender:test_asserts_when_tile_id_is_not_in_config()
  local captured = {}
  local unit = _make_unit(captured)
  local ok = pcall(tile_renderer.render_tile, unit, 99999, nil, nil, 0)
  lu.assertEvalToTrue(not ok, "unknown tile_id should assert")
end

function TestTileRender:test_renders_owner_color_for_owned_land_tile()
  local captured = {}
  local unit = _make_unit(captured)
  local tile_id = _land_tile_id()
  tile_renderer.render_tile(unit, tile_id, 3, "owner", 0)
  lu.assertEvalToTrue(captured.color ~= nil,
    "owned land tile should render owner color")
end

function TestTileRender:test_skips_color_silently_on_non_land_tile_without_color_node()
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
  lu.assertEvalToTrue(ok,
    "non-land tile without color node should not assert: " .. tostring(err))
end

function TestTileRender:test_asserts_when_land_tile_color_node_is_missing()
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
  lu.assertEvalToTrue(not ok, "land tile missing color node should assert")
end


return TestTileRender
