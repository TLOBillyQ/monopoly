-- 「带 reset 的默认值配置模块」工厂。
-- 收敛 config/content/constants 与 config/gameplay/debug_flags 的同形模块体：
-- defaults 表 → 已铺好默认值、且挂 reset() 的模块表。
-- reset() 清掉调用方后加的所有键,再铺回 defaults(元表上的 reset 自身不受影响)。
local M = {}

local function _apply_defaults(target, defaults)
  for key, value in pairs(defaults) do
    target[key] = value
  end
end

function M.build(defaults)
  local module_table = {}
  _apply_defaults(module_table, defaults)
  setmetatable(module_table, {
    __index = {
      reset = function()
        for key in pairs(module_table) do
          module_table[key] = nil
        end
        _apply_defaults(module_table, defaults)
      end,
    },
  })
  return module_table
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=ca08b8beb365aa25
scope.0.id=chunk:src/foundation/resettable_defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=d093a2f78c43c5e5
scope.1.id=function:_apply_defaults
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=813f5b2fa67debce
scope.2.id=function:M.build
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=27
scope.2.semanticHash=8deab59961d5ad63
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=23
scope.3.semanticHash=a9138e7b4b95a71a
]]
