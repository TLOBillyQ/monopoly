local leaderboard = {
  host_pending = true,
  quit_reasons = {
    disconnect = true,
    manual_exit = true,
    crash = true,
  },
}

-- TODO_HOST_INTEGRATION: connect host ranking submit and quit reason reporting.
function leaderboard.submit(_payload)
  return { ok = false, reason = "host_pending" }
end

function leaderboard.is_quit_reason(reason)
  return leaderboard.quit_reasons[reason] == true
end

return leaderboard
