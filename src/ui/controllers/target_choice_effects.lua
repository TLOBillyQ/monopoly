local target_module = "src.ui.ctl.target_choice_effects"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.target_choice_effects"] = module
return module
