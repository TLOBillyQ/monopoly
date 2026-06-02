# CRAP 残留再判：6 个"住在 src/ui 下的纯逻辑"——可诚实 cover（第一批）

## 背景修正

`crap-gate-tail-disposition.md` 曾把 `ui/* ×15` 一律判为 ACCEPT residue，依据 `.luacov` 排除 src/ui。该判过粗：其中 6 个是**碰巧住在 UI 目录的纯逻辑/纯数学/纯校验**，零或可注入依赖。CRAP 工具用独立 tier 能看见它们的覆盖（`reference_crap_report_topN_cap_and_cx8_floor`：给 UI 加测降 CRAP 有效，只是不动 luacov 聚合），所以补它们=**诚实降 CRAP + 真实正确性收益**，且这 2 个是全集最高 crap（10.5 / 10.0）。

逐函数已阅读确认无 host 耦合（HEAD `914da0ab`）。cx≤6 → 满覆盖即落回地板≤6，本批全部理论可降到门内。

## 第一批 cover backlog（6 项，最高 ROI）

| # | 函数 | cx / crap | 未覆盖分支（待钉） | 依赖 |
|---|---|---|---|---|
| 1 | `src/ui/state/canvas_store.lua:78 patch_slice` | 6 / **10.5** | `patch==function` 调用路径；`else error("…expects table/function patch")` 非法 patch 路径（nil / table / marks-dirty 已由 `canvas_store_patch_slice_marks_dirty` 覆盖） | 纯 store，fake state+ui 表即可 |
| 2 | `src/ui/view/role_avatar.lua:26 sanitize_image_key` | 5 / **10.0** | nil / 非整数(warn) / `as_int<=0` 且 `<0`(warn) / `==0`(无 warn) / 正整数；相邻 `resolve_from_role:44`（无 get_head_icon / pcall 失败 / 成功） | logger 可注入，纯 |
| 3 | `src/ui/render/board/placement.lua:118 _calc_slot_offset` | 3 / 8.2 | `count<=1 or spacing<=0` 早返；`per_row` 平方循环；row/col/start 网格算式；相邻 `_calc_y_offset:134`（`base_y<min` / 否） | **纯数学**，零依赖 |
| 4 | `src/ui/render/board_feedback/catalog.lua:13 _resolve_numeric_field` | — / — | nil / `is_numeric`强转 / `table`→vector warn / 非数值 warn | 纯校验，logger 可注入 |
| 5 | `src/ui/view/choice_support.lua:5 _find_option` + 解析族 | 6 / 8.3 | options 非 table；predicate 命中/未命中；`resolve_option_id` / `resolve_option_label`（table.label / id / tostring）/ `resolve_option_by_id`；`_fallback_confirm_body` 空/非空 | 纯 choice 表逻辑 |
| 6 | `src/ui/coord/event_log_view.lua:92 _set_visibility` | — / — | no-ui；`role_id_utils.normalize` 返回 nil；`set_event_log_visible` 存在/缺席；相邻 `open`/`close`/`is_open` | fake ui 表 |

## 边界与注意

- 测试归属：CRAP-coverage 闭合 spec 属 hardening 测试，**与单元/验收/property 分层隔离**（constitution）。放 mutation/hardening 测试相应目录，勿混入普通 unit lane。
- 校验：闭合后 `lua tools/quality/crap.lua collect --lane behavior --out tmp/crap_collect.json` → `lua tools/quality/crap_gate.lua --in tmp/crap_collect.json`；CRAP 降到门内的文件应从 baseline 消失。架构侧合并后跑 `crap_gate.lua --update-baseline` 把 21 棘轮下调并复跑 `verify`。
- 余下 9 个 freeze（退化 guard / host 耦合渲染·适配 shell）维持现 baseline，见 `crap-gate-tail-disposition.md` 修订表。
- 第二批"中成本 cover"（item.lua:148 随 mutation-survivor 闭合、items/phase:178、popup:53、game_action:41、item_slots:40、move_anim/playback:21）**不在本批**，挂相邻行为/survivor spec 扩展时顺带。

参考：[[reference_crap_report_topN_cap_and_cx8_floor]]、[[reference_luacov_excludes_ui_crap_separate_coverage]]、[[feedback_refactorer_writes_closure_spec]]。
