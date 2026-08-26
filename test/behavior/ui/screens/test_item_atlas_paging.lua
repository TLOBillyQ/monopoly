local lu = require("luaunit")
local property = require("test.support.property")
local atlas_state = require("src.ui.screens.item_atlas.item_atlas_state")
local item_atlas_nodes = require("src.ui.schema.item_atlas")

local PAGE = item_atlas_nodes.page_size

-- 图鉴翻页/取物纯逻辑住 item_atlas_state 卫星。这里把页码钳制的界与幂等、
-- 槽位到全局目录下标的对应关系钉成属性,门面(screens/item_atlas.lua)的
-- 开屏/翻页/选择行为全部踩在这几条不变量上。

local function _build_catalog(rng)
  local n = rng:int(1, PAGE * 4)
  local catalog = {}
  for i = 1, n do
    catalog[i] = { id = "item" .. i, name = "道具" .. i }
  end
  return { catalog = catalog, n = n }
end

TestItemAtlasPaging = {}

do
  function TestItemAtlasPaging:tearDown()
    atlas_state.set_catalog(nil)
  end

  TestItemAtlasPaging["test_clamp_page always lands in [1, page_count] for any integer input"] = function(self)
    property.for_all(function(rng)
      local case = _build_catalog(rng)
      case.page_input = rng:int(-999, 999)
      return case
    end, function(case)
      atlas_state.set_catalog(case.catalog)
      local pages = math.max(1, math.ceil(case.n / PAGE))
      local clamped = atlas_state.clamp_page(case.page_input)
      lu.assertEvalToTrue(clamped >= 1 and clamped <= pages,
        "clamped page " .. tostring(clamped) .. " must lie in [1, " .. pages .. "]")
      lu.assertEvalToTrue(atlas_state.clamp_page(clamped) == clamped,
        "clamping must be idempotent")
    end)
  end

  TestItemAtlasPaging["test_clamp_page pins non-numeric input to page 1"] = function(self)
    property.for_all(_build_catalog, function(case, rng)
      atlas_state.set_catalog(case.catalog)
      local junk = rng:pick({ "not-a-page", {}, false })
      lu.assertEvalToTrue(atlas_state.clamp_page(junk) == 1,
        "non-numeric page input must clamp to 1")
      lu.assertEvalToTrue(atlas_state.clamp_page(nil) == 1,
        "nil page input must clamp to 1")
    end)
  end

  TestItemAtlasPaging["test_item_at maps (page, slot) to the matching global catalog entry and nil past the end"] = function(self)
    property.for_all(function(rng)
      local case = _build_catalog(rng)
      case.page = rng:int(1, math.max(1, math.ceil(case.n / PAGE)))
      case.slot = rng:int(1, PAGE)
      return case
    end, function(case)
      atlas_state.set_catalog(case.catalog)
      local global_index = (case.page - 1) * PAGE + case.slot
      local expected = case.catalog[global_index]
      local actual = atlas_state.item_at({ page_index = case.page }, case.slot)
      lu.assertEvalToTrue(actual == expected,
        "slot " .. case.slot .. " on page " .. case.page
        .. " must resolve to catalog[" .. global_index .. "]")
    end)
  end

  TestItemAtlasPaging["test_set_catalog(nil) restores the default catalog"] = function(self)
    local default_catalog = atlas_state.catalog()
    property.for_all(_build_catalog, function(case)
      atlas_state.set_catalog(case.catalog)
      lu.assertEvalToTrue(atlas_state.catalog() == case.catalog, "set_catalog must install the injected catalog")
      atlas_state.set_catalog(nil)
      lu.assertEvalToTrue(atlas_state.catalog() == default_catalog, "set_catalog(nil) must restore the default")
    end)
  end
end


return TestItemAtlasPaging
