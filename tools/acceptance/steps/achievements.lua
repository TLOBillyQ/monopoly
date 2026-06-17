local number_utils = require("src.foundation.number")
local achievement = require("src.app.host_integrations.achievement")

local achievements_steps = {}

local function _to_integer(example, field)
  local value = number_utils.to_integer(example[field])
  if value == nil then
    return nil, "invalid integer for " .. field .. ": " .. tostring(example[field])
  end
  return value
end

local function _ensure_current(world)
  local current = world.achievement_current
  if current == nil then
    return nil, "no achievement selected"
  end
  return current
end

local function _assert_equal(actual, expected, label)
  if actual ~= expected then
    return nil, label .. " mismatch: expected " .. tostring(expected) .. ", got " .. tostring(actual)
  end
  return true
end

local function _assert_current_field(field_name, example_field, label, convert)
  return function(world, example)
    local current, err = _ensure_current(world)
    if current == nil then
      return nil, err
    end
    local expected = example[example_field]
    if convert ~= nil then
      expected = convert(expected)
      if expected == nil then
        return nil, "invalid expected " .. label .. ": " .. tostring(example[example_field])
      end
    end
    return _assert_equal(current[field_name], expected, label)
  end
end

local function _expected_bool(value)
  if value == "true" then
    return true
  end
  if value == "false" then
    return false
  end
  return nil
end

function achievements_steps.handlers()
  return {
    ["成就目录已加载"] = function(world)
      world.achievement_catalog = achievement.list()
      return true
    end,

    ["成就目录包含<总数>条成就"] = function(_, example)
      local expected, err = _to_integer(example, "总数")
      if expected == nil then
        return nil, err
      end
      return _assert_equal(achievement.count(), expected, "achievement count")
    end,

    ["成就编号从<起始编号>连续到<结束编号>"] = function(_, example)
      local first_id, first_err = _to_integer(example, "起始编号")
      if first_id == nil then
        return nil, first_err
      end
      local last_id, last_err = _to_integer(example, "结束编号")
      if last_id == nil then
        return nil, last_err
      end
      if achievement.ids_are_contiguous(first_id, last_id) ~= true then
        return nil, "achievement ids are not contiguous from " .. tostring(first_id) .. " to " .. tostring(last_id)
      end
      return true
    end,

    ["成就目录包含<简单数>个简单成就"] = function(_, example)
      local expected, err = _to_integer(example, "简单数")
      if expected == nil then
        return nil, err
      end
      return _assert_equal(achievement.category_counts()["简单"], expected, "简单 achievement count")
    end,

    ["成就目录包含<普通数>个普通成就"] = function(_, example)
      local expected, err = _to_integer(example, "普通数")
      if expected == nil then
        return nil, err
      end
      return _assert_equal(achievement.category_counts()["普通"], expected, "普通 achievement count")
    end,

    ["成就目录包含<困难数>个困难成就"] = function(_, example)
      local expected, err = _to_integer(example, "困难数")
      if expected == nil then
        return nil, err
      end
      return _assert_equal(achievement.category_counts()["困难"], expected, "困难 achievement count")
    end,

    ["成就目录包含<传奇数>个传奇成就"] = function(_, example)
      local expected, err = _to_integer(example, "传奇数")
      if expected == nil then
        return nil, err
      end
      return _assert_equal(achievement.category_counts()["传奇"], expected, "传奇 achievement count")
    end,

    ["成就目录包含<隐藏数>个隐藏成就"] = function(_, example)
      local expected, err = _to_integer(example, "隐藏数")
      if expected == nil then
        return nil, err
      end
      return _assert_equal(achievement.category_counts()["隐藏"], expected, "隐藏 achievement count")
    end,

    ["查询编号为<成就编号>的成就"] = function(world, example)
      local id, err = _to_integer(example, "成就编号")
      if id == nil then
        return nil, err
      end
      local current = achievement.find(id)
      if current == nil then
        return nil, "missing achievement id " .. tostring(id)
      end
      world.achievement_current = current
      return true
    end,

    ["成就名称为<成就名称>"] = _assert_current_field("name", "成就名称", "achievement name"),
    ["成就类型为<成就类型>"] = _assert_current_field("category", "成就类型", "achievement category"),
    ["成就达成条件为<达成条件>"] = _assert_current_field("condition", "达成条件", "achievement condition"),
    ["成就目标进度为<目标进度>"] = _assert_current_field("target_progress", "目标进度", "achievement target", number_utils.to_integer),

    ["为成就编号<成就编号>增加<增加进度>点进度"] = function(world, example)
      local id, id_err = _to_integer(example, "成就编号")
      if id == nil then
        return nil, id_err
      end
      local amount, amount_err = _to_integer(example, "增加进度")
      if amount == nil then
        return nil, amount_err
      end
      world.achievement_progress_result = achievement.add_progress(id, amount)
      return true
    end,

    ["成就进度增加结果为<增加结果>"] = function(world, example)
      local expected = _expected_bool(example["增加结果"])
      if expected == nil then
        return nil, "invalid expected progress result: " .. tostring(example["增加结果"])
      end
      return _assert_equal(world.achievement_progress_result, expected, "achievement progress result")
    end,

    ["成就进度快照为空"] = function()
      if next(achievement.snapshot()) ~= nil then
        return nil, "achievement progress snapshot should be empty"
      end
      return true
    end,
  }
end

return achievements_steps
