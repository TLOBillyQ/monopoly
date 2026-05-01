# 审计 pending_choice 原地改写 → UI 不刷新的同类隐患

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件遵循 [.agents/harness/PLANS.md](.agents/harness/PLANS.md) 维护。


## 目的 / 全局视角

刚修完 `a54beb8` 的"黑市点击无效"bug 后，需要排查同类隐患：**任何"choice 已 open 时原地改写 pending_choice 字段（options/active_tab/page_index/title/...）"的路径，是否都让 UI 看见了变化并重渲？**

修完之后用户能确信：未来再有人写"原地刷新 pending_choice"的代码（page 切换、动态选项、临时禁用某项等），UI 不会再悄悄停留在旧快照上。

可观察结果：

- 跑 `git grep -nE 'pending_choice\.(options|title|body_lines|active_tab|page_index|allow_cancel|cancel_label|meta|owner_role_id) *='` 列出的每一处"in-place 改写"都有对应的 dirty flag 标记，且至少一条 UI sync 路径会因这个 flag 触发重渲。
- 给每个"原地改写但 dirty 没接通"的位置补 dirty / 修 UI sync 短路，并补 regression 测试。
- 如果检查后发现没有同类隐患，也要在"结果与复盘"里写明审计范围与结论。


## 进度

- [x] 列出仓库内所有"in-place 改写 pending_choice"位置（grep 提供原始清单）
- [x] 对每处分类：① 改完会 close choice → 不需要刷新；② 改完 choice 还活着 → 必须能触发 UI 重渲
- [x] 对类 ② 的每处，确认 dirty 是否被 mark、`_should_open_choice_modal` 是否会拿到这个 dirty
- [x] ~~对漏接 dirty 的位置补修复~~ — 审计未发现新漏点，无需补修
- [x] ~~补 regression 测试~~ — 已有 `market_navigation_dirty_forces_modal_refresh` 已覆盖唯一类 ② 路径
- [x] 全 behavior + lint 通过（2013 ok / 0 not ok；lint 0 errors / 497 warnings）


## 意外与发现

### 审计范围（实际跑的命令）

```
git grep -nE 'pending_choice\.(options|title|body_lines|active_tab|page_index|allow_cancel|cancel_label|meta|owner_role_id) *=' -- 'src/**.lua'
git grep -nE 'pending_choice\.[a-z_]+ *=' -- 'src/**.lua'    # 拓宽到任意字段
git grep -nE 'pending_choice\[' -- 'src/**.lua'              # 动态键写入
git grep -nE '(turn|game\.turn)\.pending_choice\s*=' -- 'src/**.lua'  # 整体替换
```

### 命中清单

| 位置 | 字段 | 改完后 choice 状态 | dirty mark | 分类 |
|------|------|-------------------|-----------|------|
| [src/rules/market/choice/session.lua:32-41](src/rules/market/choice/session.lua#L32-L41) （`_apply_spec`） | title / body_lines / options / allow_cancel / cancel_label / active_tab / page_index / page_count / owner_role_id / meta | 仍活（market 翻页/切 tab/支付回调） | ✅ `_mark_choice_dirty` 写 `dirty.market` + `dirty.turn` + `dirty.any`（[session.lua:9-16](src/rules/market/choice/session.lua#L9-L16)） | 类 ②，已被 a54beb8 接通 |

`pending_choice.[a-z_]+ =` 的拓宽 grep 只多出 `page_count`（同函数内），其余两条 grep 均无命中。整个仓库的"原地改写 pending_choice"路径**只有这一条**，三个调用方 `rebuild_pending` / `apply_navigation` / `refresh_after_paid_callback` 全部统一走 `_apply_spec`。

### a54beb8 修复链路实测

- `_apply_spec` 末尾 `_mark_choice_dirty(game)` → `game.dirty.market = true`
- `src/ui/ports/ui_sync/model.lua:67` `if dirty and dirty.market == true then return true` 仍在，强制 reconcile 分支未被回滚
- 首次 open 时（market_active=false 路径）`dirty.market=false`，仍走 `should_reconcile`，78acda7 的 AI 闪屏修复完整保留


## 决策日志

- 决策：清理范围只覆盖"原地改写 pending_choice"，不覆盖"通过 `intent_dispatcher.open_choice` 重新打开新 choice"。
  理由：后者会让 `choice.id` 变化，UI sync 看到新 id 自然会触发 reconcile（`_should_skip_reopen` 用 id 判等）；前者才是 78acda7 短路漏过的盲区。
  日期/作者：2026-05-01 / 主线 debug 收尾后立项

- 决策：复用 `dirty_tracker` 已有的域，不新建 dirty 域。
  理由：`market` 域已存在（[src/state/dirty_tracker.lua:7](src/state/dirty_tracker.lua#L7)），`a54beb8` 直接复用没有破坏现有 consume 路径。如发现 item_phase / target 等路径需要刷新，优先看能不能复用 `turn` / `players` 等已有域。
  日期/作者：2026-05-01


## 结果与复盘

**结论：完成判定 B —— 审计后确认无同类隐患。**

- **审计范围**：上述四条 grep 命令在 `src/**.lua` 的全部输出。
- **结论**：除 a54beb8 已修复的 `src/rules/market/choice/session.lua:_apply_spec` 外，仓库内不存在其他"原地改写 pending_choice 字段（不变 choice.id）"的路径。
- **a54beb8 链路完整性**：`_apply_spec` mark `dirty.market` → `_should_open_choice_modal` 在 `dirty.market==true` 时强制返回 true；首次 open 仍走 `should_reconcile`，78acda7 的 AI 闪屏修复未受影响。
- **未发现需要新增 dirty 域**：`dirty_tracker._dirty_keys` 维持 `{ "any", "players", "board_tiles", "turn", "market", "turn_countdown" }` 不变。

### 验证基线

| 项目 | 结果 |
|------|------|
| `busted --run behavior` | 2013 ok / 0 not ok |
| `lua tools/quality/lint.lua` | 0 errors / 497 warnings（与基线一致） |
| `git grep` 候选清单 | 仅 1 处，已全部接通 dirty |
| 代码改动 | 0 行（纯审计） |

### 后续守门建议（非本计划范围）

将来如果有人在 `src/rules/<其他>/choice/...` 新增"复用现有 pending_choice 修字段"的 session 模块，应：

1. 调用 `_mark_choice_dirty(game)` 等价物（mark `dirty.<route>`）
2. 在 `src/ui/ports/ui_sync/model.lua:_should_open_choice_modal` 对应 route 分支加同样的"dirty.<route> 强制返回 true"豁免
3. 在 `spec/suites/gameplay/ui_sync/` 仿 `auto_player_market_modal_race.lua` 加 `<route>_navigation_dirty_forces_modal_refresh` 用例

可以考虑用 lint/guard 规则在未来检测"`pending_choice.<field> =` 紧邻处缺少 `dirty.<x>=true` 调用"，但成本与命中率不成正比，本计划未实施。


## 背景与导读

### 黑市 bug 简史

- **现象**：用户点黑市商品 → resolver 抛 `invalid choice option: market_buy <id>`，无法购买。
- **根因**：`78acda7` 把 `_should_open_choice_modal` 的 `route_key=="market"` 分支从无条件 `return true` 改为走 `choice_ui_state.should_reconcile`，目的是修 AI/托管玩家闪屏。但 should_reconcile 在 `ui.market_active=true` 时返回 false，导致用户切 tab/翻页时 server 端 `pending_choice.options` 已被 `_apply_spec` 改写，UI 端 `market_view.refresh_market` 不再被触发。表现为 `ui_runtime.choice_visible_option_ids` 与槽位标签停留在旧 tab 的快照，点击发出旧 option_id，server 拿新 options 比对 → reject。
- **修复（a54beb8）**：
    1. `src/rules/market/choice/session.lua:_apply_spec` mark `game.dirty.market = true`
    2. `src/ui/ports/ui_sync/model.lua:_should_open_choice_modal` 在 `dirty.market == true` 时强制返回 true，绕过 should_reconcile
    3. 首次 open 仍走 should_reconcile（`dirty.market=false`），78acda7 的 AI 不闪屏修复完整保留
- **regression**：`spec/suites/gameplay/ui_sync/auto_player_market_modal_race.lua` 新增 `market_navigation_dirty_forces_modal_refresh`

### 关键文件

- [src/state/dirty_tracker.lua](src/state/dirty_tracker.lua) — dirty 域定义（any/players/board_tiles/turn/market/turn_countdown）
- [src/ui/ports/ui_sync/model.lua](src/ui/ports/ui_sync/model.lua) — `refresh_from_dirty` / `_should_open_choice_modal` 的 dirty 流转入口
- [src/ui/ports/ui_sync/choice_state.lua](src/ui/ports/ui_sync/choice_state.lua) — `should_reconcile` / `resolve_gate_state`，`gate.open` 的来源
- [src/ui/coord/modal.lua](src/ui/coord/modal.lua) — `open_choice_modal` 的 route 分发，`_should_skip_reopen` 用 id 去重（market 永不 skip）
- [src/rules/market/choice/session.lua](src/rules/market/choice/session.lua) — 已知"原地改写 pending_choice"的范本（rebuild_pending / apply_navigation）

### 名词解释

- **原地改写 pending_choice**：不调 `intent_dispatcher.open_choice` 创建新 choice、不变 `choice.id`，而是直接修改现有 `game.turn.pending_choice` 上的字段。
- **dirty flag**：`game.dirty` 上的布尔位，在 turn loop 的 `consume_dirty` 后被传给 UI sync，决定要不要重渲。
- **reconcile（指 should_reconcile）**：UI sync 决定"模型变了，但模态框可能没跟上，要不要重新调一次 open"。当前实现以"目标 UI 是否已在 open 状态"为条件，open=true 就直接返回 false。
- **闪屏（78acda7 修的）**：AI/托管玩家在黑市瞬间被 modal 弹出又被 auto runner 关掉，造成一帧的视觉抖动。


## 工作计划

工作分两步走，不写代码、先收集证据。

### 第一步：列原始清单

在仓库根跑：

    git grep -nE 'pending_choice\.(options|title|body_lines|active_tab|page_index|allow_cancel|cancel_label|meta|owner_role_id) *=' -- 'src/**.lua'

把命中行整理成"位置 → 是否会 close choice → 改了哪些字段"的小表格放进"意外与发现"。

### 第二步：分类与决策

对每个命中位置：

1. **若改完会立刻 close choice**（如 `_clear_choice` / `finish_choice` 链路），跳过 — 因为 UI close 路径走 `_should_close_choice_modal`，不依赖 should_reconcile。
2. **若改完 choice 还活着**（像 market 的 `_apply_spec`），追问两件事：
   - 此路径在调用前后，UI 的对应 active flag（`ui.choice_active` / `ui.market_active`）是 true 还是 false？
   - 它有没有 mark dirty？mark 的 dirty 在 `_should_open_choice_modal` 里能不能让该 route 强制 reconcile？

第 2 类如果"没 mark dirty"或"dirty 在 model.lua 里被 should_reconcile 短路掉"，就需要补修。

补修参照 `a54beb8`：

- 在 mark 处加合适的 dirty 域（优先复用 `dirty_tracker` 已有的域；不够才扩 `_dirty_keys` / `valid_domains`）
- 在 `_should_open_choice_modal` 对应 route 分支加"见 dirty 强制返回 true"的短路豁免
- 加 regression 测试：构造 active=true + dirty=true 场景，断言 `open_choice_modal` 被调

### 第三步：复核 78acda7 的"AI 闪屏"修复仍生效

每补一个新的 dirty 豁免，都要确认：

- 首次 open 时该 dirty 是否为 false（避免 AI 也走 dirty 强制路径而再次闪屏）
- 必要时在 should_reconcile 之前加 `expects_ui` 校验（即 dirty=true 但 owner_auto=true 仍不刷新）

如果发现某 route 必须在 owner_auto=true 时也刷新（例如 server 改了 owner 但 UI 不变会 desync），那是另一类 bug，归到"意外与发现"，不在本计划范围。


## 具体步骤

实施时按以下命令推进。**注意：本计划只做审计与必要修复，不重构 dirty 系统。**

### 1. 列清单

    cd /Users/billyq/Dev/Github/Lua/monopoly
    git grep -nE 'pending_choice\.(options|title|body_lines|active_tab|page_index|allow_cancel|cancel_label|meta|owner_role_id) *=' -- 'src/**.lua'

把输出贴进"意外与发现"，去掉测试用 fixture 和已 close 路径。

### 2. 跑现有 spec 建立 baseline

    busted --run behavior 2>&1 | tail -3
    lua tools/quality/lint.lua 2>&1 | tail -3

记录基线（应为 2013 通过 / 0 errors）。

### 3. 对每处疑点写最小 regression test

参照 [spec/suites/gameplay/ui_sync/auto_player_market_modal_race.lua](spec/suites/gameplay/ui_sync/auto_player_market_modal_race.lua) 的 `_run_market_dirty_refresh_case`：

- 构造目标 route 的 choice 已 open 的状态（设 `ui.choice_active=true` 或对应 active 标志）
- 调 `ui_model_sync.refresh_from_dirty` 两次：一次不带 dirty、一次带可疑 dirty
- 断言 `modal.open_choice_modal` 被调用次数为 0/1 / 1/2 等期望值

测试先写，预期它在当前代码下失败 → 然后补修复 → 测试通过。

### 4. 修复并验证

每个 fix 单独提交，commit message 引用本计划与原始 78acda7 / a54beb8 的关系。每次 push 前：

    busted --run behavior 2>&1 | grep -E "^not ok|FAIL"
    lua tools/quality/lint.lua 2>&1 | tail -3


## 验证与验收

完成判定（任一即可）：

- **A. 发现并修了同类 bug**：
    - 至少 1 个新 regression test 在修复前失败、修复后通过
    - 全 behavior 仍 2013+ 通过、0 errors
    - 实测（手动跑游戏）确认对应 route 的 UI 在 `pending_choice` 改写后会刷新
- **B. 审计后确认无同类隐患**：
    - "意外与发现"里给出完整清单与每行的分类理由
    - "结果与复盘"明确写"审计范围 = 上面 git grep 命令的输出，结论 = 除已修的 market 外无其他原地改写路径"


## 可重复性与恢复

每一步都是只读 grep 或新增测试，无破坏性。如果中途发现要扩 `dirty_tracker._dirty_keys`，要同时：

- 改 `valid_domains`
- 改 `dirty_tracker.new()` 默认值
- 改 `consume()` snapshot 字段
- 改 `reset()` 重置字段
- 改 `merge_into()` 合并键

漏一个会导致 `dirty_tracker.mark` 触发 assert 或 dirty 信号丢失。改完跑：

    busted --run guards 2>&1 | tail -3

确认 architecture / dirty 相关 guard 没失败。

回滚：每个修复独立 commit，`git revert <sha>` 即可。


## 产物与备注

实施过程中把关键 grep 输出、failing test 输出、修复 diff 收在这里。例如：

    git grep ... 输出（节选）
    src/rules/market/choice/session.lua:33:  pending_choice.options = spec.options
    （已修，复用 dirty.market）
    src/rules/<其他>/...lua:NN:  pending_choice.<field> = ...
    （待审计）

failing test 证据（先 fail 后 pass 的关键差异）：

    expected: open_choice_modal called once
    actual: 0 (before fix)
    actual: 1 (after fix)


## 接口与依赖

不引入新依赖。涉及修改时遵守现有契约：

- `dirty_tracker` API 在 [src/state/dirty_tracker.lua](src/state/dirty_tracker.lua)，扩域要五处同步
- `_should_open_choice_modal(game, state, next_model, dirty)` 已是新签名（a54beb8 加了 dirty），后续 fix 直接复用
- `choice_ui_state.resolve_gate_state` 不要乱改，78acda7 依赖它的 `expects_ui` 语义挡 AI

里程碑结束时存在的接口签名：

- `dirty_tracker._dirty_keys` 至少包含 `{ "any", "players", "board_tiles", "turn", "market", "turn_countdown" }`（如新增也要写在这里）
- `_should_open_choice_modal(game, state, next_model, dirty)` — `dirty` 不能为 nil（`refresh_from_dirty` 总会传）
