local target_module = "src.ui.pres.choice_support"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.choice_support"] = module
return module
