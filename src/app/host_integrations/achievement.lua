local number_utils = require("src.foundation.number")
local catalog = require("src.config.content.achievements")
local event_progress = require("src.config.content.achievement_progress_events")
local role_resolver = require("src.host.role_resolver")

local achievement = {
  host_pending = false,
  catalog = catalog,
}

local progress_adapter = nil

local function _copy_ids(ids)
  local copy = {}
  for index, id in ipairs(ids or {}) do
    copy[index] = id
  end
  return copy
end

local function _resolve_adapter(role)
  if role ~= nil then
    return role
  end
  if progress_adapter ~= nil then
    return progress_adapter
  end
  local roles = role_resolver.resolve_roles()
  return roles and roles[1] or nil
end

local function _valid_progress_args(id, amount)
  return achievement.find(id) ~= nil and number_utils.to_integer(amount) ~= nil
end

local function _call_host(adapter, method_name, ...)
  if adapter == nil or type(adapter[method_name]) ~= "function" then
    return nil
  end
  local ok, result = pcall(adapter[method_name], ...)
  if not ok or result == false then
    return false
  end
  return true, result
end

local function _apply_progress(id, amount, method_name, role)
  local achievement_id = number_utils.to_integer(id)
  local progress_count = number_utils.to_integer(amount)
  if not _valid_progress_args(achievement_id, progress_count) then
    return false
  end
  local ok = _call_host(_resolve_adapter(role), method_name, achievement_id, progress_count)
  return ok == true
end

local function _id_range(start_id, end_id)
  local first_id = number_utils.to_integer(start_id)
  local last_id = number_utils.to_integer(end_id)
  if first_id == nil or last_id == nil or last_id < first_id then
    return nil, nil
  end
  return first_id, last_id
end

local function _has_every_id(first_id, last_id)
  for expected_id = first_id, last_id do
    if achievement.find(expected_id) == nil then
      return false
    end
  end
  return true
end

function achievement.list()
  return catalog
end

function achievement.count()
  return #catalog
end

function achievement.find(id)
  local target_id = number_utils.to_integer(id)
  if target_id == nil then
    return nil
  end

  for _, entry in ipairs(catalog) do
    if entry.id == target_id then
      return entry
    end
  end
  return nil
end

function achievement.category_counts()
  local counts = {}
  for _, entry in ipairs(catalog) do
    local category = tostring(entry.category or "")
    counts[category] = (counts[category] or 0) + 1
  end
  return counts
end

function achievement.ids_are_contiguous(start_id, end_id)
  local first_id, last_id = _id_range(start_id, end_id)
  if first_id == nil then
    return false
  end

  if #catalog ~= (last_id - first_id + 1) then
    return false
  end

  return _has_every_id(first_id, last_id)
end

function achievement.configure_progress_adapter(adapter)
  progress_adapter = adapter
end

function achievement.reset_for_tests()
  progress_adapter = nil
end

function achievement.mapped_ids_for_event(event_name)
  local mapped = event_progress[event_name]
  if mapped == nil then
    return {}
  end
  return _copy_ids(mapped.ids)
end

function achievement.add_progress(id, amount, role)
  return _apply_progress(id, amount, "add_achievement_progress", role)
end

function achievement.current_progress(id, role)
  local achievement_id = number_utils.to_integer(id)
  if achievement.find(achievement_id) == nil then
    return nil
  end
  local ok, result = _call_host(_resolve_adapter(role), "get_achievement_progress", achievement_id)
  if ok ~= true then
    return nil
  end
  return number_utils.to_integer(result)
end

function achievement.set_progress(id, count, role)
  return _apply_progress(id, count, "set_achievement_progress", role)
end

function achievement.record_gameplay_event(event_name, event_value, role)
  local mapped = event_progress[event_name]
  if mapped == nil then
    return false
  end

  local amount = number_utils.to_integer(event_value)
  if amount == nil then
    amount = mapped.default_amount
  end
  local advanced = false
  for _, id in ipairs(mapped.ids) do
    if achievement.add_progress(id, amount, role) then
      advanced = true
    end
  end
  return advanced
end

function achievement.snapshot()
  local adapter = _resolve_adapter()
  if adapter ~= nil and type(adapter.snapshot) == "function" then
    local ok, result = pcall(adapter.snapshot)
    if ok and type(result) == "table" then
      return result
    end
  end
  return {}
end

return achievement
