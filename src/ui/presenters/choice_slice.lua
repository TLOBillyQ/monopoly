local target_module = "src.ui.pres.choice_slice"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.choice_slice"] = module
return module
