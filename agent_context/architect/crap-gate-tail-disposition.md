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
| rules/movement.lua:293 `_resolve_pass_start_hold` | 8/75/9.0 | **可选 cover** | 纯 ctx 函数，仅因 25% 覆盖缺口越 ceiling(9)；几条断言即落回 cx8 下限 8.0。唯一 cx≥7 违规。低成本，refactorer 若愿可收；否则 accept |
| ui/* ×15（见下） | cx≤6 全低覆盖 | **ACCEPT residue** | 渲染/呈现层，`.luacov` 聚合排除该层（见 reference_luacov_excludes_ui_crap_separate_coverage）；用重 host-stub 覆盖纯渲染/effect 代码 churn 高价值低 |

ui/* 15 个：event_log_view:92、popup:53、canvas_route/item_slots:40、dispatch/game_action:41、ports/callbacks:8、anim/overlay_compute:18、anim/overlay_runtime:61、anim/unit_overlay:169+:34、board/placement:118+:179、board_feedback/catalog:13、move_anim/playback:21、widgets/player_slots(main)、state/canvas_store:78、view/choice_support:5、view/role_avatar:26。

## 唯一剩余结构杠杆（按需，非本轮）

真正再降 CRAP 需：(a) movement:293 补覆盖（低成本，已列可选）；(b) 若要动 cx≥7 本征复杂度则拆分函数→desync manifest→coder lane（见 crap-structural-ceiling.md）。两者均非必要：gate 已接受 cx 下限，22 残留已 baseline 保护。建议**冻结**，refactorer 停止 drawdown，除非用户要继续推 UI 覆盖或拆分。
