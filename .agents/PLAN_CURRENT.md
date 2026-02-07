# 全量切换 Store 主源（P1 风险项一次收敛）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次改造把运行态真相统一到 `Store`，消除“Player 对象 + Store”双重真相。改造完成后，玩家状态、地块状态、回合状态都通过统一路径读写，避免状态漂移。用户可见结果是：行为不变、回归测试全通过、结构更清晰，后续扩展不会再因为双写导致隐蔽 bug。

## 进度

- [x] (2026-02-07 13:40Z) 清空并重写 `PLAN_CURRENT.md`
- [x] (2026-02-07 14:05Z) 新增 `src/core/StorePaths.lua` 并接入核心模块
- [x] (2026-02-07 14:20Z) `Player.lua` 去行为化，行为迁移到 `GameState.lua`
- [x] (2026-02-07 14:35Z) 修复 P1 结构问题（Bankruptcy 单遍历、命名、模块组织、tile_state_path）
- [x] (2026-02-07 14:45Z) 全仓 Store 路径集中化（业务代码）
- [x] (2026-02-07 14:50Z) assert 分级审计（边界降级、核心保留）
- [x] (2026-02-07 15:00Z) 新增 6 个契约测试并接入 `.agents/tests/all.lua`
- [x] (2026-02-07 15:05Z) 运行 `lua .agents/tests/all.lua` 并验收通过

## 意外与发现

- 观察：`bankruptcy_idempotent` 契约测试的 fake store 只有 `state` 没有 `get`，导致 `BankruptcyManager` 接口回归失败。
  证据：`lua .agents/tests/all.lua` 首轮失败栈指向 `BankruptcyManager.lua:10`。
- 观察：`store.state` 白名单要求与兼容性测试桩存在冲突，需要把 fallback 从生产代码挪到测试桩。
  证据：静态扫描 `rg -n "store\\.state" src` 初次出现 `BankruptcyManager.lua`，调整后仅剩 `GameplayLoop/UIModel`。

## 决策日志

- 决策：本轮直接执行破坏性重构（Player 去行为化）。
  理由：用户已明确要求“全量切 Store 主源”，不做过渡双轨。
  日期/作者：2026-02-07 / Codex

- 决策：模块重命名采用“新主模块 + 兼容壳”策略。
  理由：保证旧 `require` 兼容，降低一次性切换风险。
  日期/作者：2026-02-07 / Codex

- 决策：`store.state` 仅允许在聚合读入口出现（`GameplayLoop`、`UIModel`），其余模块统一走 `store:get`。
  理由：保证“路径协议统一 + 读写边界清晰”，避免隐式旁路。
  日期/作者：2026-02-07 / Codex

## 结果与复盘

- 完成结果：
  - `StorePaths` 已落地，业务代码 `store:get/set({ ... })` 路径字面量已清零（静态扫描无命中）。
  - `Player` 已去行为化，旧行为调用在 `src/game` 已清零（静态扫描无命中）。
  - `GameState` 已接管玩家资金/状态/神力/座驾/位置/背包核心行为。
  - `BankruptcyManager` 已改为单来源单遍历（按 Store 的 player.properties）。
  - `ItemBoardUtils`、`MarketUI/UIMarket` 已重组为主模块 + 兼容壳。
  - `tile_state_path` 共享可变表已移除。
  - 边界断言降级：`Chance` / `ChanceRegistry` 在 `TriggerCustomEvent` 缺失时不崩溃。

- 验证结果：
  - 旧回归 + 旧契约 + 新增 6 契约全部通过。
  - 命令：`lua .agents/tests/all.lua`
  - 关键输出：`All tests passed`

- 后续建议：
  - 下一轮可继续把 `GameplayLoop` 的 `store.state` 读取收敛为只读适配层，进一步收口状态访问面。
  - 可为 `GameState` 新增更细粒度契约（如 deity 生命周期、occupants 同步一致性）。

## 背景与导读

当前代码里存在以下结构性问题：

1. `Player` 与 `Store` 同时持有状态，导致双重写入。
2. `BankruptcyManager` 同时遍历 `player.properties` 与 `store.state.board.tiles`，存在重复来源。
3. `ItemBoardUtils` 位于 `item` 域但被 `land` 业务广泛依赖，依赖方向不清。
4. `MarketUI` 与 `UIMarket` 命名相近、职责混杂（布局常量与渲染逻辑）。
5. `tile_state_path` 使用共享可变表，存在重入风险。
6. Store 路径字面量散落全仓，路径协议不统一。

关键文件：

- `src/core/Store.lua`
- `src/core/StorePaths.lua`（本次新增）
- `src/game/player/Player.lua`
- `src/game/game/GameState.lua`
- `src/game/game/BankruptcyManager.lua`
- `src/game/land/LandActions.lua`
- `src/game/item/ItemBoardUtils.lua`（兼容壳）
- `src/game/land/LandBoardUtils.lua`（本次新增主模块）
- `src/ui/MarketUI.lua` / `src/ui/UIMarket.lua`（兼容壳）
- `src/ui/MarketLayout.lua` / `src/ui/MarketView.lua`（本次新增主模块）

## 工作计划

先构建统一路径中心 `StorePaths`，再把 `Player` 行为迁移到 `GameState`，保证“所有状态写入必须经过 `GameState + StorePaths`”。随后处理结构性问题（Bankruptcy 单遍历、模块重组、命名统一），最后做全仓路径收敛与 assert 分级审计，并以新增契约测试和全量回归测试验收。

## 具体步骤

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行：

    lua .agents/tests/all.lua

预期（基线与最终）输出包含：

    Running .agents/tests/regression.lua
    ...
    All tests passed

静态门禁命令：

    rg -n "store:(get|set)\(\{" src
    rg -n "store\.state" src
    rg -n "tile_state_path" src
    rg -n ":add_cash\(|:deduct_cash\(|:set_cash\(|:set_deity\(" src/game

## 验证与验收

- 所有现有测试通过：`lua .agents/tests/all.lua`
- 新增 6 个契约测试通过并纳入 `all.lua`
- 静态门禁满足：
  - 路径字面量不再散落（仅 `StorePaths` 白名单）
  - 无 `tile_state_path` 共享可变表
  - 无旧 Player 行为调用残留

## 可重复性与恢复

- 本计划步骤可重复执行。
- 若重构中测试失败，按模块粒度回退：
  1) 先恢复 `Player/GameState` 对应提交
  2) 再恢复模块重命名与兼容壳
  3) 最后恢复路径集中化
- 每一阶段均以 `lua .agents/tests/all.lua` 作为回归关口。

## 产物与备注

主要产物：

- 新增：`StorePaths`、`LandBoardUtils`、`MarketLayout`、`MarketView`、6 个契约测试
- 修改：`Player`、`GameState`、`BankruptcyManager`、`LandActions`、`Turn*`、`ItemPhase`、UI/Market 相关模块

## 接口与依赖

本次统一依赖规则：

- 状态写入：仅通过 `GameState`。
- Store 路径：仅通过 `StorePaths`。
- 布局常量：`MarketLayout`。
- 黑市渲染逻辑：`MarketView`。
- 地块图算法：`LandBoardUtils`。

里程碑完成后必须存在以下接口：

- `src/core/StorePaths.lua`：提供 `turn/players/board/market` 路径常量与动态路径函数。
- `src/game/game/GameState.lua`：提供完整玩家域行为接口（资金、状态、位置、神力、座驾、背包、地产、淘汰）。
- `src/game/item/ItemBoardUtils.lua`、`src/ui/MarketUI.lua`、`src/ui/UIMarket.lua`：兼容壳，仅转发到新模块。

---

变更说明（2026-02-07）：完成全量 Store 主源迁移，追加了路径中心、Player 去行为化、GameState 接管、模块兼容壳、6 个契约测试与回归证据。这样修改是为了一次性收敛双真相和路径散落问题，并确保行为可验证。
