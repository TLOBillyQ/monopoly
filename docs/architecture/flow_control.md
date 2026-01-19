# 流程控制与恢复架构文档

## 概述

游戏流程控制基于状态机模式实现，支持可中断可恢复的回合流程。

## 核心组件

### 1. Flow状态机 (`src/core/flow.lua`)
- 纯状态转换逻辑
- 状态函数返回 `(next_state, next_args)`
- 返回 `nil` 表示流程结束

### 2. TurnManager (`src/gameplay/turn_manager.lua`)  
- 管理回合阶段流程：start → roll → move → landing → post_action → end_turn
- 实现 `wait_choice` 特殊状态处理用户输入
- 通过 `resume_state/resume_args` 实现中断恢复

### 3. 回合阶段 (`src/gameplay/turn_*.lua`)
每个阶段是纯函数，返回下一状态或等待标记：
```lua
function phase_xxx(tm, args)
  -- 业务逻辑
  
  -- 需要等待
  return "wait_choice", {
    resume_state = "target_phase",
    resume_args = { ... }
  }
  
  -- 正常流转  
  return "next_phase", { ... }
end
```

### 4. 选择系统 (`src/gameplay/choice_service.lua`)
- 统一选择处理接口
- 插件式处理器注册机制
- 支持无效输入优雅降级

### 5. Store状态容器 (`src/core/store.lua`)
- 集中式状态管理
- 深拷贝保证不可变性
- 路径访问：`store:get({"turn", "phase"})`

## 中断与恢复机制

### 支持的中断类型

1. **黑市中断** - 移动经过黑市时暂停，等待购买选择
2. **偷窃中断** - 经过其他玩家时暂停，等待偷窃选择  
3. **道具阶段中断** - pre_action/pre_move/post_action等待道具使用
4. **落地效果中断** - 落地在空地等待购买，落地在他人地等待支付租金

### 恢复参数结构

所有中断使用统一格式：
```lua
{
  resume_state = "目标阶段名",
  resume_args = {
    player = player,
    continue_from_xxx = true,  -- 中断类型标志
    remaining_steps = 5,        -- 剩余步数
    facing = "right",          -- 朝向
    -- 其他特定数据
  }
}
```

### wait_choice恢复逻辑

```lua
states.wait_choice = function(args)
  local choice = get_choice(game)
  
  if not choice then
    -- 无选择，直接恢复
    return args.resume_state, args.resume_args
  end
  
  -- 尝试AI自动决策
  pending_action = decide_choice_action(...)
  
  if not pending_action then
    -- 继续等待
    return "wait_choice", args
  end
  
  -- 解析选择
  local res = resolve_choice(game, choice, pending_action)
  
  if res.stay then
    -- 选择要求停留
    return "wait_choice", args
  end
  
  -- 恢复到目标状态
  return args.resume_state, args.resume_args
end
```

## 状态同步

所有写操作通过Store同步：
```lua
function Game:set_player_status(player, key, value)
  player.status[key] = value  -- 内存
  self.store:set({"players", player.id, "status", key}, value)  -- Store
end
```

依赖组件自动通知：
- RNG保存随机数状态
- Inventory触发 `_on_change` 回调

## 错误处理

### 无效选择
```lua
if not option_exists(choice, action.option_id) then
  clear_choice(game)
  return { stay = false }  -- 清除并继续
end
```

### 缺失处理器  
```lua
local handler = handler_registry[kind] or function(...)
  logger.warn("unknown choice kind:", kind)
  clear_choice(game)
  return { stay = false }
end
```

## 测试覆盖

- `tests/regression.lua` - 25个端到端测试
- `tests/flow_control_test.lua` - 13个流程控制专项测试

测试类别：
- Flow状态机基础测试
- TurnManager恢复机制测试
- 中断恢复场景测试（黑市、偷窃、多重中断）
- 选择系统测试（有效/无效/取消）
- 状态一致性测试
- 错误恢复测试

运行测试：
```bash
lua tests/regression.lua
lua tests/flow_control_test.lua  
lua tests/deps_check.lua
```

## 架构优势

1. **可测试性** - 纯函数设计，状态隔离
2. **可维护性** - 单一职责，清晰边界
3. **健壮性** - 统一错误处理，状态一致性保证
4. **灵活性** - 支持同步/异步，任意嵌套等待

## 最佳实践

### 添加新阶段
```lua
-- 1. 定义阶段函数
local function phase_new(tm, args)
  -- 逻辑
  return "next_phase", { ... }
end

-- 2. 注册到phases
local phases = {
  new = phase_new,
}
```

### 添加新中断  
```lua
-- 1. 检测点返回中断数据
move_result.my_interrupt = { remaining_steps = x }

-- 2. 阶段处理中断
if move_result.my_interrupt then
  return "wait_choice", {
    resume_state = "move",
    resume_args = { continue_from_my_interrupt = true, ... }
  }
end

-- 3. 恢复时检测标志
if args.continue_from_my_interrupt then
  -- 使用中断数据继续
end
```

### 添加新选择类型
```lua
-- 1. 创建处理器
local function build(helpers)
  return {
    my_choice = function(game, choice, action)
      if helpers.is_cancel(action) then
        return helpers.finish_choice(game, false)
      end
      -- 处理逻辑
      return helpers.finish_choice(game, false)
    end
  }
end

-- 2. 注册到ChoiceService
ChoiceService.setup({ my_handler = my_handler })
```

## 未来改进方向

1. **状态快照与回放** - 基于Store不可变性实现历史记录
2. **流程可视化** - 生成状态转换图和执行轨迹
3. **分布式支持** - Store序列化传输，阶段函数无副作用

## 总结

流程控制架构通过 Flow状态机 + TurnManager + 阶段函数 + Store + ChoiceService 协同工作，实现可中断、可恢复、可测试、可维护的游戏流程控制系统。

核心设计：
- Flow提供可预测的状态转换
- TurnManager统一管理流程和恢复
- 阶段函数纯函数设计
- Store集中式状态管理
- ChoiceService插件式选择处理
- resume_state/resume_args统一恢复机制
