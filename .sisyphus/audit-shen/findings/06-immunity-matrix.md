# T6 — Immunity Matrix（天使免疫矩阵）静态审计结论

参照产物：`./.sisyphus/audit-shen/artifacts/immunity-matrix.md`

## 1) 结论摘要

- 矩阵总行数（数据行）= **32**：
  - item（`items.lua` 含 `angel_immune` 字段）= 19 行
  - chance（`chance_cards.lua` 含 `negative=true`）= 13 行
- 按矩阵分类统计：
  - **PROTECTED：16**（item 3 + chance 13）
  - **UNPROTECTED：3**（`roadblock`/`share_wealth`/`exile`）
  - **N/A：13**（item 中 `angel_immune=false`）
  - **DEAD-CONFIG：0（按矩阵行分类）**
- 配置字段层面的事实：`angel_immune` 在 `src/config/content/items.lua` 中被声明，但在运行时代码中未被读取（见 §3）；当前免疫行为来自硬编码分支，而非读取 `angel_immune`。

## 2) 运行时 angel 检查点（file:line）

以下为 `src/` 内实际出现的 angel 判断及其作用：

1. `src/rules/effects/mine.lua:88`
   - `if game:player_has_angel(player) then`
   - 作用：地雷触发时直接免疫（地雷无效）。

2. `src/rules/items/steal.lua:92`
   - `if not t.eliminated and not game:player_has_deity(t, "angel") then`
   - 作用：偷窃卡选目标时排除有天使的目标。

3. `src/rules/items/post_effects.lua:110`
   - `if game:player_has_deity(target, "angel") then`
   - 作用：查税卡对有天使目标无效。

4. `src/rules/chance/resolver.lua:8`
   - `if card.negative and game:player_has_angel(player) then`
   - 作用：负面机会卡整体短路，不进入后续 handler。

5. 非直接“敌对效果防护”的 angel 查询点（记录性）
   - `src/player/actions/state_ops/deity_ops.lua:14-15`：`player_has_angel` 仅封装到 `player_has_deity(player, "angel")`
   - `src/computer/agent/action.lua:55`：AI 选神相关目标时优先识别 angel 玩家

## 3) `angel_immune` 配置读取状态

- `angel_immune` 在配置中出现：`src/config/content/items.lua:2-20`（共 19 个 item 声明该字段）。
- 在 `src/` 运行时代码的检索结果：仅命中配置文件本身，不存在读取 `item.angel_immune` 的逻辑分支。
- 因此：item 的免疫效果并非由 `angel_immune` 驱动，而是由 §2 的硬编码检查点驱动。

## 4) 宽 grep 复核结果（spec/、tools/、assets/、scripts/）

- `spec/`：0 hits
- `tools/`：2 hits（`tools/data/export_xlsx.lua:427,437`）
  - 这两处为配置导出脚本对 `angel_immune` 字段的写出/字段序列定义，不是运行时判定读取。
- `assets/`：0 hits
- `scripts/`：0 hits

## 5) 矩阵解释（仅陈述现状）

- 所有 `negative=true` 机会卡均被 `src/rules/chance/resolver.lua:8` 统一覆盖，矩阵中对应 13 行均为 PROTECTED。
- `angel_immune=true` 的 item 中，只有与硬编码检查对应的 3 项（mine/steal/tax）表现为 PROTECTED。
- 其余 `angel_immune=true` 且无运行时 angel 检查的 3 项（roadblock/share_wealth/exile）在矩阵中为 UNPROTECTED。
- `DEAD-CONFIG` 关键字对应的事实体现在“字段层面”（`angel_immune` 声明存在、运行时无读取）；矩阵行分类中未单列 DEAD-CONFIG 行。

---

## 未审查清单

以下相关代码本次未覆盖：

- `src/rules/items/roadblock.lua`、`src/rules/items/share_wealth.lua`、`src/rules/items/exile.lua` 的完整实现（仅确认无 angel 检查，未审计其他逻辑）
- 是否存在通过 item effect chain 间接触发 angel 检查的路径
- `tools/data/export_xlsx.lua:427,437` 的 `angel_immune` 导出用途（配置导出，不影响运行时，仅记录）
- cheat / debug 入口是否有绕过 item 免疫的路径
- 测试 fixture 中 angel 免疫相关 stub 是否与真实行为一致
