local cash_display = {}

function cash_display.for_player(game, player)
  return game:player_balance(player, "金币") or 0
end

return cash_display
