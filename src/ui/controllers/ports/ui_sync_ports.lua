local target_module = "src.ui.ctl.ports.ui_sync_ports"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.ports.ui_sync_ports"] = module
return module
