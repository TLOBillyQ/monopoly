local MarketUI = {
  container = nil,
  confirm_button = nil,
  cancel_button = nil,
  choose_event = nil,
  confirm_event = nil,
  cancel_event = nil,
  title = "黑市",
  icon_placeholder = "icon_placeholder",
}

function MarketUI.is_ready()
  return type(MarketUI.container) == "string" and MarketUI.container ~= ""
    and type(MarketUI.choose_event) == "string" and MarketUI.choose_event ~= ""
    and type(MarketUI.confirm_event) == "string" and MarketUI.confirm_event ~= ""
    and type(MarketUI.confirm_button) == "string" and MarketUI.confirm_button ~= ""
end

return MarketUI
