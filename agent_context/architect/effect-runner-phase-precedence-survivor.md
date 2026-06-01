# effects/runner.lua — _resolve_phase survivor （已闭 — 历史记录）

> **状态：CLOSED**。coder（`d79e092b`）与 refactorer（`632861a9`）平行闭合；architect 合并去重保留 refactorer 超集断言（turn_over_default + default_over_floor），复跑 `--mutate-all` 确认 **41/41 killed**，经验 manifest 已回写（`7aa9378c`）。以下为原始路由记录。

发现于 architect commit `8a2befb5`（build_game_ctx 拆 _resolve_phase / _resolve_effect_registry 降 CRAP 后，runner.lua 经验变异 40/41 killed）。

## survivor
- 位置：`src/rules/effects/runner.lua` `_resolve_phase`，行
  `return game.turn.phase or opts.phase_default or "wait_choice"`
- 突变：第一处 `or` → `and`（`game.turn.phase and opts.phase_default`）存活。
- 现有 spec（`spec/behavior/rules/effect_runner_spec.lua` "build_game_ctx prefers ..."）只测了
  opts.phase 命中、turn.phase 命中（无 phase_default）、两者皆缺三种；**从未同时给 truthy 的
  game.turn.phase 与 truthy 的 opts.phase_default**，所以"turn.phase 优先于 phase_default"这条
  优先级没有被钉住。

## 为什么是真缺口（非等价）
- 真实调用方 `src/turn/phases/land.lua:260` 在回合内（game.turn.phase 已设）传 `phase_default = "landing"`。
- 原始 `or` 链返回 game.turn.phase；突变 `and` 返回 "landing"，会在 turn 已处于别的 phase 时强制
  landing → 行为差异可达生产。

## 闭合判据（busted，不要落 Gherkin example）
在 `spec/behavior/rules/effect_runner_spec.lua` 的 build_game_ctx 测试块加一条：
game.turn.phase 与 opts.phase_default 同时为 truthy 且不同值时，断言
`build_game_ctx(...).phase == game.turn.phase`（turn phase 胜出，phase_default 不被采用）。

## 闭合后回路
coder 落 spec 后通知；architect 复跑 `lua tools/quality/mutate.lua src/rules/effects/runner.lua --mutate-all --max-workers 8`
（runner.lua 无循环，安全经验变异），确认 41/41 → 经验 manifest 自动写回 → architect 提交。
