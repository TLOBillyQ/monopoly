require("test.bootstrap").install_package_paths()

-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local tables = require("src.foundation.tables")

-- 文件内局部断言 helper:调用点与语义(值相等,即 `==`)不变,只把后端换成
-- luassert 的 is.equal(expected, actual, message)——参数顺序翻过来。表不做深比较
-- 是有意的:这里的期望值本来就是「同一个引用」。
local function _assert_eq(a, b, msg)
  luassert.is.equal(b, a, msg)
end


describe("TestTables", function()

  it("test_returns_non_table_values_unchanged", function()
    _assert_eq(tables.copy(7), 7, "number passes through")
    _assert_eq(tables.copy("hi"), "hi", "string passes through")
    _assert_eq(tables.copy(nil), nil, "nil passes through")
    _assert_eq(tables.copy(true), true, "boolean passes through")
  end)

  it("test_deep_copies_a_flat_table_into_a_distinct_reference", function()
    local src = { a = 1, b = 2 }
    local out = tables.copy(src)
    luassert.truthy(out ~= src, "copy is a new table reference")
    _assert_eq(out.a, 1, "value a copied")
    _assert_eq(out.b, 2, "value b copied")
  end)

  it("test_recursively_copies_nested_tables_no_shared_sub_references", function()
    local src = { outer = { inner = { leaf = 42 } }, list = { 1, 2, 3 } }
    local out = tables.copy(src)
    luassert.truthy(out.outer ~= src.outer, "nested table is a distinct reference")
    luassert.truthy(out.outer.inner ~= src.outer.inner, "deeply nested table is distinct")
    luassert.truthy(out.list ~= src.list, "array-part table is distinct")
    _assert_eq(out.outer.inner.leaf, 42, "leaf value preserved")
    _assert_eq(out.list[2], 2, "array value preserved")
  end)

  it("test_mutating_the_copy_does_not_affect_the_original", function()
    local src = { nested = { value = 1 } }
    local out = tables.copy(src)
    out.nested.value = 999
    out.added = "new"
    _assert_eq(src.nested.value, 1, "original nested value untouched")
    _assert_eq(src.added, nil, "original gains no new key")
  end)

  it("test_creates_a_table_when_the_field_is_missing", function()
    local t = {}
    local field = tables.ensure_table_field(t, "foo")
    _assert_eq(type(field), "table", "returns a table")
    _assert_eq(t.foo, field, "sets the same table on the input")
  end)

  it("test_creates_a_table_when_the_field_is_not_a_table", function()
    local t = { foo = 42 }
    local field = tables.ensure_table_field(t, "foo")
    _assert_eq(type(field), "table", "returns a table")
    _assert_eq(type(t.foo), "table", "replaces non-table value")
    _assert_eq(t.foo, field, "sets the same table on the input")
  end)

  it("test_returns_the_existing_table_without_modification", function()
    local existing = { a = 1 }
    local t = { foo = existing }
    local field = tables.ensure_table_field(t, "foo")
    _assert_eq(field, existing, "returns existing table")
    _assert_eq(t.foo.a, 1, "preserves existing contents")
  end)

  it("test_ensure_field_fills_nil_with_fallback", function()
    local t = {}
    local field = tables.ensure_field(t, "foo", 7)
    _assert_eq(field, 7, "returns fallback")
    _assert_eq(t.foo, 7, "sets fallback on the input")
  end)

  it("test_ensure_field_preserves_existing_value_including_false", function()
    local t = { foo = false }
    local field = tables.ensure_field(t, "foo", 7)
    _assert_eq(field, false, "existing false is preserved")
    _assert_eq(t.foo, false, "input untouched")
  end)


end)
