--- LuaUnit 断言补件(自研 busted → LuaUnit 迁移):busted 的 `has_error` /
--- `has_no.errors` 在 LuaUnit 无直接对应物,语义按旧自研兼容层 assert 逐条对齐:
---   - has_error(fn):抛出任何 error 即通过;
---   - has_error(fn, expected):字符串期望值先剥 `<src>:<line>:` 位置前缀再做
---     相等比对;table 期望值与 raised 原值做递归深比较(不剥前缀);
---   - has_no_error(fn):不抛 error 才通过,抛了报 failure 并带 caught 内容。
--- 失败一律走 LuaUnit FAILURE_PREFIX 重抛,归 FAIL 类(对齐 shim 的分类契约)。
local lu = require("luaunit")

local M = {}

--- 从 has_error/has_no_error 的调用帧往上数:error 在本函数内触发,level 3
--- 指向 spec 里的调用行(1=本函数, 2=M.* 断言函数, 3=spec 测试方法)。
local function _fail(msg)
  error(lu.FAILURE_PREFIX .. msg, 3)
end

local function _strip_location(err)
  if type(err) == "string" then
    return (err:gsub("^.-:%d+:%s*", "", 1))
  end
  return err
end

function M.has_error(fn, expected)
  local ok, raised = pcall(fn)
  if ok then
    _fail("Expected an error to be raised, but none was")
  end
  if expected == nil then
    return
  end
  if type(expected) == "table" then
    lu.assertEquals(raised, expected)
  else
    lu.assertEquals(_strip_location(raised), expected)
  end
end

function M.has_no_error(fn)
  local ok, raised = pcall(fn)
  if not ok then
    _fail("Expected no error to be raised, caught: " .. tostring(raised))
  end
end

return M
