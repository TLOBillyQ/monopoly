---
kind: adr
status: stable
owner: architecture
last_verified: 2026-07-08
---
# ADR 0026 - debug deploy 的 autotest 车道：一次启动跑完全部 test profile

## 背景

debug deploy 原本一次只能注入一个 `STARTUP_TEST_PROFILE`：每验证一个场景要重新部署、
重新启动宿主、人工驱动 P1、人工读 log.txt。35 个 test profile 全量回归意味着 35 次
"部署→启动→手玩→看日志"，实际从未被完整执行过。

已有的机制缺口只在编排层：

- auto 玩家会在 pre_action 自动打出背包道具（`src/rules/items/phase.lua` 的
  `_run_auto_phase`），P2-P4 在 debug 下已默认托管，唯独 P1 留人工。
- `gameplay_loop.new_game` + `state.on_game_replaced` 的换局链路已备好，但生产代码
  没有调用方。
- profile 的 `expect` 断言（ADR 见 `spec/behavior/app/test_profiles_expect_spec.lua`）
  只在 headless 车道被消费，宿主上没人评估。
- 宿主帧回调里 `gameplay_loop.tick` 无 pcall 保护，一个坏场景会击穿整个运行。

## 决策

新增 autotest 车道，全部编排逻辑收进 `src/app/testing/`（release 部署整体剥离，
零 release 足迹）：

- **启动契约**：`deploy.ps1 -Autotest <selector>` 注入 `STARTUP_AUTOTEST`
  （`all` / `group:<组>` / 逗号名单），强制 debug 构建；`policy.resolve` 透传
  `autotest` 字段，init 以 build mode 门控 + 惰性 require 接入（同 roster 边界约定）。
- **旧方案退役**：`-Profile` 参数与 `STARTUP_TEST_PROFILE` 全局随之移除——单
  profile 验证用 `-Autotest <name>`（自动端到端），手工试玩用普通 debug 部署
  （default 局）。policy 不再产出 profile 概念，启动一律 default 局。
- **编排器** `autotest_runner`：逐 profile 换局（`build_game_factory(profile,
  auto_all=true)` → `new_game` → `on_game_replaced` → prime），全员托管端到端演练；
  结束条件优先级 tick 崩溃 > expect 满足 > 对局结束 > 回合/时间预算；单 profile
  失败不中断整批。驱动模型是 `step(dt)`：宿主帧缝与 headless spec 走同一条路径，
  不依赖宿主定时器。
- **帧守护缝**：`gameplay_start` 的帧回调支持 `state.tick_observer(dt, ok, err)`；
  装了观察者时 tick 受 pcall 守护。未装时行为不变。
- **结果契约**：`autotest_results` 产出 `[autotest] begin/profile/summary` 行
  （key=value，机器可解析），经 `logger.info_unlimited` → print → 宿主 log.txt；
  `tools/ops/autotest_report.ps1` 解析并以退出码表达结果（0 全过 / 1 失败 / 2 无数据）。
- **速度档**：autotest 下关闭动画等待门、压缩托管决策间隔到 0.2s——该车道只验
  规则/结算/中断端到端，不验动画节奏；全量 profile 宿主上分钟级跑完。
- **CI 镜像**：`spec/behavior/scenarios/autotest/run_all_profiles_spec.lua` 用真实
  roster/建局/turn loop headless 跑同一编排器全量 profile（约 0.4s），任何 profile
  崩溃或 expect 不满足都会红。

## 使用

```bash
# 部署 autotest 包（隐含 debug）
pwsh tools/ops/deploy.ps1 -Autotest all
pwsh tools/ops/deploy.ps1 -Autotest group:combat_obstacle
pwsh tools/ops/deploy.ps1 -Autotest solo_missile,combo_mine_vs_angel

# 宿主启动地图一次，跑完后（或 -Wait 边跑边等）读结果
pwsh tools/ops/autotest_report.ps1 -Wait
```

## 后果

- 无 `expect` 的 profile 以"预算内无崩溃跑完"为通过标准（smoke 语义）；`expect`
  仍按既有契约增量补充（每条 expect 必须镜像既有 behavior spec 的设计事实），
  补一条就自动升级一条的验证强度，宿主与 headless 双车道同时受益。
- `timing.auto_decision_delay_seconds` 在 autotest 模式下被进程内改写；该进程
  只跑 autotest，不影响正常对局部署。
- 行格式是 `autotest_results` 与 `autotest_report.ps1` 的跨语言契约，改动要同步
  `spec/behavior/app/autotest_results_spec.lua` 与
  `script_tools_contract.lua` 的 `autotest_report` 用例。
