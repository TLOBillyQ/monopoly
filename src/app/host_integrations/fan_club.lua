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

--[[ mutate4lua-manifest
version=2
projectHash=309081ceb6b2e147
scope.0.id=chunk:src/app/host_integrations/fan_club.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=19
scope.0.semanticHash=79a4b6c9bccb7aea
scope.1.id=function:fan_club.is_member:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=1814cf07fe435b79
scope.2.id=function:fan_club.starting_cash_bonus:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=16
scope.2.semanticHash=e5dbadbc0a2474a1
]]
