# T4 Rent Read-site Audit

## 结论

**Classification: WORKING**

租金翻倍确实影响最终支付金额，而且同一个 `rent` 局部变量一路流到实际扣款/入账调用，没有看到缓存旧值或另起金额变量的路径。

## 翻倍是否影响最终金额

- `src/rules/land/rules.lua:106-109`：先计算 `rent = land_rules.contiguous_rent(...)`，随后在 `player_has_deity(player, "poor")` 时执行 `rent = rent * 2`，在 `player_has_deity(owner, "rich")` 时再次对**同一个** `rent` 变量翻倍。
- `src/rules/land/rules.lua:111-121`：事件 payload 的 `amount = rent`，并且当余额足够时实际调用 `game:deduct_player_cash(player, rent)` / `game:add_player_cash(owner, rent)`。
- `src/rules/land/rules.lua:125-127`：资金不足分支也继续用同一个 `paid`/`rent` 逻辑链，最终入账仍是 `game:add_player_cash(owner, paid)`。
- `src/player/actions/state_ops/deity_ops.lua:6-11`：`player_has_deity` 先取 `player.status and player.status.deity`，再做 `deity.type == name and deity.remaining > 0` 的严格相等判断。

**边界情况**：富人站在自己的地块上时，基础租金本来就是 `0`；`0 * 2` 仍然是 `0`，这是符合当前实现的。

## 绕过路径搜索结果

### `add_player_cash` + rent 相关命中

- `src/rules/land/rules.lua:121` — `game:add_player_cash(owner, rent)`

### `pay_rent` / `charge_rent` 命中

- `src/rules/land/effects/base.lua:114` — `_can_pay_rent`
- `src/rules/land/effects/base.lua:160` — `_apply_pay_rent`
- `src/rules/land/effects/base.lua:187` — `land_actions.execute_pay_rent(ctx.game, player.id, t.id)`
- `src/rules/land/effects/base.lua:225` — `pay_rent = { can_apply = _can_pay_rent, apply = _apply_pay_rent },`
- `src/rules/land/actions.lua:41` — `function land_actions.execute_pay_rent(game, player_id, tile_id)`
- `src/rules/land/actions.lua:42` — `local result = land_rules.execute_pay_rent(game, player_id, tile_id)`
- `src/rules/land/rules.lua:86` — `function land_rules.execute_pay_rent(game, player_id, tile_id)`
- `src/rules/land/landing_defs.lua:12` — `{ id = "pay_rent", mandatory = true },`
- `src/rules/choice_handlers/land.lua:31` — `land_actions.execute_pay_rent(game, player_id, tile_id)`

未发现绕过路径。

---

## 未审查清单

以下相关代码本次未覆盖：

- `src/rules/land/effects/` 其余 effect 文件（如特殊地块、机场、公共设施等）是否也走 `execute_pay_rent`
- 多人同地块时的租金分配逻辑（若存在）
- cheat / debug 入口是否有直接跳过租金的路径
- 测试 fixture 中租金相关 stub 是否与真实行为一致
- save/load 对租金中间状态的影响（Q3 已排除，仅记录）
