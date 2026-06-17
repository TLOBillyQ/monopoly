local number_utils = require("src.foundation.number")
local catalog = require("src.config.content.achievements")

local achievement = {
  host_pending = true,
  catalog = catalog,
}

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

-- TODO_HOST_INTEGRATION: connect host achievement progress APIs. The catalog
-- above is exported from the editor project save by
-- tools/ops/export_achievements.py (full table: name/desc/condition/type/target).
-- Progress tracking and unlock delivery are owned by the host achievement system.
function achievement.add_progress(_event_id, _count)
  return false
end

function achievement.snapshot()
  return {}
end

return achievement
