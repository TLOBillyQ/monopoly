local target_module = "src.ui.ctl.debug_view"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.debug_view"] = module
return module
