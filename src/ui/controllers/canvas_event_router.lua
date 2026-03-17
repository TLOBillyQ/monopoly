local target_module = "src.ui.ctl.canvas_event_router"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.canvas_event_router"] = module
return module
