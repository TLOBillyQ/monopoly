local UIState = {}

function UIState.create(bridge)
  return setmetatable({
    bridge = bridge,
    auto_play = false,
    auto_interval = 0.1,
    selected_tile = nil,
    choice_active = false,
    popup_active = false,
    choice = {
      root = "modal_choice",
      title = "choice_title",
      body = "choice_body",
      cancel = "choice_cancel",
      option_buttons = {
        "choice_option_1",
        "choice_option_2",
        "choice_option_3",
        "choice_option_4",
      },
    },
    popup = {
      root = "modal_popup",
      title = "popup_title",
      body = "popup_body",
      confirm = "popup_confirm",
    },
  }, { __index = UIState })
end

function UIState:set_label(name, text)
  if self.bridge then
    self.bridge:set_label(name, text)
  end
end

function UIState:set_button(name, text)
  if self.bridge then
    self.bridge:set_button(name, text)
  end
end

function UIState:set_visible(name, visible)
  if self.bridge then
    self.bridge:set_visible(name, visible)
  end
end

function UIState:set_touch_enabled(name, enabled)
  if self.bridge then
    self.bridge:set_touch_enabled(name, enabled)
  end
end

return UIState
