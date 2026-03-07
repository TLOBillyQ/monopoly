local intent_output_port = require("src.game.ports.intent_output_port")
local action_anim_port = require("src.core.ports.action_anim_port")

local landing_presenter = {}

function landing_presenter.push_popup(game, title, body, opts)
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

function landing_presenter.queue_action_anim(game, payload)
  return action_anim_port.queue(game, payload)
end

return landing_presenter
