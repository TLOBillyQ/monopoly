local commands = require("src.v2.domain.Commands")

local reconnect_service = {}
reconnect_service.__index = reconnect_service

local command_types = commands.types

local function _as_set(list)
  local out = {}
  for _, value in ipairs(list or {}) do
    out[value] = true
  end
  return out
end

function reconnect_service.new(opts)
  opts = opts or {}
  local instance = {
    runtime = assert(opts.runtime, "missing runtime"),
    dispatch = assert(opts.dispatch, "missing dispatch callback"),
    known_online = {},
  }
  setmetatable(instance, reconnect_service)
  return instance
end

function reconnect_service:bootstrap_online(now)
  local ids = self.runtime:get_online_role_ids()
  self.known_online = _as_set(ids)
  for _, role_id in ipairs(ids) do
    self.dispatch(commands.new(command_types.role_online, {
      role_id = role_id,
      issued_at = now,
    }))
  end
end

function reconnect_service:on_role_offline(role_id, now)
  if role_id == nil then
    return
  end
  self.dispatch(commands.new(command_types.role_offline, {
    role_id = role_id,
    issued_at = now,
  }))
end

function reconnect_service:on_role_online(role_id, now)
  if role_id == nil then
    return
  end
  self.dispatch(commands.new(command_types.role_online, {
    role_id = role_id,
    issued_at = now,
  }))
end

function reconnect_service:refresh(now)
  local current_ids = self.runtime:get_online_role_ids()
  local current_set = _as_set(current_ids)

  for role_id in pairs(self.known_online) do
    if not current_set[role_id] then
      self:on_role_offline(role_id, now)
    end
  end

  for role_id in pairs(current_set) do
    if not self.known_online[role_id] then
      self:on_role_online(role_id, now)
    end
  end

  self.known_online = current_set
end

return reconnect_service
