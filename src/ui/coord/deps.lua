local host_runtime_ports = require("src.ui.host_bridge")
local runtime_deps = {}

function runtime_deps.build(opts)
  return {
    runtime = require("src.ui.render.runtime_ui"),
    host_runtime = host_runtime_ports,
    ui_events = require("src.ui.coord.ui_events"),
    modal_state = require("src.ui.state.modal_state"),
    ui_touch_policy = require("src.ui.input.touch"),
    camera_sync = opts and opts.camera_sync or nil,
  }
end

return runtime_deps
