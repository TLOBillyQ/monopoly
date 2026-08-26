local number_utils = require("src.foundation.number")

local row_field = {}

function row_field.to_integer(row, key)
  if not row then
    return nil
  end
  return number_utils.to_integer(row[key])
end

return row_field

--[[ mutate4lua-manifest
version=4
projectHash=220f2a9f69f527f6
scope.0.id=chunk:src/ui/render/widgets/row_field.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=13
scope.0.semanticHash=c9d87e9e3f2bc7f6
scope.1.id=function:row_field.to_integer
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=4fee8c085774cb39
]]
