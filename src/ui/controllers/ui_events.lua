local target_module = "src.ui.ctl.ui_events"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.ui_events"] = module
return module
