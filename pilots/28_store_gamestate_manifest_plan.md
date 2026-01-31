# Store 状态树文档：显式列出 GameState.lua


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md`，后续每次修改都必须按其中规则维护。

## 目的 / 全局视角


本仓库用 `Components/Store.lua` 维护一棵“状态树”（就是一个嵌套 table），并通过 `store:get({ ... })` / `store:set({ ... }, value)` 以“路径数组”的方式读写。

目前状态树的“写入点”分散在各个模块里，缺少一份面向新手的清单，导致读代码时很难回答两个问题：某个状态从哪里写入、哪些模块负责哪些路径。

本计划交付一个可验证的结果：新增一份文档，把 `Manager/GameManager/GameState.lua` 作为 Store 的核心写入点显式列出，并列清它读写的路径；随后把这些状态路径重构为“非字符串的数值枚举”，并通过小测试锁定枚举类型与映射的正确性。

验收方式：运行 `lua tests/acceptance.lua` 通过，并且文档中能直接搜索到 `Manager/GameManager/GameState.lua` 这一行以及对应的路径清单；同时枚举测试确认所有枚举值是数字类型。

## 进度


- [x] (2026-01-31 02:06Z) 确认 Store 实现位置为 `Components/Store.lua`，并定位 `Manager/GameManager/GameState.lua` 对 Store 的读写点。
- [x] (2026-01-31 02:22Z) 新增 `docs/store/00_state_tree_writers.md`，显式列出 `Manager/GameManager/GameState.lua` 的读写路径与语义。
- [x] (2026-01-31 02:23Z) 新增 `tests/store_docs_test.lua`，断言文档包含 `Manager/GameManager/GameState.lua` 与标题。
- [x] (2026-01-31 02:24Z) 在 `Manager/GameManager/Constants.lua` 中新增 Store 路径枚举（数值型）与映射表。
- [x] (2026-01-31 02:24Z) 重构 `Manager/GameManager/GameState.lua`，通过枚举与映射表构建 Store 路径。
- [x] (2026-01-31 02:25Z) 新增 `tests/store_enum_test.lua`，断言枚举值为数字且映射可用。
- [x] (2026-01-31 02:26Z) 更新 `tests/acceptance.lua` 并运行 `lua tests/acceptance.lua` 验证通过。

## 意外与发现


观察：仓库目前没有专门的 Store/状态树文档；Store 的使用点分散在 `Manager/*`、`Library/*`、`Components/*` 与 tests 中。
证据：`find docs -name '*.md'` 未发现与 Store 相关的现有文档；`rg "store:set\\(|store:get\\("` 可搜到大量散点使用。

观察：`Manager/GameManager/Constants.lua` 已作为玩法常量集中点，适合作为 Store 路径枚举的放置位置。
证据：该文件包含 `turn_limit` 与 `item_ids` 等玩法常量。

## 决策日志


- 决策：先做“文档 + 最小防回归测试”，不引入自动抽取 Store 路径的脚本。
  理由：Lua 代码里路径表包含变量与表达式（例如 `player.id`、`tile.id`），用简单正则抽取会产生大量误报/漏报；先用人工清单把 `GameState.lua` 这块最关键的写入点固化下来，成本最低，且可直接服务新人阅读。
  日期/作者：2026-01-31 / Codex。

- 决策：Store 路径枚举使用“数值型枚举 + 字符串映射表”的方式落地到 `Manager/GameManager/Constants.lua`。
  理由：Store 的实际路径片段必须是字符串（用于 table key），但枚举值必须是数字；用映射表能同时满足“非字符串枚举”与现有数据结构不变的要求。
  日期/作者：2026-01-31 / Codex。

- 决策：`GameState:update_tile` 同时兼容数值枚举键与原有字符串键。
  理由：仅 `GameState` 内调用，但保留兼容能降低后续改动风险，并保证未知键不被误丢弃。
  日期/作者：2026-01-31 / Codex。

## 结果与复盘


已新增 Store 写入点文档与枚举测试，并完成 `GameState` 枚举化重构。验收通过 `lua tests/acceptance.lua`。当前仅覆盖 `GameState.lua`，其它 Store 写入点尚未纳入文档，可在后续计划扩展为“全仓库 Store 路径索引”。

## 背景与导读


### Store 是什么

`Components/Store.lua` 定义了 `Store` 类，它持有 `state`（一棵嵌套 table）。`get(path)` 会沿着 `path` 数组逐级取值；`set(path, value)` 会在不存在时自动创建中间表。

这里的“路径数组”形如：

    { "players", 1, "cash" }

含义是 `state.players[1].cash`。

### 为什么是 GameState.lua

`Manager/GameManager/GameState.lua` 是 GameManager 侧面向“状态同步/持久化”的收口点：它封装了 `_store_set`，并在玩家状态、地块状态、动画队列、回合状态等事件发生时写入 Store。

本计划要求把它显式列入文档，并把它涉及的路径写清楚，作为后续扩展“Store 路径索引”的基础。同时把这些路径的片段抽成数值枚举，统一通过映射表转回字符串。

### 枚举放置位置与类型约束

为减少新增文件并复用现有习惯，本计划把 Store 路径枚举放进 `Manager/GameManager/Constants.lua`。枚举值必须是数字类型，不允许直接用字符串；字符串仅出现在“枚举 -> 路径片段”的映射表里。

### 需要被文档化的 GameState.lua Store 路径（现状盘点）

以下“路径模式”来自当前 `Manager/GameManager/GameState.lua` 的直接读写（变量用占位符表示）：

写入（`store:set`）：

- 玩家：
  - `{ "players", <player.id>, "status", <key> }`：玩家状态字典（如 buff、标记等）。
  - `{ "players", <player.id>, "seat_id" }`：座位号。
  - `{ "players", <player.id>, "eliminated" }`：是否出局（boolean）。
  - `{ "players", <player.id>, "properties", <tile_id> }`：是否拥有某地块（拥有写 `true`，取消拥有写 `nil`）。
  - `{ "players", <player.id>, "inventory" }`：背包快照（由 `CompositionRoot.snapshot_inventory()` 生成）。
  - `{ "players", <player.id>, "position" }`：当前位置索引（棋盘格 index）。

- 棋盘地块（仅 land）：
  - `{ "board", "tiles", <tile.id>, <key> }`：地块快照字段写入（目前主要为 `owner_id`、`level`）。
  - `{ "board", "tiles", <tile.id>, "owner_id" }`：地块归属（`nil` 表示无主）。
  - `{ "board", "tiles", <tile.id>, "level" }`：地块等级（`reset_tile` 会写 0）。

- 回合/动画：
  - `{ "turn", "action_anim_seq" }`：动作动画序号（自增）。
  - `{ "turn", "action_anim" }`：动作动画 payload（包含 `seq`）。

读取（`store:get`）：

- `{ "turn", "current_player_index" }`：当前玩家下标（默认 1）。
- `{ "turn", "pending_choice" }`：当前待处理的选择（choice）。

## 工作计划


先新增 Store 文档目录与“写入点清单”文档，第一版只覆盖 `Manager/GameManager/GameState.lua`，并把上面的路径模式整理成稳定的、可读的条目。

然后新增两个最小测试：一个读文档并断言关键字符串，另一个校验 Store 路径枚举的类型与映射；最后把它们加入 acceptance 套件，保证 CI/本地一跑就能发现文档或枚举被破坏。

## 具体步骤


1) 新增文档 `docs/store/00_state_tree_writers.md`，建议结构：

    - 标题：Store 状态树写入点（Writers）
    - 解释 Store/路径数组的概念（保持简短，避免重复本计划太多）
    - 小节：`Manager/GameManager/GameState.lua`
      - 用“写入/读取”分组列出路径模式与一句话语义
      - 备注：哪些方法会触发写入（例如 `set_player_status`、`update_tile`、`queue_action_anim`）

2) 新增测试 `tests/store_docs_test.lua`，以纯 Lua 方式读取文件并断言内容包含：

    - `Manager/GameManager/GameState.lua`
    - `Store 状态树写入点`（或你在文档里采用的稳定标题）

   测试失败时应给出清晰提示，比如：

    - `expected docs/store/00_state_tree_writers.md to mention Manager/GameManager/GameState.lua`

3) 修改 `tests/acceptance.lua`，把 `tests/store_docs_test.lua` 加入 `scripts` 列表。

4) 在 `Manager/GameManager/Constants.lua` 中新增 Store 路径枚举与映射表，要求：

    - 枚举值为数字类型（如 1, 2, 3），不要使用字符串。
    - 映射表把枚举值映射为实际路径片段字符串（如 `"players"`、`"turn"`）。

5) 在 `Manager/GameManager/GameState.lua` 中替换所有 Store 路径构造方式，使用枚举 + 映射表生成路径片段，避免直接写 `"players"` / `"turn"` 等字符串。

6) 新增测试 `tests/store_enum_test.lua`，断言：

    - 枚举值为数字类型。
    - 映射表返回的路径片段为字符串（仅映射表允许字符串）。

7) 修改 `tests/acceptance.lua`，把 `tests/store_enum_test.lua` 加入 `scripts` 列表。

8) 在仓库根目录运行：

    lua tests/acceptance.lua

   预期输出包含：

    ok - acceptance suite

## 验证与验收


验收标准（必须同时满足）：

1) 文档存在且可检索：`rg "Manager/GameManager/GameState.lua" docs/store/00_state_tree_writers.md` 有命中。
2) `tests/store_enum_test.lua` 断言枚举值为数字且映射可用。
3) `lua tests/acceptance.lua` 通过，输出包含 `ok - acceptance suite`。

## 可重复性与恢复


本计划只新增文档与测试，属于可重复执行的增量改动，不应影响运行时代码路径。

若需要回滚，只需删除新增的 `docs/store/` 文档与 `tests/store_docs_test.lua`，并从 `tests/acceptance.lua` 移除该测试条目即可。

## 产物与备注


关键输出片段：

    [acceptance] tests/store_docs_test.lua
    ok - store docs
    [acceptance] tests/store_enum_test.lua
    ok - store enum
    [acceptance] tests/regression.lua
    ..............................
    All regression checks passed (30)
    ok - acceptance suite

## 接口与依赖


本计划不引入新依赖。

涉及的关键现有接口：

1) `Components/Store.lua`
   - `Store:get(path: table): any`
   - `Store:set(path: table, value: any): void`

2) `Manager/GameManager/GameState.lua`
   - `_store_set(path: table, value: any): void`
   - 通过 `_store_set` 与 `store:get` 对状态树读写。

3) `Manager/GameManager/Constants.lua`
   - 新增 Store 路径枚举（数值型）与映射表（枚举 -> 路径片段字符串）。

变更说明：新增“Store 路径枚举化”目标与步骤，明确枚举值为数字类型，并补充对应测试与验收要求，以满足“枚举不要使用字符串类型”的要求。

变更说明（执行记录）：完成文档、枚举、重构与测试落地，更新进度与结果复盘，并记录兼容性决策与验收输出。
