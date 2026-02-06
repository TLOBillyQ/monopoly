# Game 重迁移：V2 架构纯净全量实现（执行中）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `/.agents/PLANS.md`。

## 目的 / 全局视角

本次工作的目标是把完整玩法从旧 `src/game` 架构迁移到 `src/v2` 纯架构，保证主入口仍然是 `main.lua -> src/app/init.lua -> src/v2/bootstrap/App.lua`，并且 V2 运行链不再依赖 `src.game.*`。  
对玩家可见的结果是：V2 单入口可以完成完整对局（回合推进、道具、机会卡、市场、破产、胜负、断线重连），且自动回归以 V2 为唯一验收对象。

## 进度

- [x] (2026-02-06 16:10Z) 清空并重建本计划，修正“上次计划与仓库事实不一致”的问题。
- [x] (2026-02-06 16:12Z) 记录基线回归结果：`lua .agents/tests/regression.lua` 36 通过；`lua .agents/tests/v2_regression.lua` 4 通过。
- [x] (2026-02-06 16:35Z) 完成 `src/v2/domain` 主干改造：Commands/Events/State/Kernel + services 路由。
- [x] (2026-02-06 16:38Z) 完成 `src/v2/domain/services/*`（移动、落地、地块、道具、机会卡、市场、破产、胜负、自动决策）接入。
- [x] (2026-02-06 16:40Z) 完成 reducers 全量化：`MatchReducer`、`PatchReducer` 新增，`ItemReducer` 去空实现。
- [x] (2026-02-06 16:44Z) 更新 `src/v2/application/MatchService.lua`，接入 choice 超时自动决策。
- [x] (2026-02-06 16:56Z) 更新展示链：`ProjectionService`、`IntentMapper`、`UIBridge` 增补 item/market/动画完成意图。
- [x] (2026-02-06 17:12Z) 创建 `/.agents/tests/v2/` 分层回归：`helpers + scenarios + runner + all.lua`，场景数提升到 49。
- [x] (2026-02-06 17:12Z) 增加架构守卫测试：静态扫描 `src/v2` + `src/app/init.lua`，运行期模块加载守卫。
- [x] (2026-02-06 17:13Z) 完成最终验收：`v2_regression` 与 `v2/all` 双入口通过。

## 意外与发现

- 观察：上一轮计划文档记录了 `src/v2/game`、`Config/V2Events.lua`、`.agents/tests/v2/all.lua`，但仓库中实际不存在。
  证据：`find . -name PLAN_CURRENT.md`、`ls .agents/tests/v2`、`rg -n "V2Events" -S` 的实际结果。
- 观察：旧回归 `/.agents/tests/regression.lua` 仍直接 require `src.game.*`，不能作为 V2 完整迁移验收依据。
  证据：`/.agents/tests/regression.lua` 文件头 require 列表。
- 观察：当前 V2 回归仅 4 项，覆盖明显不足。
  证据：执行 `lua .agents/tests/v2_regression.lua` 输出 `V2 regression passed (4)`。
- 观察：棋盘路径不是线性环，`position=#path -> +1` 不一定经过起点；“经过起点”需按图导航求解。
  证据：调试 `MovementService.move` 后，实际一跳经过起点的索引是 `32 -> 1`。
- 观察：黑市“背包满”时 `list_buyable` 可能直接不返回 item 条目，不能用“遍历 buyable 找 item”做断言。
  证据：`market/full_inventory_blocks_items` 首版失败，改为对固定 item 条目 `product_id=2003` 做 `can_buy_entry` 断言后稳定通过。

## 决策日志

- 决策：`src/game` 保留只读镜像，不参与 V2 运行链。
  理由：保留对照与回滚信息，同时确保新链路纯净。
  日期/作者：2026-02-06 / Codex。
- 决策：允许规则重设计，但仅限引擎实现，不删玩法骨架（地块、机会卡、道具、市场、破产、胜负）。
  理由：满足“干净重写”并控制产品语义风险。
  日期/作者：2026-02-06 / 用户+Codex。
- 决策：当新规则与旧断言冲突时，重写 V2 断言，覆盖不降级。
  理由：避免“伪等价”卡死重构。
  日期/作者：2026-02-06 / 用户+Codex。
- 决策：禁止“复制 old game 到 `src/v2/game` 命名空间”作为迁移方案。
  理由：该路线已被证明会绕过 V2 架构治理目标。
  日期/作者：2026-02-06 / Codex。
- 决策：禁止“用 legacy 回归通过替代 V2 验收”。
  理由：验收对象必须是 V2 单入口。
  日期/作者：2026-02-06 / Codex。
- 决策：V2 回归统一收敛到 `/.agents/tests/v2/runner.lua`，`v2_regression.lua` 与 `v2/all.lua` 共享同一组场景。
  理由：避免再次出现“两个入口覆盖不一致”导致的假通过。
  日期/作者：2026-02-06 / Codex。
- 决策：V2 回归场景硬门槛设为 `>=36`，当前固定执行 49 场景。
  理由：直接对齐“覆盖不降级”验收约束，防止回归规模回落。
  日期/作者：2026-02-06 / Codex。

## 结果与复盘

本次重迁移已完成到“可验收”状态。  
V2 入口链（`src/app/init.lua -> src/v2/bootstrap/App.lua`）保持不变，领域实现已落在 `src/v2`，并由 49 场景回归覆盖核心能力域。

最终验证结果：

- `lua .agents/tests/v2_regression.lua` -> `V2 regression passed (49)`
- `lua .agents/tests/v2/all.lua` -> `V2 all passed (49)`
- `lua .agents/tests/regression.lua` -> `All regression checks passed (36)`（legacy 基线仍可运行）

复盘结论：

1. 失败根因“验收错位”已修复：V2 有独立且规模化的验收入口，不再依赖 legacy 回归证明能力。
2. 失败根因“计划与事实脱节”已修复：计划文档中的关键产物路径均已实际存在并可执行。
3. 后续风险在于规则细节与体验调优，而不是架构绕行；下一轮应以玩法细节校准为主，而非再做结构性迁移。

## 背景与导读

仓库当前同时存在两套逻辑：`src/game`（旧）与 `src/v2`（新）。入口已切到 V2，但 V2 目前只覆盖最小玩法子集，且 `ItemReducer` 为空实现。旧回归脚本覆盖更全但依赖旧架构。  
本次需要在不依赖 `src.game.*` 的前提下，把完整玩法能力迁入 `src/v2`，并让自动回归完全围绕 V2。

关键目录如下：

- `src/v2/domain`：命令、事件、状态、内核、reducers（本次重构核心）。
- `src/v2/application`：用例编排、tick/超时/动画/重连、快照恢复。
- `src/v2/presentation`：UI 输入意图与投影渲染桥接。
- `.agents/tests/v2`：新的 V2 回归入口与场景集。

## 工作计划

先在 `domain` 层把“命令驱动 -> 事件 -> reducer”主干一次性补齐，再将玩法规则拆成独立 services，避免再次回到“巨型 Kernel + 分散副作用”的结构。然后重构应用层时间驱动和重连策略，使其只编排命令，不直接改状态。最后将回归测试迁到 V2，并引入架构守卫，确保运行链彻底剥离 `src.game.*`。

## 具体步骤

在仓库根目录执行以下步骤，并在每个里程碑后更新本文档。

1. 重写 `src/v2/domain/Commands.lua`、`src/v2/domain/Events.lua`、`src/v2/domain/State.lua`、`src/v2/domain/Kernel.lua`。
2. 新增 `src/v2/domain/services/` 下九个服务模块，并接入 Kernel 路由。
3. 完成 reducers 改造并新增 `src/v2/domain/Reducers/MatchReducer.lua`。
4. 重写 `src/v2/application/MatchService.lua` 与 `ProjectionService.lua`。
5. 重写 `src/v2/presentation/IntentMapper.lua` 与 `UIBridge.lua`。
6. 新建 `/.agents/tests/v2/helpers/*`、`/.agents/tests/v2/scenarios/*`、`/.agents/tests/v2/all.lua`，并重写 `/.agents/tests/v2_regression.lua` 到 `>=36` 覆盖。
7. 追加架构守卫测试（扫描 `src/v2` + `src/app/init.lua` 禁止 `src.game.`）。
8. 执行验收命令并把结果写回本计划。

## 验证与验收

本任务的硬门槛是以下命令全部通过：

- `cd /Users/billyq/Dev/Github/Lua/monopoly && lua .agents/tests/v2_regression.lua`
- `cd /Users/billyq/Dev/Github/Lua/monopoly && lua .agents/tests/v2/all.lua`

验收行为标准：

1. V2 单入口可推进完整玩法链路（回合、道具、机会卡、市场、破产、胜负、重连）。
2. V2 回归覆盖数大于等于 36，并且场景类别不少于 legacy。
3. 架构守卫通过，`src/v2` 运行链无 `src.game.*` 依赖。
4. `src/game` 仅作为历史参考，不被 V2 运行时调用。

## 可重复性与恢复

本方案可重复执行。若中途失败，可按以下顺序恢复：

1. 还原 `src/v2/domain`、`src/v2/application`、`src/v2/presentation` 到上一提交。
2. 删除新增的 `/.agents/tests/v2` 目录与 `v2_regression.lua` 变更。
3. 重新运行 legacy 回归确认回退成功。

## 产物与备注

预计产物：

- `src/v2/domain/services/*.lua`
- `src/v2/domain/Reducers/MatchReducer.lua`
- 重写后的 `src/v2/domain/*.lua`
- 重写后的 `src/v2/application/*.lua`
- 重写后的 `src/v2/presentation/*.lua`
- `.agents/tests/v2/**` 与 `.agents/tests/v2_regression.lua`

## 接口与依赖

本次保持入口不变，新增/重写后仍需保证以下接口可用：

- `MatchService:handle_intent(intent, role_id)`
- `MatchService:tick(dt)`
- `MatchService:projection()`
- `Kernel:dispatch(command)`
- `Kernel:replay(events, base_state)`

外部依赖保持现状：Eggy 运行时 API、UIManager、`SetFrameOut`、`SetTimeOut`、配置表 `Config/Generated/*`。

## 计划变更说明

本次将旧 `PLAN_CURRENT.md` 完整替换为“V2 架构纯净全量实现”执行版，原因是上一版与仓库事实不一致且无法作为可靠导航。  
本次更新内容包括：重置进度、补充真实基线、锁定决策、明确验收与禁令（禁止旧逻辑复制迁移、禁止 legacy 替代 V2 验收）。

2026-02-06 第二次更新：补写了本轮实施完成后的真实进度与验收证据，新增“棋盘导航/黑市断言”两条实施发现，并记录“统一回归入口 + 49 场景硬门槛”决策，原因是将计划从“执行中”转为“已验证可交付”状态。
