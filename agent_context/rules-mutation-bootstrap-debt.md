# 规则层变异 bootstrap 债（待 coder 闭合）

发现时间：2026-05-31，architect 在合入 `share-task-host-rewards` 重构后跑
`mutate.lua --mutate-all --lane behavior` 实证扫描时暴露。

## 结论

下列 src 文件的 mutate4lua manifest 自 merge-base（c6dc86d，重构之前）起就是
**bootstrap-only**（只有 scope 结构 + semanticHash，无 `lastMutationStatus`），
差分模式因此拒绝运行。`--mutate-all` 跑出大量 behavior-lane survivor。
这是**既存覆盖债**，不是本次重构引入；重构本身行为保真（verify / acceptance /
property / tooling 全绿）。本周期未提交这些文件的实证 manifest，保留 refactorer
的 bootstrap 提交态，避免把无关 churn 混进 share-task 合入。

## survivor 普查（behavior lane，全 behavior 套件每变异体跑）

| 文件 | survivor |
|---|---|
| src/rules/items/demolish.lua | 59 → **已闭（148/155，余 7 不可约等价）** |
| src/rules/chance/handlers.lua | 33 → **已闭（193/204=94.6%，余 11 等价/死守卫）** |
| src/rules/items/handlers.lua | 26 → **已闭（98/99=99.0%，余 1 config 等价）** |
| src/rules/effects/mine.lua | 20 → **已闭（93/96=96.9%，余 3 等价/不可达）** |
| src/rules/board/facing_policy.lua | 19 → **已闭（65/65=100%）** |
| src/rules/items/obstacle_clear.lua | 0（已绿） |
| src/turn/loop/tick_flow.lua | **已闭（31/32=96.9%，余 1 防御守卫）** |
| src/turn/waits/timeout.lua | **已闭（137/144=95.1%，余 7 等价/log-coupled，实证 manifest 已写）** |
| src/turn/loop/init.lua | **已闭（155/168=92.3%，余 13 等价/不可达/log-coupled，实证 manifest 已写）** |

## demolish 进度（2026-05-31）

refactorer 交付 `spec/behavior/rules/demolish_closure_spec.lua`（184771e6，15 ok）闭了一批。
architect 续写（用户指令"继续完成工作"，跨 role 授权）补齐人类选择构造、免疫过滤、
anim patch、fully_blocked 真值表、`<=0` 边界、缺 turn 守卫等断言：**27 ok**。
`--mutate-all` 复测：59 → 31 → **148/155 killed（95.5%）**。

剩余 7 个全为**不可约等价 / 死守卫**，任何 behavior 测试都杀不掉（不补 false-closure），
详注见 closure spec 头部：L14（timing 默认 1.0）、L23（owned level 恒非 nil）、
L122 ×2（value∉[0,1)）、L155（hit 死初值）、L162（reach 时 hit 恒 0，not injure 等价）、
L201（position 永不入候选，守卫不可达）。

**工具策略已调整（2026-06-01，用户指令）**：mutate4lua engine 原先仅在 survivor==0
时写 manifest（engine.lua），含不可约等价的文件永远卡 bootstrap。已改为
**kill score>=90% 且无 timeout 即记录实证 manifest**，残留 survivor 按 scope 诚实记为
`last_mutation_status=survived`（不伪装 passed）；差分重测仍按 semanticHash 跳过未改
scope。submodule mutate4lua@4b3073bd（branch swarmforge-architect），父仓 gitlink 提升。
这落地了 ADR 0004 等价张力（[[project_mutation_no_equivalence_annotation]]）的解法。

demolish.lua 现已写入实证 manifest（148/155，95.5%），3 个含残留 scope 记 survived，
其余 passed。下一文件（chance/handlers 等）闭到 >=90% 即可同样记录。

## chance/handlers 进度（2026-06-01 已闭）

refactorer 交付 `spec/behavior/rules/chance_handlers_closure_spec.lua`（e7575f68，14 ok）。
architect 续写 12 个 pin（26 ok），`--mutate-all` 复测 33 → 177 → **193/204 killed（94.6%）**，
manifest 已写实证态（kill≥90% 阈值）。新增 pin 杀掉：

- `move_steps` source="chance_move"（move_anim 通道 source）；
- `move_backward` move_opts.facing_mode/skip_market_check/direction（spy `movement.move` 捕获 opts）、
  context=nil 不索引（and→or 守卫）、move_result.allow_optional=true；
- `forced_move` 山地目标走 forced_relocation（teleport_tile_types.mountain）；
- `collect_from_others` total_collected==1 仍排 cash_receive（>0 边界）；
- `emit_event` payload.text 为 string 时 publish 一条 chance_card feed（spy `event_feed.publish`，
  杀 type→nil/==~=/"string"→nil 三个）；
- `destroy_buildings_on_path` level-1 毁 / level-nil 留（(level or 0)>0 边界，注入 `_asset` common）；
- `discard_items` count=0 清空全部、丢≥1 才列名、丢 0 不加 ": "（>0 边界）；
- `add_cash` rich 翻倍 1 金币微增益（>0 vs >1）。

**余 11 survivor 全为不可约等价 / 死守卫 / 公开 API 不可达**（不补 false-closure）：
L16 `or→and`（timing.action_anim_default_seconds 恒 1.0，两路同值）；
L22 `and→or`（emit_event 私有，真实流 game 恒非 nil，无法构造 game=nil）；
L37 `>→>=`、L40 `<→<=`、L40 `0→1`（delta==0 时 rich/poor 翻倍 0=0 无观测；整数负 delta `<0` 与 `<1` 同真）；
L60/L67 `false→true`（queue_action_anim/_queue_relocation_anim 的 nil-payload/nil-player 死守卫，
调用方恒传非 nil，且 shared 未导出无法直呼）；
L348 `<=→<` ×2 / `1→0`（_resolve_drop_rng 仅决定随机 vs 顺序选地，丢光时落地集合相同）；
L408 `and→or`（`res and res.move_result`，move_steps 恒返表，两路同真）。

## effects/mine.lua 进度（2026-06-01 已交 coder closure spec）

`can_trigger` + `_is_mine_grace_expired`（scope.4）与 `apply`（scope.5）此前仅
`_find_pending_roadblock_trigger`（scope.2/3）有直接覆盖；landing_spec 走 `apply` 整合
流但不碰触发门。refactorer 先在 mine_effect_spec 加了 can_trigger 全分支 + grace 边界
pin，coder 据此交付 **`spec/behavior/rules/mine_closure_spec.lua`**（c3a4a13f），把
can_trigger 收成 superset（补 nil-position、nil-player）并补齐 `apply` closure：

- can_trigger：无 board / nil position / 无雷 → false；非 table 雷 → true；`armed==false`
  → false；他人雷无视宽限 → true；nil player 过期 → true；主人无 placement → true；
  主人宽限 `own_count > placement+1` 三点真值表（==placement+1 免疫，+2 引爆，杀
  `>→>=`/`+1→±`）。
- apply：angel-immune 拆弹不送医（detonated+protected）；正常触发清雷+送医+排 blast
  anim；roadblock 链式 tip 字段（chain_key/focus_text/tip_policy/dedupe_key/tip_source）；
  turn_count 缺失回退 0 链键。

**refactorer 去重（本轮）**：merge 'ort' 把 refactorer 旧的 can_trigger describe 复活进
mine_effect_spec.lua（与 coder superset 重复）。已删除该块，mine_effect_spec 回归只覆盖
`_find_pending_roadblock_trigger`；can_trigger/apply closure 单源在 mine_closure_spec。
合并后 mine_effect_spec(10) + mine_closure_spec(14) = **24 ok**，smoke 6/0。见
[[reference_parallel_closure_spec_collision]]。

**architect 复测 + 并行碰撞解析（已闭）**：architect `--mutate-all` 测出 78/96
（81.2%，18 survivor），曾在 mine_effect_spec 续写 `mine_effect.apply` describe（4 pin）
打 anim payload；同期 refactorer 在单源 `mine_closure_spec` 写了等价 apply closure 的
**superset**（详上）。第二次 handoff（5d54ad31）解析采纳 refactorer 单源结构：
mine_effect_spec 只留 `_find`，apply/can_trigger closure 全在 mine_closure_spec，
architect 的 apply describe 去重删除（覆盖无损）。合并后 `--mutate-all` 重记 manifest：
**93/96=96.9%**。余 3 不可约：L7 `or 1.0`（timing 恒 1.0）、L44 `tostring(position)→nil`
（default_map 全格有名，无名格 fallback 不可达，突变仅在 nil-name 时 concat 报错）、
L52 `own_count or 0` 的 `0→1`（仅 status 缺失且 placement==-1 才差，回合计数恒 ≥0 → 等价）。

## board/facing_policy.lua 进度（2026-06-01）

refactorer 交付 `spec/behavior/rules/facing_policy_closure_spec.lua`（**20 ok**，smoke 6/0）。
此前 movement_spec 只覆盖 sync 的 forced_move/clear 值用例与 resume_forward 错误契约；
roadblock_spec 把 `resolve_initial_facing` stub 掉而非真跑。空白补：

- `should_skip_inner_entry`（scope.4）**零直接覆盖**：flag+entry-point→true、无 flag→false、
  非 entry tile→false、tile 不可解析→false、缺 entry_points map→false、无 position→false。
- `resolve_initial_facing`（scope.5）只有错误路径：fresh_forward 无视 direction 返 nil、
  resume_forward 回显 opts.direction、relative_forward 显式 direction 优先、relative_backward
  回退 player.move_dir、无 direction 无 heading→nil、非法 mode assert。
- `sync_move_dir_after_position_change`（scope.3）补 preserve 分支、nil mode 默认 preserve、
  `_set_move_dir` 改/不改的 true/false 返回（含 market 已朝右的不写状态守卫）、clear 重置
  skip_next_inner_entry 并回传该写入、非法 mode assert。

纯函数 + stub game（无同进程污染）。

**architect 复测 + 续写（已闭 100%）**：`--mutate-all` 测出 63/65（96.9%，refactorer spec 已记 manifest），
余 2：L20 `mountain=false→true`（_tile_type_move_dir.mountain 清向守卫，refactorer 测了 hospital 未测
mountain）、L65 整调用→nil（普通格 sync fallback 的 `false` 无变更返回值未断言）。architect 续 2 pin
（mountain forced_move 清向 + 普通格返回 false），**65/65=100%**，manifest 重记。

## items/handlers.lua 进度（2026-06-01 已交 coder closure spec）

coder 交付 `spec/behavior/rules/item_handlers_closure_spec.lua`（df31d293，**24 ok**），
直接驱动导出的 `handle_*` 并 patch 注入端口，逐分支隔离派发层 survivor：

- `handle_target_player_item`：target_id 校验（无效/自指/已淘汰/不在候选）、`_resolve_apply_ok`
  三形态、`_maybe_consume_item` 两条跳过（preconsumed/item_consumed）、`_finalize_apply`、
  `_apply_share_wealth_context`（share_wealth 落 context vs 其他不落）、`_queue_target_player_anim`
  payload、already_queued 不重排。
- `_run_item_choice_flow`：空候选→false、by_ai→ai_select、human→waiting choice_spec 全字段。
- `handle_remote_dice`：ai feed-publish 守卫（有目标格+apply ok 才发）、choice_spec。
- `handle_roadblock`：ai auto vs human manual candidates（radius 3）、pick_best/apply 接线、
  空候选→false、choice_spec。
- `handle_demolish`：monster/missile cfg 派发、未知 item 断言。

负面测试故意触发的 3 个校验 warn 已入 `behavior_warns_data` 白名单 + 同步 behavior-warns.md。
refactorer 合并（merge-base f4c46259，与 facing_policy 分叉，无冲突，两 spec 并存）。

**architect 复测 + 续写（已闭）**：快进合并后 `--mutate-all` 测出 97/99（98.0%，manifest 已记），
余 2：L17 `or 1.0`（timing 恒 1.0，等价）、L24 `_resolve_apply_ok` 的 table-无-ok `return true→false`
（refactorer 测了 ok=true/ok=false/bare-true 三形态，漏 table 缺 ok 字段→默认 applied）。续 1 pin
（apply_res={note=...} 无 ok → consumed=true、res.ok 被 finalize 盖 true），**98/99=99.0%**，manifest 重记。
余 1 仅 L17 config 等价（全 rules 层复现的同一不可约残留）。

## 收尾（2026-06-01）：规则层变异 bootstrap 债全部闭合

5 个 debt 文件全部跨过实证 manifest：demolish 148/155、chance 193/204、mine 93/96、
facing_policy 65/65、items/handlers 98/99。残留全部为不可约等价/死守卫/不可达（已逐条注明），
无 false-closure。

## turn/* 三文件复核（2026-06-01，coder 质疑后 architect 实测）

**纠正**：此前把 `src/turn/{waits/timeout,loop/tick_flow,loop/init}.lua` 记「未跑完（已停）」
并归因 macOS 无 timeout 的 loop-mutant 挂起——**对这三文件是误判**。实测：三文件均无
`while`/`repeat`，只有有界 `for...in pairs/ipairs`（tick_flow 零循环），`--mutate-all` 全部
**秒级完成、无挂起**：

- `tick_flow.lua`：31/32=96.9%，manifest 已记。余 1：L24 `if not (game.turn and game.advance_turn)`
  的 `and→or`——防御守卫，真实 game 恒有 advance_turn，仅 stub game 缺该方法可杀（近死守卫）。
- `timeout.lua`：96/144=**66.7%，48 survivor**（端口解析/类型守卫/config 默认分支为主：
  L43 modal_ports 类型校验、L220/228 choice-ui 端口校验、L22/35/81 数值边界等）。
- `init.lua`：115/168=**68.5%，53 survivor**（端口装配/类型守卫：L25 端口校验簇 ×3、L43/50/64
  端口类型校验、L106 簇、L159/163/164 端口构建等）。

timeout/init 是**真实既存 behavior 覆盖债**（非工具阻塞、非等价），已 routing 给 coder 写
busted closure spec（direction A）。coder 在自有 worktree 重跑 `--mutate-all` 取实时 survivor 列表
（确定性、秒级）。closure 后 architect 复跑写实证 manifest（≥90% 记录）。
[[reference_mutate_hang_no_timeout_loop_mutants]] 的 loop-hang 规则仍对**含 while/repeat** 的文件
有效，但这三文件不属此类，不该据此豁免。

### timeout.lua 进度（2026-06-01 已交 coder closure spec）

coder 交付 `spec/behavior/turn/timeout_closure_spec.lua`（11816ed6，**20 ok**），直驱导出面
+ patch timing/constants config，命中 architect 标注的端口/类型守卫/config 默认分支区：
`resolve_choice_timeout_seconds`（runtime_state 第三 or-臂、`_positive_numeric` 的 `>0` 边界、
scope_timeouts 非表→constants base、无 base→0）、`default_policy`（`_clone_policy` 深拷贝、
`get_min_visible_seconds`、modal.on_timeout 经 `_resolve_modal_ports` 的 L43 or 守卫）、
`step_modal_timeout`（`_resolve_modal_timeout` override 三态、`_update_modal_elapsed` 的
`dt or 0` 与 `>=` 边界、`_assert_modal_opts`/`_resolve_modal_ref` 断言）。
scope.21-23（step_default_choice 经 tick_choice_timeout 深集成端口闭包 fallback）留待 architect
复测，不写脆弱 log-observing pin。refactorer fast-forward 合并（与 d9b4d517 同栈），verify 9/0。

#### architect 复测 + 分桶裁定（2026-06-01，HEAD 2b1830ca）

`--mutate-all --max-workers 8 --lane behavior` → **75.7%（109/144），35 survivor**（manifest 仍
bootstrap，未过 90% 阈值不写实证）。coder 首轮闭 13（modal-timer 算术 + resolve 路径），余 35
按可杀性分三桶：

- **桶 1 — 真等价（3，architect 裁定不 pin，已记）**：L102 `_modal_timer_reset.elapsed_seconds=0`、
  L103 `_modal_timer_update.elapsed_seconds=0`、L200 `_choice_ui_fallback.should_warn=false`——
  全是模块级表字面量初值，每次使用前必被重写（L110/L126、L119、L232），初值永不被读 → 不可约等价。
- **桶 2 — 干净可杀（~29，退回 coder，非脆弱）**：coder「scope.21-23 深集成端口闭包脆弱」的
  framing 不成立。`resolve_port.resolve` 只读 `state.gameplay_loop_ports.{output,ui_sync}`，
  注入 fake 端口表 + 直驱导出面 `step_default_choice`/`step_default_modal` 即可观测：
  - L151/L157/L163：`default_policy.choice` 闭包 + ui_sync 解析（timeout getter / build_action 经
    `choice_auto_policy.decide` / 端口注入观测委派）。
  - L213/L214/L220/L221/L223：`on_pending_choice`/`is_choice_active` 闭包——注入 ui_sync 端口
    （方法 present）观测委派调用 vs 缺端口走 `ctx.pending_choice ~= nil` fallback。
  - L43/L49/L50/L53/L59：`_resolve_modal_ports`/`_dispatch_action_with_close_choice`——modal 端口
    present vs 缺，dispatch 传 `_dispatch_close_opts` vs nil（需 stub `turn_dispatch` 经 package.loaded）。
  - L134 `<=`（timeout==0 边界）、L6 require choice_auto、L22/L29 `_positive_numeric`/scope fallback、
    L81 modal timeout config base、L126 `_handle_modal_timeout` elapsed reset——均单元/集成可杀。
- **桶 3 — 真 log-coupled（仅 ~2，可接受 state-log 断言）**：L228/L229/L231/L232 的 should_warn
  fallback 喂 `tick_choice_timeout._maybe_warn_missing_ui` → `runtime_state.log_once`；这是
  coder 唯一站得住的「脆弱」点，断言 state 日志缓冲即可，不必避。

裁定（direction A）：桶 2（~29）退回 coder 续写 closure spec；桶 1（3）architect 已记为等价
（移出分母后过 90% 的目标是 109+~18≥127/141）；桶 3（~2）可选。**驱动配方**：fake
`state.gameplay_loop_ports = { output = <记录表实现 get/set_pending_choice* + sync_modal_timer 等>,
ui_sync = <实现 on_pending_choice/is_choice_active/resolve_choice_ui_state> }`，`deadlines`/
`runtime_state` 用真模块；`step_default_choice(game, state, dt)` 在 pending_choice 存在 + elapsed≥timeout
时一次 tick 即贯穿全部闭包。

### timeout 桶 2 续闭 + init 交付（2026-06-01，coder 9c2e0622 / f68a7dff，refactorer 合并）

- **timeout**：coder 按桶 2 配方续写 `timeout_closure_spec`（+6 集成 → **26 ok**），注入 fake
  `state.gameplay_loop_ports`，直驱 `step_default_choice`/`step_default_modal` 观测端口委派
  vs fallback。桶 3（L231/232 should_warn→log_once，~2）architect 裁定可选，留复测。
- **init**：coder 交付 `spec/behavior/turn/loop_init_closure_spec.lua`（**14 ok**，3 describe）：
  fallback-port 守卫、`step_auto_runner`、`set_game` initialize-ports。覆盖端口装配/类型守卫簇。

两者 specs-only（无 src 改动），fast-forward 合并（3-commit 栈基于 refactorer HEAD），verify 9/0。

#### architect 复测 + timeout 闭合（2026-06-01，HEAD dc7d0f06）

- **timeout.lua 已闭**：`--mutate-all` 复测 refactorer 桶 2 续写后 = 88.2%(127/144)，差 90%
  一步——architect top-off 6 pin（→ **32 ok**）：L22 `>0` 边界、L29 scope.choice fallback、
  L81/L134 nil base→0 timeout 的 `<=0` 空短路、L126 触发 reset elapsed=0、L157
  policy timeout getter 委派、L43×3/L53 仅-close_choice_modal 端口经 or 守卫解析 + on_close_choice
  接线。**95.1%(137/144)**，实证 manifest 已写。**余 7 全残留（不补 false-closure）**：
  - L102/103/200：模块级表字面量初值（`_modal_timer_reset/_update.elapsed_seconds`、
    `_choice_ui_fallback.should_warn`），每次使用前必被重写 → 等价。
  - L231×2：fallback 的 `route_key` 仅在 warn 触发时被 `_maybe_warn_missing_ui` 读，但同一
    fallback 强制 should_warn=false → warn 永不触发 → route_key 永不被读 → 等价。
  - L223/L232：仅影响 `should_warn`→`runtime_state.log_once` warn 路径（`step` 的 `active`
    取自 `pending ~= nil`，**不依赖** `is_choice_active`）。log-coupled，不写脆弱 log-observing pin。
- **init.lua 续闭中**：`--mutate-all` = **81.5%(137/168)，31 survivor**（refactorer loop_init_closure
  闭 22）。距 90%（≥152/168）尚差 ~15 kill——属批量 closure，非 architect top-off，退回续写。
  残留端口装配/类型守卫簇：L64（intent_output_port type-guard ×3 + build_port）、L72/75/88
  端口 resolve、L100/106×3/107/110/111/114×2 cfg 装配守卫、L118/119/122/126 边界、
  L159/171/202/203/217/220/230/282 端口构建/model 同步。

DRY：仅既存跨层小工具/anonymous 噪音，本周期无 in-scope 项。soft Gherkin：本周期零 feature/step
delta，acceptance 546 ok 无回归。timeout 闭合落 dc7d0f06；init 退回 coder/refactorer。

#### refactorer init 续闭（2026-06-01，承接 architect 退回）

refactorer 扩写 `loop_init_closure_spec`（14 → **22 ok**，+8 pin），打 architect 列的残留簇：

- `_is_auto_popup_waiting`/`_is_auto_popup_owner` 三条 fall-through（L110/L114/L122/L126）：
  delay>0 + popup_active 时——人类持有 popup（is_auto false）/ 无 active popup / 无 owner index
  三种都**不**挂起，runner 仍被 consult（用 next_action 是否被调用观测，与既有"挂起"正例对偶）。
- `gameplay_loop.tick` → `_ensure_runtime_ports`（L64）：缺 intent_output_port 时构建 + 填 fallback；
  已是 table 时保留（sentinel 不被重建）；nil game 短路（patch tick_flow.tick 隔离）。
- `_initialize_ports` bankruptcy_feedback_port arg-shuffle（L171）：4-arg shape 读 arg4、3-arg shape
  读 arg3 作 owned_tile_ids（set_game 后替换 board_visual_feedback_port.sync_many 捕获）。

verify 9/0、lint 0 warning。

**并行碰撞解析（2026-06-01）**：refactorer（941d8f23，+8 pin）与 coder（292c7d8f，+7 pin）
**从同一 architect base b76ba167 各自续写 loop_init_closure_spec**——典型并行 closure 碰撞
（[[reference_parallel_closure_spec_collision]]）。merge 'ort' 文本自动合（不同 offset 追加），
但产生语义重复：双方都打了 popup owner-unknown / tick nil-game / tick 建端口。refactorer 去重保
**并集**：删 refactorer 的 owner-unknown + nil-game tick + builds-missing（coder 版等价或更优，
含 dep 委派断言），保 refactorer 独有的 human-owned popup / no-active popup / bankruptcy arg-shuffle
（L171）/ intent-port sentinel 保留；保 coder 独有的 _reset_runtime_state+role-lock /
_fill_auto_action_actor 双臂 / elapsed-window 边界 / tick+dep。**26 ok，零重复 it-block**，verify 9/0。

剩余 survivor（端口 resolve 缓存 L75、模块级 dispatch 缓存 L88、cfg 装配深处 L100/106/118-126、
_configure_* L217/220、port-build L159/202/203/230/282 等）多需深集成或受模块级状态跨测污染，
留 architect 复测后判定 top-off vs 等价。请 architect 跑 `init.lua --mutate-all` 写实证 manifest。

coder 另请 refactorer 收敛 `_drive_turn`/driver 内联（[[project_turn_driver_drive_loop_dedup]]）：
本轮 turn driver 无新增 drive-loop 变体（DRY 扫无 in-scope 命中），无可收敛项，未动 src。

#### architect 复测 + init 闭合（2026-06-01，HEAD = merge of d47bb1bc + 1fbc5f9f）

两个并行 closure 栈在 architect 处汇合：architect 自己的 top-off（d47bb1bc，88.1%→92.3%，
5 test/7 pin：L159 game.state、L202/203 role-lock、L230 player_units_missing、L88 dispatch
缓存、L118 delay-nil、L119 `0→1` 子秒窗）与 refactorer 的派发层 superset（1fbc5f9f，含 coder
292c7d8f 去重并集，26 ok）。二者**互补非父子**：refactorer 在重叠区（set_game stale-state、
tick deps、popup owner-unknown）是 superset，architect 独有 L118/L119`0→1`/L88/L159 四 pin。
`--no-ff` 合并，spec 冲突按 [[reference_parallel_closure_spec_collision]] 解析——采纳 refactorer
superset 结构 + graft architect 四独有 pin，零重复 it-block，**30 ok**。

`--mutate-all` 复测 = **92.3%(155/168)**，实证 manifest 已写。**余 13 全残留（不补 false-closure）**：
- 等价：L75（`_resolve_ports` source 缓存守卫，resolve 幂等→改 `==`/`~=` 行为同）、L119
  `<=→<`（min=0 时 `elapsed<0` 恒假→与 `<=0` 同 not-waiting 结果）。
- 公开 API 不可达：L72（`_resolve_ports(nil-state)`，导出面恒传非 nil state）、L106×3/107/110
  （`_is_auto_popup_owner` 的 `game and state and ...` 守卫，game/state 经 step_auto_runner 断言
  恒真，无法构造 false 臂）、L100×2（`cfg.name or tostring(cfg.id)`，真实 items_cfg 全有 name，
  tostring fallback 不可达）。
- log-coupled：L282（`auto_action == nil` → `_log_missing_auto_choice_action` 的 `log_once`）。
- 可杀待续（非本轮 top-off）：L217/L220（`_configure_pending_choice` 的 pending→build_model→
  open_modal 路径，需 non-nil pending + 返表 ui_sync.build_model fixture）。

DRY：仅既存跨层噪音，无 in-scope。soft Gherkin：零 feature/step delta；acceptance 待复跑确认。
至此 timeout.lua(95.1%) + init.lua(92.3%) 两个 turn-loop bootstrap 债全部跨实证 manifest，
turn/* 三文件（含 tick_flow 96.9%）全闭。

## 不算债的两类（勿误闭）

- `src/app/host_integrations/share_task.lua` 的 `reward_for`（3 survivor）与
  `src/rules/items/target_query.lua` 的 `find_best_tile`（2 survivor）由
  **property 套件**覆盖（`spec/property/share_task_spec.lua`、
  `spec/property/target_query_spec.lua`）。宪法规定 property 不进语言变异 behavior
  lane，故这些是 lane 分离产物，非 behavior 债。见 [[reference_mutate4lua_test_corpus]]。

## 闭合路径

routing 给 coder 写 busted 闭合 spec（不是 Gherkin example），见
[[feedback_mutation_survivor_routing]]。建议按文件分批：先 demolish / chance / mine。
每批 coder 闭 survivor 后由 architect 跑 `--mutate-all` 写实证 manifest
（见 [[feedback_architect_owns_manifest_refresh]]、[[feedback_mutate_bootstrap_not_coverage]]）。
注意 [[project_behavior_test_intra_process_pollution]]：部分规则覆盖依赖同进程兄弟测试顺序。
