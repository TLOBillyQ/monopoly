# T7: Transfer Semantics（送神 / 请神）静态审计

范围：只读审计 `send_poor` / `invite_deity` 的转移语义；未修改 `src/`、`spec/`、`tools/`。

## send_poor 类型契约

**Classification: BROKEN（apply 层）；正常道具入口为 WORKING。**

- `src/rules/items/post_effects.lua:154-158` 的 `require_user` 会通过 `game:player_has_deity(user, "poor")` 限制使用者必须有穷神。
- `src/player/actions/state_ops/deity_ops.lua:6-11` 定义了 `player_has_deity` 的真实语义：`deity.type == name and deity.remaining > 0`。
- `src/rules/items/registry.lua:33-34` 在构造目标候选前执行 `spec.require_user`，因此正常 item flow 会在选目标前挡住 rich / angel / expired poor。
- `src/computer/agent/action.lua:77-81` 的 AI picker 也额外检查 `game:player_has_deity(player, "poor")`。
- 但 `src/rules/items/post_effects.lua:161-163` 的 `send_poor.apply` 只 `assert(user.status.deity)`，随后无条件把 `target` 设置为 `"poor"` 并清空 `user`。
- `src/rules/items/post_effects.lua:280-283` 导出的 `apply_target` 直接分派到 `spec.apply`，没有重新执行 `require_user`。
- `spec/behavior/gameplay/items/post_effects_spec.lua:129-143` 只覆盖 `user.status.deity.type == "poor"` 的 happy path，没有覆盖 rich / angel / remaining=0 直调。

结论：正常道具入口会阻止 rich / angel 被送出；但 `apply_target(game, user, item_ids.send_poor, ...)` 若被直调，rich / angel / expired poor 只要存在 `user.status.deity` 表，就会被按穷神送给目标。这是叶子函数类型契约缺失。

## invite_deity 空源处理

**Classification: BROKEN。**

- `src/rules/items/post_effects.lua:139-140` 的 `filter_target` 只检查 `target.status.deity` 是否 truthy。
- `src/player/actions/state_ops/deity_ops.lua:18-22` 的 `clear_player_deity` 不会删除 `status.deity`，而是保留表并写成 `type = ""`、`remaining = 0`。
- `src/rules/items/registry.lua:37-41` 直接用 `filter_target` 构造可选玩家列表；`src/rules/items/availability.lua:114-115` 又用候选数决定目标道具是否可提供。
- `src/rules/items/handlers.lua:105-117` 对显式 `target_id` 只验证目标是否存在于候选列表；候选列表一旦收进空 deity 表，显式选择也会通过。
- `src/rules/items/post_effects.lua:143-145` 的 apply 会把该表里的 `type` / `remaining` 原样设置到 user。

结论：`filter_target` 能拦住 `status.deity == nil` 的目标，但拦不住被 `clear_player_deity` 清过的空占位表。结果是“无有效神仙”的玩家仍可能成为请神目标，并把 `"" / 0` 写回使用者。

## 原子性

**Classification: BROKEN。**

- `src/rules/items/post_effects.lua:143-145` 的 `invite_deity` 顺序是先读取 target deity，再 `clear_player_deity(target)`，再 `set_player_deity(user, deity.type, deity.remaining)`。
- `src/player/actions/state_ops/deity_ops.lua:27-33` 的 `set_player_deity` 在写状态前有 `assert(name ~= nil)`，写状态后还会发 `deity_applied` 事件。
- 因此若 `deity.type` 为 nil 或后续 set/emit 失败，`target` 已经被清，`user` 未必完成写入；没有回滚。
- `src/rules/items/post_effects.lua:161-163` 的 `send_poor` 顺序是先读 user deity，再 `set_player_deity(target, "poor", remaining)`，再 `clear_player_deity(user)`。
- 该顺序同样不是事务：若 set 后 clear 失败，会留下 source / target 状态不一致；代码中没有补偿逻辑。

结论：两条转移路径都不是原子操作。`send_poor` 的第一处 assert 在突变前，缺失 deity 不会产生半成品；但突变之间的失败仍会留下半成品。`invite_deity` 因先清 source 再写 receiver，风险更直接。

## 自指

**Classification: WORKING（正常目标选择路径）；SUSPICIOUS（直调 apply 层）。**

- `src/rules/items/registry.lua:37-41` 构造候选时要求 `p.id ~= player.id`，正常 UI 候选不包含自己。
- `src/rules/items/handlers.lua:99-117` 对 `context.target_id` 的显式目标再次拒绝 `target.id == player.id`。
- `src/computer/agent/action.lua:7-20` 的 `_richest_other` 排除 `p.id == player.id`；`src/computer/agent/action.lua:51-63` 的 `_pick_deity_target` 也排除自己。
- `src/computer/agent/decision.lua:62-68` 的自动选择只把 picker 返回的目标 id 写回 choice action。
- 但 `src/rules/items/post_effects.lua:280-283` 的 `apply_target` 不检查 `user == target`，`src/rules/items/post_effects.lua:143-145` 和 `src/rules/items/post_effects.lua:161-163` 的具体 apply 也没有自指保护。

结论：通过正常道具选择、显式 `target_id`、AI picker 都不能选自己；但直调 `apply_target` 时仍允许 `user == target`。直调自指下，`send_poor` 会先给自己设置 poor 再清空自己；`invite_deity` 在真实 `clear_player_deity` 的就地清表语义下也会把自己的 deity 变成空值。

## 链式

**Classification: BROKEN。**

- A 使用送神后，`src/rules/items/post_effects.lua:161-163` 会把 B 设置为 poor，并调用 `clear_player_deity(A)`。
- 生产态清理逻辑来自 `src/player/actions/state_ops/deity_ops.lua:18-22`，A 的 `status.deity` 会保留为空占位表，而不是 nil。
- B 再使用请神时，`src/rules/items/post_effects.lua:139-140` 会把 A 的空占位表当成可请目标。
- B 选中 A 后，`src/rules/items/post_effects.lua:143-145` 会清 A，并把 A 的空 `type` / `remaining` 设置到 B，覆盖 B 身上的 poor。
- `src/config/testing/test_profiles.lua:109-145` 有 `deity_transfer` 启动剖面，目标是 `invite_and_send_poor_chain`；但现有 `spec/behavior/runtime/test_profile_bootstrap_scenarios_spec.lua:202-210` 只校验启动状态。
- 现有直接 apply 覆盖 `spec/behavior/gameplay/items/post_effects_spec.lua:35-50` 和 `spec/behavior/gameplay/items/post_effects_spec.lua:129-143`，没有覆盖 “A 送 B 后 B 再请回 A” 的状态链。

结论：链式状态不一致。按正常生产态清理语义，A 被清后仍可能作为空源进入 B 的请神候选，B 再请 A 会把自己的 poor 覆盖为空 deity，而不是保持有效状态或禁止该目标。

## 未审查清单

**Classification: SUSPICIOUS（范围外 / 未覆盖）。**

- 未审查非转移目标道具的状态语义；`src/rules/items/post_effects.lua:15-22` 的 target item 列表还包含 `share_wealth`、`exile`、`tax`、`poor`。
- 未审查表现层动画和事件消费是否会放大上述问题；相关发出点包括 `src/rules/items/post_effects.lua:146-149`、`src/rules/items/post_effects.lua:164-167`、`src/rules/items/handlers.lua:58-66`。
- 未执行行为测试；本任务要求纯静态审计。现有测试证据只说明 happy path 存在，缺少 rich/angel 直调、空 deity table、user==target、send→invite 链式回归。
