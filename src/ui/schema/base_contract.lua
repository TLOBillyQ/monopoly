local nodes = require("src.ui.schema.base")

return {
  key = "base",
  canvas = nodes.canvas,
  action_log = {
    label = nodes.action_log_label,
    toggle_targets = { nodes.action_log_button },
  },
}
