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
version=2
projectHash=8df61d8d6e0bcde3
scope.0.id=chunk:src/ui/input/route_specs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=b723a83ebd1db3dc
scope.1.id=function:anonymous@10:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=24e446bc357e7c2c
scope.2.id=function:anonymous@4:4
scope.2.kind=function
scope.2.startLine=4
scope.2.endLine=17
scope.2.semanticHash=f06a875c06539909
scope.3.id=function:M.builder:3
scope.3.kind=function
scope.3.startLine=3
scope.3.endLine=18
scope.3.semanticHash=324768ab04795300
]]
