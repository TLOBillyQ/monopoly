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
  if first_id == nil or last_id == nil then
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

--[[ mutate4lua-manifest
version=2
projectHash=67e8291e60b8df1b
scope.0.id=chunk:src/app/host_integrations/achievement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=186
scope.0.semanticHash=cf2af2035b326e71
scope.0.lastMutatedAt=2026-07-07T04:12:03Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=28
scope.0.lastMutationKilled=28
scope.1.id=function:_resolve_adapter:21
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=30
scope.1.semanticHash=c7e098da156f1e9f
scope.1.lastMutatedAt=2026-07-07T04:12:03Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_valid_progress_args:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=34
scope.2.semanticHash=f65051257fe7b6be
scope.2.lastMutatedAt=2026-07-07T04:12:03Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_call_host:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=45
scope.3.semanticHash=11a4133d1ce2d639
scope.3.lastMutatedAt=2026-07-07T04:12:03Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=12
scope.3.lastMutationKilled=12
scope.4.id=function:_apply_progress:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=55
scope.4.semanticHash=f7909f5ff2fab6ec
scope.4.lastMutatedAt=2026-07-07T04:12:03Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=8
scope.4.lastMutationKilled=8
scope.5.id=function:_id_range:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=64
scope.5.semanticHash=b783aa3d17b6e8df
scope.5.lastMutatedAt=2026-07-07T04:12:03Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:achievement.list:75
scope.6.kind=function
scope.6.startLine=75
scope.6.endLine=77
scope.6.semanticHash=353c3c59fd6ad475
scope.6.lastMutatedAt=2026-07-07T03:15:59Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=no_sites
scope.6.lastMutationSites=0
scope.6.lastMutationKilled=0
scope.7.id=function:achievement.count:79
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=81
scope.7.semanticHash=734b4014b4cf3831
scope.7.lastMutatedAt=2026-07-07T03:15:59Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:achievement.ids_are_contiguous:106
scope.8.kind=function
scope.8.startLine=106
scope.8.endLine=117
scope.8.semanticHash=6e39981bcaf7c139
scope.8.lastMutatedAt=2026-07-07T04:12:03Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=9
scope.8.lastMutationKilled=9
scope.9.id=function:achievement.configure_progress_adapter:119
scope.9.kind=function
scope.9.startLine=119
scope.9.endLine=121
scope.9.semanticHash=3dc2873b311aa7bc
scope.9.lastMutatedAt=2026-07-07T03:15:59Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=no_sites
scope.9.lastMutationSites=0
scope.9.lastMutationKilled=0
scope.10.id=function:achievement.reset_for_tests:123
scope.10.kind=function
scope.10.startLine=123
scope.10.endLine=125
scope.10.semanticHash=6c6ac5c880467fa0
scope.10.lastMutatedAt=2026-07-07T03:15:59Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=no_sites
scope.10.lastMutationSites=0
scope.10.lastMutationKilled=0
scope.11.id=function:achievement.mapped_ids_for_event:127
scope.11.kind=function
scope.11.startLine=127
scope.11.endLine=133
scope.11.semanticHash=556b06257f53c6a6
scope.11.lastMutatedAt=2026-07-07T04:12:03Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=2
scope.11.lastMutationKilled=2
scope.12.id=function:achievement.add_progress:135
scope.12.kind=function
scope.12.startLine=135
scope.12.endLine=137
scope.12.semanticHash=8d0e3b48de3464fe
scope.12.lastMutatedAt=2026-07-07T04:12:03Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:achievement.current_progress:139
scope.13.kind=function
scope.13.startLine=139
scope.13.endLine=149
scope.13.semanticHash=71ba0c8a71f2bf0e
scope.13.lastMutatedAt=2026-07-07T04:12:03Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=7
scope.13.lastMutationKilled=7
scope.14.id=function:achievement.set_progress:151
scope.14.kind=function
scope.14.startLine=151
scope.14.endLine=153
scope.14.semanticHash=6d83cb6f8df073ee
scope.14.lastMutatedAt=2026-07-07T04:12:03Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:achievement.snapshot:174
scope.15.kind=function
scope.15.startLine=174
scope.15.endLine=183
scope.15.semanticHash=78abf26c041773ac
scope.15.lastMutatedAt=2026-07-07T04:12:03Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=11
scope.15.lastMutationKilled=11
]]
