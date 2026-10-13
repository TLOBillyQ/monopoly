require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- Mutation-pinning specs for src/foundation/identity.lua (role_id).
-- The empty string is the key discriminator: it survives the string branch of
-- normalize (returned verbatim) but is rejected by the tostring fallback
-- (`as_text ~= ""`), so any mutation that skips the string branch returns nil.

local role_id = require("src.foundation.identity")

describe("TestIdentityMutation", function()

  it("test_L13/L14 normalize returns empty string via the string branch", function()
    -- normalize(""): to_integer("") is nil, value_type == "string" -> return "".
    --   L13 `type(value)`->nil : value_type=nil -> "string" branch skipped ->
    --     tostring fallback rejects "" (as_text ~= "" is false) -> returns nil.
    --   L14 `"string"`->nil : value_type ("string") == nil is false -> same skip ->
    --     tostring fallback -> returns nil.
    -- Original returns "" (not nil), pinning both mutants.
    local result = role_id.normalize("")
    luassert.is.equal("", result, "normalize('') must return the empty string via the string branch; got " .. tostring(result))
  end)


end)
