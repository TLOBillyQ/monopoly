local target_module = "src.ui.ctl.ports.debug_ports"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.ports.debug_ports"] = module
return module
