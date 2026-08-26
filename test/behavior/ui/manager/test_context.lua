-- context.lua chunk 直测:本模块全是 load 期代码(共享态初始化),require 缓存只跑一遍,
-- 故用 loadfile 重放 chunk 钉死初始形状——这也是变异车道能触达 chunk 位点的唯一方式。
-- 宿主无关:角色列表走 foundation runtime port(测试基线已装默认实现)。
require("test.support.ui_manager_nodes_support")

local lu = require("luaunit")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,断言词汇从 luassert 兼容层
-- 切到 lu.assertXxx,用例数与改写前一一对应(2 例)。

local function _load_fresh()
  local chunk = assert(loadfile("src/ui/manager/context.lua"))
  return chunk()
end

TestContext = {}

function TestContext:test_initializes_shared_state_with_the_documented_shape()
  local ctx = _load_fresh()

  lu.assertEvalToTrue(type(ctx.allroles) == "table", "allroles resolved from the runtime port")
  lu.assertEvalToTrue(ctx.client_role == nil, "client_role starts nil")
  lu.assertEvalToTrue(type(ctx.nodes_list) == "table", "nodes_list initialized")
  lu.assertEvalToTrue(next(ctx.nodes_list) == nil, "nodes_list starts empty")
  lu.assertEvalToTrue(type(ctx.name_node_mapping) == "table", "name_node_mapping initialized")
  lu.assertEvalToTrue(next(ctx.name_node_mapping) == nil, "name_node_mapping starts empty")
  lu.assertEvalToTrue(type(ctx.event_handlers) == "table", "event_handlers initialized")
  lu.assertEvalToTrue(next(ctx.event_handlers) == nil, "event_handlers starts empty")
  lu.assertEvalToTrue(ctx.config_list == nil, "config_list starts nil")
end

function TestContext:test_each_chunk_load_produces_independent_state_tables()
  local first = _load_fresh()
  local second = _load_fresh()

  lu.assertEvalToTrue(first.nodes_list ~= second.nodes_list, "no shared backing between loads")
end


return TestContext
