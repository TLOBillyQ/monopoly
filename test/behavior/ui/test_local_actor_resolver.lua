-- local_actor_resolver(#341/#601):解析链只到 client_role 为止——事件解析不出
-- 身份即返回 nil,不得把 A 的点击当成 B 的。「上一次点击者缓存」随 #601 整体
-- 退役:解析既不读缓存也不再写缓存,state 上不再出现 local_actor_role_id。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local local_actor_resolver = require("src.ui.render.support.local_actor_resolver")
local runtime = require("src.ui.render.support.runtime_ui")

local function _role(role_id)
  return { get_roleid = function() return role_id end }
end

-- 解析期间把 client_role 钉为 nil(验收/单测环境的 UIManager 无 client_role)。
local function _with_no_client_role(fn)
  return support.with_patches({
    { target = runtime, key = "get_client_role", value = function() return nil end },
  }, fn)
end

TestLocalActorResolver = {}

function TestLocalActorResolver:test_anonymous_event_returns_nil_even_with_stale_state_field()
  -- 事件无身份、client_role 缺位 → 必须返回 nil;state 上就算躺着旧字段也
  -- 不得被读(#601 后该字段不再是解析链的一环)。
  local state = { local_actor_role_id = 2 }
  local resolved
  _with_no_client_role(function()
    resolved = local_actor_resolver.resolve_from_event(state, {})
  end)
  lu.assertEvalToTrue(resolved == nil,
    "anonymous event must resolve to nil; got " .. tostring(resolved))
end

function TestLocalActorResolver:test_event_role_resolves_without_writing_any_cache()
  -- #601:成功解析不再写「本地角色缓存」——state 不得被塞入 local_actor_role_id。
  local state = {}
  local resolved
  _with_no_client_role(function()
    resolved = local_actor_resolver.resolve_from_event(state, { role = _role(3) })
  end)
  lu.assertEvalToTrue(resolved == 3, "an explicit event role must still resolve")
  lu.assertEvalToTrue(state.local_actor_role_id == nil,
    "resolution must not write the retired local actor cache")
end

function TestLocalActorResolver:test_client_role_still_resolves_without_event_role()
  local resolved
  support.with_patches({
    { target = runtime, key = "get_client_role", value = function() return _role(5) end },
  }, function()
    resolved = local_actor_resolver.resolve_from_event({}, {})
  end)
  lu.assertEvalToTrue(resolved == 5,
    "client_role fallback must still resolve before the nil outcome")
end

function TestLocalActorResolver:test_resolve_turn_bound_uses_the_same_chain()
  local resolved
  _with_no_client_role(function()
    resolved = local_actor_resolver.resolve_turn_bound({ local_actor_role_id = 4 }, {})
  end)
  lu.assertEvalToTrue(resolved == nil,
    "turn-bound resolution must also ignore any stale cache field")
end

return TestLocalActorResolver
