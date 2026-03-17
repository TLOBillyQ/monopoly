local target_module = "src.ui.ctl.local_actor_resolver"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.controllers.local_actor_resolver"] = module
return module
