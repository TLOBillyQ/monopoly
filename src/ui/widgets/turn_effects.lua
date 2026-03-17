local target_module = "src.ui.wid.turn_effects"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.widgets.turn_effects"] = module
return module
