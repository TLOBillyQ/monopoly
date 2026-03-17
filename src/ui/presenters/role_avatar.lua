local target_module = "src.ui.pres.role_avatar"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.role_avatar"] = module
return module
