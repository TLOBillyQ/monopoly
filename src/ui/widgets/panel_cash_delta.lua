local target_module = "src.ui.wid.panel_cash_delta"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.widgets.panel_cash_delta"] = module
return module
