local runtime_deps = {}

function runtime_deps.build()
  return {
    runtime = require("src.presentation.runtime.ui"),
    host_runtime = require("src.presentation.runtime.host"),
    ui_events = require("src.presentation.runtime.events"),
    modal_state = require("src.presentation.runtime.modal_state"),
    ui_touch_policy = require("src.presentation.input.touch_policy"),
  }
end

return runtime_deps
