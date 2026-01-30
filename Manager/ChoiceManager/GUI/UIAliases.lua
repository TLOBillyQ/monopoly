local UIAliases = {}

local alias_map = {
  choice_option_1 = "choice_option1",
  choice_option_2 = "choice_option2",
  choice_option_3 = "choice_option3",
  choice_option_4 = "choice_option4",
}

for i = 1, 10 do
  alias_map["market_item_button_" .. tostring(i)] = "market_item_button" .. tostring(i)
end

function UIAliases.resolve(name)
  return alias_map[name] or name
end

return UIAliases
