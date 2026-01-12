local UI = {}

-- UI port wrapper; payload keeps title/body/body_lines/options/on_select
function UI.push_popup(game, payload)
  if game and game.ui_hooks and game.ui_hooks.push_popup then
    game.ui_hooks.push_popup({
      title = payload.title,
      body = payload.body,
      severity = payload.severity,
    })
    return true
  end
  return false
end

function UI.request_choice(game, payload)
  if not game or not game.ui_hooks or not game.ui_hooks.request_choice then
    return false
  end
  game.ui_hooks.request_choice({
    title = payload.title,
    candidates = payload.candidates or payload.options,
    body_lines = payload.body_lines or {},
    on_select = payload.on_select,
    allow_cancel = payload.allow_cancel,
    cancel_label = payload.cancel_label,
  })
  return true
end

return UI
