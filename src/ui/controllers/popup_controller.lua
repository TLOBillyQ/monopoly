local target_module = "src.ui.ctl.popup_controller"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.popup_controller"] = module
return module
