---@diagnostic disable: need-check-nil, undefined-field

local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local role_id = require("src.foundation.identity")

local function _labelled(text)
  return setmetatable({}, {
    __tostring = function()
      return text
    end,
  })
end

describe("role_id identity", function()
  describe("normalize", function()
    it("returns nil for nil", function()
      _assert_eq(role_id.normalize(nil), nil, "nil normalizes to nil")
    end)

    it("coerces numeric ids and numeric strings to integers", function()
      _assert_eq(role_id.normalize(5), 5, "integer id stays an integer")
      _assert_eq(role_id.normalize("7"), 7, "numeric string becomes an integer")
    end)

    it("keeps non-numeric strings unchanged", function()
      _assert_eq(role_id.normalize("hero"), "hero", "non-numeric string is preserved")
    end)

    it("falls back to tostring for non-string, non-numeric values", function()
      _assert_eq(role_id.normalize(_labelled("guild")), "guild", "tostring fallback supplies the id")
    end)

    it("returns nil when the tostring fallback is empty", function()
      _assert_eq(role_id.normalize(_labelled("")), nil, "an empty tostring fallback yields nil")
    end)
  end)

  describe("equals", function()
    it("treats numeric and string forms of an id as equal", function()
      _assert_eq(role_id.equals(3, "3"), true, "3 and \"3\" are the same role")
    end)

    it("is false for different ids", function()
      _assert_eq(role_id.equals(3, 4), false, "different ids are not equal")
    end)

    it("is false when either side normalizes to nil", function()
      _assert_eq(role_id.equals(nil, 3), false, "nil never equals a real id")
      _assert_eq(role_id.equals(_labelled(""), 3), false, "an unnormalizable value never equals a real id")
    end)
  end)

  describe("read", function()
    it("returns nil when the map is not a table", function()
      _assert_eq(role_id.read(nil, 1), nil, "a nil map reads nil")
      _assert_eq(role_id.read("nope", 1), nil, "a non-table map reads nil")
    end)

    it("reads through the normalized integer key", function()
      _assert_eq(role_id.read({ [1] = "a" }, "1"), "a", "a string key resolves to the integer slot")
    end)

    it("falls back to the stringified normalized key", function()
      _assert_eq(role_id.read({ ["1"] = "a" }, 1), "a", "an integer key resolves to the string slot")
    end)

    it("falls back to the raw key when normalization fails", function()
      local raw = _labelled("")
      _assert_eq(role_id.read({ [raw] = "value" }, raw), "value", "an unnormalizable key still resolves raw")
    end)

    it("returns nil when no slot matches", function()
      _assert_eq(role_id.read({ [1] = "a" }, 2), nil, "a missing key reads nil")
    end)
  end)

  describe("write", function()
    it("returns nil when the map is not a table", function()
      _assert_eq(role_id.write(nil, 1, "x"), nil, "a nil map writes nothing")
    end)

    it("returns nil when the key cannot be normalized", function()
      _assert_eq(role_id.write({}, _labelled(""), "x"), nil, "an unnormalizable key writes nothing")
    end)

    it("writes under the normalized integer key and clears the string duplicate", function()
      local map = { ["5"] = "stale" }
      local written = role_id.write(map, 5, "fresh")
      _assert_eq(written, 5, "write returns the normalized key")
      _assert_eq(map[5], "fresh", "value is stored under the integer key")
      _assert_eq(map["5"], nil, "the string-keyed duplicate is cleared")
    end)

    it("writes string ids without clearing anything", function()
      local map = {}
      local written = role_id.write(map, "hero", "v")
      _assert_eq(written, "hero", "a string id is returned unchanged")
      _assert_eq(map["hero"], "v", "value is stored under the string key")
    end)
  end)
end)
