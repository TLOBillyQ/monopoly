local nodes = require("src.ui.schema.always_show")

return {
  key = "always_show",
  canvas = nodes.canvas,
  action_log = {
    label = "日志",
    toggle_targets = { nodes.action_log_button },
  },
}
