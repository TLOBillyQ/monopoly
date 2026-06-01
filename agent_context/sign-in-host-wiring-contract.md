# 签到奖励宿主接线契约（sign-in-host-wiring）

specifier → coder。规约缺口的契约定义，非实现处方。

## 缺陷状态（coder 报）

宿主触发 `RewardDay1..7` 时玩家金币不增加。**接线缺失，非逻辑 bug**：

- `src/app/host_integrations/sign_in.lua` 的 `grant` / `claim` / `day_from_event` 已实现，`spec/behavior/app/sign_in_spec.lua` 覆盖纯逻辑；`src/config/content/sign_in_rewards.lua` 完整（500/1000/2000/4000/6000/8000/10000）。
- `RewardDay1..7` 从未经 `host_runtime.register_custom_event`（`src/host/init.lua:19`）订阅；`host_install.lua:_load_required_modules` 接了 `skin_purchase` 却没接 `sign_in`。
- `sign_in.lua:44 TODO_HOST_INTEGRATION`：事件 payload 形状 + 如何解析领奖玩家——本契约裁定如下。

## 假绿来源（同皮肤路由 bug 的同款）

`features/v102/sign_in.feature` 的验收步骤直接调适配器：
- `玩家领取第N天签到奖励` → `sign_in.grant(game, player, day)`（手搓 game/player，绕过事件名解析与订阅）。
- `触发未配置奖励的签到事件` → `sign_in.claim(game, "RewardDay99", player)`（绕过订阅）。

两者都够不到真正缺失的「订阅 + 从事件解析玩家」两环，所以适配器绿、游戏内不发钱。

## 可观察行为契约

1. 宿主在玩家领取第 N 天奖励时触发自定义事件 `RewardDay{N}`（N=1..7），payload 为 `data` 表。
2. Lua 侧收到事件后，给**领取玩家**金币 `+= sign_in.rewards[N]`。
3. 日历推进 / 当天是否可领 / 首登弹窗等门控由宿主面板管理，不在本契约范围。
4. 未配置奖励的天（如 `RewardDay99`）或非 `RewardDay<正整数>` 事件名 → 不发钱（`day_from_event`/`grant` 已处理）。

## 玩家解析裁决（用户已批准 2026-05-31）

**沿用现有约定：payload.role + 本地回退。** 即用 `src/ui/coord/local_actor_resolver.lua` 的 `resolve_from_event(state, data)` 链：
- 先读 `data.role`（Eggy Role）→ `runtime.resolve_role_id`；
- 解不出再回退 client 角色（`runtime.get_client_role()`）；
- 再回退缓存的本地 actor role id。

解析出 role_id 后经 `game:find_player_by_id(role_id)` 拿 player（同 `skin_purchase._resolve_player` 模式），再 `sign_in.grant`。兼容多人与单机。

## 接线要求（coder 实现 lane）

- 在 `host_install.lua:_load_required_modules` 订阅 `RewardDay1..7`，参照 `skin_purchase.configure` 的注入式接线形态（可测模块 + 薄宿主边界，符合宪法「最小化不可测边界」）。`register_custom_event` 那一行的实际 LuaAPI 调用是唯一不可测薄片；解析 + grant 应在可注入/可测的集成模块里。

## 张红在哪（coder 写 busted spec）

本缺口的忠实 RED **在 `spec/behavior/app/host_install_spec.lua`**，不在验收层——验收 harness（`tools/acceptance`, `ui_mock`）够不到 host_install + runtime context + LuaAPI 捕获。仿该 spec 第 36 行 `skin_purchase` 接线测试：
- 用捕获型 LuaAPI（`global_register_custom_event` 记录 `(name, handler)`）+ 带 `find_player_by_id`/`add_player_cash` 的 fake game 跑 `host_install.install`；
- fire 捕获到的 `RewardDay{N}` handler，payload `{ role = <解析到玩家R的role> }`；
- 断言玩家 R 金币 `+= rewards[N]`；并覆盖 `data.role` 缺失回退 client、未配置天不发钱。

按本项目 mutation-closure routing，该 busted spec 由 coder 写（不是 specifier 落 Gherkin example）。

## 不动的东西

`features/v102/sign_in.feature` 及其 manifest 不改（用户裁定不动 Gherkin）。既有适配器纯逻辑 spec 保留。
