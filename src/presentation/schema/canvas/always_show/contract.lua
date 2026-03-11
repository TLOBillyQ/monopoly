local nodes = require("src.presentation.schema.canvas.always_show.nodes")

return {
  key = "always_show",
  canvas = nodes.canvas,
  action_log = {
    label = "日志",
    toggle_targets = { nodes.action_log_button },
  },
}
