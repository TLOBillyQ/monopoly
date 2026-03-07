local ui_aliases = {}

local alias_map = {
  btn_next = "基础_行动按钮",
  btn_auto = "始终显示_托管按钮",
  panel_turn = "基础_倒计时",
  market_panel = "黑市屏",
  market_confirm_button = "黑市_购买按钮",
  market_cancel_button = "黑市_关闭",
  market_price_label = "黑市_售价",
  market_selected_card = "黑市_选中卡牌",
}

for i = 1, 5 do
  local idx = tostring(i)
  alias_map["item_slot_" .. idx] = "基础_道具槽位" .. idx
end

for i = 1, 4 do
  local idx = tostring(i)
  alias_map["panel_player_" .. idx .. "_name"] = "基础_玩家" .. idx .. "名字"
  alias_map["panel_player_" .. idx .. "_cash"] = "基础_玩家" .. idx .. "现金"
  alias_map["panel_player_" .. idx .. "_land_count"] = "基础_玩家" .. idx .. "地块数量"
  alias_map["panel_player_" .. idx .. "_detail"] = "基础_玩家" .. idx .. "总资产"
end

for i = 1, 10 do
  local idx = tostring(i)
  alias_map["market_item_button" .. idx] = "黑市_购买项" .. idx
  alias_map["market_item_button_" .. idx] = "黑市_购买项" .. idx
  alias_map["market_item_label_" .. idx] = "黑市_道具名称" .. idx
  alias_map["market_item_frame_" .. idx] = "黑市_底框" .. idx
end

function ui_aliases.resolve(name)
  return alias_map[name] or name
end

return ui_aliases
