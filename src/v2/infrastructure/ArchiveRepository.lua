local archive_repository = {}
archive_repository.__index = archive_repository

local function _call_role(role, method_name, ...)
  if role == nil then
    return nil, false
  end
  local fn = role[method_name]
  if type(fn) ~= "function" then
    return nil, false
  end

  local ok, result = pcall(fn, role, ...)
  if ok then
    return result, true
  end
  ok, result = pcall(fn, ...)
  if ok then
    return result, true
  end
  return nil, false
end

local function _encode(snapshot_ref)
  local parts = {}
  for key, value in pairs(snapshot_ref or {}) do
    parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

local function _decode(raw)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end
  local out = {}
  for segment in string.gmatch(raw, "[^;]+") do
    local key, value = string.match(segment, "([^=]+)=(.*)")
    if key then
      local as_number = tonumber(value)
      out[key] = as_number or value
    end
  end
  return out
end

function archive_repository.new(opts)
  opts = opts or {}
  local instance = {
    runtime = opts.runtime,
    key_prefix = opts.key_prefix or "monopoly_v2_checkpoint",
    memory_fallback = {},
  }
  setmetatable(instance, archive_repository)
  return instance
end

function archive_repository:_archive_key(role_id)
  return self.key_prefix .. ":" .. tostring(role_id)
end

function archive_repository:save_role_checkpoint(role_id, snapshot_ref)
  if role_id == nil then
    return false
  end
  local key = self:_archive_key(role_id)
  local encoded = _encode(snapshot_ref)

  local role = self.runtime and self.runtime.find_role_by_id and self.runtime:find_role_by_id(role_id) or nil
  if role and Enums and Enums.ArchiveType and Enums.ArchiveType.Str then
    local _, ok = _call_role(role, "set_archive_by_type", Enums.ArchiveType.Str, key, encoded)
    if ok then
      return true
    end
  end

  self.memory_fallback[key] = encoded
  return true
end

function archive_repository:load_role_checkpoint(role_id)
  if role_id == nil then
    return nil
  end
  local key = self:_archive_key(role_id)

  local role = self.runtime and self.runtime.find_role_by_id and self.runtime:find_role_by_id(role_id) or nil
  if role and Enums and Enums.ArchiveType and Enums.ArchiveType.Str then
    local raw, ok = _call_role(role, "get_archive_by_type", Enums.ArchiveType.Str, key)
    if ok then
      return _decode(raw)
    end
  end

  return _decode(self.memory_fallback[key])
end

return archive_repository
