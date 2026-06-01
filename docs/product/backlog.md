---
kind: spec
status: stable
owner: product, architect
last_verified: 2026-06-01
---
# Backlog

## 开放项

- **default_ports / endgame 变异债（bootstrap-only manifest，从未证明覆盖）→ 待派专门 mutation-closure 周期**：v102-leaderboard 触碰这两文件时 `--mutate-all` 暴露——`src/host/default_ports.lua` 53.7%（88 survived，**多为宿主 API 探测的环境不适配壳**：`TriggerCustomEvent`/`game_api.*`/`get_timestamp`/`effect_track` 的 `type()~="function"` + pcall 分支），`src/rules/endgame.lua` 65.8%（54 survived，含 **可测的胜者判定逻辑 L200-249** + 宿主 role.die/get_component 探测壳）。本周期新增代码已全证（archive ports 35/35、_total_assets 委托 killed），**仅是预存债不属本周期**。架构问题：default_ports 混了「可测端口解析」与「环境不适配宿主探测」，未来可考虑抽出可测核心；endgame 胜者逻辑是真覆盖债。不要差分跑（bootstrap-only 会静默放行，见 [[feedback_mutate_bootstrap_not_coverage]]）；首跑必 `--mutate-all`。
