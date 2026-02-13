local nodes = {}

nodes.canvas = {
  base = "基础屏",
  player_choice = "玩家选择屏",
  target_choice = "位置选择屏",
  remote_choice = "遥控骰子屏",
  building_choice = "建筑升级屏",
  market = "黑市屏",
  popup = "卡牌展示屏",
  bankruptcy = "破产展示屏",
  debug = "调试屏",
}

nodes.debug = {
  toggle_image = "图片_82",
  toggle_button = "基础_行动日志按钮",
  log_label = "日志",
}

nodes.buttons = {
  action = "行动按钮",
  auto = "托管按钮",
  close = "关闭",
  cancel = "取消按钮",
  building_confirm = "建筑升级_确定按钮",
  building_cancel = "建筑升级_取消",
  remote_cancel = "遥控骰子_取消",
}

nodes.labels = {
  auto = "托管_文本",
  countdown = "倒计时文本",
  no_action = "基础_无法行动提示",
}

nodes.effects = {
  auto = "基础屏-AI托管光效",
}

nodes.choice = {
  player = {
    root = "玩家选择屏",
    title = "玩家选择_标题",
    body = "玩家选择_副标题",
    slots = {
      "玩家选择_槽位1",
      "玩家选择_槽位2",
      "玩家选择_槽位3",
    },
    cancel = "取消按钮",
  },
  target = {
    root = "位置选择屏",
    title = "位置_副标题",
    body = "位置_放置文本",
    slots = {
      "位置前1",
      "位置前2",
      "位置前3",
      "位置后1",
      "位置后2",
      "位置后3",
    },
    under = "位置脚下",
    cancel = "取消按钮",
  },
  remote = {
    root = "遥控骰子屏",
    title = "遥控骰子_标题",
    body = "遥控骰子_正文",
    options = {
      "遥控骰子_选项_01",
      "遥控骰子_选项_02",
      "遥控骰子_选项_03",
      "遥控骰子_选项_04",
      "遥控骰子_选项_05",
      "遥控骰子_选项_06",
    },
    cancel = "遥控骰子_取消",
  },
  building = {
    root = "建筑升级屏",
    title = "建筑升级_标题",
    body = "建筑升级_文本",
    confirm = "建筑升级_确定按钮",
    cancel = "建筑升级_取消",
  },
}

nodes.popup = {
  root = "卡牌展示屏",
  title = "卡牌展示_标题",
  confirm = "取消按钮",
  card = "卡牌展示_图片",
  dismiss_nodes = { "卡牌展示_灰底", "卡牌展示_图片" },
}

nodes.bankruptcy = {
  root = "破产展示屏",
  text = "破产_文字",
  avatar = "破产玩家头像",
}

nodes.panel = {
  player_name = "玩家%s名字",
  player_cash = "玩家%s现金",
  player_land_count = "玩家%s地块数量",
  player_total_assets = "玩家%s总资产",
  player_avatar = "玩家%s头像",
  player_color = "玩家%s底板颜色",
}

return nodes
