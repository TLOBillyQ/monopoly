-- call-count(#128):测试钉内部调用次数判红。CODING_STANDARDS 测试节「不钉
-- 私有函数或内部调用次数」的机械判据。fixture 原型是 cb44141 之前
-- test_bootstrap.lua 的 where_luarocks:stub 里 `n = n + 1`,测试体
-- `check.equal(0, n)` 断言 where.exe 被调了几次。
--
-- 判定:计数变量在测试体内的嵌套函数(stub/回调)里自增(`x = x + k` 或
-- `x = k + x`,k 为数字字面量),且测试体内(含 run 回调等嵌套函数)有断言调用
-- 的实参引用了它(`check.equal(N, x)`、`assert.is_true(x == 1)` 等)即命中,
-- 每处断言报一条,行号取断言所在行。
--
-- 从宽避免误报:测试体自己的循环里数可见产物(自增不在嵌套函数里)不算;
-- 计数只用来编排 stub 第 N 次的返回、从未被断言也不算;同文件 helper 里的
-- 断言与跨文件计数器不追究。计数本身即公共契约(如订阅通知次数)时,在断言
-- 行或上一行写 `-- lint-allow: call-count <理由>`。
local M = {}

M.name = "call-count"

local ASSERT_ROOTS = { assert = true, luassert = true, check = true }

local function _callee_root_name(call_node)
  local base = call_node[1]
  while type(base) == "table" and base.tag == "Index" do
    base = base[1]
  end
  if type(base) == "table" and base.tag == "Id" then
    return base[1]
  end
  return nil
end

local function _is_number(node)
  return type(node) == "table" and node.tag == "Number"
end

local function _id_name(node)
  if type(node) == "table" and node.tag == "Id" then
    return node[1]
  end
  return nil
end

-- `x = x + k` / `x = k + x` -> "x";否则 nil。
local function _increment_target(stmt)
  if stmt.tag ~= "Set" or #stmt[1] ~= 1 or #stmt[2] ~= 1 then
    return nil
  end
  local name = _id_name(stmt[1][1])
  local value = stmt[2][1]
  if name == nil or type(value) ~= "table" or value.tag ~= "Op" or value[1] ~= "add" then
    return nil
  end
  if (_id_name(value[2]) == name and _is_number(value[3]))
    or (_is_number(value[2]) and _id_name(value[3]) == name) then
    return name
  end
  return nil
end

-- 收集嵌套函数里自增的计数名:inside_fn 表示已进入测试体内的某个函数字面量。
local function _collect_counters(node, inside_fn, counters)
  if type(node) ~= "table" then
    return
  end
  if inside_fn and node.tag == "Set" then
    local name = _increment_target(node)
    if name ~= nil then
      counters[name] = true
    end
  end
  local nested = inside_fn or node.tag == "Function"
  for _, child in ipairs(node) do
    _collect_counters(child, nested, counters)
  end
end

local function _references_counter(node, counters)
  if type(node) ~= "table" or node.tag == "Function" then
    return nil
  end
  local name = _id_name(node)
  if name ~= nil and counters[name] then
    return name
  end
  for _, child in ipairs(node) do
    local found = _references_counter(child, counters)
    if found ~= nil then
      return found
    end
  end
  return nil
end

-- 测试体里引用计数变量的断言调用;下钻嵌套函数(`_with_stubs(stubs, run)` 的
-- run 回调里断言同样是钉调用次数)。
local function _collect_pins(node, counters, pins)
  if type(node) ~= "table" then
    return
  end
  if (node.tag == "Call" or node.tag == "Invoke")
    and ASSERT_ROOTS[_callee_root_name(node)] == true then
    for i = 2, #node do
      local name = _references_counter(node[i], counters)
      if name ~= nil then
        pins[#pins + 1] = { line = node.line, counter = name }
        return
      end
    end
  end
  for _, child in ipairs(node) do
    _collect_pins(child, counters, pins)
  end
end

-- body: { name, fn, line }。命中返回违规记录列表(每处断言一条),否则 nil。
function M.check_body(body)
  local block = body.fn[2]
  local counters = {}
  _collect_counters(block, false, counters)
  if next(counters) == nil then
    return nil
  end
  local pins = {}
  _collect_pins(block, counters, pins)
  if #pins == 0 then
    return nil
  end
  local violations = {}
  for _, pin in ipairs(pins) do
    violations[#violations + 1] = {
      rule = M.name,
      line = pin.line,
      test = body.name,
      message = "断言了计数变量 " .. pin.counter .. "(在 stub/回调里自增),钉的是内部调用次数;"
        .. "改为断言可见结果,计数确属公共契约在断言行或上一行写 -- lint-allow: call-count <理由>",
    }
  end
  return violations
end

return M
