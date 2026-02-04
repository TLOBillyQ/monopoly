# 使用 GameAPI.random_int 替换游戏 RNG


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角


把游戏内自实现 RNG 改为统一调用 `GameAPI.random_int`，移除 `game.store.state.rng` 字段，并在回归脚本中补充 `GameAPI.random_int` 的本地模拟以保持可跑与稳定。验收方式是运行 `lua .agents/tests/regression.lua`，脚本输出通过且不报错。

## 进度


- [x] (2026-02-04 11:41Z) 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-04 11:41Z) 修改 `src/game/game/CompositionRoot.lua` 使用 `GameAPI.random_int` 并移除 `rng` 快照
- [x] (2026-02-04 11:41Z) 在 `.agents/tests/regression.lua` 增加 `GameAPI.random_int` 本地模拟
- [x] (2026-02-04 11:41Z) 运行 `lua .agents/tests/regression.lua` 并确认通过

## 意外与发现


暂无。

## 决策日志


决策：游戏 RNG 仅使用 `GameAPI.random_int`，不再维护本地状态。理由：符合引擎随机一致性要求，并避免自实现带来的行为偏差。日期/作者：2026-02-04 / Codex。

决策：本地回归脚本补充 `GameAPI.random_int` 模拟并固定随机种子。理由：保证脚本在无引擎环境下可稳定运行。日期/作者：2026-02-04 / Codex。

## 结果与复盘


已完成代码修改并通过回归脚本验证，确认 `GameAPI.random_int` 缺失不会导致回归失败。

## 背景与导读


`src/game/game/CompositionRoot.lua` 负责组装 `game` 并创建 RNG，`src/game/turn/TurnRoll.lua` 通过 `game.rng:next_int` 投骰子，`.agents/tests/regression.lua` 是本地回归入口。此次调整只影响 RNG 生成方式和初始状态字段。

## 工作计划


先改 `src/game/game/CompositionRoot.lua`，移除 LCG 自实现并把 `rng:next_int` 直接转为 `GameAPI.random_int`，同时删除 `rng` 快照写入。然后在 `.agents/tests/regression.lua` 增加 `GameAPI.random_int` 的本地模拟，最后运行回归脚本验证。

## 具体步骤


在仓库根目录依次完成代码修改后执行 `lua .agents/tests/regression.lua`，检查终端输出确认通过。

## 验证与验收


运行 `lua .agents/tests/regression.lua`，预期输出 `All regression checks passed (N)`，且无 `GameAPI.random_int` 缺失报错。

## 可重复性与恢复


本变更为纯代码调整，可重复执行。若需回退，恢复 `CompositionRoot.lua` 的 RNG 实现并移除回归脚本中的 `GameAPI.random_int` 模拟即可。

## 产物与备注


    文件：src/game/game/CompositionRoot.lua
    片段：
      function rng:next_int(min, max)
        assert(min ~= nil and max ~= nil, "rng.NextInt requires min/max")
        assert(GameAPI and GameAPI.random_int, "missing GameAPI.random_int")
        return GameAPI.random_int(min, max)
      end

    回归输出：
      All regression checks passed (36)

## 接口与依赖


依赖引擎提供 `GameAPI.random_int(min, max)`，其余接口不变。

计划变更说明：2026-02-04 将 `.agents/PLAN_CURRENT.md` 替换为 RNG 改造计划以匹配当前任务。
计划变更说明：2026-02-04 更新进度并记录回归脚本通过结果。
