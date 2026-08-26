local landing_result = {}

function landing_result.settle(finish_choice, game, result)
  if result and result.stay then
    return result
  end
  return finish_choice(game, false)
end

return landing_result

--[[ mutate4lua-manifest
version=4
projectHash=6d469dc77ee9c2f6
scope.0.id=chunk:src/rules/choice_handlers/landing_result.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=11
scope.0.semanticHash=c35079da8a49f6a0
scope.1.id=function:landing_result.settle
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=3483d36844cadf28
]]
