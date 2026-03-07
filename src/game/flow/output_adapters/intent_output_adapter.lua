local intent_dispatcher = require("src.game.flow.intent.intent_dispatcher")

local adapter = {}

function adapter.build()
  return {
    open_choice = function(game, choice_spec, opts)
      return intent_dispatcher.open_choice(game, choice_spec, opts)
    end,
    push_popup = function(game, payload, opts)
      return intent_dispatcher.push_popup(game, payload, opts)
    end,
  }
end

return adapter
