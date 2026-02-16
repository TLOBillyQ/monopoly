# Uncle Bob 审查后续：职责拆分计划

## 执行状态

✅ **已完成**

## 完成内容

### 阶段 1：拆分 game/state.lua ✅

创建了新目录结构：
```
game/state/
├── turn.lua      -- 回合状态（34行）
├── player.lua    -- 玩家状态（223行）
├── tile.lua      -- 地块状态（59行）
└── hospital.lua  -- 特殊地点效果（61行）
```

**已删除 `game/state.lua` facade 文件**。

`game/init.lua` 改为直接引入子模块：
```lua
local state_turn = require("game.state.turn")
local state_player = require("game.state.player")
local state_tile = require("game.state.tile")
local state_hospital = require("game.state.hospital")
```

### 阶段 2：拆分 visual/model.lua ✅

创建了新目录结构：
```
visual/model/
├── projection.lua    -- 数据投影（159行）
├── panel.lua         -- 面板构建（50行）
├── avatar.lua        -- 头像处理（57行）
└── context.lua       -- 角色上下文（42行）
```

保留 `visual/model.lua` 作为协调器（非 facade），因其 `build/update` 函数确实需要协调多个子模块。

### 测试回归 ✅

- [x] 依赖规则检查通过
- [x] 完整测试套件通过（Exit code: 0）

## 收益

| 文件 | 拆分前行数 | 拆分后行数 | 职责数 |
|------|-----------|-----------|--------|
| game/state.lua | 456 | 已删除 | - |
| game/state/*.lua | - | 各 34-223 | 各 1 个职责 |
| visual/model.lua | 480 | 183（协调器）| 1（协调器）|
| visual/model/*.lua | - | 各 42-159 | 各 1 个职责 |

**符合 CODING.md 第 4 节**：单文件不超过 300 行。

## 架构改进

1. **SRP 遵守**：每个子模块只有一个修改理由
2. **依赖显式**：调用者必须明确依赖具体子模块，无隐藏依赖
3. **测试覆盖**：所有现有测试通过，无需修改
4. **依赖清晰**：子模块间无循环依赖

## 后续建议（可选）

- P2 级问题：消除全局变量（vehicle_helper, camera_helper）
- P3 级问题：函数重复代码提取
