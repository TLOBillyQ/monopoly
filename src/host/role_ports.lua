-- 角色解析与标记默认实现(自 default_ports.lua 拆分,行为保持):角色枚举、
-- 合成角色适配器回退、单角色解析、失败标记与出局的宿主侧执行。
local logger = require("src.foundation.log")
local role_die = require("src.host.role_die")

local role_ports = {}

local function _current_env(runtime_context)
  local ctx = runtime_context.current and runtime_context.current() or nil
  return ctx and ctx.env or nil
end

local function _current_game_api(runtime_context)
  local env = _current_env(runtime_context)
  return env and env["Game" .. "API"] or nil
end

local function _try_get_role_id(role)
  if role == nil then
    return nil
  end
  if type(role.get_roleid) == "function" then
    local ok, role_id = pcall(role.get_roleid)
    if ok then
      return role_id
    end
  end
  return role.id
end

local function _query_game_roles(runtime_context)
  local game_api = _current_game_api(runtime_context)
  if game_api and type(game_api.get_all_valid_roles) == "function" then
    local ok, roles = pcall(game_api.get_all_valid_roles)
    if ok and type(roles) == "table" then
      return roles
    end
  end
  return {}
end

local function _registry(ctx)
  return ctx and ctx.synthetic_actor_registry or nil
end

local function _resolvable(registry)
  return registry ~= nil and type(registry.resolve_actor) == "function"
end

local function _adapter_of(actor)
  if actor and actor.adapter then
    return actor.adapter
  end
  return nil
end

local function _try_resolve_synthetic_role(player_id, ctx)
  local synthetic_registry = _registry(ctx)
  if not _resolvable(synthetic_registry) then
    return nil
  end
  return _adapter_of(synthetic_registry.resolve_actor(player_id))
end

local function _find_role_by_id(roles, player_id)
  if type(roles) ~= "table" then
    return nil
  end
  for _, role in ipairs(roles) do
    if _try_get_role_id(role) == player_id then
      return role
    end
  end
  return nil
end

local function _resolve_role_via_game_api(player_id, runtime_context)
  local game_api = _current_game_api(runtime_context)
  if not (game_api and type(game_api.get_role) == "function") then
    return nil
  end
  local ok, role = pcall(game_api.get_role, player_id)
  if ok then
    return role
  end
  return nil
end

local function _resolve_roles(runtime_context)
  local ctx = runtime_context.current()
  if ctx and type(ctx.roles) == "table" then
    if #ctx.roles > 0 then
      return ctx.roles
    end
    local refreshed = _query_game_roles(runtime_context)
    if #refreshed > 0 then
      ctx.roles = refreshed
      return refreshed
    end
    return ctx.roles
  end
  return _query_game_roles(runtime_context)
end

local function _resolve_role(player_id, runtime_context)
  if player_id == nil then
    return nil
  end
  local ctx = runtime_context.current()
  local synthetic_adapter = _try_resolve_synthetic_role(player_id, ctx)
  if synthetic_adapter then
    return synthetic_adapter
  end
  local role = _find_role_by_id(_resolve_roles(runtime_context), player_id)
  if role ~= nil then
    return role
  end
  return _resolve_role_via_game_api(player_id, runtime_context)
end

function role_ports.install(defaults, runtime_context)
  defaults.resolve_roles = function()
    return _resolve_roles(runtime_context)
  end

  defaults.resolve_role = function(player_id)
    return _resolve_role(player_id, runtime_context)
  end

  -- 名字即「标记失败」:破产淘汰的标记语义正确,保留 role.lose() 不换方法
  -- (#334);跳过分支必留痕(ADR 0046),禁止静默。
  defaults.mark_role_lose = function(role)
    if role == nil then
      logger.warn("mark_role_lose skip: role is nil")
      return
    end
    if type(role.lose) ~= "function" then
      logger.warn("mark_role_lose skip: role lacks lose method")
      return
    end
    role.lose()
  end

  -- 出局的宿主侧执行(ADR 0046):宿主 Role 走控制单位、合成适配器走自带 die,
  -- 分支与判据收在 src/host/role_die,规则层只经端口触达。
  defaults.call_role_die = role_die.call_role_die
end

return role_ports

--[[ mutate4lua-manifest
version=4
projectHash=5447cdb09c9ada96
scope.0.id=chunk:src/host/role_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=150
scope.0.semanticHash=d673c373bbceee1d
scope.1.id=function:_current_env
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=d08d43958f5bffa4
scope.2.id=function:_current_game_api
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=16
scope.2.semanticHash=c1a993e537c4d1c6
scope.3.id=function:_try_get_role_id
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=29
scope.3.semanticHash=afdd7d3beed337aa
scope.4.id=function:_query_game_roles
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=40
scope.4.semanticHash=60109cdedc0ced72
scope.5.id=function:_registry
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=44
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_resolvable
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=48
scope.6.semanticHash=0644415798925f16
scope.7.id=function:_adapter_of
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=55
scope.7.semanticHash=23b638226dd7a3e1
scope.8.id=function:_try_resolve_synthetic_role
scope.8.kind=function
scope.8.startLine=57
scope.8.endLine=63
scope.8.semanticHash=a84155966d8bfce3
scope.9.id=function:_find_role_by_id
scope.9.kind=function
scope.9.startLine=65
scope.9.endLine=75
scope.9.semanticHash=21b5fff98d4253f5
scope.10.id=function:_resolve_role_via_game_api
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=87
scope.10.semanticHash=957ecbdcab194c59
scope.11.id=function:_resolve_roles
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=103
scope.11.semanticHash=2d66d66446271bcc
scope.12.id=function:_resolve_role
scope.12.kind=function
scope.12.startLine=105
scope.12.endLine=119
scope.12.semanticHash=fb8b888770be9af2
scope.13.id=function:role_ports.install
scope.13.kind=function
scope.13.startLine=121
scope.13.endLine=147
scope.13.semanticHash=19b975b6caa75c9e
scope.14.id=function:defaults.resolve_roles
scope.14.kind=function
scope.14.startLine=122
scope.14.endLine=124
scope.14.semanticHash=7bbf31ab6751de78
scope.15.id=function:defaults.resolve_role
scope.15.kind=function
scope.15.startLine=126
scope.15.endLine=128
scope.15.semanticHash=e504e513aab7d79c
scope.16.id=function:defaults.mark_role_lose
scope.16.kind=function
scope.16.startLine=132
scope.16.endLine=142
scope.16.semanticHash=677e1453aea213a3
]]
