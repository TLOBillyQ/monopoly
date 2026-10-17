-- 测试 lint 骨架(#127):测试体识别。两种风格并存(ADR 0069 两步迁移):
--   busted:describe/it,it 第二参可以是匿名函数或同文件 local 函数引用;
--   旧式:TestX = {} 函数表里的 test_* 成员(表构造器与 TestX.test_* = function 两种形态)。
-- 返回 bodies(每个 { name, fn, line },fn 是 luacheck AST 的 Function 节点)
-- 与 locals(文件级 local 函数表 name -> Function,供规则做单层 helper 展开)。
local ast_mod = require("test.guards.lib.test_lint.ast")

local M = {}

local _id_name = ast_mod.id_name

local function _is_id(node, name)
  return type(node) == "table" and node.tag == "Id" and node[1] == name
end

local function _string_value(node)
  if type(node) == "table" and node.tag == "String" then
    return node[1]
  end
  return nil
end

local function _is_function(node)
  return type(node) == "table" and node.tag == "Function"
end

-- ast: luacheck parser.parse 的根 block(语句数组)。
function M.collect(ast)
  local bodies = {}
  local locals = {}
  local scopes = {}
  local describe_stack = {}

  local function push_scope()
    scopes[#scopes + 1] = {}
  end

  local function pop_scope()
    scopes[#scopes] = nil
  end

  local function register_local(name, fn_node)
    if #scopes == 0 then
      push_scope()
    end
    scopes[#scopes][name] = fn_node
    -- 文件级表供规则展开 helper;遮蔽场景取后定义者(过度近似,偏宽容)。
    locals[name] = fn_node
  end

  local function lookup_local(name)
    for i = #scopes, 1, -1 do
      local fn = scopes[i][name]
      if fn ~= nil then
        return fn
      end
    end
    return nil
  end

  local function add_body(name, fn_node, line)
    local parts = {}
    for _, describe_name in ipairs(describe_stack) do
      parts[#parts + 1] = describe_name
    end
    parts[#parts + 1] = name
    bodies[#bodies + 1] = { name = table.concat(parts, " "), fn = fn_node, line = line }
  end

  local walk_block

  local function walk_function_body(fn_node)
    push_scope()
    walk_block(fn_node[2])
    pop_scope()
  end

  -- 旧式 TestX 函数表:表构造器里的 test_* Pair。
  local function collect_table_tests(suite_name, table_node)
    for _, item in ipairs(table_node) do
      if type(item) == "table" and item.tag == "Pair" then
        local key = _string_value(item[1])
        if key ~= nil and key:match("^test_") ~= nil and _is_function(item[2]) then
          add_body(suite_name .. "." .. key, item[2], item[2].line)
        end
      end
    end
  end

  local function handle_call(node)
    local callee = node[1]
    if _is_id(callee, "describe") then
      local name = _string_value(node[2])
      if name ~= nil and _is_function(node[3]) then
        describe_stack[#describe_stack + 1] = name
        walk_function_body(node[3])
        describe_stack[#describe_stack] = nil
      end
      return
    end
    if _is_id(callee, "it") then
      local name = _string_value(node[2]) or "<动态名>"
      local target = node[3]
      local fn_node
      if _is_function(target) then
        fn_node = target
      else
        local ref = _id_name(target)
        if ref ~= nil then
          fn_node = lookup_local(ref)
        end
      end
      -- 解析不出函数体的 it(动态 dispatch)跳过,不误报也不拦。
      if fn_node ~= nil then
        add_body(name, fn_node, node.line)
      end
      return
    end
    -- 其他调用的函数实参里可能再嵌 describe/it(注册器风格),继续下钻。
    for i = 2, #node do
      if _is_function(node[i]) then
        walk_function_body(node[i])
      end
    end
  end

  local function handle_statement(stmt)
    local tag = stmt.tag
    if tag == "Call" or tag == "Invoke" then
      handle_call(stmt)
      return
    end
    if tag == "Localrec" then
      -- local function name() ... end
      local name = _id_name(stmt[1] and stmt[1][1])
      local fn_node = stmt[2] and stmt[2][1]
      if name ~= nil and _is_function(fn_node) then
        register_local(name, fn_node)
        walk_function_body(fn_node)
      end
      return
    end
    if tag == "Local" then
      local lhs, rhs = stmt[1], stmt[2]
      if type(rhs) == "table" then
        for i, value in ipairs(rhs) do
          local name = _id_name(lhs[i])
          if name ~= nil and _is_function(value) then
            register_local(name, value)
            walk_function_body(value)
          elseif name ~= nil and name:match("^Test") ~= nil
            and type(value) == "table" and value.tag == "Table" then
            collect_table_tests(name, value)
          end
        end
      end
      return
    end
    if tag == "Set" then
      local lhs, rhs = stmt[1], stmt[2]
      local target = lhs and lhs[1]
      local value = rhs and rhs[1]
      if _is_function(value) and type(target) == "table" and target.tag == "Index" then
        -- TestX.test_foo = function / function TestX.test_foo()
        local root = target[1]
        local key = _string_value(target[2])
        local root_name = _id_name(root)
        if root_name ~= nil and root_name:match("^Test") ~= nil
          and key ~= nil and key:match("^test_") ~= nil then
          add_body(root_name .. "." .. key, value, value.line)
          return
        end
      end
      if type(target) == "table" and target.tag == "Id" and target[1]:match("^Test") ~= nil
        and type(value) == "table" and value.tag == "Table" then
        collect_table_tests(target[1], value)
        return
      end
      if _is_function(value) then
        walk_function_body(value)
      end
      return
    end
    -- 其余带块的语句(if/while/for/do/repeat):块里可能再嵌 describe/it。
    for _, child in ipairs(stmt) do
      if type(child) == "table" then
        if child.tag == nil then
          push_scope()
          walk_block(child)
          pop_scope()
        elseif child.tag == "Function" then
          walk_function_body(child)
        end
      end
    end
  end

  walk_block = function(block)
    for _, stmt in ipairs(block or {}) do
      if type(stmt) == "table" then
        handle_statement(stmt)
      end
    end
  end

  push_scope()
  walk_block(ast)
  pop_scope()

  return bodies, locals
end

return M
