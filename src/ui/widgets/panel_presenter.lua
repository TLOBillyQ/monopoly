local target_module = "src.ui.wid.panel_presenter"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.widgets.panel_presenter"] = module
return module
