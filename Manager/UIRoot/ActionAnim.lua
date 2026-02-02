require "Globals.Macro"

local ActionAnim = {}

local DURATIONS = {
  roll = 1.0,
  roadblock = 0.8,
  mine = 0.8,
  missile = 1.2,
  monster = 1.2,
  clear_obstacles = 1.0,
}

local function _BuildTip(anim)
  local kind = anim.kind
  if kind == "roll" then
    local rolls = anim.rolls and table.concat(anim.rolls, ",") or "?"
    local total = anim.total or "?"
    return "投骰动画：" .. rolls .. " => " .. total
  end
  if kind == "roadblock" then
    return "路障动画：放置在格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "mine" then
    return "地雷动画：埋设在格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "missile" then
    return "导弹动画：轰炸格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "monster" then
    return "怪兽动画：破坏格子 " .. tostring(anim.tile_index or "?")
  end
  if kind == "clear_obstacles" then
    local count = anim.cleared_indices and #anim.cleared_indices or 0
    return "清障动画：清除数量 " .. tostring(count)
  end
  return "动作动画"
end

function ActionAnim.Play(_, anim)
  assert(anim ~= nil, "missing anim")
  local duration = anim.duration or DURATIONS[anim.kind] or 1.0
  local tip_duration = duration
  if type(duration) == "number" and math and math.tofixed then
    tip_duration = math.tofixed(duration)
  end
  GlobalAPI.show_tips(_BuildTip(anim), tip_duration)
  return duration
end

return ActionAnim

