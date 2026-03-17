local target_module = "src.ui.ctl.ports.ui_sync.ui_gate_sync"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.ports.ui_sync.ui_gate_sync"] = module
return module
