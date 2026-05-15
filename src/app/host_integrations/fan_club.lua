local fan_club = {
  host_pending = true,
  starting_cash_bonus_amount = 2000,
}

-- TODO_HOST_INTEGRATION: connect host fan-club membership check.
function fan_club.is_member()
  return false
end

function fan_club.starting_cash_bonus()
  if fan_club.is_member() then
    return fan_club.starting_cash_bonus_amount
  end
  return 0
end

return fan_club
