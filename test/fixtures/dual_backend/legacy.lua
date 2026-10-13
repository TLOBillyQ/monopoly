local lu = require("luaunit")
TestLegacyBackend = {}
function TestLegacyBackend:test_real_legacy_assertion()
  lu.assertEquals(2 + 3, 5)
end
return TestLegacyBackend
