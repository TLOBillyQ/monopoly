local nodes = {}

-- ═══════════════ 基础屏 ═══════════════
nodes.base = {
  canvas = "基础屏",
  action_button = "基础_行动按钮",
  countdown = "基础_倒计时",
  countdown_line = "基础_倒计时横线",
  action_hint = "基础_行动提示",
  action_hint_effect = "基础_行动提示特效",
  other_player_hint = "基础_其他玩家行动提示",
  player_name = "基础_玩家%s名字",
  player_cash = "基础_玩家%s现金",
  player_land_count = "基础_玩家%s地块数量",
  player_total_assets = "基础_玩家%s总资产",
  player_avatar = "基础_玩家%s头像",
  player_color = "基础_玩家%s底板颜色",
  item_slots = {
    "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3",
    "基础_道具槽位4", "基础_道具槽位5",
  },
  card_outlines = {
    "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3",
    "基础_可出牌外框4", "基础_可出牌外框5",
  },
  player_action_effects = {
    "基础_玩家1行动动效", "基础_玩家2行动动效",
    "基础_玩家3行动动效", "基础_玩家4行动动效",
  },
}

-- ═══════════════ 始终显示屏 ═══════════════
nodes.always_show = {
  canvas = "始终显示屏",
  auto_button = "始终显示_托管按钮",
  auto_effect = "始终显示_托管按钮特效",
  auto_label = "始终显示_文本",
  action_log_button = "始终显示_行动日志图标",
  action_log_label = "始终显示_行动日志文本",
}

-- ═══════════════ 玩家选择屏 ═══════════════
nodes.player_choice = {
  canvas = "玩家选择屏",
  title = "玩家选择_标题",
  slots = {
    "玩家选择_槽位1", "玩家选择_槽位2",
    "玩家选择_槽位3", "玩家选择_槽位4",
  },
}

-- ═══════════════ 位置选择屏 ═══════════════
nodes.target_choice = {
  canvas = "位置选择屏",
  title = "位置_副标题",
  body = "位置_放置文本",
  slots = {
    "位置_前1", "位置_前2", "位置_前3",
    "位置_后1", "位置_后2", "位置_后3",
  },
  under = "位置_脚下",
}

-- ═══════════════ 遥控骰子屏 ═══════════════
nodes.remote_choice = {
  canvas = "遥控骰子屏",
  title = "遥控骰子_标题",
  body = "遥控骰子_正文",
  options = {
    "遥控骰子_选项_01", "遥控骰子_选项_02", "遥控骰子_选项_03",
    "遥控骰子_选项_04", "遥控骰子_选项_05", "遥控骰子_选项_06",
  },
  cancel = "遥控骰子_取消",
}

-- ═══════════════ 建筑升级屏 ═══════════════
nodes.building_choice = {
  canvas = "建筑升级屏",
  title = "建筑升级_标题",
  body = "建筑升级_文本",
  confirm = "建筑升级_确定按钮",
  cancel = "建筑升级_取消",
}

-- ═══════════════ 黑市屏 ═══════════════
nodes.market = {
  canvas = "黑市屏",
  confirm = "黑市_购买按钮",
  cancel = "黑市_取消按钮",
  close = "黑市_关闭",
  price_label = "黑市_售价",
  selected_card = "黑市_选中卡牌",
  item_buttons = {},
  item_labels = {},
  item_frames = {},
}
for i = 1, 10 do
  local idx = tostring(i)
  nodes.market.item_buttons[i] = "黑市_购买项" .. idx
  nodes.market.item_labels[i] = "黑市_道具名称" .. idx
  nodes.market.item_frames[i] = "黑市_底框" .. idx
end

-- ═══════════════ 卡牌展示屏 ═══════════════
nodes.popup = {
  canvas = "卡牌展示屏",
  title = "卡牌展示_标题",
  card = "卡牌展示_图片",
  dismiss_nodes = { "卡牌展示_灰底", "卡牌展示_图片" },
}

-- ═══════════════ 破产展示屏 ═══════════════
nodes.bankruptcy = {
  canvas = "破产展示屏",
  text = "破产_文字",
  avatar = "破产玩家头像",
}

-- ═══════════════ 骰子屏 ═══════════════
nodes.dice = {
  canvas = "骰子屏",
  spin = "骰子_旋转中",
  faces = {
    "骰子_点数1", "骰子_点数2", "骰子_点数3",
    "骰子_点数4", "骰子_点数5", "骰子_点数6",
  },
}

-- ═══════════════ 加载屏 ═══════════════
nodes.loading = {
  canvas = "加载屏",
}

-- ═══════════════ 调试屏 ═══════════════
nodes.debug = {
  canvas = "调试屏",
}

-- ═══════════════ 行动日志（全局节点） ═══════════════
nodes.action_log = {
  label = "日志",
  toggle_targets = { "始终显示_行动日志图标" },
}

-- ═══════════════ canvas 便捷查询 ═══════════════
nodes.canvas = {
  base = nodes.base.canvas,
  always_show = nodes.always_show.canvas,
  player_choice = nodes.player_choice.canvas,
  target_choice = nodes.target_choice.canvas,
  remote_choice = nodes.remote_choice.canvas,
  building_choice = nodes.building_choice.canvas,
  market = nodes.market.canvas,
  popup = nodes.popup.canvas,
  bankruptcy = nodes.bankruptcy.canvas,
  dice = nodes.dice.canvas,
  loading = nodes.loading.canvas,
  debug = nodes.debug.canvas,
}

-- ═══════════════ 启动校验 ═══════════════
function nodes.required_click_nodes(opts)
  local required = {
    nodes.base.action_button,
    nodes.always_show.auto_button,
    nodes.building_choice.confirm,
    nodes.building_choice.cancel,
    nodes.remote_choice.cancel,
  }
  for _, name in ipairs(nodes.player_choice.slots) do
    required[#required + 1] = name
  end
  for _, name in ipairs(nodes.target_choice.slots) do
    required[#required + 1] = name
  end
  required[#required + 1] = nodes.target_choice.under
  for _, name in ipairs(nodes.remote_choice.options) do
    required[#required + 1] = name
  end
  for _, name in ipairs(nodes.action_log.toggle_targets or {}) do
    required[#required + 1] = name
  end

  local extra = opts and opts.extra or nil
  if type(extra) == "table" then
    for _, name in ipairs(extra) do
      required[#required + 1] = name
    end
  end

  return required
end

return nodes
