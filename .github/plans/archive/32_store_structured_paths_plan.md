# GameState 结构化路径写入计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md`，后续每次修改都必须按其中规则维护。

## 目的 / 全局视角


当前 `GameState` 通过构造路径数组调用 `Store:get/set`，可读性尚可但路径分配与遍历会带来额外开销。本计划的目标是把 `GameState` 的 Store 读写改为“结构化路径表”的方式：直接定位到 Store 的中间节点并原地写入，从而提升可读性与性能，并确保行为与现有一致。

验收要点：基准脚本显示 `game_ops` 时间明显下降，且现有逻辑不依赖 `Store:get/set` 的语义变化。

## 进度


- [x] (2026-01-31 03:20Z) 实现结构化路径写入：`GameState` 直接操作 Store 节点并保持行为一致。
- [x] (2026-01-31 03:21Z) 运行基准脚本并记录对比数据。
- [x] (2026-01-31 03:22Z) 更新计划与产物说明，确保可复现。

## 意外与发现


观察：`GameState` 现有写入点主要集中在玩家、地块与回合节点，适合用结构化路径表减少分配。
证据：`Manager/GameManager/GameState.lua` 读写路径集中在 `players`、`board.tiles`、`turn` 三组节点。

## 决策日志


- 决策：不改动 `Store` 接口，仅在 `GameState` 内改为直接访问 `store.state`。
  理由：避免影响其他模块的 `store:get/set` 调用，降低变更风险。
  日期/作者：2026-01-31 / Codex。

## 结果与复盘


基准脚本显示 `game_ops` 由 0.378558 降至 0.130148（同样 loops=20000），说明结构化路径写入显著降低开销。后续若需要进一步优化，可考虑将 `Store:get/set` 本身做微优化，但当前收益已足够明显。

## 背景与导读


Store 是一棵嵌套 table，`GameState` 原先通过路径数组调用 `store:get/set`。此方案会为每次调用分配路径表，并在 `Store` 内部做逐层遍历。结构化路径写入的核心是：在 `GameState` 内部用 `ensure_table` 构建或复用中间节点，直接写入叶子字段，避免重复分配与遍历。

## 工作计划


先在 `GameState` 引入 `store_root` 与 `ensure_table`，把所有 `_store_set` 调用替换为结构化节点写入，并确保只在 `GameState` 内使用，`Store` 仍保持原样。完成后运行基准脚本，记录 `game_ops` 与路径基准的结果，并写入计划。

作为下一阶段可选优化，补充 `Store:get/set` 的遍历微优化（例如把 `ipairs` 改为 `for i = 1, #path do`），但本计划只记录方案，不执行实际改动。

## 具体步骤


1) 修改 `Manager/GameManager/GameState.lua`：

    - 新增 `store_root` 与 `ensure_table` 工具函数。
    - 移除 `_store_set`，所有写入改为直接操作 `store.state` 的中间节点。
    - 保持 `queue_action_anim` 与 `pending_choice` 的现有语义（不增加深拷贝）。

2) 运行基准脚本：

    lua .github/scripts/bench_store_gamestate.lua

3) 把输出记录到“产物与备注”。

4) 记录 `Store:get/set` 遍历优化的候选方案与预计影响，但不进行代码修改。

## 验证与验收


1) `lua .github/scripts/bench_store_gamestate.lua` 可运行。
2) `game_ops` 相比之前降低（同样 loops=20000）。
3) `GameState` 对 Store 的写入路径与字段保持一致。

## 可重复性与恢复


本变更只影响 `GameState`，如需回滚，恢复 `GameState` 对 `store:get/set` 的调用即可。基准脚本不修改持久状态，可反复运行。

## 产物与备注


运行命令与关键输出：

    lua .github/scripts/bench_store_gamestate.lua
    loops=20000
    game_ops=0.130148
    path_alloc=0.020803
    path_reuse=0.011731

相关改动：

1) `Manager/GameManager/GameState.lua`

变更说明：执行结构化路径写入方案，降低 `GameState` 写入开销并记录基准数据。
