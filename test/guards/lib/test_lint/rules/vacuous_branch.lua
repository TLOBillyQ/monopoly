-- vacuous-branch(#127):测试体里确实有断言、但存在一条不经过任何断言的执行
-- 路径(断言只躲在条件分支里)判红。fixture 原型是 cb44141 之前
-- runner_spawn_carries_tool_discovery_env 的 `if captured_options ~= nil then` 空转写法
-- ——即便同测试体里还有别的无条件断言,被条件挡住的断言本身即是空转路径。
--
-- 判定单位是测试体内的每个 if:子树里含断言、但存在不经过断言的穿越路径
-- (无 else;或某个分支块/else 块内断言仍被更深条件挡住)即命中,报那条 if 的行号。
--
-- 断言认定:根名为 assert / luassert / check 的调用链(含 luassert.is.equal
-- 多级索引与 Invoke 方法调用),或调用同文件内、函数体含直接断言的 local 函数
-- (只展开一层,build_helpers 预算)。嵌套函数(回调/stub)是路径边界,里面的
-- 断言不算外层路径的覆盖。
--
-- 更深的控制流从宽,避免误报:循环体含断言即视为覆盖(零迭代路径不追究),
-- 提前 return 产生的无断言路径暂不追究,跨文件/多层 helper 不展开。
-- 条件表达式(含 and/or 短路左侧)里的断言计入该分支覆盖——不区分求值
-- 是否短路,偏宽容方向。
local ast_mod = require("test.guards.lib.test_lint.ast")

local M = {}

M.name = "vacuous-branch"

local ASSERT_ROOTS = { assert = true, luassert = true, check = true }

local _callee_root_name = ast_mod.callee_root_name

-- is_assert_call(call_node) -> bool 由调用方给出(直接断言 / 含 helper 展开两档)。
local function _scan(node, is_assert_call)
  if type(node) ~= "table" then
    return false
  end
  if node.tag == "Function" then
    return false
  end
  if (node.tag == "Call" or node.tag == "Invoke") and is_assert_call(node) then
    return true
  end
  for _, child in ipairs(node) do
    if _scan(child, is_assert_call) then
      return true
    end
  end
  return false
end

local function _is_direct_assert(call_node)
  return ASSERT_ROOTS[_callee_root_name(call_node)] == true
end

-- 直接断言:只认断言对象调用链,不展开 helper(helper 判定的「含直接断言」用这档)。
local function _has_direct_assertion(fn_node)
  return _scan(fn_node[2], _is_direct_assert)
end

-- locals: 文件级 local 函数表(name -> Function)。返回 name -> true 的 helper 表:
-- 函数体含直接断言的 local 函数才算断言 helper(单层,不再递归展开)。
function M.build_helpers(locals)
  local helpers = {}
  for name, fn_node in pairs(locals or {}) do
    if _has_direct_assertion(fn_node) then
      helpers[name] = true
    end
  end
  return helpers
end

-- 骨架扩展点(#127):规则自备上下文,#128 的 call-count 换自己的 build_ctx 即可。
function M.build_ctx(scan)
  return { helpers = M.build_helpers(scan.locals) }
end

local function _contains_assertion(node, helpers)
  return _scan(node, function(call_node)
    local root = _callee_root_name(call_node)
    return ASSERT_ROOTS[root] == true or helpers[root] == true
  end)
end

local _block_may_skip

-- if:分支是 (cond, block) 对,尾部多一个 block 即 else。
-- 无 else 时跳过整条 if 的路径恒在,仅第一个条件在所有路径上求值,
-- 它的断言能覆盖跳过路径;有 else 时任一分支可避开断言即有空转路径。
-- 到达第 i 个分支必先求值前 i 个条件,条件里的断言计入该分支覆盖。
local function _if_may_skip(node, helpers)
  if #node % 2 == 0 then
    return not _contains_assertion(node[1], helpers)
  end
  local cond_asserts = false
  local index = 1
  while index + 1 <= #node do
    cond_asserts = cond_asserts or _contains_assertion(node[index], helpers)
    if not cond_asserts and _block_may_skip(node[index + 1], helpers) then
      return true
    end
    index = index + 2
  end
  -- else 分支:到达它必先求值全部条件,条件断言同样计入覆盖。
  return not cond_asserts and _block_may_skip(node[#node], helpers)
end

-- 语句级「可避开断言」:非 if 语句看自身是否处处断言;循环从宽(含断言即覆盖);
-- return/break 的提前出口从宽(见文件头)。
local function _stmt_may_skip(stmt, helpers)
  local tag = stmt.tag
  if tag == "If" then
    return _if_may_skip(stmt, helpers)
  end
  if tag == "While" or tag == "Fornum" or tag == "Forin" then
    return not _contains_assertion(stmt, helpers)
  end
  if tag == "Repeat" then
    return _block_may_skip(stmt[1], helpers) and not _contains_assertion(stmt[2], helpers)
  end
  if tag == "Do" then
    return _block_may_skip(stmt, helpers)
  end
  return not _contains_assertion(stmt, helpers)
end

-- 分支块的路径是各语句路径的串联:每句都能避开断言,整块才存在无断言路径
-- (一句处处断言即全覆盖)。
_block_may_skip = function(block, helpers)
  for _, stmt in ipairs(block) do
    if not _stmt_may_skip(stmt, helpers) then
      return false
    end
  end
  return true
end

-- 自顶向下找第一条「含断言却仍有空转路径」的 if;嵌套函数是边界不下钻。
local function _find_vacuous_if(node, helpers)
  if type(node) ~= "table" or node.tag == "Function" then
    return nil
  end
  if node.tag == "If" and _contains_assertion(node, helpers) and _if_may_skip(node, helpers) then
    return node
  end
  for _, child in ipairs(node) do
    local found = _find_vacuous_if(child, helpers)
    if found ~= nil then
      return found
    end
  end
  return nil
end

-- body: { name, fn, line };ctx.helpers 由 build_helpers 预算。
-- 命中返回违规记录列表(与 call-count 同一契约),否则 nil。
function M.check_body(body, ctx)
  local helpers = (ctx or {}).helpers or {}
  local block = body.fn[2]
  if not _contains_assertion(block, helpers) then
    -- 测试体里一处断言都没有不归本规则管。
    return nil
  end
  local vacuous = _find_vacuous_if(block, helpers)
  if vacuous == nil then
    return nil
  end
  return { {
    rule = M.name,
    line = vacuous.line,
    test = body.name,
    message = "断言被条件分支挡住:这条 if 存在不经断言的穿越路径,条件不满足时这部分检查空转;"
      .. "每条路径至少断言一次,确需豁免在判红行或上一行写 -- lint-allow: vacuous-branch <理由>",
  } }
end

return M
