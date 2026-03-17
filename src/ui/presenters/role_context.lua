local target_module = "src.ui.pres.role_context"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.role_context"] = module
return module
