local target_module = "src.ui.wid.panel_player_slots"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.widgets.panel_player_slots"] = module
return module
