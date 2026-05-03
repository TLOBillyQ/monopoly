# T8: 神仙字符串/常量一致性静态审计

## 结论

**Classification: SUSPICIOUS**

核心逻辑字符串 `rich` / `poor` / `angel` 在 src 内部基本一致；未发现 `Rich` / `Poor` / `Angel` 之类的错误大小写，也未发现 `angle` 误拼写。风险主要来自内容配置中的硬编码 `5回合` 文案，与 `deity_duration_turns = 5` 这条逻辑常量并列存在，存在双源不一致风险。

## 字符串字面量出现位置全表

| string literal | file:line | context |
|---|---|---|
| rich | `src/computer/agent/action.lua:58` | read / game logic |
| rich | `src/rules/chance/handlers/common.lua:41` | read / chance |
| rich | `src/rules/chance/handlers/cash.lua:128` | read / cash |
| rich | `src/rules/land/rules.lua:109` | read / land |
| rich | `src/rules/items/post_effects.lua:198` | apply / item config |
| rich | `src/rules/items/strategy.lua:115` | apply / item selection |
| rich | `src/ui/coord/event_handlers.lua:193` | UI event dispatch |
| rich | `src/ui/render/status3d/status.lua:41` | UI render key |
| rich | `src/ui/render/status3d/specs.lua:11,16` | UI label / priority |
| rich | `src/config/content/items.lua:18` | config text |
| rich | `src/config/testing/test_profiles.lua:137,457` | test |
| poor | `src/computer/agent/action.lua:71,78` | read / game logic |
| poor | `src/rules/chance/handlers/common.lua:44` | read / chance |
| poor | `src/rules/chance/handlers/cash.lua:104` | read / cash |
| poor | `src/rules/land/rules.lua:108` | read / land |
| poor | `src/rules/items/post_effects.lua:153,155,162,171,173` | apply / item config |
| poor | `src/ui/render/status3d/status.lua:40` | UI render key |
| poor | `src/ui/render/status3d/specs.lua:12,16` | UI label / priority |
| poor | `src/config/content/items.lua:19` | config text |
| poor | `src/config/testing/test_profiles.lua:113,127` | test |
| angel | `src/computer/agent/action.lua:55` | read / game logic |
| angel | `src/player/actions/state_ops/deity_ops.lua:15` | read / state op |
| angel | `src/rules/chance/resolver.lua:8` | read / chance |
| angel | `src/rules/items/post_effects.lua:110,199` | read / apply / item config |
| angel | `src/rules/items/steal.lua:92` | read / item rule |
| angel | `src/rules/items/strategy.lua:117` | apply / item selection |
| angel | `src/ui/coord/event_handlers.lua:195` | UI event dispatch |
| angel | `src/ui/render/status3d/status.lua:42` | UI render key |
| angel | `src/ui/render/status3d/specs.lua:13,16` | UI label / priority |
| angel | `src/config/content/items.lua:20` | config text |
| angel | `src/config/testing/test_profiles.lua:457` | test |

### SUSPICIOUS

- `src/config/content/items.lua:18-20` 使用 `5回合` 文案，和逻辑常量 `deity_duration_turns` 并列存在；文案不是 bug，但属于神仙持续时间的第二套来源。
- `src/config/content/items.lua:18-20` 的文案与逻辑字符串一致性依赖人工维护，后续改常量时容易漏改。

## 常量一致性

- `src/config/content/constants.lua:11` 明确定义 `deity_duration_turns = 5`。
- 读取点：
  - `src/app/game_factory.lua:69,95` 注入到每个 `player:new(...)` 调用。
  - `src/player/actions/player.lua:29` 保存到 `self.deity_duration_turns`。
  - `src/player/actions/state_ops/deity_ops.lua:31` 作为 `duration or player.deity_duration_turns` 的回退值。
  - `src/rules/items/post_effects.lua:217` 作为神仙附身时长写入。
- 代码层面未发现直接写死 `5` 的 deity 逻辑分支；但内容层面的 `5回合` 文案存在于 `src/config/content/items.lua:18-20`。

### SUSPICIOUS

- `src/config/content/items.lua:18-20` 的 `5回合` 不是常量读取，而是硬编码文案；如果 `deity_duration_turns` 改动，这里会失配。

## deity_duration_turns 注入路径

路径：`src/config/content/constants.lua:11` → `src/app/game_factory.lua:69,95` → `src/player/actions/player.lua:29` → `src/player/actions/state_ops/deity_ops.lua:31`。

- `game_factory.lua` 的两个创建分支都传入 `deity_duration_turns = constants.deity_duration_turns`，包含 AI 分支与普通玩家分支。
- `player.lua` 统一把 `attrs.deity_duration_turns` 存入实例属性，未见按玩家类型分流。
- `deity_ops.lua` 读取 `player.deity_duration_turns` 作为 duration 回退值，说明所有 player 实例都应具备该属性。
- 目前未发现任何玩家类型绕过 `game_factory` / `player:new` 注入链；AI 玩家也会拿到该属性。

### SUSPICIOUS

- 若未来新增玩家构造入口但不复用 `game_factory.lua`，`player.deity_duration_turns` 可能缺失；当前仓库未见该路径。

## UI 字符串一致性

- `src/ui/render/status3d/status.lua:39-42` 使用与逻辑一致的内部 key：`poor` / `rich` / `angel`。
- `src/ui/render/status3d/specs.lua:11-13` 使用的是中文展示文案：`财神状态` / `穷神状态` / `天使状态`。
- `src/ui/coord/event_handlers.lua:193-196` 也按同一内部 key 分派 cue。

结论：UI 的**逻辑 key** 与游戏逻辑一致；**展示字符串**是独立本地化文案，不是同一层面的常量。

---

## 未审查清单

以下相关代码本次未覆盖：

- `src/ui/` 其余文件中是否有其他神仙类型字符串引用（仅抽查了 status3d 和 event_handlers）
- cheat / debug 入口中的神仙类型字符串（如 cheat panel 直接输入）
- 测试 fixture 中的神仙类型字符串是否与运行时一致
- `src/config/content/items.lua` 中 `angel_immune` 字段名本身的拼写一致性（已确认，仅记录）
- 本地化/多语言文案文件（若存在）中的神仙相关字符串
