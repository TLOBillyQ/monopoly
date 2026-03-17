local target_module = "src.ui.ctl.item_slots"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.item_slots"] = module
return module
