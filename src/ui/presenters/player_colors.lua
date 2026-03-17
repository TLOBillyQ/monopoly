local target_module = "src.ui.pres.player_colors"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.player_colors"] = module
return module
