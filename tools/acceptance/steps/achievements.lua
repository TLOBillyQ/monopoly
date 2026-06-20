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

local function _to_id_list(example, field)
  local ids = {}
  for raw in tostring(example[field] or ""):gmatch("[^,]+") do
    local id = number_utils.to_integer(raw)
    if id == nil then
      return nil, "invalid achievement id in " .. field .. ": " .. tostring(raw)
    end
    ids[#ids + 1] = id
  end
  if #ids == 0 then
    return nil, "empty achievement id list for " .. field
  end
  return ids
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

local function _ensure_progress_world(world)
  if world.achievement_progress == nil then
    world.achievement_progress = {}
  end
  if world.achievement_added == nil then
    world.achievement_added = {}
  end
  return world.achievement_progress
end

local function _set_progress_for_ids(world, ids, count)
  local progress = _ensure_progress_world(world)
  for _, id in ipairs(ids) do
    progress[id] = count
    world.achievement_added[id] = 0
  end
end

local function _assert_progress_for_ids(world, ids, expected)
  for _, id in ipairs(ids) do
    local actual = achievement.current_progress(id)
    local ok, err = _assert_equal(actual, expected, "achievement " .. tostring(id) .. " progress")
    if not ok then
      return nil, err
    end
  end
  return true
end

local function _assert_added_for_ids(world, ids, expected)
  for _, id in ipairs(ids) do
    local actual = world.achievement_added and world.achievement_added[id] or 0
    local ok, err = _assert_equal(actual, expected, "achievement " .. tostring(id) .. " added progress")
    if not ok then
      return nil, err
    end
  end
  return true
end

function achievements_steps.handlers()
  return {
    ["成就目录已加载"] = function(world)
      world.achievement_catalog = achievement.list()
      return true
    end,

    ["宿主成就进度接口已连接"] = function(world)
      achievement.reset_for_tests()
      local progress = _ensure_progress_world(world)
      achievement.configure_progress_adapter({
        add_achievement_progress = function(id, amount)
          local achievement_id = number_utils.to_integer(id)
          local add_count = number_utils.to_integer(amount)
          if achievement_id == nil or add_count == nil then
            return false
          end
          progress[achievement_id] = (progress[achievement_id] or 0) + add_count
          world.achievement_added[achievement_id] = (world.achievement_added[achievement_id] or 0) + add_count
          return true
        end,
        get_achievement_progress = function(id)
          return progress[number_utils.to_integer(id)] or 0
        end,
        set_achievement_progress = function(id, count)
          local achievement_id = number_utils.to_integer(id)
          local progress_count = number_utils.to_integer(count)
          if achievement_id == nil or progress_count == nil then
            return false
          end
          progress[achievement_id] = progress_count
          world.achievement_added[achievement_id] = 0
          return true
        end,
        snapshot = function()
          return progress
        end,
      })
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

    ["玩家成就编号<成就编号列表>当前进度均为<之前进度>"] = function(world, example)
      local ids, ids_err = _to_id_list(example, "成就编号列表")
      if ids == nil then
        return nil, ids_err
      end
      local progress, progress_err = _to_integer(example, "之前进度")
      if progress == nil then
        return nil, progress_err
      end
      _set_progress_for_ids(world, ids, progress)
      return true
    end,

    ["玩家成就编号<成就编号>当前进度为<之前进度>"] = function(world, example)
      local id, id_err = _to_integer(example, "成就编号")
      if id == nil then
        return nil, id_err
      end
      local progress, progress_err = _to_integer(example, "之前进度")
      if progress == nil then
        return nil, progress_err
      end
      _set_progress_for_ids(world, { id }, progress)
      return true
    end,

    ["玩家成就编号1当前进度为2"] = function(world)
      _set_progress_for_ids(world, { 1 }, 2)
      return true
    end,

    ["玩家成就编号25当前进度为1"] = function(world)
      _set_progress_for_ids(world, { 25 }, 1)
      return true
    end,

    ["玩家成就编号40当前进度为0"] = function(world)
      _set_progress_for_ids(world, { 40 }, 0)
      return true
    end,

    ["玩家完成<玩法事件>，事件数值为<事件数值>"] = function(world, example)
      local value, err = _to_integer(example, "事件数值")
      if value == nil then
        return nil, err
      end
      world.achievement_event_result = achievement.record_gameplay_event(example["玩法事件"], value)
      return true
    end,

    ["玩家完成<玩法事件>"] = function(world, example)
      world.achievement_event_result = achievement.record_gameplay_event(example["玩法事件"])
      return true
    end,

    ["玩家完成未映射事件"] = function(world)
      world.achievement_event_result = achievement.record_gameplay_event("未映射事件")
      return true
    end,

    ["玩家完成黑市购买失败"] = function(world)
      world.achievement_event_result = achievement.record_gameplay_event("黑市购买失败")
      return true
    end,

    ["玩家完成皮肤装备失败"] = function(world)
      world.achievement_event_result = achievement.record_gameplay_event("皮肤装备失败")
      return true
    end,

    ["玩家成就编号<成就编号列表>均增加<增加进度>点进度"] = function(world, example)
      local ids, ids_err = _to_id_list(example, "成就编号列表")
      if ids == nil then
        return nil, ids_err
      end
      local expected, expected_err = _to_integer(example, "增加进度")
      if expected == nil then
        return nil, expected_err
      end
      return _assert_added_for_ids(world, ids, expected)
    end,

    ["玩家成就编号<成就编号>增加<增加进度>点进度"] = function(world, example)
      local id, id_err = _to_integer(example, "成就编号")
      if id == nil then
        return nil, id_err
      end
      local expected, expected_err = _to_integer(example, "增加进度")
      if expected == nil then
        return nil, expected_err
      end
      return _assert_added_for_ids(world, { id }, expected)
    end,

    ["玩家成就编号<成就编号>没有增加进度"] = function(world, example)
      local id, id_err = _to_integer(example, "成就编号")
      if id == nil then
        return nil, id_err
      end
      return _assert_added_for_ids(world, { id }, 0)
    end,

    ["玩家成就编号1没有增加进度"] = function(world)
      return _assert_added_for_ids(world, { 1 }, 0)
    end,

    ["玩家成就编号25没有增加进度"] = function(world)
      return _assert_added_for_ids(world, { 25 }, 0)
    end,

    ["玩家成就编号40没有增加进度"] = function(world)
      return _assert_added_for_ids(world, { 40 }, 0)
    end,

    ["玩家成就编号<成就编号列表>当前进度均为<之后进度>"] = function(world, example)
      local ids, ids_err = _to_id_list(example, "成就编号列表")
      if ids == nil then
        return nil, ids_err
      end
      local expected, expected_err = _to_integer(example, "之后进度")
      if expected == nil then
        return nil, expected_err
      end
      return _assert_progress_for_ids(world, ids, expected)
    end,

    ["玩家成就编号<成就编号>当前进度为<之后进度>"] = function(world, example)
      local id, id_err = _to_integer(example, "成就编号")
      if id == nil then
        return nil, id_err
      end
      local expected, expected_err = _to_integer(example, "之后进度")
      if expected == nil then
        return nil, expected_err
      end
      return _assert_progress_for_ids(world, { id }, expected)
    end,

    ["玩家成就编号1当前进度仍为2"] = function(world)
      return _assert_progress_for_ids(world, { 1 }, 2)
    end,

    ["玩家成就编号25当前进度仍为1"] = function(world)
      return _assert_progress_for_ids(world, { 25 }, 1)
    end,

    ["玩家成就编号40当前进度仍为0"] = function(world)
      return _assert_progress_for_ids(world, { 40 }, 0)
    end,
  }
end

return achievements_steps
