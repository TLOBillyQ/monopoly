local share_task = {
  host_pending = true,
  reward = { currency = "金币", amount = 1000 },
}

-- TODO_HOST_INTEGRATION: connect host share callback and completion state.
function share_task.is_available()
  return false
end

function share_task.claim()
  return { ok = false, reason = "host_pending" }
end

return share_task
