local cash_display = {}

function cash_display.for_player(game, player)
  return game:player_balance(player, "金币") or 0
end

return cash_display

--[[ mutate4lua-manifest
version=2
projectHash=58f005ffb95b6383
scope.0.id=chunk:src/rules/market/cash_display.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=8
scope.0.semanticHash=3e946875abc81611
scope.1.id=function:cash_display.for_player:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=e38a8d27e2f7ca35
]]
