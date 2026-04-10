local base_nodes = require("src.ui.schema.base")

local M = {}

function M.resolve_label(choice)
  if choice and choice.kind == "item_phase_passive" then
    return "继续"
  end
  return ""
end

function M.apply(ui, choice)
  if not (ui and ui.set_label) then
    return
  end
  ui:set_label(base_nodes.action_button, M.resolve_label(choice))
end

return M
