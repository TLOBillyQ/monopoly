-- context.lua chunk 直测:本模块全是 load 期代码(共享态初始化),require 缓存只跑一遍,
-- 故用 loadfile 重放 chunk 钉死初始形状——这也是变异车道能触达 chunk 位点的唯一方式。
-- 宿主无关:角色列表走 foundation runtime port(测试基线已装默认实现)。
require("test.support.ui_manager_nodes_support")

local luassert = assert

local function _load_fresh()
  local chunk = assert(loadfile("src/ui/manager/context.lua"))
  return chunk()
end

describe("TestContext", function()

it("test_initializes_shared_state_with_the_documented_shape", function()
  local ctx = _load_fresh()

  luassert.truthy(type(ctx.allroles) == "table", "allroles resolved from the runtime port")
  luassert.truthy(ctx.client_role == nil, "client_role starts nil")
  luassert.truthy(type(ctx.nodes_list) == "table", "nodes_list initialized")
  luassert.truthy(next(ctx.nodes_list) == nil, "nodes_list starts empty")
  luassert.truthy(type(ctx.name_node_mapping) == "table", "name_node_mapping initialized")
  luassert.truthy(next(ctx.name_node_mapping) == nil, "name_node_mapping starts empty")
  luassert.truthy(type(ctx.event_handlers) == "table", "event_handlers initialized")
  luassert.truthy(next(ctx.event_handlers) == nil, "event_handlers starts empty")
  luassert.truthy(ctx.config_list == nil, "config_list starts nil")
end)

it("test_each_chunk_load_produces_independent_state_tables", function()
  local first = _load_fresh()
  local second = _load_fresh()

  luassert.truthy(first.nodes_list ~= second.nodes_list, "no shared backing between loads")
end)


end)
