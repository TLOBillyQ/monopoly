-- foundation.tables 深拷贝直测：M.copy 递归复制、非表透传、引用隔离。

local lu = require("luaunit")
local tables = require("src.foundation.tables")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- 原生 LuaUnit 迁移:两个平级 describe 均无钩子 → 合并为一个 Test* 类,
-- 用例数与改写前一一对应(4 + 3 = 7 例)。

TestTables = {}

function TestTables:test_returns_non_table_values_unchanged()
  _assert_eq(tables.copy(7), 7, "number passes through")
  _assert_eq(tables.copy("hi"), "hi", "string passes through")
  _assert_eq(tables.copy(nil), nil, "nil passes through")
  _assert_eq(tables.copy(true), true, "boolean passes through")
end

function TestTables:test_deep_copies_a_flat_table_into_a_distinct_reference()
  local src = { a = 1, b = 2 }
  local out = tables.copy(src)
  lu.assertEvalToTrue(out ~= src, "copy is a new table reference")
  _assert_eq(out.a, 1, "value a copied")
  _assert_eq(out.b, 2, "value b copied")
end

function TestTables:test_recursively_copies_nested_tables_no_shared_sub_references()
  local src = { outer = { inner = { leaf = 42 } }, list = { 1, 2, 3 } }
  local out = tables.copy(src)
  lu.assertEvalToTrue(out.outer ~= src.outer, "nested table is a distinct reference")
  lu.assertEvalToTrue(out.outer.inner ~= src.outer.inner, "deeply nested table is distinct")
  lu.assertEvalToTrue(out.list ~= src.list, "array-part table is distinct")
  _assert_eq(out.outer.inner.leaf, 42, "leaf value preserved")
  _assert_eq(out.list[2], 2, "array value preserved")
end

function TestTables:test_mutating_the_copy_does_not_affect_the_original()
  local src = { nested = { value = 1 } }
  local out = tables.copy(src)
  out.nested.value = 999
  out.added = "new"
  _assert_eq(src.nested.value, 1, "original nested value untouched")
  _assert_eq(src.added, nil, "original gains no new key")
end

function TestTables:test_creates_a_table_when_the_field_is_missing()
  local t = {}
  local field = tables.ensure_table_field(t, "foo")
  _assert_eq(type(field), "table", "returns a table")
  _assert_eq(t.foo, field, "sets the same table on the input")
end

function TestTables:test_creates_a_table_when_the_field_is_not_a_table()
  local t = { foo = 42 }
  local field = tables.ensure_table_field(t, "foo")
  _assert_eq(type(field), "table", "returns a table")
  _assert_eq(type(t.foo), "table", "replaces non-table value")
  _assert_eq(t.foo, field, "sets the same table on the input")
end

function TestTables:test_returns_the_existing_table_without_modification()
  local existing = { a = 1 }
  local t = { foo = existing }
  local field = tables.ensure_table_field(t, "foo")
  _assert_eq(field, existing, "returns existing table")
  _assert_eq(t.foo.a, 1, "preserves existing contents")
end

function TestTables:test_ensure_field_fills_nil_with_fallback()
  local t = {}
  local field = tables.ensure_field(t, "foo", 7)
  _assert_eq(field, 7, "returns fallback")
  _assert_eq(t.foo, 7, "sets fallback on the input")
end

function TestTables:test_ensure_field_preserves_existing_value_including_false()
  local t = { foo = false }
  local field = tables.ensure_field(t, "foo", 7)
  _assert_eq(field, false, "existing false is preserved")
  _assert_eq(t.foo, false, "input untouched")
end


return TestTables
