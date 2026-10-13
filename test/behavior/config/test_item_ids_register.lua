require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end
local item_ids = require("src.config.gameplay.item_ids")

describe("TestItemIdsRegister", function()

  it("test_registers_valid_item", function()
    local map = {}
    item_ids._register_item(map, { key = "test_item", id = 42 })
    _assert_eq(map["test_item"], 42, "item registered with correct id")
  end)

  it("test_skips_nil_config", function()
    local map = {}
    item_ids._register_item(map, nil)
    _assert_eq(next(map), nil, "nil config is skipped")
  end)

  it("test_skips_empty_key", function()
    local map = {}
    item_ids._register_item(map, { key = "", id = 1 })
    _assert_eq(next(map), nil, "empty key is skipped")
  end)

  it("test_skips_nil_key", function()
    local map = {}
    item_ids._register_item(map, { id = 1 })
    _assert_eq(next(map), nil, "nil key is skipped")
  end)

  it("test_errors_on_duplicate_key", function()
    local map = { existing = 1 }
    local ok, err = pcall(item_ids._register_item, map, { key = "existing", id = 2 })
    _assert_eq(ok, false, "duplicate key errors")
    luassert.truthy(err:find("duplicate"), "error mentions duplicate")
  end)


end)
