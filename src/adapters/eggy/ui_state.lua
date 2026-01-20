local UIState = {}

function UIState.create()
  return {
    auto_play = false,
    auto_interval = 0.1,
  }
end

return UIState
