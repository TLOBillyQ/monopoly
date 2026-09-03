# 决策登记簿

本登记簿只保留仍需独立解释的约束。编号沿用历史编号，不重排；过程和被取代方案由 Git 历史承担。

## ADR 0001 / 0002 — 七层、foundation 与 state 边界

采用 `app / host / ui / turn / player|computer / rules / state|config` 七层，`foundation` 是唯一 substrate。物理目录名、逻辑层名与 arch 组件名一致；`host` 的终态是 L2 宿主适配层。foundation 可被任意层依赖，但不依赖任何七层，也不含玩法语义。

state 只向 foundation 依赖。foundation 需要可变状态时暴露参数化纯算法，由状态持有层包装“取状态 + 调算法”；装配和 mixin 安装归 `src/app`，不为单点需求开反向依赖例外。

## ADR 0012 / 0017 — Acceptance、Behavior 与 driver/port 边界

Acceptance 是玩家可观察行为真源，按玩法主题组织，经真实 driver、UI facade 或产品级边界替身观察。Behavior 是实现回归网，覆盖端口 fallback、装配、异常分支与内部协作，不机械翻译成 Gherkin。

Acceptance fixture 只造初始状态，规则结论由真实 `src` 计算；step handler 和 driver 不复制业务常量、不访问私有字段、不平行实现规则。`features/steps/**` 只通过公开接缝、driver 和 per-feature context 组合行为，具体准入由 acceptance seam guard 执行。

## ADR 0018 — 局内金币以角色 Fixed 属性为真源

局内金币唯一真源是角色 Fixed 属性 `coin_count`；不建立 `player.cash` 缓存或镜像。读写统一经 `src/player/actions/balance.lua`，规则层不直调宿主属性接口。金额只接受有限整数，余额不得为负；缺失属性、角色不可读写或写入失败都硬失败并可诊断。转账先验证双方能力与付款余额，再写双方，部分失败时尽力回滚。

## ADR 0029 — `src/ui/manager` 是 host-EUI adapter 例外

`src/ui/manager` 保留在 UI 层，承担宿主 EUI 节点镜像，因此可在 guard 明示豁免下直调 `GameAPI` / `LuaAPI`。例外不扩散到 UI 业务；业务查询仍走 port。若出现第二个同类子系统，或 manager 开始持有大量业务状态，重新评估归属。

## ADR 0030 — 无 debug/release 二分，日志常开

项目没有 debug/release 构建分叉；部署只复制 payload。logger 常开，测试静音由测试层注入；发布后排障以部署目录 `log.txt` 为证据。日志和调试能力仅在能定位发布异常时保留，纯开发探针连同专属测试一起删除。

## ADR 0038 — 道具窗口是局面快照

道具窗口打开时一次物化 options，存续期内局面冻结；每次合法变化经 `reopen_or_finish` 重建窗口。验收先铺局面再开窗，断言窗口打开时的 offer 面。若未来引入窗口存续期内的并行局面变化，必须重议本决策。

## ADR 0046 — 宿主调用以取证、端口和明确成功信号为准

已取证宿主签名采用单次直调，`pcall` 只防异常炸穿；成功按接口规定的明确信号判定，无返回值的宿主调用以可读回的状态翻转为准。宿主调用经外层 adapter/port 进入内层，业务规则不索引宿主方法。对象缺失、方法缺失、调用异常、状态未翻转与跳过分支必须各自留痕。宿主类名不稳定，逻辑不依赖 `type()` 名；API 注解只是线索，签名与返回值以真机证据为准。

**通用事实（2026-09-03，#610 取证）：宿主 API 参数错误不抛 Lua 异常**，只记一条 ERROR 日志并返回 nil，`pcall` 报告成功。所以「pcall 没抛」永远不是成功信号——这与 ADR 0065 登记的 `default_ports.end_game` 例外同型：那条例外之所以成立，只因 `game_end` 的成功信号真机尚未取证，取证后按本条收紧。

**取证结论修正（2026-09-03，#610，取代 #263 探针结论）**：宿主 `CampRole` 上**没有** `die`，`die` 在 `role.get_ctrl_unit()` 返回的单位（`LCharacter`）上；真实签名 `unit.die(dmg_unit?)`，单参可省、**不带 self**（冒号调用被宿主以 params count mismatch 拒收），且**无返回值**，成功只能以 `unit.is_die_status()` 由 false 翻 true 判定。#263 探针记录的 `role_type=table`、`role.die` 存在且返回真值，探到的是我们自己的合成 AI 角色适配器（Lua table，自带 `die` 并自行退役），不是宿主 Role；据此写下的「role 有 die、签名 `die(self, nil)`、成功按 truthy 返回值」对宿主 Role 三条全不成立，真人玩家破产时宿主 `die` 从未成功过。修复后 `src/host/role_die.lua` 按对象分两条路径：合成适配器仍按 truthy 返回值判定，宿主 Role 走控制单位并回读 `is_die_status`。**分派认 `is_synthetic_actor` 标志，不认 `die` 存在性**——后者正是 #263 误判的形状，宿主 Role 哪天长出 `die` 就会静默退回被证伪的判据；只有既无标志又无 `get_ctrl_unit` 的鸭子替身才回落到自带 `die`。

出局后的棋子移除调同一个宿主入口 `GameAPI.destroy_unit`，使两类玩家一致（`LCharacter` 有 `destroy`、无 `set_visible`，隐藏路径尚无取证手段）。取句柄的路子两侧不同但同源：合成 AI 退役读 `registry.env.GameAPI`，真人侧经 `src/host/units.lua` 读全局 `GameAPI`，而 `host_install` 正是用全局 `GameAPI` 填的 `ctx.env`。移除失败**不推翻**端口成功：出局语义由 `is_die_status` 承担，移除只是表现层收尾，失败留一条 warn。真机验证待办：若销毁真人控制单位触发宿主重生或镜头异常，退到隐藏路径并重新取证。

## ADR 0054 — 单进程整房间，可见性与授权分离

一个 Lua 进程服务整房间并逐席位渲染，不是每客户端一进程。`client_role` 是 UI 写作用域选择器，不是授权身份。可见性由目标席位和展示态计算；授权独立校验事件边界解析出的 `actor_role_id`，不得用 `current_player_id` 或上次点击者替代。多席位测试不伪造“本机角色”掩盖生产缺失条件。

## ADR 0059 — Agent-only 知识面与显式路径白名单

项目知识入口固定为 `AGENTS.md → 任务真源`。可执行代码、测试、配置、CLI 帮助和工具契约优先于叙事文档；`docs/` 只保留显式白名单中的五份 Markdown，不使用逐文件 front matter，不保留墓碑、兼容页、阶段报告或历史探索，Git 历史承担归档。

该决策取代历史 ADR 0003、0033、0056。新增长期知识先证明明确消费者、当前有效、没有更权威的可执行真源，且独立文件比并入现有真源更便宜；否则写入代码、测试、配置、工具契约或工单。技能、Gherkin、工具契约和上游资产各由自己的执行/同步边界管理，不并入项目叙事文档白名单。

## ADR 0060 — 行动日志显示窗口取机型容量保守下界

宿主运行时读不到字号、节点高度与分辨率（`Role.*` 只有 setter，`GameAPI.get_eui_*` 只取句柄；已全文核实 `EggyAPI.lua` / `EggyEditorAPI.lua`），ELabel 可视行数无法推导，任何按单一机型标定的行数上限都会在其他分辨率上失效。因此行动日志显示窗口取常量 `DISPLAY_LINE_LIMIT = 20`，语义是「最小支持机型也不溢出」的保守下界，不是「填满屏幕」；状态层仍保留完整历史。若宿主日后暴露可读尺寸/字号，或日志控件换成可滚动容器，重议本决策。

## ADR 0061 — 玩家控制语义的两轴模型与唯一模块

席位身份与控制模式是两个正交事实：补位电脑身份继续由 `player.is_ai` 表示，托管模式收敛为 `direct` / `manual_delegation` / `afk_delegation` 三态，以扁平字段 `player.control_mode` 保存。该字段只允许 `src/player/control.lua` 解释或修改；对外只有领域命令（`toggle_manual_delegation`、`enable_afk_delegation`）和窄查询（`is_replacement_computer`、`is_delegated`、`is_afk_delegated`、`is_computer_controlled`），模块本身不执行分享面板、广播或提示副作用。

「当前是否由电脑执行」只有 `is_computer_controlled` 一处派生语义：补位电脑身份或任一托管模式任一成立即为 true。规则层继续经既有 `auto_play_port` 查询，端口谓词更名为 `is_computer_controlled`；允许依赖玩家层的回合与电脑决策直接使用控制模块。UI 不依赖玩家层：回合输出侧物化不可变玩家控制快照（至少 `is_delegated` 与 `is_computer_controlled`），选择门控与托管特效消费同一快照。旧的 `auto` / `auto_source` / `ai` 字段与 `is_auto_player` / `by_ai` 标识一次性删除，不保留镜像或兼容层，并由架构 guard 阻止复现。分享面板锁存、AFK 超时计数与恢复提示节流仍归各自交互/回合流程，不属于控制模块。本决定遵循 ADR 0018 的唯一真源先例，并保持 ADR 0054 的本机角色可见性与行动者授权边界。

## ADR 0062 — 验收步骤绑定行数预算调升为 5500

`steps_budget_guard` 的 5000 行预算设于 2026-07-20（#192 DSL 重写基线 4,050 行 + ~23% 生长余量）。到 #594 时既有 29 个绑定域已占 4,993 行，余量实际耗尽：任何新验收域——哪怕收敛到极限——都会触门，而预算的本意是防复胖，不是冻结验收面。

因此预算调升为 5500 行，语义不变：仍是「先参数化合并与句面收敛，再谈调升」。#594 的 `item_slot_highlight_replay` 绑定在收敛后为 270 行（重复句面对折为 pattern handler、两侧身份解析与两个发送出口各自合一、逐槽事件断言合一），总计 5,263 行，留约 4% 余量。

调升不是「按需加数」的先例：下一次触门仍须先证明本域已收敛，且优先收敛存量大域（当前 `base_screen.lua` 618 行、`turn_flow.lua` 435 行、`card_reveal_broadcast.lua` 354 行）而非再次抬数。若绑定层再次逼近预算而存量大域仍未收敛，重议本决策。

## ADR 0063 — 超时外壳退役：选择/弹层超时模块各自自持

`src/turn/waits/timeout.lua` 原是 choice 与 modal 两族超时的装配外壳：转发解析、合并 default_policy、经 `step_default_choice` / `step_modal_timeout` 两个出口步进。#602 将其整壳退役，理由有三：

1. **构造面虚胖**。ChoiceTimeout 构造器收 10 个依赖键，其中 `resolve_output_ports` / `deadline_service` / `resolve_choice` / `force_skip` 四个是全仓唯一实现的不变量，注入只会伪装可变性。收窄为 7 键后，不变量收进模块内部直 require，可覆盖面只剩真实策略点。
2. **幽灵依赖**。`resolve_choice_ui_state` 原先不在必填键里，缺了静默降级（`choice_ui_sync` 里的 type 守卫吞掉缺失），缺屏探测形同虚设。升格为必填键后，缺失在构造期即报错。
3. **外壳零增值**。`default_policy` 导出零生产调用，纯为测试存在；modal 半壳只剩一行转发。退役后 `step_choice_timeout` / `step_modal_timeout` 端口分别直挂 `ChoiceTimeout.step_default` 与 `modal_timeout.step_default`，`ui_sync` / `loop/ports` / `ui/ports/init` 的模块清单同步改指两个本源模块。

**modal 耦合评估结论（保留）**：choice_timeout 对 modal 的唯一耦合是 `_dispatch_action_with_close_choice`——超时派单前经 modal 端口收屏。这是「超时收屏」验收场景的承重路径，不是可剪的依赖方向问题，予以保留。

**测试通路随之切换**：不变量不可再注入，观测型测试改用仓库既有模块字段补丁通路（`with_patches` 替换 `src.turn.deadlines` 字段），输出端口经 `state.gameplay_loop_ports.output` 注入（与生产 `resolve_port` 路径一致）；min-visible 等策略钉改经公开 `step_default` 驱动默认装配，不再触碰策略表导出。

## ADR 0064 — 选择超时默认装配的 no-op 回落：三透传键与 modal 收屏缓存保留

#603 收尾 #602 的两处余留并钉 no-op 回落：验收车道的超时驱动态是裸 runtime state（`ensure_all` 不注入 `gameplay_loop_ports`），默认装配若在 ui_sync 端口缺位时直接调键会崩在 arm 帧。现三键全部带回落，缺端口不崩，超时自动代答/分阶段警告/收屏链路照常。

1. **ui_sync 三透传键保留（不收窄）**。`on_pending_choice` / `is_choice_active` / `resolve_choice_ui_state` 保持必填构造键与端口在场时的一比一委派；端口缺位时分别回落：arm 帧静默 no-op、`is_choice_active` 回落运行时待决、`resolve_choice_ui_state` 回落 `should_warn=false` gate。收窄不可行：生产路径端口恒在场，委派是真实行为而非虚胖注入；缺位回落只服务无端口车道，两者都由 `type(ports[key]) == "function"` 守卫切换。
2. **modal 收屏引用缓存保留（不逐次重建）**。`_dispatch_close_opts` 与 `_cached_dispatch_modal_ref` 按端口引用比较重绑，`on_close_choice` 在 `dispatch_action` 内同步消费（当次派单即读），共享表不会跨局残留，两局端口引用交替不串；每次重建无观测收益，予以保留。
3. **缺屏告警不在默认装配承担**。引擎步进只取 `active` 判定做跟踪清算，gate 回落的结果即弃（#523 注释）；缺屏探针与告警经生产 ui_sync 端口在 dirty 刷新后采样（#524 时序），默认装配的 `should_warn=false` 只保证裸车道不误报。

## ADR 0065 — 终局收尾：胜负标记后显式 game_end，终态事件不参与落地 hold 延迟

上线实测「游戏胜利不退出」暴露两个叠加断点，本 ADR 钉死修复决策与宿主时序约定：

1. **整局结束必须显式调用 `GameAPI.game_end()`**。宿主文档明示「胜利并不代表玩家将离开游戏，还需要设置游戏结束才会离开」，且「设置胜利或失败需要在结束之前」——时序为逐玩家 `game_win/game_lose_and_show_result_panel()` 标记（带面板）→ 最后一次 `game_end()`。此前全仓零调用，会话永不终止（与 #608 漏调 `request_archive` 同型缺口）。落地为 `runtime_ports.end_game` 端口 + `default_ports.end_game` 宿主直调（ADR 0046 留痕），由 `endgame_result_panels._finalize_game_result` 在面板路由后无条件调用；面板链任何一环断裂（面板方法抛错、`resolve_role` 抛错）都吞成 warn，不阻塞收尾。
2. **`gm.finished` 是终态事件，绕过落地视觉 hold 的 defer**。淘汰型胜利的 emit 天然落在 hold 激活窗口（`move_followup` 进 landing 前先 `hold.start`，结算淘汰后脚本泊在 `wait_landing_visual`），而 defer 的释放依赖 `advance_turn` 恢复脚本——`finished` 后 `advance_turn` 直接返回，release_pending 永不置位，回调永久滞留。`event_handlers._register_handler` 对 `monopoly_event.game.finished` 置 immediate 直派，其余事件 defer 语义不变。

已登记例外（#609 复审，2026-09-03 真机试玩后维持）：**`default_ports.end_game` 暂以「pcall 无异常」为成功**，偏离宿主调用第 3 条「成功按接口规定的明确信号判定」。理由：`game_end` 返回值仍未取证——真机试玩只观测到副作用（会话退出），没有读回返回值；宿主文档亦只述副作用。若其确无返回值，truthy 判定会把真实成功误报为失败。收紧的前提是单独探针读一次 `game_end` 的返回值，而非再跑一次试玩；在此之前本例外与上文「pcall 没抛不是成功信号」的通用事实并存，即本端口的 `true` 只代表「调用未炸」，不代表宿主已结束会话。

遗留嫌疑已由真机试玩排除（2026-09-03，#609 取证）：宿主事件回调三参签名假定 `(_, _, data)`、`gm.finished` 注册句柄被丢弃未校验（对照 #585 已证实宿主会静默拒注册）——真机胜负面板按玩家正确弹出且会话随即退出，说明句柄注册未被静默拒、`winner_ids` 也确实从第三参取到，整条 `gm.finished` → 面板 → `game_end` 链路端到端成立。两条嫌疑均按观测证据关闭，不再列为待办。
