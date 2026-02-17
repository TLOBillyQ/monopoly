local bootstrap = require("game.bootstrap")
local win = require("game.rule.win")
local flow = require("core.flow")
local turn_states = require("game.state.turn")
local state_player = require("game.state.player")
local state_tile = require("game.state.tile")
local state_hospital = require("game.state.hospital")

---游戏状态表，参考 deepfuture 设计模式
---不再是 Class，而是扁平的状态函数表
local game = {}

---初始化游戏状态表
---@param opts table 初始化选项
---@return string 初始状态名
function game.setup(opts)
  opts = opts or {}

  -- 重置 flow 状态机（支持测试场景重复初始化）
  flow.reset()

  -- 加载回合状态到 flow
  turn_states.load_states()

  -- 使用 bootstrap 创建游戏上下文
  local ctx = bootstrap.assemble(opts)

  -- 将 bootstrap 创建的上下文绑定到 game 表
  for k, v in pairs(ctx) do
    game[k] = v
  end

  -- 绑定胜利检查
  game.check_victory = win.check_victory

  -- 启动状态机
  flow.enter("start", {})

  return flow.state.start
end

---更新游戏状态机，每帧调用
function game.update()
  if game.finished then
    return nil
  end

  -- 驱动 flow 状态机
  local current = flow.update()

  -- 同步 turn.phase 用于 UI 显示
  if current and game.turn then
    game.turn.phase = current
  end

  return current
end

---分发玩家动作
---在状态等待时由外部调用
---@param action table 玩家动作
function game.dispatch_action(action)
  if game.finished then
    return
  end

  -- 动作存储在 game 表中，由当前状态处理
  game.pending_action = action

  -- 驱动一次状态机更新以处理动作
  game.update()
end

---推进到下一玩家回合
---供 turn_dispatch 使用
function game.advance_turn()
  if game.finished then
    return
  end

  local current_idx = game.turn.current_player_index
  local count = #game.players
  local next_idx = current_idx % count + 1

  game.turn.current_player_index = next_idx
  game.turn.turn_count = game.turn.turn_count + 1
  game.dirty.turn = true
  game.dirty.any = true

  game.check_victory()

  -- 重新进入 start 状态
  flow.enter("start", {})
end

---获取当前玩家
---@return table|nil
function game.current_player()
  local idx = game.turn and game.turn.current_player_index
  if not idx then
    return nil
  end
  return game.players and game.players[idx]
end

---通过ID查找玩家
---@param self table game 对象
---@param player_id number 玩家ID
---@return table|nil
function game.find_player_by_id(self, player_id)
  return state_player.find_player_by_id(self, player_id)
end

---消费脏数据标记
---@param self table game 对象
---@return table
function game.consume_dirty(self)
  local dirty_tracker = require("core.dirty")
  return dirty_tracker.consume(self.dirty)
end

---获取待处理的选择
---@param self table game 对象
---@return table|nil
function game.pending_choice(self)
  return turn_states.pending_choice(self)
end

---队列动作动画
---@param self table game 对象
---@param payload table 动画数据
function game.queue_action_anim(self, payload)
  return turn_states.queue_action_anim(self, payload)
end

---设置玩家状态
---@param self table game 对象
---@param player table 玩家对象
---@param key string 状态键
---@param value any 状态值
function game.set_player_status(self, player, key, value)
  return state_player.set_player_status(self, player, key, value)
end

---停止所有玩家移动
function game.stop_all_players_movement(self)
  return state_player.stop_all_players_movement(self)
end

---获取玩家骰子数量
---@param self table game 对象
---@param player table 玩家对象
---@return number
function game.player_dice_count(self, player)
  return state_player.player_dice_count(self, player)
end

---设置玩家金币
---@param self table game 对象
---@param player table 玩家对象
---@param amount number 金额
function game.set_player_cash(self, player, amount)
  return state_player.set_player_cash(self, player, amount)
end

---添加玩家金币
---@param self table game 对象
---@param player table 玩家对象
---@param amount number 金额
function game.add_player_cash(self, player, amount)
  return state_player.add_player_cash(self, player, amount)
end

---扣除玩家金币
---@param self table game 对象
---@param player table 玩家对象
---@param amount number 金额
function game.deduct_player_cash(self, player, amount)
  return state_player.deduct_player_cash(self, player, amount)
end

---获取玩家余额
---@param self table game 对象
---@param player table 玩家对象
---@param currency string 货币类型
---@return number
function game.player_balance(self, player, currency)
  return state_player.player_balance(self, player, currency)
end

---设置玩家余额
---@param self table game 对象
---@param player table 玩家对象
---@param currency string 货币类型
---@param value number 金额
function game.set_player_balance(self, player, currency, value)
  return state_player.set_player_balance(self, player, currency, value)
end

---扣除玩家余额
---@param self table game 对象
---@param player table 玩家对象
---@param currency string 货币类型
---@param amount number 金额
function game.deduct_player_balance(self, player, currency, amount)
  return state_player.deduct_player_balance(self, player, currency, amount)
end

---检查玩家是否有神明庇护
---@param self table game 对象
---@param player table 玩家对象
---@param name string 神明名称
---@return boolean
function game.player_has_deity(self, player, name)
  return state_player.player_has_deity(self, player, name)
end

---检查玩家是否有天使庇护
---@param self table game 对象
---@param player table 玩家对象
---@return boolean
function game.player_has_angel(self, player)
  return state_player.player_has_angel(self, player)
end

---清除玩家神明
---@param self table game 对象
---@param player table 玩家对象
function game.clear_player_deity(self, player)
  return state_player.clear_player_deity(self, player)
end

---设置玩家神明
---@param self table game 对象
---@param player table 玩家对象
---@param name string 神明名称
---@param duration number 持续回合
function game.set_player_deity(self, player, name, duration)
  return state_player.set_player_deity(self, player, name, duration)
end

---设置玩家座位（载具）
---@param self table game 对象
---@param player table 玩家对象
---@param seat_id number 座位ID
function game.set_player_seat(self, player, seat_id)
  return state_player.set_player_seat(self, player, seat_id)
end

---获取玩家载具配置
---@param self table game 对象
---@param player table 玩家对象
---@return table
function game.player_vehicle_cfg(self, player)
  return state_player.player_vehicle_cfg(self, player)
end

---获取玩家载具名称
---@param self table game 对象
---@param player table 玩家对象
---@return string
function game.player_vehicle_name(self, player)
  return state_player.player_vehicle_name(self, player)
end

---检查玩家载具是否不可摧毁
---@param self table game 对象
---@param player table 玩家对象
---@return boolean
function game.player_is_vehicle_indestructible(self, player)
  return state_player.player_is_vehicle_indestructible(self, player)
end

---设置玩家出局状态
---@param self table game 对象
---@param player table 玩家对象
---@param eliminated boolean 是否出局
function game.set_player_eliminated(self, player, eliminated)
  return state_player.set_player_eliminated(self, player, eliminated)
end

---设置玩家财产
---@param self table game 对象
---@param player table 玩家对象
---@param tile_id number 地块ID
---@param owned boolean 是否拥有
function game.set_player_property(self, player, tile_id, owned)
  return state_player.set_player_property(self, player, tile_id, owned)
end

---更新玩家位置
---@param self table game 对象
---@param player table 玩家对象
---@param new_index number 新位置
function game.update_player_position(self, player, new_index)
  return state_player.update_player_position(self, player, new_index)
end

---清除玩家临时标记
---@param self table game 对象
---@param player table 玩家对象
function game.clear_player_temporal_flags(self, player)
  return state_player.clear_player_temporal_flags(self, player)
end

---检查玩家是否在山中
---@param self table game 对象
---@param player table 玩家对象
---@return boolean
function game.player_is_in_mountain(self, player)
  return state_hospital.player_is_in_mountain(self, player)
end

---送玩家去医院
---@param self table game 对象
---@param player table 玩家对象
function game.player_send_to_hospital(self, player)
  return state_hospital.player_send_to_hospital(self, player)
end

---送玩家去矿山
---@param self table game 对象
---@param player table 玩家对象
function game.player_send_to_mountain(self, player)
  return state_hospital.player_send_to_mountain(self, player)
end

---设置地块所有者
---@param self table game 对象（冒号调用时自动传入）
---@param tile table 地块对象
---@param owner_id number 所有者ID
function game.set_tile_owner(self, tile, owner_id)
  return state_tile.set_tile_owner(self, tile, owner_id)
end

---设置地块等级
---@param self table game 对象
---@param tile table 地块对象
---@param level number 等级
function game.set_tile_level(self, tile, level)
  return state_tile.set_tile_level(self, tile, level)
end

---重置地块
---@param self table game 对象
---@param tile table 地块对象
function game.reset_tile(self, tile)
  return state_tile.reset_tile(self, tile)
end

---更新地块
---@param self table game 对象
---@param tile table 地块对象
---@param updates table 更新字段
function game.update_tile(self, tile, updates)
  return state_tile.update_tile(self, tile, updates)
end

---重建地块占用信息
function game.rebuild(self)
  return state_player.rebuild(self)
end

---获取存活玩家列表
---@param self table game 对象
---@return table
function game.alive_players(self)
  return state_player.alive_players(self)
end

return game
