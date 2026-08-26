-- Mutation-pinning specs for src/foundation/identity.lua (role_id).
-- The empty string is the key discriminator: it survives the string branch of
-- normalize (returned verbatim) but is rejected by the tostring fallback
-- (`as_text ~= ""`), so any mutation that skips the string branch returns nil.

local lu = require("luaunit")
local role_id = require("src.foundation.identity")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 Test* 类,断言切到 lu.assertXxx
-- (== 转 assertIs),用例数与改写前一一对应(1 例)。it 名含斜杠等非标识符
-- 字符,方法名用字符串键逐字保留。
TestIdentityMutation = {}

TestIdentityMutation["test_L13/L14 normalize returns empty string via the string branch"] = function(self)
  -- normalize(""): to_integer("") is nil, value_type == "string" -> return "".
  --   L13 `type(value)`->nil : value_type=nil -> "string" branch skipped ->
  --     tostring fallback rejects "" (as_text ~= "" is false) -> returns nil.
  --   L14 `"string"`->nil : value_type ("string") == nil is false -> same skip ->
  --     tostring fallback -> returns nil.
  -- Original returns "" (not nil), pinning both mutants.
  local result = role_id.normalize("")
  lu.assertIs(result, "",
    "normalize('') must return the empty string via the string branch; got " .. tostring(result))
end


return TestIdentityMutation
