# 回合结算关键路径性能优化计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。  
本计划遵循仓库内 `.agents/PLANS.md` 的要求。

## 简要总结

本计划在不改变行为与输出的前提下，优化回合结算关键路径的分配与重复计算，主要通过路径表复用、租金连通缓存、日志构建降耗与随机抽样预计算来降低 GC 压力与热点 CPU 开销。实施后，回合落地与支付租金、破产清算等流程应保持同样结果，但运行更稳、更少卡顿。

## 目的 / 全局视角

目标是减少回合结算中高频分配与重复遍历导致的卡顿，同时保持所有规则与结果完全一致。成功的可见证据是：运行回归脚本 `lua .agents/tests/regression.lua` 仍全部通过，并且在连续结算（机会卡、多次落地）场景下无行为变化，日志与选择流程与变更前一致。

## 进度

- [x] (2026-02-04 12:00Z) 创建并写入本计划到 `.agents/PLAN_CURRENT.md`
- [x] (2026-02-04 12:00Z) 优化 Store 路径表分配与安全读取
- [x] (2026-02-04 12:00Z) 新增地块连通租金缓存与邻接表
- [x] (2026-02-04 12:00Z) 优化回合日志构建与背包扫描
- [x] (2026-02-04 12:00Z) 优化破产清算遍历与随机抽样
- [x] (2026-02-04 12:00Z) 调整 EffectPipeline 临时表分配策略
- [x] (2026-02-04 12:00Z) 增补租金缓存相关回归测试并运行全量回归

## 意外与发现

- 观察：尚无  
  证据：无

## 决策日志

- 决策：租金缓存使用 `game._land_rent_version` 统一失效，变更点为 `set_tile_owner`、`set_tile_level`、`reset_tile`  
  理由：租金只受所有者与等级影响，集中失效最稳妥  
  日期/作者：2026-02-04 / Codex

- 决策：`EffectPipeline` 只复用内部临时表，不复用 `choice_spec` 的 `options/body_lines`  
  理由：这些数组会被 UI 持有，复用会破坏数据  
  日期/作者：2026-02-04 / Codex

- 决策：土地邻接表按 `board.path` 遍历并对缺失邻接 `assert`  
  理由：保持与旧逻辑对缺失邻接的报错行为一致  
  日期/作者：2026-02-04 / Codex

## 结果与复盘

已完成路径表复用、租金连通缓存、日志构建降耗、机会卡抽样预计算与 EffectPipeline 表池复用；回归脚本通过，行为保持一致。主要风险在于机会卡权重若运行期动态变更，需要显式重建权重缓存；目前配置为静态，风险可接受。建议后续如出现卡顿仍可加入真实运行时 Profiling。

## 背景与导读

本仓库回合结算从 `src/game/turn/TurnManager.lua` 驱动，落地逻辑位于 `src/game/land/Landing.lua` 与 `src/game/land/Land.lua`，其中租金结算由 `src/game/land/LandActions.lua` 完成。状态存储通过 `src/core/Store.lua` 管理，地块状态在 `store.state.board.tiles` 内。破产清算在 `src/game/game/BankruptcyManager.lua` 中完成。回归测试入口为 `.agents/tests/regression.lua`。

## 接口变化概览（对外）

无对外公共 API 变更。新增的是内部缓存字段与局部优化逻辑，外部调用方式保持不变。

## 假设与默认

默认配置下 `chance_cfg` 权重静态不变；若未来改为运行期修改权重，需要显式触发重建权重缓存。  
默认不启用任何“跳过日志”的行为，日志输出与顺序必须保持一致。

## 工作计划

本次优化分为八块，逐步修改并保持行为一致。第一块是 Store 访问路径表复用和安全读取，减少 `store:get/set` 的临时表分配，涉及 `EffectPipeline`、`ItemInventory`、`TurnManager`、`LandActions` 与 `BankruptcyManager`。第二块是连通租金缓存，通过 `game._land_rent_version` 失效，并在 `LandActions._contiguous_rent` 使用土地邻接表进行 BFS，避免每次重建全图邻接。第三块是 `safe_tile_state` 去 `pcall`，使用 `store` 直接读取并做空值兜底，确保语义等价。第四块是回合日志构建降耗，避免无地产时的排序与 `pcall`，并减少不必要的全局查找。第五块是在 `Land.lua` 合并背包扫描，替代重复 `inventory.find_index`。第六块是破产清算时减少重复地块查找与使用 `store.state` 直读，保持扫描逻辑但降低开销。第七块是 `EffectPipeline` 临时表复用，避免递归不安全的共享数组。第八块是机会卡抽样权重预计算，减少每次落地的权重数组构建。

## 具体步骤

步骤一：将 `.agents/PLAN_CURRENT.md` 清空并写入本计划全文，确保后续实施符合项目流程。

步骤二：在 `src/game/land/LandActions.lua` 中修改 `safe_tile_state`，改为直接从 `game.store` 读取 `board.tiles[tile.id]`，并使用一个可复用的路径表 `{"board","tiles",nil}`，每次调用时设置第三位为 `tile.id`。若 `game`、`store` 或 `tile` 非 land 或 state 缺失，则返回 `{ owner_id = nil, level = 0 }`。同时新增 `_ensure_land_neighbors(board)`，构建并缓存 `board.land_neighbors`，仅包含 land-to-land 的邻接列表。

步骤三：在 `src/game/game/GameState.lua` 中为 `set_tile_owner`、`set_tile_level`、`reset_tile` 增加 `_land_rent_version` 自增逻辑，例如 `self._land_rent_version = (self._land_rent_version or 0) + 1`，并在 `CompositionRoot.assemble` 中初始化 `game._land_rent_version = 0` 与 `game._land_rent_cache = nil`。

步骤四：在 `src/game/land/LandActions.lua` 的 `_contiguous_rent` 增加缓存逻辑：  
先从 `game._land_rent_cache` 取缓存并比对 `game._land_rent_version`。若版本不一致则清空缓存。缓存结构建议为 `{ version = v, by_owner = { [owner_id] = { tile_sum = { [tile_id] = sum } } } }`。  
若起点 tile 已有缓存值则直接返回。否则使用 `board.land_neighbors` BFS，遍历同一 owner 的 land，计算总租金，并把总和写入该连通分量内每个 tile 的 `tile_sum`。保持与当前算法一致的计算顺序与逻辑，确保结果一致。

步骤五：在 `src/game/turn/TurnManager.lua` 的 `_build_turn_log_line` 中减少无用分配。先用 `next(player.properties)` 判断是否为空；为空则不构建地产列表。读地块等级时不再 `pcall(tile_state)`，改用 `store:get` 读取 `board.tiles[tile_id]` 并做空值兜底。将常用函数与表引用做局部绑定，例如 `local items = inventory.items(player)`、`local item_name = inventory.item_name`、`local tile_lookup = game.board.tile_lookup`，减少全局查找。

步骤六：在 `src/game/land/Land.lua` 的 `_apply_pay_rent` 中合并背包扫描。通过一次 `inventory.items(player)` 遍历同时找到强征卡与免租卡索引，保留原有优先级：若有强征卡且现金足够，先提示强征；否则如果有免租卡，再提示免租。

步骤七：在 `src/game/game/BankruptcyManager.lua` 中减少重复查表。使用 `local store_tiles = game.store and game.store.state and game.store.state.board and game.store.state.board.tiles` 直接读取。将 `owned_tile_ids` 转为 `owned_tiles`（tile 对象列表）以便日志与重置复用，避免两次 `get_tile_by_id`。仍保留对 `store_tiles` 的扫描以维持原有“兜底修复”语义。

步骤八：在 `src/game/effect/EffectPipeline.lua` 内部增加临时表池，复用 `mandatory` 与 `optional` 数组。必须保证递归安全，使用“取表/还表”的栈式池。注意不要复用 `choice_spec` 里的 `options/body_lines/effect_ids`，这些数组要长期保留。确保在每个 return 前归还临时表。

步骤九：在 `src/game/land/Landing.lua` 中为机会卡抽样预计算权重数组与总权重。新增局部函数 `_pick_chance_card()`，使用 `LuaAPI.rand()` 与预计算权重进行抽样，权重为负时当作 0，保持与 `Utils.choice_weight_list` 同等分布。若总权重为 0 或列表为空，仍回退到 `chance_cfg[1]` 的行为。

步骤十：在 `.agents/tests/regression.lua` 中增加或扩展租金相关测试，确保缓存失效正确。建议在 `_test_land_rent_contiguous_sum` 中追加一次“升级地块后再次支付租金”的断言，用以验证版本失效逻辑。然后运行回归脚本。

## 测试用例与场景

测试场景必须覆盖以下内容：  
回归脚本完整通过；支付租金前后结果一致；升级地块后租金变化被正确反映；机会卡仍能触发并且使用 `LuaAPI.rand()` 抽样。

## 验证与验收

在仓库根目录运行命令：

    lua .agents/tests/regression.lua

预期输出包含：

    All regression checks passed (N)

其中 N 为测试数量。  
此外建议手动运行一次“相邻两块地同一所有者”的租金支付，用同一局面重复支付两次，确保缓存命中后结果相同且升级后结果变化正确。

## 可重复性与恢复

所有改动为内部优化，不引入数据迁移。若出现行为异常，可逐项回退对应文件。建议每完成一块优化后运行一次回归，以缩小排错范围。

## 产物与备注

完成后在此附上关键 diff 片段（每段控制在 20 行以内），并说明对应优化点。示例占位：

    文件：src/game/land/LandActions.lua
    变更：新增 land_neighbors 与 _land_rent_cache 的使用
    片段：
      local tile_sum = _get_rent_cache(game, owner_id)
      local cached = tile_sum[start_tile.id]
      if cached then
        return cached
      end

    文件：src/game/land/Landing.lua
    变更：机会卡抽样预计算权重
    片段：
      local rand = LuaAPI.rand() * chance_total_weight
      local accumulated = 0
      for i, card in ipairs(chance_cfg) do
        accumulated = accumulated + (chance_weights[i] or 0)
        if accumulated >= rand then
          return card
        end
      end

    文件：src/game/effect/EffectPipeline.lua
    变更：复用 mandatory/optional 临时表
    片段：
      local mandatory = _acquire_list()
      local optional = _acquire_list()
      local function _finalize(result)
        _release_list(mandatory)
        _release_list(optional)
        return result
      end

## 接口与依赖

内部新增字段与结构如下，保持对外 API 不变：  
`game._land_rent_version` 为整数版本号，仅用于缓存失效。  
`game._land_rent_cache` 为租金缓存表，结构为 `{ version = number, by_owner = table }`。  
`board.land_neighbors` 为 land-to-land 邻接表，键为 tile_id，值为相邻 land tile_id 列表。  
无新增外部依赖。

计划变更说明：2026-02-04 清空旧计划并写入回合结算性能优化计划，原因是用户请求实施该优化。
计划变更说明：2026-02-04 更新进度、决策日志、结果与复盘及产物片段，原因是实现完成并通过回归。
