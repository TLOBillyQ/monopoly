local target_module = "src.ui.pres.init"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.init"] = module
return module
