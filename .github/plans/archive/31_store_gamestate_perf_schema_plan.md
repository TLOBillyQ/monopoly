# GameState 性能优化与 Store Schema 可行性计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md`，后续每次修改都必须按其中规则维护。

## 目的 / 全局视角


当前 `Manager/GameManager/GameState.lua` 通过 `Components/Store.lua` 读写状态树，路径以字符串片段构成。随着回合推进、动画与地块更新频繁调用，Store 的路径构造与拷贝可能成为性能热点。本计划要验证两件事：一是 GameState 是否存在可测的性能瓶颈；二是 Store 是否可以采用类似 `.github/docs/SecretOfEscaper/Manager/PlayerManager/Player.lua` 中 `schema` 的方式进行结构化定义，从而减少运行时的分支与分配。

交付结果必须可观察：给出性能对比数据与明确结论（保留现状/引入 schema/采用其它优化方案），并提供最小的落地改动或原型验证，确保读者能复现实验并看到提升或验证不可行。

## 进度


- [x] (2026-01-31 03:02Z) 基线测量 GameState/Store 的热点调用成本，并记录测试场景与输出。
- [x] (2026-01-31 03:03Z) 设计 Store schema 结构草案，映射到现有路径与数据结构。
- [x] (2026-01-31 03:04Z) 产出最小原型并评估性能与复杂度成本。
- [x] (2026-01-31 03:05Z) 依据数据做出取舍决策并记录结论。
- [x] (2026-01-31 03:06Z) 更新验证与复盘，补充可复现证据。

## 意外与发现


观察：仓库中 `.github/tests/test_bootstrap.lua` 不存在，基准脚本不能依赖测试引导文件。
证据：`lua .github/scripts/bench_store_gamestate.lua` 初次运行提示 `cannot open .github/tests/test_bootstrap.lua`。

## 决策日志


- 决策：不采用 Player 存档的 schema 编解码方式直接驱动 Store。
  理由：Store 是运行时状态，schema 编解码属于序列化流程，带来的容错/回退/分片逻辑不适合运行时路径写入；性能收益不明确且引入额外复杂度。
  日期/作者：2026-01-31 / Codex。

- 决策：保留现有 Store 接口，仅保留 schema 草案与基线脚本作为评估依据。
  理由：基线数据表明路径复用确有收益，但与 GameState 全量改造相比收益仍偏局部；先保留轻量评估产物，等待更明确瓶颈后再动核心路径。
  日期/作者：2026-01-31 / Codex。

## 结果与复盘


已完成基线脚本与 schema 草案。基线结果显示“路径复用”比“每次新建路径表”更快，但当前仅有微基准数据，尚不足以证明引入复杂 schema 的整体收益。结论：暂不引入 Player schema 方式到 Store，仅保留草案与基准脚本，后续若发现 Store 热点再做针对性优化。

## 背景与导读


Store 是一棵嵌套 table，由 `Components/Store.lua` 的 `get/set` 读写。`Manager/GameManager/GameState.lua` 负责把玩家状态、地块状态、动画队列等写入 Store。最近已将路径片段抽为数值枚举并通过映射表回到字符串，这保证了枚举值不是字符串，但 Store 仍以字符串作为最终 table key。

`.github/docs/SecretOfEscaper/Manager/PlayerManager/Player.lua` 展示了一个“schema + 编解码”的存档结构：schema 定义结构与字段，运行时依照 schema 读写并做序列化。此方式可能为 Store 提供结构化路径定义、减少动态路径拼装和分配，但也可能引入额外复杂度或与现有运行时写法冲突。本计划将验证其可行性与收益。

## 工作计划


先在不改变行为的前提下获取基线数据，确认 `GameState` 调用 `store:set/get` 的频率与成本。然后设计一个 Store schema 草案，要求能覆盖 `GameState` 当前的写入/读取路径，且不改变 `Store` 的外部 API。接着实现一个最小原型：仅覆盖 `GameState` 相关路径，验证性能、内存占用与实现复杂度，并对比现状。

若 schema 有明显收益且复杂度可控，则推进将 `GameState` 的路径构造替换为 schema 驱动；否则保留现状，并给出更轻量的替代优化（例如缓存路径表或减少深拷贝范围）。

## 具体步骤


1) 在仓库根目录新增一个最小可复现的基线脚本或测试场景，驱动 `GameState` 的典型写入路径（玩家状态变更、地块更新、动画入队），并输出调用次数与耗时。要求场景可在纯 Lua 下运行，且不会引入引擎依赖。

2) 基于 `.github/docs/store/00_state_tree_writers.md` 与 `GameState.lua` 的现有路径，编写一份 Store schema 草案。schema 必须是显式结构定义，包含每个路径片段与叶子字段的类型或用途说明，并能映射回当前字符串路径。

3) 实现原型（仅覆盖 GameState 路径），以“路径复用”微基准作为 schema 预生成路径的代理指标：

   - 不改变 `Store:get/set` 的签名。
   - 通过 schema 预生成路径片段与中间表结构，减少运行时路径构造与分配。
   - 保持行为一致（写入路径与读取路径完全匹配，值不变）。

4) 对比基线与原型的性能数据，记录耗时变化。若差异不显著或复杂度过高，则退回并记录原因；若显著提升，则推进最小改动落地。

5) 更新 `GameState` 或 `Store` 的实现（仅在收益明显时），并补充必要的测试或脚本，确保可复现结果。

## 验证与验收


必须满足以下条件：

1) 提供可复现的基线与对比结果（包含命令与关键输出片段）。
2) 如引入 schema，必须证明行为一致：关键路径写入与读取结果相同。
3) 不引入引擎依赖，`lua` 在纯环境下可运行验证脚本。

## 可重复性与恢复


所有基线/对比脚本应可重复运行且不会写入持久状态。若 schema 原型未被采用，应完整删除相关实现或在文档中标注为“弃用原型”。如需回滚，恢复到原 `Store`/`GameState` 实现并移除新增脚本。

## 产物与备注


运行命令与关键输出：

    lua .github/scripts/bench_store_gamestate.lua
    loops=20000
    game_ops=0.378558
    path_alloc=0.021690
    path_reuse=0.012024

新增文件：

1) `.github/scripts/bench_store_gamestate.lua`
2) `.github/docs/store/01_store_schema_draft.md`

## 接口与依赖


关键依赖与接口：

1) `Components/Store.lua`
   - `Store:get(path: table): any`
   - `Store:set(path: table, value: any): void`

2) `Manager/GameManager/GameState.lua`
   - `_store_set(path: table, value: any): void`
   - 读写当前 Store 路径的核心入口。

3) `.github/docs/SecretOfEscaper/Manager/PlayerManager/Player.lua`
   - `schema`：作为“结构化定义”的参考样式，评估其对 Store 的适配性。

变更说明：完成基线脚本、schema 草案与对比结论，记录意外与决策，并补充可复现输出。
