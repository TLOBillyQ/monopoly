local catalog = require("src.config.content.achievements")

local achievement = {
  host_pending = true,
  catalog = catalog,
}

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
