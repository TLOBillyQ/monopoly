local number_utils = require("src.foundation.number")
local catalog = require("src.config.content.achievements")
local role_resolver = require("src.host.role_resolver")

local achievement = {
  host_pending = false,
  catalog = catalog,
}

local progress_adapter = nil

local EVENT_PROGRESS = {
  ["游戏胜利"] = { ids = { 1, 2, 3, 4 }, default_amount = 1 },
  ["买下地块"] = { ids = { 5, 6, 7, 8 }, default_amount = 1 },
  ["收取金币"] = { ids = { 9, 10, 11, 12 }, default_amount = 1 },
  ["支付税金"] = { ids = { 13, 14, 15, 16 }, default_amount = 1 },
  ["使用道具卡"] = { ids = { 17, 18, 19, 20 }, default_amount = 1 },
  ["抽到机会卡"] = { ids = { 21, 22, 23, 24 }, default_amount = 1 },
  ["黑市购买道具"] = { ids = { 25, 26, 27, 28 }, default_amount = 1 },
  ["加盖1级建筑"] = { ids = { 29 }, default_amount = 1 },
  ["加盖2级建筑"] = { ids = { 30 }, default_amount = 1 },
  ["加盖3级建筑"] = { ids = { 31 }, default_amount = 1 },
  ["被福神附身"] = { ids = { 32 }, default_amount = 1 },
  ["被财神附身"] = { ids = { 33 }, default_amount = 1 },
  ["被穷神附身"] = { ids = { 34 }, default_amount = 1 },
  ["被送进医院"] = { ids = { 35 }, default_amount = 1 },
  ["被送进深山"] = { ids = { 36 }, default_amount = 1 },
  ["获得三个连续地块"] = { ids = { 37 }, default_amount = 1 },
  ["被怪兽拆除房屋"] = { ids = { 38 }, default_amount = 1 },
  ["被台风拆除房屋"] = { ids = { 39 }, default_amount = 1 },
  ["使用小猪佩奇皮肤"] = { ids = { 40 }, default_amount = 1 },
  ["使用小猪乔治皮肤"] = { ids = { 41 }, default_amount = 1 },
  ["使用海绵宝宝皮肤"] = { ids = { 42 }, default_amount = 1 },
  ["使用派大星皮肤"] = { ids = { 43 }, default_amount = 1 },
  ["使用奶龙皮肤"] = { ids = { 44 }, default_amount = 1 },
  ["使用水豚嘟嘟皮肤"] = { ids = { 45 }, default_amount = 1 },
}

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
  local first_id = number_utils.to_integer(start_id)
  local last_id = number_utils.to_integer(end_id)
  if first_id == nil or last_id == nil or last_id < first_id then
    return false
  end

  if #catalog ~= (last_id - first_id + 1) then
    return false
  end

  for expected_id = first_id, last_id do
    if achievement.find(expected_id) == nil then
      return false
    end
  end
  return true
end

function achievement.configure_progress_adapter(adapter)
  progress_adapter = adapter
end

function achievement.reset_for_tests()
  progress_adapter = nil
end

function achievement.mapped_ids_for_event(event_name)
  local mapped = EVENT_PROGRESS[event_name]
  if mapped == nil then
    return {}
  end
  return _copy_ids(mapped.ids)
end

function achievement.add_progress(id, amount, role)
  local achievement_id = number_utils.to_integer(id)
  local add_count = number_utils.to_integer(amount)
  if not _valid_progress_args(achievement_id, add_count) then
    return false
  end
  local ok = _call_host(_resolve_adapter(role), "add_achievement_progress", achievement_id, add_count)
  return ok == true
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
  local achievement_id = number_utils.to_integer(id)
  local progress_count = number_utils.to_integer(count)
  if not _valid_progress_args(achievement_id, progress_count) then
    return false
  end
  local ok = _call_host(_resolve_adapter(role), "set_achievement_progress", achievement_id, progress_count)
  return ok == true
end

function achievement.record_gameplay_event(event_name, event_value, role)
  local mapped = EVENT_PROGRESS[event_name]
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
