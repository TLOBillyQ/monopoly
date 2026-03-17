local target_module = "src.ui.pres.panel_builder"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.panel_builder"] = module
return module
