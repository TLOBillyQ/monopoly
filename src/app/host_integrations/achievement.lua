local achievement = {
  host_pending = true,
}

-- TODO_HOST_INTEGRATION: connect host achievement progress APIs.
function achievement.add_progress(_event_id, _count)
  return false
end

function achievement.snapshot()
  return {}
end

return achievement
