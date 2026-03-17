local target_module = "src.ui.ctl.market_controller"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.market_controller"] = module
return module
