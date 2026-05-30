---
kind: spec
status: stable
owner: product, architect
last_verified: 2026-05-29
---
# Backlog

## 开放项

- **default_ports / endgame 变异债（bootstrap-only manifest，从未证明覆盖）→ 待派专门 mutation-closure 周期**：v102-leaderboard 触碰这两文件时 `--mutate-all` 暴露——`src/host/default_ports.lua` 53.7%（88 survived，**多为宿主 API 探测的环境不适配壳**：`TriggerCustomEvent`/`game_api.*`/`get_timestamp`/`effect_track` 的 `type()~="function"` + pcall 分支），`src/rules/endgame.lua` 65.8%（54 survived，含 **可测的胜者判定逻辑 L200-249** + 宿主 role.die/get_component 探测壳）。本周期新增代码已全证（archive ports 35/35、_total_assets 委托 killed），**仅是预存债不属本周期**。架构问题：default_ports 混了「可测端口解析」与「环境不适配宿主探测」，未来可考虑抽出可测核心；endgame 胜者逻辑是真覆盖债。不要差分跑（bootstrap-only 会静默放行，见 [[feedback_mutate_bootstrap_not_coverage]]）；首跑必 `--mutate-all`。



**T12 已关闭（A，2026-05-29）**：原"合 swarmforge-coder 10 commits"前提过期——coder 内容即 mutate-perf，已随 `mutate-perf-l123` 进 main；Design A（`9ec8a02e` 中文名绑定）是孤儿 commit 不在任何分支，main 仍用 pN 定位绑定且 acceptance 全绿。pN 系统在用，name-based 重构 defer。复活路径见 `agent_context/plan-step-binding-name-based.md` + [[project_gherkin_step_positional_binding]]。

## 近期交付

- **v102-sign-in（specifier→coder→refactorer→architect）→ architect 完成**：收到宿主 `RewardDay{N}` 自定义事件给领取玩家发对应签到金币（500/1000/2000/4000/6000/8000/10000）。新增 `src/config/content/sign_in_rewards.lua`（按天金币表，纯数据 no_sites）+ `src/app/host_integrations/sign_in.lua` 的 `day_from_event` 解析 / `grant` / `claim` 适配器；日历推进与领取门控留宿主面板（TODO_HOST_INTEGRATION 边界）。架构审查：纯函数全可测，无环境耦合。新代码 100% killed（24/24——架构补 `claim` 适配器 4 个 survivor）；verify 9/9、property 27/27、DRY 净、soft Gherkin 21/21。merged into architect。
- **v102-leaderboard（specifier→coder→refactorer→architect）→ architect 完成**：每局结束累计胜利次数（胜利榜 key 1001）/ 剩余总资产（富豪榜 key 1002）进宿主存档。新增 `src/app/host_integrations/leaderboard.lua`（幂等 settle、退出玩家排除、archives 禁用跳过）、`src/rules/land/asset_total.lua`（现金+地产投入，从 endgame 内联抽出去重）、`src/host/default_ports.lua` archive ports。refactorer 顺带把 `runtime_ports` 三个 arity 工厂收敛为单个可变参 `_make_port` + 补 asset_total property（守恒/可加性/现金平移）。架构审查：依赖方向干净（端口 foundation 声明 / host 实现 / app 消费）。新代码全证 100% killed（runtime_ports 43/43、asset_total 10/10、leaderboard 27/27、archive ports 35/35——架构补 L222 nil-api / L238 非数值归零 2 个 survivor）；verify 9/9、property 24/24、DRY 净、soft Gherkin 19/19。merged into architect。预存债见开放项。

- **uisync-survivors → architect 完成**：5 个无 manifest 的 ui_sync ports 文件 HEAD 重测确认 15 个 survivor，全为**未测早返护栏分支**（host 已在可注入 `runtime_ports` + `type(x)~="function"` 探针后隔离 → 非环境壳）。补 13 个 busted 行为闭合（camera_pan/ports_init/ui_sync_model spec），camera/gate/model/facade **全 100% killed**。camera L196/L197 等价根因 = `release_target_pan` 死 nil-guard（`ensure_turn_runtime` 契约恒返表）→**删死码**而非 false-closure spec。status3d "no specs cover" = 经消费方 `render/status3d/specs` 透传覆盖的**归因伪缺口**，不补 change-detector。verify 9/9、DRY 无重复、soft Gherkin 无 feature 面 N/A。commit `6bfc426f`。
- **mutate-perf-poll（`mutate-perf-l123` 续）→ refactorer/architect 完成**：ADR 0014 实测只有 1.35× 非 3×，根因并行 `internal/parallel.lua` 默认 `0.2s` 轮询 + `os.execute("sleep")` fork shell（L1 把 mutant 砍到亚秒级后被粗轮询顶成新瓶颈）。修复 `DEFAULT_POLL_INTERVAL 0.2→0`（忙等、不 fork shell）+ 暴露 `--poll-interval` 逃生阀（mutate4lua `2968a1aa`，已推 origin/main）。重测 log.lua 30s→17s（1.76×）、小文件净亏消失、D4 裁决等价守住（log 180/183、identity 38/41 串=并）。残余瓶颈是进程 spawn + suite 加载 + I/O 争用（非轮询），D3 已为隔离否决 in-process 复用，本线不追。详见 ADR 0014 Resolution。
- **mutate-perf-l123**（specifier→coder→refactorer→architect 完整周期）：变异测试 L1 懒加载（按 suite-list 选择性加载 spec）+ L2 fail-fast + L3 并行执行器（mutate4lua `92ef4069` 引擎 `--max-workers` / `--fail-fast`），ADR 0014。merged to main `f2f34042`，`harness_fail_fast_spec` 3/3 PASS。副利：加速 T15 的 mutator sweep。
- **T15 measurement（`t15-quality-mutator`）→ architect 完成**：quality/* 82 mut / 72 survived，**全部 structural residue，零可闭子集**。根因：`tools/acceptance/steps/quality.lua` 是契约模拟 harness，example cell 无独立于 example 的 observable → example-value 突变天然 benign（不是覆盖债）。报告 `agent_context/architect/t15-quality-mutator-measurement.md`。**结论：Gherkin example-value mutation 不是契约/模拟 feature 的锋利度指标。**
- **T13（`page-size-schema`）→ refactorer/architect 完成**：PAGE_SIZE 收进 `src/ui/schema/{skin,item_atlas}.lua` 的 `nodes.page_size` 单点，coord/steps 引用之，消除 6 处字面量漂移。净行为不变。merged to main（commit `78eed242`）。acceptance skin_shop 62 / item_atlas 47 passed，无回归。
- **T15 closure（`items-survivors`）→ architect 重测裁定关闭，无工作**：HEAD 上 `game/items.feature` **155/155 killed、0 survived**。旧 backlog 的 9-survivor/4-closable 列表跑在更短旧 feature（30 mutation）上，已陈旧；现 feature 1072 行 / 155 mutation 全杀。CJK example cell 经 `_dither_string` 字节污染成非法 UTF-8，被 `83380ce3` 的 `_require_allowed` 白名单在 setup 阶段挡下→killed。报告 `agent_context/architect/items-survivors-remeasure.md`。教训：**派 Gherkin closure 前必须在 current HEAD 重测**（见 [[project_gherkin_survivor_measurement_staleness]]）。
