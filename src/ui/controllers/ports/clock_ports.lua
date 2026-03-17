local target_module = "src.ui.ctl.ports.clock_ports"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.ports.clock_ports"] = module
return module
