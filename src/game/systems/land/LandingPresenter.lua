local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")
local action_anim_port = require("src.core.ActionAnimPort")

local landing_presenter = {}

function landing_presenter.push_popup(game, title, body, opts)
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

function landing_presenter.queue_action_anim(game, payload)
  return action_anim_port.queue(game, payload)
end

return landing_presenter
