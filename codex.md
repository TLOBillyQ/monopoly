# 蛋仔大富翁工程风险评审（可执行版）

## 一、结论摘要（TL;DR）

- [P0][事实] 回合状态机存在等待态长期停留风险（`wait_choice` / `wait_move_anim` / `wait_action_anim`），会直接表现为“界面可见但流程不前进”，影响全体玩家对局可用性。
- [P0][事实] 关键流程大量使用 `assert`，触发后会中断当前流程甚至整局，属于高影响故障模式，不是普通“卡顿”。
- [P1][事实] 当前状态源是“运行时对象 + `Store` 双轨”，若绕过 `Store:set` 直接改对象字段，会造成 UI 与逻辑状态漂移。
- [P1][推断] 配置数据（地图路径、Tile 配置、UI 节点）缺失或错配时，系统更可能在启动/首轮交互期失败，而不是平滑降级。
- [P1][推断] 未见对局状态持久化读写路径，重启后无法续局；若产品目标包含“跨重启续局”，当前实现不满足。

## 二、证据与推断边界

| 结论 | 证据位置 | 结论类型 | 置信度 |
| --- | --- | --- | --- |
| 回合由状态机驱动并写入 `turn.phase` | `src/game/turn/TurnManager.lua:150` `src/game/turn/TurnManager.lua:159` | 事实 | 高 |
| 系统存在三类等待态并可能停留 | `src/game/turn/TurnManager.lua:164` `src/game/turn/TurnManager.lua:195` `src/game/turn/TurnManager.lua:212` | 事实 | 高 |
| 动画完成依赖 `done_action` 回注 | `src/game/turn/TurnAnim.lua:26` `src/game/turn/TurnAnim.lua:33` | 事实 | 高 |
| UI 事件绑定失败仅提示“节点未适配” | `src/ui/UIEventRouter.lua:35` `src/ui/UIEventRouter.lua:57` | 事实 | 高 |
| 状态主存放在内存 `Store` | `src/core/Store.lua:22` `src/core/Store.lua:23` | 事实 | 高 |
| 对象与 `Store` 需同步维护 | `src/game/game/GameState.lua:35` `src/game/game/GameState.lua:40` `src/game/game/CompositionRoot.lua:210` | 事实 | 高 |
| 系统强依赖运行时 API（非“完全无外部依赖”） | `src/app/init.lua:121` `src/core/Logger.lua:81` `src/game/game/CompositionRoot.lua:35` | 事实 | 高 |
| 未见网络/数据库/文件化存档用于对局恢复 | `src/core/Store.lua:23` `src/game/turn/GameplayLoop.lua:235`（重开直接 new game） | 推断 | 中 |

> 边界说明：
> - “未见网络/DB 调用证据”不等于“无外部依赖”；本项目对 Eggy 运行时能力有强依赖。  
> - “重启丢局”是代码扫描推断，需结合产品目标最终确认是否算缺陷。

## 三、风险矩阵（P0/P1/P2）

| ID | 等级 | 触发概率 | 影响 | 当前检测能力 | 推荐处理时序 |
| --- | --- | --- | --- | --- | --- |
| R1 等待态卡死 | P0 | 中 | 高（对局停滞） | 中（靠日志与现象） | D0 |
| R2 断言中断流程 | P0 | 中 | 高（流程终止） | 低（缺统一断言计数） | D0 |
| R3 状态漂移 | P1 | 中 | 中高（UI/逻辑冲突） | 低（缺一致性探针） | D1-D2 |
| R4 配置错配 | P1 | 中 | 中高（启动期崩溃或异常） | 中（assert 可见） | D1 |
| R5 重启不可恢复 | P1 | 低~中（看运行场景） | 高（进度丢失） | 低（缺恢复测试） | D2-D3 |
| R6 运行时能力不匹配 | P2 | 中 | 中（初始化失败或功能缺失） | 中（初始化 assert） | D3 |

## 四、重点风险条目（可执行卡片）

### R1（P0）等待态卡死

- 触发条件：
  - 动画完成动作未回注（`move_anim_done` / `action_anim_done` 未送达）；
  - 回注 `seq` 与当前动画 `seq` 不一致；
  - 等待 choice 时无可用 action 输入。
- 失效表现：
  - `turn.phase` 长时间停在 `wait_choice` / `wait_move_anim` / `wait_action_anim`；
  - UI 有画面，但“下一步”不推进或按钮无实际效果。
- 检测信号（可量化）：
  - 指标 `phase_stuck_seconds{phase=wait_*}` 连续 > 5s 记 Warn，> 10s 记 Critical；
  - 同一 `turn_count` 下 `turn.phase` 未变化且无 `dispatch_action` 记录。
- 代码锚点（文件:行）：
  - `src/game/turn/TurnManager.lua:164`
  - `src/game/turn/TurnManager.lua:195`
  - `src/game/turn/TurnManager.lua:212`
  - `src/game/turn/TurnAnim.lua:26`
  - `src/game/turn/TurnAnim.lua:33`
- 修复方案（最小改动路径）：
  - 在等待态引入“超时兜底动作”与“seq 不匹配重试计数”；
  - 连续重试超过阈值后，自动清理对应 anim 并回到可恢复状态（优先回 `resume_state`）；
  - 将等待态停留时长写入日志并带 `choice_id/seq`。
- 回归场景：
  - 前置条件：构造一个 `wait_move_anim` 场景并阻断 `done_action`；
  - 复现步骤：触发移动动画后不发送完成事件，持续 tick 12s；
  - 期望检测信号：`phase_stuck_seconds` 超阈值并产生日志；
  - 期望系统行为：系统触发兜底，`turn.phase` 在阈值后可继续推进；
  - 通过标准：连续 3 次复现均不永久卡死，且每次都有可追踪日志。
- 验收标准：
  - 任一等待态连续停留 > 10s 时必须进入兜底分支；
  - 兜底后 2s 内 `turn.phase` 发生变化。
- 残余风险/权衡：
  - 自动兜底可能绕过部分演出；需优先保证“可玩性”而非“演出完整性”。

### R2（P0）断言触发导致流程中断

- 触发条件：
  - 动画对象缺失、phase 不符合预期、choice 缺失、UI 节点缺失、运行时 API 缺失。
- 失效表现：
  - 直接抛出断言，回合或初始化中断。
- 检测信号（可量化）：
  - 指标 `assert_fail_count` 每分钟增量 > 0 即 Warn；
  - 同一错误签名 5 分钟内重复 >= 3 次即 Critical。
- 代码锚点（文件:行）：
  - `src/game/turn/TurnManager.lua:198`
  - `src/game/turn/TurnManager.lua:215`
  - `src/game/turn/TurnAnim.lua:14`
  - `src/ui/UIEventRouter.lua:176`
  - `src/ui/UIView.lua:19`
- 修复方案（最小改动路径）：
  - 将“可恢复场景”从硬断言改为软失败（记录 + 跳过 + 兜底）；
  - 仅保留“绝对不应发生”的断言；
  - 给断言统一加错误码前缀，便于聚合统计。
- 回归场景：
  - 前置条件：移除一个可选 UI 节点映射；
  - 复现步骤：进入对应交互并点击相关按钮；
  - 期望检测信号：记录软失败日志与错误码，不出现进程级中断；
  - 期望系统行为：UI 给出提示并允许继续对局；
  - 通过标准：流程可继续推进，且日志可检索到对应错误码。
- 验收标准：
  - R2 覆盖路径下，用户可操作场景不应因断言直接终局；
  - 断言日志具备 `模块 + 错误码 + 上下文` 三元信息。
- 残余风险/权衡：
  - 软失败会掩盖严重问题；需保留少量硬断言作为“防腐线”。

### R3（P1）对象状态与 `Store` 状态漂移

- 触发条件：
  - 直接改 `player` / `tile` / `inventory` 对象字段，未同步 `Store:set`；
  - 新增逻辑遗漏 `_on_change` 回调或 `game_state` 封装。
- 失效表现：
  - UI 与逻辑决策不一致；
  - 日志显示值与面板显示冲突。
- 检测信号（可量化）：
  - 指标 `state_divergence_count`（对象快照 vs `Store.state`）每回合校验；
  - `dirty.any=false` 但关键字段变化时记异常。
- 代码锚点（文件:行）：
  - `src/core/Store.lua:42`
  - `src/core/Store.lua:62`
  - `src/game/game/GameState.lua:35`
  - `src/game/game/GameState.lua:91`
  - `src/game/game/CompositionRoot.lua:210`
- 修复方案（最小改动路径）：
  - 约束关键状态只能通过 `game_state` 方法修改；
  - 在回合边界增加轻量一致性校验（仅校验玩家现金/位置/地块等级等关键字段）；
  - 校验失败时打点并阻断后续高风险动作。
- 回归场景：
  - 前置条件：在测试桩中直接修改 `player.cash`，不调用 `Store:set`；
  - 复现步骤：刷新 UI 并触发一次 AI 决策；
  - 期望检测信号：`state_divergence_count` 增加且包含玩家 ID；
  - 期望系统行为：触发一致性告警并拒绝继续执行高风险结算；
  - 通过标准：至少捕获一次漂移且无静默错误。
- 验收标准：
  - 关键字段漂移可在 1 回合内被探测；
  - 漂移探测日志覆盖玩家与地块两类对象。
- 残余风险/权衡：
  - 一致性校验会增加少量 tick 成本；优先做关键字段白名单。

### R4（P1）配置不一致导致启动/运行异常

- 触发条件：
  - `Map.path`、`Generated.Tiles`、UI 节点命名不一致；
  - 运行时资源键缺失（如道具图标映射）。
- 失效表现：
  - 组装期或首轮渲染期出现 `assert` / nil 访问。
- 检测信号（可量化）：
  - 指标 `config_validation_fail_count`（启动前校验失败次数）；
  - 启动阶段出现 `missing tile cfg` / `missing ui node` / `missing item icon`。
- 代码锚点（文件:行）：
  - `src/game/game/CompositionRoot.lua:44`
  - `src/game/game/CompositionRoot.lua:53`
  - `Config/Map.lua:30`
  - `src/ui/UIModel.lua:18`
  - `src/ui/UIView.lua:143`
- 修复方案（最小改动路径）：
  - 增加“启动前配置校验步骤”：地图路径、tile 完整性、UI 关键节点、资源引用；
  - 校验失败时阻止进入对局并输出聚合错误列表。
- 回归场景：
  - 前置条件：在 `Config.Map.path` 注入一个非法 tile id；
  - 复现步骤：启动游戏；
  - 期望检测信号：配置校验报告包含非法 id 与路径索引；
  - 期望系统行为：启动失败并给出明确错误清单，不进入半初始化状态；
  - 通过标准：错误定位到具体配置项，修复后可正常启动。
- 验收标准：
  - 启动前校验覆盖地图、Tile、UI、资源四类配置；
  - 失败信息必须包含 `文件 + 字段 + 索引/键名`。
- 残余风险/权衡：
  - 校验更严格会提升首次启动耗时；可接受，属于上线前成本。

### R5（P1）重启后局内状态不可恢复（条件性）

- 触发条件：
  - 进程重启、崩溃、热重载后重新初始化。
- 失效表现：
  - 对局进度丢失，重新开局。
- 检测信号（可量化）：
  - 指标 `recovery_success_rate`；
  - 目前基线预期为 0（未实现恢复链路时）。
- 代码锚点（文件:行）：
  - `src/core/Store.lua:23`
  - `src/game/turn/GameplayLoop.lua:219`
  - `src/game/turn/GameplayLoop.lua:235`
- 修复方案（最小改动路径）：
  - 若需求要求续局：先做回合粒度快照（玩家/地块/turn）再做恢复入口；
  - 若需求不要求续局：在文档与产品说明中显式声明“重启即重开局”。
- 回归场景：
  - 前置条件：进行到第 N 回合（N>=3）；
  - 复现步骤：强制重启进程并重新进入；
  - 期望检测信号：有恢复成功/失败日志及快照版本号；
  - 期望系统行为：已实现续局时恢复到最近快照；未实现时明确提示重开；
  - 通过标准：行为与产品定义一致且可重复。
- 验收标准：
  - 若目标是续局：`recovery_success_rate >= 95%`（30 次重启样本）；
  - 若目标非续局：必须有明确提示文案，不允许“静默丢局”。
- 残余风险/权衡：
  - 快照会引入 I/O 和版本兼容成本；需控制快照粒度。

### R6（P2）运行时能力/版本不匹配

- 触发条件：
  - `GameAPI`、`UIManager`、事件系统能力缺失或签名变化。
- 失效表现：
  - 初始化阶段 `assert`，或局部功能失效（计时、UI 交互、随机数等）。
- 检测信号（可量化）：
  - 指标 `runtime_capability_fail_count`；
  - 启动期能力探测失败项数量 > 0。
- 代码锚点（文件:行）：
  - `src/app/init.lua:121`
  - `src/core/Logger.lua:81`
  - `src/game/game/CompositionRoot.lua:35`
  - `src/game/turn/TurnDispatch.lua:22`
- 修复方案（最小改动路径）：
  - 启动时集中做 capability probe（必须能力/可选能力分级）；
  - 可选能力失败时降级，必须能力失败时中止并报版本要求。
- 回归场景：
  - 前置条件：模拟缺失 `GameAPI.random_int`；
  - 复现步骤：启动对局；
  - 期望检测信号：probe 报告明确缺失项；
  - 期望系统行为：启动被拒绝并提示最小运行时版本；
  - 通过标准：错误可被非开发同学理解和定位。
- 验收标准：
  - 启动日志必须输出能力探测结果（通过/失败项）；
  - 能力失败错误信息含“能力名 + 最小版本 + 影响范围”。
- 残余风险/权衡：
  - 探测清单需随运行时升级同步维护，否则会误报或漏报。

## 五、接口/类型影响

- 代码公共 API 变更：无。
- 文档接口变更：有。后续风险评审统一使用“8 字段风险卡片”模板：
  - `触发条件`
  - `失效表现`
  - `检测信号（可量化）`
  - `代码锚点（文件:行）`
  - `修复方案（最小改动路径）`
  - `回归场景`
  - `验收标准`
  - `残余风险/权衡`

## 六、监控与告警最小集

| 指标 | 采集点 | 阈值建议 | 告警等级 |
| --- | --- | --- | --- |
| `phase_stuck_seconds` | `turn.phase` 连续不变时长 | >5s Warn, >10s Critical | Warn/Critical |
| `assert_fail_count` | 断言或软失败捕获层 | 每分钟 >0 Warn；重复 3 次 Critical | Warn/Critical |
| `choice_timeout_count` | `step_choice_timeout` 超时分支 | 单局 >=3 Warn | Warn |
| `state_divergence_count` | 回合边界一致性校验 | 任意 >0 即 Warn | Warn |
| `config_validation_fail_count` | 启动前配置校验 | 任意 >0 即阻断启动 | Critical |
| `runtime_capability_fail_count` | 启动 capability probe | 必须能力任意失败 | Critical |
| `recovery_success_rate` | 重启恢复测试任务 | <95%（仅当要求续局） | Critical |

## 七、实施顺序与工时估计

- D0（当天止血，约 0.5~1 人天）
  - 落地 R1/R2 的最小兜底：等待态超时、软失败日志、统一错误码。
- D1-D3（结构性修复，约 2~3 人天）
  - R3 一致性探针；
  - R4 启动前配置校验；
  - R6 能力探测与降级策略。
- 后续优化（按产品目标排期，约 2+ 人天）
  - R5 续局能力（快照/恢复）；
  - 指标上报与看板沉淀。

## 八、完成验收标准（Definition of Done）

- 所有风险条目具备：等级 + 代码锚点 + 量化检测信号。
- 所有修复措施具备可验证阈值，不使用“加强/优化”空话。
- 所有推断结论均在“证据与推断边界”中标注“推断 + 置信度”。
- 文档可直接拆解为排期任务（按 P0/P1/P2 分配实现）。
- 六类重点场景均有可复现步骤与通过标准：
  - 动画完成事件缺失/seq 不一致；
  - UI 节点缺失；
  - 绕过 `Store:set` 的状态写入；
  - `Config.Map.path` 非法 tile；
  - 进程重启恢复判定；
  - 运行时能力缺失判定。

## 九、默认假设

- 目标读者：项目维护者与实现工程师。
- 优先目标：先降卡死与中断风险，再做一致性与可恢复性。
- 表达风格：直白、简练、工程化。
- 文档定位：工程风险评审，不扩展为产品需求文档。

