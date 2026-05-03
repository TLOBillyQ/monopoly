# T1 — 神仙状态卡 应用站（Apply-site）静态审计

范围：所有写入 `player.status.deity` 的代码路径（apply 入口）。
不包含：tick 生命周期、读端（rent/chance）、清除路径、tools/cheat、save/load、测试夹具。

---

## 写入 API（设计契约）

`set_player_deity(self, player, name, duration)` — 定义于 `src/player/actions/state_ops/deity_ops.lua:26-39`：

- 行 27：`assert(name ~= nil, "missing deity name")`，缺名直接崩。
- 行 29：若 `status.deity` 不存在，初始化为 `{ type = "", remaining = 0 }`。
- 行 30：`status.deity.type = name`。
- 行 31：`status.deity.remaining = duration or player.deity_duration_turns`。
  - **回退路径**：当 `duration` 为 `nil`（或 `false`）时，使用 `player.deity_duration_turns` 字段。
- 行 32：`common.mark_players(self)` 标脏。
- 行 33-38：发出 `feedback.deity_applied` 事件。

`player.deity_duration_turns` 注入路径：

- `src/player/actions/player.lua:29`：`self.deity_duration_turns = attrs.deity_duration_turns`。
- `src/app/game_factory.lua:69`：构造分支 1（按 role 创建），`deity_duration_turns = constants.deity_duration_turns`。
- `src/app/game_factory.lua:95`：构造分支 2（按 names 创建），同上。
- `src/config/content/constants.lua:11`：`deity_duration_turns = 5`。

结论：经 `game_factory` 创建的玩家，`player.deity_duration_turns` 必为 `5`（数值真值），`duration or player.deity_duration_turns` 表达式不会落入 `nil`。

---

## 调用站清单

所有 `set_player_deity` 调用站（grep 全 `src/`，5 处匹配，去除定义本身共 4 个调用点）：

| # | 文件:行 | 调用上下文 | 入参 `name` | 入参 `duration` | 评级 |
|---|---|---|---|---|---|
| 1 | `src/rules/items/post_effects.lua:145` | `invite_deity`（请神卡）apply：把目标身上的神搬到使用者身上 | `deity.type`（来自 `target.status.deity.type`，运行时字符串） | `deity.remaining`（来自 `target.status.deity.remaining`，剩余回合数） | WORKING |
| 2 | `src/rules/items/post_effects.lua:162` | `send_poor`（送神卡）apply：把使用者身上的穷神送给目标 | 字面量 `"poor"` | `remaining`（来自 `user.status.deity.remaining`） | WORKING |
| 3 | `src/rules/items/post_effects.lua:173` | `poor`（穷神卡）apply：直接给目标附穷神 | 字面量 `"poor"` | **未传**（nil） | WORKING（依赖回退） |
| 4 | `src/rules/items/post_effects.lua:217` | `_handle_deity` 通用处理器（被 `rich`/`angel` 配置触发） | `cfg.deity`（"rich" 或 "angel"，见 post_effects.lua:198-199） | `constants.deity_duration_turns`（显式传 5） | WORKING |

调用站详细说明：

### 1. `invite_deity` — post_effects.lua:138-152
```
142:    apply = function(game, user, target, _context)
143:      local deity = assert(target.status.deity, "missing target deity")
144:      game:clear_player_deity(target)
145:      game:set_player_deity(user, deity.type, deity.remaining)
```
- `filter_target`（行 139-141）保证 `target.status.deity` 真值才进入 apply，但表是 `{ type="", remaining=0 }` 初始化（player.lua:33），意味着 `target.status.deity` 永远真，过滤器形同空过滤。
- 若 target 当前没神（type=""），行 145 会把空串和 0 搬到 user，等同清除 user 的神。SUSPICIOUS（语义不在本任务范围，留给读端 T 项审查）。
- `duration` 显式传值，不走回退。

### 2. `send_poor` — post_effects.lua:153-170
```
160:    apply = function(game, user, target, _context)
161:      local remaining = assert(user.status.deity, "missing user deity").remaining
162:      game:set_player_deity(target, "poor", remaining)
163:      game:clear_player_deity(user)
```
- `require_user`（行 154-159）保证 user 当前确实有 `poor` 神，因此 `remaining > 0` 在正常路径上成立。
- `duration` 显式传值，不走回退。

### 3. `poor` — post_effects.lua:171-180
```
171:  [item_ids.poor] = {
172:    apply = function(game, user, target, _context)
173:      game:set_player_deity(target, "poor")
```
- **未传 duration**。
- 静态可证：`target` 来自 game_factory，故 `target.deity_duration_turns == 5`（constants.lua:11 → game_factory.lua:69/95 → player.lua:29）。
- deity_ops.lua:31 表达式 `duration or player.deity_duration_turns` 计算为 `nil or 5 = 5`。
- 评级 **WORKING（依赖回退）**：行为正确，但是隐式约定。如未来出现绕开 game_factory 的 player 实例（如裸 `player:new` 调用而未传 `deity_duration_turns`），此处会写入 `nil` 到 `status.deity.remaining`，下一次 tick 在 deity_ops.lua:45 `if deity.remaining <= 0` 比较时会因 `nil <= 0` 抛错。tools/cheat/test fixtures 是否存在此类裸构造，列入未审查清单。

### 4. `_handle_deity` — post_effects.lua:216-225
```
216:  local function _handle_deity(game, player, cfg, context)
217:    game:set_player_deity(player, cfg.deity, constants.deity_duration_turns)
```
- 显式传 `constants.deity_duration_turns`（=5）。
- `cfg.deity` 由 post_effects.lua:198-199 配置：
  - `[item_ids.rich] = { type = "deity", deity = "rich", ... }`
  - `[item_ids.angel] = { type = "deity", deity = "angel", ... }`
- 评级 WORKING。

---

## 绕过直写

对 apply 写法进行的绕过性 grep（在 `src/` 全量搜索）：

| 模式 | 命中 |
|---|---|
| `status\.deity\.type\s*=` | 仅 2 处，均位于 `src/player/actions/state_ops/deity_ops.lua`（行 21 在 `clear_player_deity`，行 30 在 `set_player_deity`）。无其他文件直写。 |
| `status\.deity\.remaining\s*=` | 仅 2 处，均位于 `src/player/actions/state_ops/deity_ops.lua`（行 22 在 `clear_player_deity`，行 31 在 `set_player_deity`）。无其他文件直写。 |
| `status\.deity\s*=\s*\{` | **无**。即没有 `status.deity = { ... }` 形式的整表替换。 |

绕过 `set_player_deity`/`clear_player_deity` API 的写入：**无**。

注：`player.lua:33` 在 `init` 时写入 `deity = { type = "", remaining = 0 }`，这是初始化，不算运行时绕过。

---

## 总评

- 4 个 apply 调用点，**全部 WORKING**。
- 1 处依赖隐式回退（`poor` 卡 / post_effects.lua:173）：在生产构造路径下正确，但破坏了"显式传 duration"的统一风格。属于代码风格层面的脆弱点，非功能 bug。
- 写入路径 100% 收敛在 `set_player_deity` / `clear_player_deity` 两个 API 内，无绕过直写。

---

## 未审查清单

下列与 apply-site 相关但本任务（T1）不覆盖的范围，留给后续任务或显式排除：

- **tools/cheat 目录**：是否存在调试用的直接写状态/直接构造 player 的代码（可能绕过 `deity_duration_turns` 注入）。
- **spec/ 测试夹具**：是否存在裸 `player:new` 调用（可能未传 `deity_duration_turns`，与 `poor` 卡的回退路径交互）。
- **save/load**：序列化与反序列化是否会重建 `status.deity`，绕开 set/clear API。
- **lifecycle (tick)**：deity_ops.lua:41-54 的 `tick_player_deity` 行为（T2 范围）。
- **read-sites**：rent / chance / 其他读 `status.deity.type` 与 `remaining` 的位置（T3-T4 范围）。
- **clear-sites**：`clear_player_deity` 的所有调用站（T5-T8 范围）。
- **配置覆盖**：`constants.lua` 之外是否存在覆写 `deity_duration_turns` 的代码（如 difficulty / mode 切换）。

---

## 证据 (file:line citations)

- `src/player/actions/state_ops/deity_ops.lua:26-39` — `set_player_deity` 定义
- `src/player/actions/state_ops/deity_ops.lua:31` — duration 回退表达式
- `src/rules/items/post_effects.lua:145` — invite_deity 调用
- `src/rules/items/post_effects.lua:162` — send_poor 调用
- `src/rules/items/post_effects.lua:173` — poor 调用（未传 duration）
- `src/rules/items/post_effects.lua:217` — _handle_deity 调用
- `src/rules/items/post_effects.lua:198-199` — rich/angel 配置
- `src/app/game_factory.lua:69` — 构造分支 1 注入 deity_duration_turns
- `src/app/game_factory.lua:95` — 构造分支 2 注入 deity_duration_turns
- `src/player/actions/player.lua:29` — 玩家字段注入
- `src/player/actions/player.lua:33` — status.deity 初始化
- `src/config/content/constants.lua:11` — deity_duration_turns = 5
