local host_runtime_ports = require("src.ui.ctl.ports.host_runtime_ports")
local runtime_deps = {}

function runtime_deps.build()
  return {
    runtime = require("src.ui.render.runtime_ui"),
    host_runtime = host_runtime_ports,
    ui_events = require("src.ui.ctl.ui_events"),
    modal_state = require("src.ui.stores.modal_state"),
    ui_touch_policy = require("src.ui.input.touch_policy"),
  }
end

return runtime_deps
