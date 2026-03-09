# Profile 自动轮播：Eggy 运行时全量 Profile 巡检

## Context

当前 `Config/testing/test_profiles.lua` 定义了 14 个场景 profile（bankruptcy、upgrade_build、market、tax 等），每个设置了特定的玩家位置、现金、道具、地块归属和覆盖物。启动时通过 `_G.STARTUP_TEST_PROFILE` 指定**单个** profile，由 `startup_policy` → `game_startup.build_state` → `test_profile_bootstrap.apply` 应用到游戏。auto_runner 驱动 AI 自动操作直到 `game.finished = true`。

**问题**：目前只能手动切换 profile，无法一键跑完全部 14 个场景做巡检。

**目标**：在 Eggy 运行时内实现 profile 自动轮播——加载一个 profile，auto_runner 跑固定回合数后自动切换到下一个 profile 重启游戏，跑完全部 14 个后停止。

## 现有关键代码路径

```
_G.STARTUP_TEST_PROFILE        → startup_policy.resolve(_G)
                                → game_startup.build_state(get_game, opts)
                                   opts.profile_name → test_profile_resolver.resolve_map()
                                   state.game_factory = function()
                                     ...
                                     test_profile_bootstrap.apply(game, profile_name)
                                     return game
                                   end
                                → game_runtime_bootstrap.start(state, game_ref)
                                   gameplay_loop.new_game(state) → state.game_factory()
                                → tick loop: gameplay_loop.tick → step_auto_runner
                                → game.turn.turn_count 每回合递增
                                → game_victory.check_victory → game.finished = true
```

关键文件：
- `src/app/bootstrap/startup_policy.lua` — 读 `_G` 全局，输出 policy
- `src/app/bootstrap/game_startup.lua:207` — `game_factory` 闭包，profile_name 被闭包捕获
- `src/app/bootstrap/game_runtime_bootstrap.lua:125` — `gameplay_loop.new_game(state)`
- `src/game/flow/turn/loop.lua:226` — `gameplay_loop.new_game` 调 `state.game_factory()`
- `src/game/flow/turn/auto_runner.lua:100` — `game_finished` 时停止
- `src/game/systems/endgame/game_victory.lua` — `game.finished = true`
- `src/game/flow/turn/auto_context.lua:8` — `ctx.game_finished = game.finished`
- `src/app/testing/test_profile_resolver.lua:34` — `available_profiles()` 返回全部 profile 名
- `src/core/config/gameplay_rules.lua:24` — `turn_limit = 1000`

## 实现方案

### 触发方式

新增全局变量 `_G.STARTUP_PROFILE_ROTATION = true`，由 `startup_policy` 读取。当此标志开启时，忽略 `STARTUP_TEST_PROFILE` 的单 profile 指定，启用轮播模式。

### 新增模块：`src/app/testing/profile_rotation.lua`

职责：维护轮播状态——当前 profile 索引、已完成列表、每个 profile 的回合限制。

```lua
-- src/app/testing/profile_rotation.lua
local test_profile_resolver = require("src.app.testing.test_profile_resolver")
local logger = require("src.core.utils.logger")

local rotation = {}
local _state = nil

local DEFAULT_TURNS_PER_PROFILE = 20

function rotation.init(opts)
  opts = opts or {}
  local names = test_profile_resolver.available_profiles()
  -- 排除 "default"，只跑有实际 bootstrap 配置的 profile
  local queue = {}
  for _, name in ipairs(names) do
    if name ~= "default" then
      queue[#queue + 1] = name
    end
  end
  _state = {
    queue = queue,
    index = 1,
    turns_per_profile = opts.turns_per_profile or DEFAULT_TURNS_PER_PROFILE,
    results = {},
    finished = false,
  }
  logger.info("[ProfileRotation]", "init", "profiles=" .. tostring(#queue),
    "turns_per_profile=" .. tostring(_state.turns_per_profile))
  return _state
end

function rotation.current_profile_name()
  if not _state or _state.finished then return nil end
  return _state.queue[_state.index]
end

function rotation.advance()
  if not _state or _state.finished then return false end
  _state.index = _state.index + 1
  if _state.index > #_state.queue then
    _state.finished = true
    rotation.report()
    return false
  end
  return true
end

function rotation.record_result(profile_name, turn_count, game_finished)
  if not _state then return end
  _state.results[#_state.results + 1] = {
    profile = profile_name,
    turns = turn_count,
    finished = game_finished,
  }
end

function rotation.is_active()
  return _state ~= nil and not _state.finished
end

function rotation.turns_per_profile()
  return _state and _state.turns_per_profile or DEFAULT_TURNS_PER_PROFILE
end

function rotation.report()
  if not _state then return end
  logger.info("[ProfileRotation]", "=== ROTATION COMPLETE ===")
  for _, r in ipairs(_state.results) do
    logger.info("[ProfileRotation]",
      r.profile,
      "turns=" .. tostring(r.turns),
      "game_finished=" .. tostring(r.finished))
  end
  logger.info("[ProfileRotation]", "=== END ===")
end
```

### 修改 1：`src/app/bootstrap/startup_policy.lua`

新增读取 `_G.STARTUP_PROFILE_ROTATION` 和可选的 `_G.STARTUP_ROTATION_TURNS`。

```lua
-- 新增
local function _read_profile_rotation(globals)
  return _read_truthy_flag(globals and globals.STARTUP_PROFILE_ROTATION or nil)
end

local function _read_rotation_turns(globals)
  local raw = globals and globals.STARTUP_ROTATION_TURNS or nil
  return number_utils.to_integer(raw)
end

-- resolve() 返回值新增两个字段
  return {
    ...
    profile_rotation = _read_profile_rotation(globals),
    rotation_turns = _read_rotation_turns(globals),
  }
```

### 修改 2：`src/app/init.lua`

在轮播模式下，初始化 profile_rotation 并将第一个 profile 名传给 game_startup。

```lua
local profile_rotation = require("src.app.testing.profile_rotation")

-- 在 startup_policy.resolve 之后
local effective_profile = startup.profile_name
if startup.profile_rotation then
  profile_rotation.init({ turns_per_profile = startup.rotation_turns })
  effective_profile = profile_rotation.current_profile_name() or "default"
end

-- 传给 game_startup.build_state
local state = game_startup.build_state(function() return current_game_ref[1] end, {
  profile_name = effective_profile,
  profile_rotation = startup.profile_rotation,
  ...
})
```

### 修改 3：`src/app/bootstrap/game_startup.lua` — game_factory 使用可变 profile

将 `profile_name` 改为通过 `state` 间接引用：

```lua
-- 当前：profile_name 直接闭包捕获
state.active_profile_name = profile_name

game_factory = function()
  local active_profile = state.active_profile_name or profile_name
  local map_cfg = test_profile_resolver.resolve_map(active_profile)
  ...
  test_profile_bootstrap.apply(created_game, active_profile)
  return created_game
end
```

这样轮播切换时只需 `state.active_profile_name = next_profile`，再调用 `gameplay_loop.new_game(state)` 即可。

### 修改 4：`src/game/flow/turn/loop.lua` — tick 中检测轮播切换

在 `gameplay_loop.tick` 末尾，检查轮播条件（回合数到达 or game.finished）：

```lua
local profile_rotation = require("src.app.testing.profile_rotation")

-- 在 tick_flow.tick 之后
if profile_rotation.is_active() and game then
  local turn_count = game.turn and game.turn.turn_count or 0
  local should_rotate = turn_count >= profile_rotation.turns_per_profile()
    or game.finished == true
  if should_rotate then
    local current_name = profile_rotation.current_profile_name()
    profile_rotation.record_result(current_name, turn_count, game.finished == true)
    if profile_rotation.advance() then
      local next_name = profile_rotation.current_profile_name()
      state.active_profile_name = next_name
      local new_game = gameplay_loop.new_game(state)
      if state.on_game_replaced then
        state.on_game_replaced(new_game)
      end
      return
    end
  end
end
```

### 修改 5：`src/app/init.lua` — 注册 game 引用更新回调

`game_runtime_bootstrap.start` 中 `current_game_ref[1]` 指向当前 game。轮播切换时需要更新它。

```lua
state.on_game_replaced = function(new_game)
  current_game_ref[1] = new_game
  gameplay_loop.set_game(state, new_game)
end
```

## 完整修改清单

| # | 文件 | 变更 |
|---|------|------|
| 1 | `src/app/testing/profile_rotation.lua` | **新建**，轮播状态机 |
| 2 | `src/app/bootstrap/startup_policy.lua` | 新增读 `STARTUP_PROFILE_ROTATION` / `STARTUP_ROTATION_TURNS` |
| 3 | `src/app/init.lua` | 轮播模式初始化 rotation + 注册 `on_game_replaced` 回调 |
| 4 | `src/app/bootstrap/game_startup.lua` | game_factory 闭包改读 `state.active_profile_name` |
| 5 | `src/game/flow/turn/loop.lua` | tick 末尾新增轮播检测与切换逻辑 |

## 使用方式

在 Eggy 运行时设置全局变量：

```lua
_G.STARTUP_PROFILE_ROTATION = true        -- 开启轮播
_G.STARTUP_ROTATION_TURNS = 15            -- 可选，每个 profile 跑 15 回合（默认 20）
```

启动后 auto_runner 自动驱动，日志输出：

```
[ProfileRotation] init profiles=13 turns_per_profile=15
[ProfileRotation] → bankruptcy (1/13)
[ProfileRotation] → upgrade_build (2/13)
...
[ProfileRotation] === ROTATION COMPLETE ===
[ProfileRotation] bankruptcy turns=15 game_finished=false
[ProfileRotation] upgrade_build turns=15 game_finished=false
[ProfileRotation] market turns=12 game_finished=true    ← 提前结束
...
[ProfileRotation] === END ===
```

## 验证

1. 设置 `_G.STARTUP_PROFILE_ROTATION = true`，`_G.STARTUP_ROTATION_TURNS = 3`，确认所有 profile 依次运行 3 回合后切换
2. 确认 bankruptcy 等可能提前结束的 profile 在 game.finished 时正确切换
3. 确认轮播完成后 auto_runner 停止
4. 确认不设置 `STARTUP_PROFILE_ROTATION` 时现有行为完全不受影响
5. 运行现有回归：`MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua`
6. 运行 profile 相关测试：确认 `tests/suites/runtime/test_profiles.lua` 和 `tests/suites/runtime/startup_release.lua` 通过
