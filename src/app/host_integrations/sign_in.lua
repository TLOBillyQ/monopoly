local sign_in = {
  host_pending = true,
  reward = { currency = "金币", amount = 1000 },
}

-- TODO_HOST_INTEGRATION: connect host calendar and first-login-of-day state.
function sign_in.should_show_popup()
  return false
end

function sign_in.claim()
  return { ok = false, reason = "host_pending" }
end

return sign_in
