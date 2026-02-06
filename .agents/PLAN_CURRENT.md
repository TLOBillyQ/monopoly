# Monopoly V2 全局重构与断线重连落地

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件遵循 `.agents/PLANS.md`。

## 目的 / 全局视角

本次改造把现有“UI 驱动 + 多处状态写入”的结构替换为 `Command -> Event -> State` 的单一真相源内核，并落地局内即时断线重连。完成后，玩家在同一局断线回连时可以恢复到当前回合与未完成交互点，系统可在长离线后自动托管，避免全局卡死。可见效果是：重连后继续同一局，不再重开。

## 进度

- [x] (2026-02-06 11:20) 清空并重建 `PLAN_CURRENT.md`，锁定目标、边界与一次性切换策略。
- [x] (2026-02-06 11:22) 搭建 `src/v2` 分层目录与基础模块。
- [x] (2026-02-06 11:24) 实现命令-事件-状态内核与 reducer。
- [x] (2026-02-06 11:30) 实现重连服务（离线冻结、回连恢复、超时托管）。
- [x] (2026-02-06 11:36) 实现快照与事件日志、角色 checkpoint 写入。
- [x] (2026-02-06 11:42) 实现 V2 UI 映射与桥接，保持节点名兼容。
- [x] (2026-02-06 11:48) 切换 `src/app/init.lua` 到 V2 单入口。
- [x] (2026-02-06 11:55) 运行回归与新增 V2 场景验证并记录结果。

## 意外与发现

- 现有项目并未提供“断线重连”专用事件；可用信号主要是 `GameAPI.get_all_online_roles` 轮询与 `Role.is_online`。
- Eggy 存档类型限制为 `Bool/Fixed/Int/SheetID/Str/Timestamp`，不支持直接存 table，需要做字符串化或引用化。
- Lua 关键字 `until` 不能作为 table 字段简写，重连保护时间字段改为 `expires_at`。

## 决策日志

- 决策：重连主路径采用“内存快照 + 事件回放”，角色存档只保存 checkpoint 引用与元信息。
  理由：满足局内即时恢复性能，避免在存档层强行序列化大状态。
  日期/作者：2026-02-06 / Codex。
- 决策：一次性切换入口到 V2，不保留长期双栈执行。
  理由：用户要求全局重构并避免旧设计干扰。
  日期/作者：2026-02-06 / Codex。
- 决策：兼容边界仅保留 UI 节点名和资源键，业务接口与状态结构重定义。
  理由：降低重构耦合与历史包袱。
  日期/作者：2026-02-06 / Codex。
- 决策：角色存档只持久化 checkpoint 引用，不直接落全量状态。
  理由：存档 API 仅支持基础类型，且本需求目标是“同进程同局”即时恢复。
  日期/作者：2026-02-06 / Codex。

## 结果与复盘

本次已完成 V2 一次性切换，入口改为 `src/v2/bootstrap/App.lua`。新架构落地了分层目录、命令-事件-状态内核、重连服务、事件日志与快照、角色 checkpoint 存储接口，以及 UI 意图映射与桥接层。回归结果：

- `lua .agents/tests/v2_regression.lua` 通过（4 项）；
- `lua .agents/tests/regression.lua` 通过（36 项）。

当前缺口：尚未加入 30 分钟长稳压测脚本与 100 次断线回连压测脚本，这两项建议在发布前补齐。

## 背景与导读

旧实现入口在 `src/app/init.lua`，回合推进在 `src/game/turn/*`，状态写入分散于 `Store` 与运行时对象，且断线恢复链路缺失。V2 将新增 `src/v2/domain`（纯规则）、`src/v2/application`（用例）、`src/v2/infrastructure`（运行时适配）、`src/v2/presentation`（UI 输入输出）与 `src/v2/bootstrap`（单入口装配）。

## 工作计划

先搭建 V2 空间并定义命令、事件、状态与 reducer，再实现内核 dispatch/replay。随后落地重连服务与快照仓储，并接入角色存档 checkpoint。然后实现 UI 意图映射与投影桥接，最后替换入口并执行回归。所有副作用（Eggy API、UIManager、定时器）仅在 infrastructure/presentation 层出现。

## 具体步骤

在仓库根目录执行。

  1. 新建 `src/v2` 分层目录与模块文件。
  2. 编写 `domain`：`Commands.lua` `Events.lua` `State.lua` `Kernel.lua` 及 `Reducers/*`。
  3. 编写 `application`：`MatchService.lua` `ReconnectService.lua` `ProjectionService.lua`。
  4. 编写 `infrastructure`：`EggyRuntime.lua` `ArchiveRepository.lua` `SessionClock.lua`。
  5. 编写 `presentation`：`IntentMapper.lua` `UIBridge.lua` 与监听绑定。
  6. 修改 `src/app/init.lua`，仅装配并启动 `src/v2/bootstrap/App.lua`。
  7. 运行回归：`.agents/tests/regression.lua` 与新增 V2 场景脚本。

## 验证与验收

需要验证四类结果：

1) 内核一致性：命令去重、事件回放一致、随机一致。  
2) 重连行为：`wait_choice/wait_move_anim/wait_action_anim` 三态断线回连可恢复。  
3) UI 兼容：主按钮、选择、市场、弹窗节点仍可交互。  
4) 稳定性：长时自动局不出现状态漂移与永久卡死。

## 可重复性与恢复

V2 代码可重复生成；若需回退，可恢复 `src/app/init.lua` 到旧入口。一次性切换前保留旧模块文件不删除，确保紧急回退路径可用。

## 产物与备注

已交付产物：`src/v2/*` 新架构代码、更新后的 `src/app/init.lua`、`Config/GameplayRules.lua` 重连配置、`.agents/tests/v2_regression.lua`、本计划文档与测试记录。

## 接口与依赖

对外契约：

- `Kernel:dispatch(command)`
- `Kernel:replay(events, base_state)`
- `MatchService:handle_intent(intent, role_id)`
- `ReconnectService:on_role_offline(role_id)`
- `ReconnectService:on_role_online(role_id)`
- `ArchiveRepository:save_role_checkpoint(role_id, snapshot_ref)`
- `ArchiveRepository:load_role_checkpoint(role_id)`

依赖：`GameAPI.get_all_online_roles`、`Role.get/set_archive_by_type`、`UIManager`、`SetFrameOut/SetTimeOut`。

## 计划变更说明

本文件已从上一任务（自动玩家最短显示）切换为“Monopoly V2 全局重构与断线重连”任务，并清空重建内容。
