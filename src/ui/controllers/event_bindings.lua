local target_module = "src.ui.ctl.event_bindings"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.event_bindings"] = module
return module
