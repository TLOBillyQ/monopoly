local target_module = "src.ui.ctl.deps"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.deps"] = module
return module
