local target_module = "src.ui.pres.gameplay_read_port"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.gameplay_read_port"] = module
return module
