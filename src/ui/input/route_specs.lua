local M = {}

function M.builder(intent_type)
  return function(specs, name, action)
    if not name then
      return
    end
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return {
          type = intent_type,
          action = action,
        }
      end,
    }
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=5061c21651cb9403
scope.0.id=chunk:src/ui/input/route_specs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=397e0ccb8e38a21c
scope.1.id=function:M.builder
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=18
scope.1.semanticHash=d6b9901bbd99e540
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=4
scope.2.endLine=17
scope.2.semanticHash=07490672e8bd163f
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=10
scope.3.endLine=15
scope.3.semanticHash=294c496fc6e380c8
]]
