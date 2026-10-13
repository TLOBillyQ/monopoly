-- ui/coord/deps.lua 直测:依赖装配器的字段契约。
-- build 返回宿主/渲染/事件/模态/触摸各依赖的模块引用,任一缺位即宿主启动崩溃;
-- camera_sync 仅在有 opts 提供时透传。
require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())

local deps = require("src.ui.coord.deps")

TestCoordDeps = {}

local function _modules()
  return {
    runtime = require("src.ui.render.support.runtime_ui"),
    host_runtime = require("src.ui.seams.host_runtime"),
    ui_events = require("src.ui.coord.ui_events"),
    modal = require("src.ui.state.modal"),
    touch = require("src.ui.input.touch"),
  }
end

function TestCoordDeps:test_build_wires_every_dependency()
  local m = _modules()
  local built = deps.build({})
  luassert.truthy(built.runtime == m.runtime, "the render runtime must be wired")
  luassert.truthy(built.host_runtime == m.host_runtime, "the host runtime ports must be wired")
  luassert.truthy(built.ui_events == m.ui_events, "the ui events must be wired")
  luassert.truthy(built.modal_state == m.modal, "the modal state must be wired")
  luassert.truthy(built.ui_touch_policy == m.touch, "the touch policy must be wired")
end

function TestCoordDeps:test_camera_sync_passthrough()
  local camera_sync = {}
  luassert.truthy(deps.build({ camera_sync = camera_sync }).camera_sync == camera_sync,
    "a provided camera sync must be forwarded")
end

function TestCoordDeps:test_camera_sync_defaults_to_nil()
  luassert.truthy(deps.build(nil).camera_sync == nil, "a nil opts must not provide camera sync")
  luassert.truthy(deps.build({}).camera_sync == nil,
    "an opts without camera_sync must not provide one")
end

return TestCoordDeps
