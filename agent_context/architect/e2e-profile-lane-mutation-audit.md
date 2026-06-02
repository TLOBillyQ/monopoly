# e2e-profile-lane 变异审计（architect，merge 5a16c78e 后）

coder/refactorer 交付时 5 个改动 src 全是 bootstrap-only manifest（闭了 survivor 但没跑 mutate）。architect 逐文件 `--mutate-all --max-workers 8`，结论分三类。

## A. 真 survivor → 交 coder 写 busted closure（可杀，非等价）

| 文件 | 分数 | survivor | 闭法 |
|---|---|---|---|
| `src/app/testing/e2e_profile_lane.lua` | 90.8% (59/65) | L100 nil-player→false、L103 `stay_turns or 0`、L104 `and/or`+`>/>=`+`0/1`、L116 in_hospital 分支 —— 全在 `lane.observe`/`_player_in_hospital`/`_observe_players` | `e2e_profile_lane_spec` 只测 `partition`+`match`（手搭 observed 表），**从不调 `lane.observe`**。模块 docstring 自称 reducer「proven headlessly against the real rule modules」，实则零直测。补 spec：搭 game stub（`board:get_tile`/`board:find_first_by_type("hospital")`/players.status.stay_turns/position）+ recorded events，断言 observe 派生的 in_hospital/tiles/events |
| `src/app/testing/test_profile_resolver.lua` | 94.7% (18/19) | L12 `"" → nil`：`profile_name==""` → "default" 分支未测（只测了 nil） | 一条 `assert` resolve_bootstrap("") 等价 default |

这两个文件 manifest 已写实证状态（≥90% 阈值），survivor 记为诚实 residue；但它们**可杀非等价**，应闭到 100%，不当 residue 接受。

### 闭合结果（coder 1ff59c82 spec-only → refactorer → architect merge b5c3a5ac，architect 复跑 --mutate-all）

- `test_profile_resolver.lua`：**100% (19/19)** —— `""→default` 已杀。
- `e2e_profile_lane.lua`：**98.5% (64/65)** —— observe reducer 6 个杀 5。**剩 1 等价 residue**：L104 `stay_turns > 0`→`> 1`。`hospital_stay_turns=2`（`config/content/constants.lua`）配置定死；reducer 只在 demolish 回合刚送医后观测，此点 stay_turns 恒=2，`>0` 与 `>1` 对一切可达观测态同值 → 调用点等价突变（[[reference_dead_guard_equivalent_mutation]]）。coder/refactorer 留它是对的，不为不可达 `stay_turns==1` 写 false-closure。
- 闭合 spec-only（不碰 src，manifest 保完整），architect 复跑后 manifest 写诚实实证状态。

## B. 数据/装配文件 → 结构-only bootstrap（非行为可变异，已 --update-manifest 修漂移）

| 文件 | 分数 | 裁定 |
|---|---|---|
| `src/config/test_profiles.lua` | 21.3% (48/225) | **数据注册表**。177 survivor 二类成因：(1) solo_missile.expect 4 个（L199-202）**已被 `test_profiles_expect_spec` 钉死**——手动改 L200 level 0→1 该 spec 当场红；mutate4lua 对数据文件的 per-file spec 选择没跑这条 pin（harness 局限，非真缺口）；(2) 其余 173 是 phase-1 无 expect 的 ~36 profile 的数据字面量（item id/count/tag/flag），经消费方透传覆盖，无承载 spec（见 [[reference_mutate_no_specs_cover_attribution]]）。钉全部=golden snapshot，违 specifier 显式「最小充分集」设计。数据文件本不该被行为变异度量，保结构-only bootstrap |
| `src/app/gameplay_start.lua` | 78.3% (36/46) | **composition 装配**。10 survivor 全是 wiring（require→nil / dispatch→nil / build→nil / flag 翻转），需 gameplay-loop 集成 spec 才能覆盖，churn 高值低。本 handoff 只 +5 行（live_handle.set seam），survivor 系**既存** bootstrap 缺口非本周期引入。保结构-only |

两文件 merge-base 即 bootstrap-only，与项目数十个 UI 文件同态；coder 编辑漂移了 semanticHash，architect `--update-manifest` 修结构（[[reference_mutate4lua_semantic_hash]]，ADR 0004 D5 合规）。

## C. 无变异位点

`src/app/testing/live_handle.lua`：纯引用 holder（set/get/clear），无运算/分支位点 → 空 manifest，诚实。

## 边界确认（architect 关注）

- `spec/property/e2e_profile_lane_spec.lua` 在独立 `property` lane（76 properties 绿），**不入** verify/behavior。
- `spec/e2e/*`（活编辑器）独立 `e2e` lane，非 Windows/无 EDITOR_CLI_FORCE 全 pending（8 SKIP），**不入** verify/mutation/CRAP。
- `src/app/testing/*` 是纯逻辑，环境不适配边界正确地落在 `spec/e2e/support/profile_driver.lua`（测试侧），src 保持可无头变异。
- ⚠ 边界微瑕：`src/app/gameplay_start.lua`（生产 boot）`require` 并调 `src.app.testing.live_handle.set(...)` —— 生产→testing 依赖反向。inert seam（headless/生产无人读），但若日后再生长，应改为生产经现有 port 暴露、e2e lane 经 port 读，避免生产命名 `testing/`。本轮不动（单条 inert 调用，重构成端口反增间接）。

soft Gherkin acceptance mutation：本 handoff 无新 APS feature（e2e lane 刻意非 feature），N/A。
