local test_profiles = require("src.app.testing.test_profiles")

-- 把部署注入的 STARTUP_AUTOTEST 选择器解析成有序 profile 名单。
-- 支持三种形态：
--   "all"              全部 profile（不含 default），按组序稳定排序
--   "group:<组名>"     指定组内全部 profile
--   "a,b,c"            显式逗号名单，保持书写顺序
local plan = {}

local function _trim(text)
  return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _resolve_all()
  local out = {}
  for _, name in ipairs(test_profiles.names()) do
    if name ~= "default" then
      out[#out + 1] = name
    end
  end
  return out
end

local function _resolve_group(group_name)
  assert(group_name ~= "", "autotest selector missing group name")
  local known = false
  for _, name in ipairs(test_profiles.groups()) do
    if name == group_name then
      known = true
      break
    end
  end
  assert(known, "unknown autotest group: " .. tostring(group_name))
  return test_profiles.profiles_in_group(group_name, { include_default = false })
end

local function _resolve_list(selector)
  local out = {}
  local seen = {}
  for raw_name in tostring(selector):gmatch("[^,]+") do
    local name = _trim(raw_name)
    if name ~= "" then
      assert(name ~= "default", "autotest list cannot include default")
      assert(test_profiles.has(name), "unknown autotest profile: " .. tostring(name))
      assert(seen[name] == nil, "duplicate autotest profile: " .. tostring(name))
      seen[name] = true
      out[#out + 1] = name
    end
  end
  return out
end

function plan.resolve(selector)
  assert(type(selector) == "string", "invalid autotest selector type")
  local trimmed = _trim(selector)
  assert(trimmed ~= "", "empty autotest selector")

  local resolved
  if trimmed == "all" then
    resolved = _resolve_all()
  else
    local group_name = trimmed:match("^group:(.*)$")
    if group_name ~= nil then
      resolved = _resolve_group(_trim(group_name))
    else
      resolved = _resolve_list(trimmed)
    end
  end
  assert(#resolved > 0, "autotest selector matched no profiles: " .. trimmed)
  return resolved
end

return plan
