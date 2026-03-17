local target_module = "src.ui.ctl.choice_screens.helpers"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.choice_screens.helpers"] = module
return module
