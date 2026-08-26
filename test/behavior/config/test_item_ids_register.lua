local lu = require("luaunit")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local item_ids = require("src.config.gameplay.item_ids")

TestItemIdsRegister = {}

function TestItemIdsRegister:test_registers_valid_item()
  local map = {}
  item_ids._register_item(map, { key = "test_item", id = 42 })
  _assert_eq(map["test_item"], 42, "item registered with correct id")
end

function TestItemIdsRegister:test_skips_nil_config()
  local map = {}
  item_ids._register_item(map, nil)
  _assert_eq(next(map), nil, "nil config is skipped")
end

function TestItemIdsRegister:test_skips_empty_key()
  local map = {}
  item_ids._register_item(map, { key = "", id = 1 })
  _assert_eq(next(map), nil, "empty key is skipped")
end

function TestItemIdsRegister:test_skips_nil_key()
  local map = {}
  item_ids._register_item(map, { id = 1 })
  _assert_eq(next(map), nil, "nil key is skipped")
end

function TestItemIdsRegister:test_errors_on_duplicate_key()
  local map = { existing = 1 }
  local ok, err = pcall(item_ids._register_item, map, { key = "existing", id = 2 })
  _assert_eq(ok, false, "duplicate key errors")
  lu.assertEvalToTrue(err:find("duplicate"), "error mentions duplicate")
end


return TestItemIdsRegister
