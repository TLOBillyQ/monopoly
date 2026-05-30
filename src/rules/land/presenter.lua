local intent_output_port = require("src.rules.ports.intent_output")
local action_anim_port = require("src.foundation.ports.action_anim")

local presenter = {}

function presenter.push_popup(game, title, body, opts)
  if not game then
    return false
  end
  opts = opts or {}
  return intent_output_port.push_popup(game, {
    title = title,
    body = body,
    kind = opts.kind,
    image_ref = opts.image_ref,
    auto_close_seconds = opts.auto_close_seconds,
  }, opts.popup_opts) == true
end

presenter.queue_action_anim = action_anim_port.queue

return presenter

--[[ mutate4lua-manifest
version=2
projectHash=fa5fe199e809c3d1
scope.0.id=chunk:src/rules/land/presenter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=23
scope.0.semanticHash=225cc8e45cc90be3
scope.1.id=function:presenter.push_popup:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=18
scope.1.semanticHash=3f96fe94d9c3accd
]]
