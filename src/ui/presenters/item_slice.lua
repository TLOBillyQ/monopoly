local target_module = "src.ui.pres.item_slice"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.item_slice"] = module
return module
