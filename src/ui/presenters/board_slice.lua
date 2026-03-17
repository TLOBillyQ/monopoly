local target_module = "src.ui.pres.board_slice"
local module = package.loaded[target_module]
if module == nil then
  module = require(target_module)
end
package.loaded["src.ui.presenters.board_slice"] = module
return module
