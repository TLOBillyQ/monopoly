local intent_dispatcher = require("turn.intent")

local presenter = {}

function presenter.push_popup(game, title, body, opts)
  if not (game and game.ui_port) then
    return false
  end
  opts = opts or {}
  intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = {
      title = title,
      body = body,
      kind = opts.kind,
      image_ref = opts.image_ref,
      auto_close_seconds = opts.auto_close_seconds,
    },
  })
  return true
end

function presenter.queue_action_anim(game, payload)
  if not (game and game.ui_port and game.ui_port.wait_action_anim) then
    return false
  end
  game:queue_action_anim(payload)
  return true
end

return presenter
