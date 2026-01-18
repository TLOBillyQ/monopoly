# 改进路线图

**日期**: 2026-01-18  
**优先级**：P0 > P1 > P2（P0 = 本迭代可做，P1 = 下迭代，P2 = 长期）

---

## 阶段一：P0 — 立即可做（无新增抽象）

### 1.1 消除直接 require 依赖

| 文件 | 现状 | 改进 | 工作量 |
|------|------|------|--------|
| `turn_manager.lua` | 硬编码 6 个 `turn_*` 模块 | 在 `composition_root.lua` 注入 `PHASES` 表 | 小 |
| `choice_service.lua` | 直接 require 4 个模块 | 通过 `deps` 参数注入 | 小 |
| `landing.lua` | 直接 require `chance_effects`/`MineEffect`/`Steal` | Effect 执行器通过 `ctx.services` 获取 | 中 |

**预期收益**：
- 依赖方向更清晰
- 便于单元测试 mock

### 1.2 简化 ctx 构建

**现状**：
```lua
-- Effect.build_ctx 产出 9 个字段
{ game, store, rng, services, phase, player, tile, move_result, on_landing }
```

**改进**：
```lua
-- 分两级传递
function Effect.execute(eff, player, tile, game_ctx)
  -- game_ctx = { store, rng, services, phase, on_landing }
end
```

**工作量**：中  
**预期收益**：ISP 改善，函数签名更清晰

---

## 阶段二：P1 — 下迭代（最小新增）

### 2.1 统一 choice handler 注册

**现状** (`choice_service.lua`)：
```lua
if choice.kind == "rent_card_prompt" then
  return handlers.rent_card_prompt(game, choice, action)
elseif choice.kind == "market" then
  return handlers.market(game, choice, action)
-- ... 多个 elseif
```

**改进**：
```lua
local handler_registry = {}
function ChoiceService.register(kind, handler)
  handler_registry[kind] = handler
end

function ChoiceService.resolve(game, choice, action)
  local handler = handler_registry[choice.kind]
  if handler then return handler(game, choice, action) end
end
```

**工作量**：小  
**预期收益**：OCP 改善，新增 choice 类型无需改动核心

### 2.2 抽象 item handler

**现状** (`item_executor.lua`)：
```lua
if item_id == 1001 then
  return handle_target_player_item(...)
elseif item_id == 1002 then
  return handle_remote_dice(...)
-- ...
```

**改进**：
```lua
local item_handlers = {
  [1001] = handle_target_player_item,
  [1002] = handle_remote_dice,
  [1003] = handle_roadblock,
}
```

**工作量**：小  
**预期收益**：OCP 改善，新增道具无需改动 `use_item`

### 2.3 Hollywood 原则：推送替代轮询

**现状**：
```lua
-- LoveLayer 主动查询
function LoveLayer:get_pending_choice()
  return self.game:pending_choice()
end
```

**改进**：
```lua
-- IntentDispatcher 推送
IntentDispatcher.on("need_choice", function(payload)
  love_layer:show_choice(payload.choice_spec)
end)
```

**工作量**：中  
**预期收益**：解耦 UI 与 gameplay，便于多 UI 适配

---

## 阶段三：P2 — 长期优化（需评估 ROI）

### 3.1 Effect 定义与执行完全分离

**目标**：
- `config/landing_effects.lua` — 纯数据定义
- `gameplay/effect_executors/` — 执行器目录
- `effect_pipeline.lua` — 通过 ID 查找执行器

**工作量**：大  
**条件**：效果数量超过 20 个时考虑

### 3.2 Service 抽象接口

**目标**：
```lua
-- 定义接口协议
local IMovementService = {
  move = function(board, player, steps, opts) end,
}

-- 实现
local MovementService = {}
function MovementService.move(board, player, steps, opts) ... end
```

**工作量**：大  
**条件**：需要多套实现（如网络同步版）时考虑

### 3.3 Player 职责拆分

**目标**：
- `core/player.lua` — 纯数据 + 基础操作
- `gameplay/player_effects.lua` — 医院/深山等效果
- `gameplay/player_vehicle.lua` — 载具逻辑

**工作量**：中  
**条件**：Player 方法超过 30 个时考虑

---

## 优先级排序（推荐执行顺序）

```
P0.1 消除 turn_manager 直接 require        [小] ✅ 立即可做
P0.2 消除 choice_service 直接 require      [小] ✅ 立即可做
P0.3 简化 ctx 构建                         [中] ✅ 本迭代可做

P1.1 统一 choice handler 注册              [小] ⏳ 下迭代
P1.2 抽象 item handler                     [小] ⏳ 下迭代
P1.3 Hollywood：推送替代轮询               [中] ⏳ 下迭代

P2.* 长期优化                              [大] ⏸️ 按需评估
```

---

## 评估标准

每项改进前需确认：
1. **是否有 ≥2 个调用点**？（AGENTS.md 规则）
2. **是否能删除现有代码**？
3. **是否增加可测试性**？
4. **是否破坏现有功能**？（必须通过 `regression.lua`）

---

## 验收清单

- [ ] `lua tests/deps_check.lua` 通过
- [ ] `lua tests/regression.lua` 通过
- [ ] 无新增"只做转发的包装层"
- [ ] 代码行数不增反减（或持平）
