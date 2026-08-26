local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local achievement = require("src.app.host_integrations.achievement")
-- 成就域绑定（#192 簇 B）：目录/进度全走真实 src.app.host_integrations.achievement,宿主进度
-- 接口以内存 adapter 接入,覆盖 achievements 与 achievement_progress 两个 feature。
-- 「当前进度」句面同形合并：玩法事件发生前为种子设值,发生后为断言。
local function _id_list(text)
  local ids = {}
  for raw in tostring(text or ""):gmatch("[^,]+") do ids[#ids + 1] = assert(number_utils.to_integer(raw), "非法成就编号: " .. tostring(raw)) end
  assert(#ids > 0, "成就编号列表为空")
  return ids
end
local function _progress_world(w) w.ach_progress, w.ach_added = w.ach_progress or {}, w.ach_added or {}; return w.ach_progress end
local function _seed(w, ids, count)
  local progress = _progress_world(w)
  for _, id in ipairs(ids) do progress[id], w.ach_added[id] = count, 0 end
  return true
end
local function _assert_progress(ids, expected)
  for _, id in ipairs(ids) do
    local ok, err = dsl.eq(achievement.current_progress(id), expected, "成就" .. tostring(id) .. " 进度")
    if not ok then return nil, err end
  end
  return true
end
local function _seed_or_assert(w, ids, count)
  if w.ach_event_result == nil then return _seed(w, ids, count) end
  return _assert_progress(ids, count)
end
local function _sa_list(w, a) return _seed_or_assert(w, _id_list(a["成就编号列表"]), a["之前进度"]) end
local function _sa_one(w, a) return _seed_or_assert(w, { a["成就编号"] }, a["之前进度"]) end
local function _assert_added(w, ids, expected)
  for _, id in ipairs(ids) do
    local ok, err = dsl.eq((w.ach_added or {})[id] or 0, expected, "成就" .. tostring(id) .. " 新增进度")
    if not ok then return nil, err end
  end
  return true
end
local function _field_eq(field, arg_name, label)
  return function(w, a)
    if w.ach_current == nil then return nil, "未选中成就" end
    return dsl.eq(w.ach_current[field], a[arg_name], label)
  end
end
local function _record_event(w, a) w.ach_event_result = achievement.record_gameplay_event(a["玩法事件"]); return true end
local defs = {
  ["成就目录已加载"] = function() return dsl.truthy(achievement.list(), "成就目录可加载") end,
  ["宿主成就进度接口已连接"] = function(w)
    achievement.reset_for_tests()
    local progress = _progress_world(w)
    achievement.configure_progress_adapter({
      add_achievement_progress = function(id, amount)
        local aid, add = number_utils.to_integer(id), number_utils.to_integer(amount)
        if aid == nil or add == nil then return false end
        progress[aid], w.ach_added[aid] = (progress[aid] or 0) + add, (w.ach_added[aid] or 0) + add
        return true
      end,
      get_achievement_progress = function(id) return progress[number_utils.to_integer(id)] or 0 end,
      set_achievement_progress = function(id, count)
        local aid, value = number_utils.to_integer(id), number_utils.to_integer(count)
        if aid == nil or value == nil then return false end
        progress[aid], w.ach_added[aid] = value, 0
        return true
      end,
      snapshot = function() return progress end,
    })
  end,
  ["查询编号为<成就编号:int>的成就"] = function(w, a)
    w.ach_current = achievement.find(a["成就编号"])
    return dsl.truthy(w.ach_current, "成就存在: " .. tostring(a["成就编号"]))
  end,
  ["成就达成条件为<达成条件>"] = _field_eq("condition", "达成条件", "成就达成条件"),
  ["成就目标进度为<目标进度:int>"] = _field_eq("target_progress", "目标进度", "成就目标进度"),
  -- 同形合并：<之前进度>（种子）与 <之后进度>（断言）经形状层共用一个注册。
  ["玩家成就编号<成就编号列表>当前进度均为<之前进度:int>"] = _sa_list,
  ["玩家成就编号<成就编号:int>当前进度为<之前进度:int>"] = _sa_one,
  ["玩家成就编号{成就编号:int}当前进度为{进度:int}"] = function(w, a) return _seed(w, { a["成就编号"] }, a["进度"]) end,
  ["玩家成就编号{成就编号:int}当前进度仍为{进度:int}"] = function(w, a) return _assert_progress({ a["成就编号"] }, a["进度"]) end,
  ["玩家完成<玩法事件>，事件数值为<事件数值:int>"] = function(w, a) w.ach_event_result = achievement.record_gameplay_event(a["玩法事件"], a["事件数值"]) end,
  ["玩家完成<玩法事件>"] = _record_event, ["玩家完成{玩法事件}"] = _record_event,
  ["玩家成就编号<成就编号列表>均增加<增加进度:int>点进度"] = function(w, a) return _assert_added(w, _id_list(a["成就编号列表"]), a["增加进度"]) end,
  ["玩家成就编号<成就编号:int>增加<增加进度:int>点进度"] = function(w, a) return _assert_added(w, { a["成就编号"] }, a["增加进度"]) end,
  ["玩家成就编号{成就编号:int}没有增加进度"] = function(w, a) return _assert_added(w, { a["成就编号"] }, 0) end,
}
return dsl.steps(defs, { name = "achievements" })
