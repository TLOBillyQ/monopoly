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
    broadcast = opts.broadcast,
  }, opts.popup_opts) == true
end

presenter.queue_action_anim = action_anim_port.queue

return presenter

--[[ mutate4lua-manifest
version=4
projectHash=6c5f355b4d6a7c6d
scope.0.id=chunk:src/rules/land/presenter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=24
scope.0.semanticHash=226827bb45b45976
scope.1.id=function:presenter.push_popup
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=19
scope.1.semanticHash=c4796195fa7c8d19
]]
