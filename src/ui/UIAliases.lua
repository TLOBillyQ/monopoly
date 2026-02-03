local ui_aliases = {}

local alias_map = {
  btn_next = "行动按钮",
  btn_auto = "托管按钮",
  panel_turn = "倒计时",
  choice_cancel = "取消按钮",
  popup_confirm = "弹窗确认",
  modal_popup = "弹窗屏",
  market_panel = "黑市屏",
  market_confirm_button = "黑市购买按钮",
  market_cancel_button = "关闭",
  market_price_label = "售价：100",
  market_selected_card = "选中卡牌",
}

for i = 1, 4 do
  local idx = tostring(i)
  alias_map["choice_option" .. idx] = "道具名称" .. idx
  alias_map["choice_option_" .. idx] = "道具名称" .. idx
end

for i = 1, 5 do
  local idx = tostring(i)
  alias_map["item_slot_" .. idx] = "道具槽位" .. idx
end

for i = 1, 4 do
  local idx = tostring(i)
  alias_map["panel_player_" .. idx .. "_name"] = "玩家" .. idx .. "名字"
  alias_map["panel_player_" .. idx .. "_cash"] = "玩家" .. idx .. "现金"
  alias_map["panel_player_" .. idx .. "_land_count"] = "玩家" .. idx .. "地块数量"
  alias_map["panel_player_" .. idx .. "_detail"] = "玩家" .. idx .. "总资产"
end

for i = 1, 10 do
  local idx = tostring(i)
  alias_map["market_item_button" .. idx] = "黑市购买项" .. idx
  alias_map["market_item_button_" .. idx] = "黑市购买项" .. idx
  alias_map["market_item_label_" .. idx] = "道具名称" .. idx
  alias_map["market_item_frame_" .. idx] = "底框" .. idx
end

function ui_aliases.resolve(name)
  return alias_map[name] or name
end

return ui_aliases
