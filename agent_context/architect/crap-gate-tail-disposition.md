# CRAP 门尾部裁定（22 违规，drawdown 收官）

gate 引入 30 → refactorer 逐轮补覆盖闭合 8 个到下限 → 现 **22**（baseline 54c96daa）。
refactorer 报告 clean-public-function seam 已耗尽，请架构裁定 per-file accept vs cover vs route。
裁定如下；**结论：接受当前 22 为稳定 baseline residue，结束 drawdown 磨削**。gate 的目的（挡新增高-CRAP 代码）已达成，继续磨腿部是递减收益。

## 裁定表

| 文件:行 | cx/cov/crap | 裁定 | 理由 |
|---|---|---|---|
| rules/land/effect_chance.lua:51 `_pick_chance_card` | 6/67/7.3 | **ACCEPT** | `total_weight<=0`/`#chance_cfg==0` 是退化配置防御 guard，覆盖需伪造不可能配置（不诚实），等价残留 |
| rules/choice_handlers/item.lua:148 | 6/58/8.6 | **ROUTE→coder** | 该文件是已知 mutation survivor lane（39 survivor，见 restructure 审计）；覆盖随 survivor closure 自然来，不双轨 |
| rules/items/phase.lua:178 | 6/55/9.4 | **ACCEPT** | 需全 game-stub 链，成本 > 价值 |
| app/profile_bootstrap.lua:100 | 4/38/7.9 | **ACCEPT** | 同上，bootstrap 装配需全 stub 链 |
| rules/movement.lua:293 `_resolve_pass_start_hold` | 8/75/9.0 | **已 cover 闭合** | 纯 ctx 函数补覆盖落回门内，已从 baseline 消失（曾为唯一 cx≥7 违规，结构杠杆现空载）。drawdown 后基线棘轮 22→21 |
| ui/* ×15（见下） | cx≤6 | **拆分判定（2026-06-02 修订）** | 原 "ACCEPT residue" 过粗。6 个是纯逻辑/纯数学/纯校验，归 **cover backlog**（见 `crap-ui-pure-logic-cover-backlog.md`，已交 refactorer）；其余 9 个是退化 guard / host 耦合渲染·适配 shell，维持 ACCEPT |

ui/* 复判（HEAD 914da0ab，逐函数阅读）：
- **→ cover backlog（6，已 routing refactorer）**：state/canvas_store:78、view/role_avatar:26、view/choice_support:5、board/placement:118、board_feedback/catalog:13、coord/event_log_view:92。
- **维持 ACCEPT（9，host 耦合渲染 / 适配 shell）**：ports/callbacks:8、anim/overlay_compute:18、anim/overlay_runtime:61、anim/unit_overlay:169+:34、board/placement:179、move_anim/playback:21、widgets/player_slots(main)、coord/popup:53。
- 注：popup:53 / canvas_route/item_slots:40 / dispatch/game_action:41 是端口注入的可达逻辑，属"第二批中成本 cover"（挂相邻行为/survivor spec 扩展时顺带），非本批。

## 唯一剩余结构杠杆（按需，非本轮）

真正再降 CRAP 需：(a) 第一批 6 个纯逻辑 cover（已交 refactorer，最高 ROI，诚实降 CRAP）；(b) 若要动 cx≥7 本征复杂度则拆分函数→desync manifest→coder lane（见 crap-structural-ceiling.md）——当前 cx≥7 违规为 0，此杠杆空载。9 个 freeze 残留已 baseline 保护。
