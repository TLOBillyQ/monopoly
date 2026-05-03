---
kind: report
status: generated
owner: quality
last_verified: 2026-05-04
---
# `src/rules/` 子目录健康度扫描（P2-1）

**日期**：2026-05-03
**Driver**：`plans/src-soft-taco.md` P2-1
**前置**：P0-2 ADR-0002 已落地、P1-1 `choice_handlers/item.lua` 已拆分

---

## 数据快照

### LOC + 文件数 + 跨目录引用

| 子目录 | 文件数 | LOC | 外部引入文件数（src/ 全量，去自身） | 仅来自 rules/ 内部的引入文件数 |
|---|---|---|---|---|
| board | 7 | 900 | 16 | 13 |
| bootstrap | 2 | 158 | 1 | 0 |
| chance | 6 | 515 | 2 | 2 |
| choice | 5 | 404 | 8 | 4 |
| choice_handlers | 11 | 794 | 1 | 1 |
| commerce | 3 | 96 | 5 | 4 |
| effects | 5 | 467 | 5 | 4 |
| endgame | 2 | 260 | 3 | 0 |
| items | 16 | 2632 | 27 | 20 |
| land | 15 | 1084 | 5 | 3 |
| market | 16 | 996 | 7 | 2 |
| ports | 7 | 168 | 47 | 35 |

### effects / items / commerce 互引矩阵

| from \ to | effects | items | commerce |
|---|---|---|---|
| effects | — | 0 | 0 |
| items | 0 | — | 2 |
| commerce | 0 | 0 | — |

总互引计数：**2 处**（items → commerce）。远低于 plan 规则的 5 处阈值。

---

## 判定（按 plan 规则）

| 规则 | 触发情况 |
|---|---|
| LOC < 200 且外部引入 < 3 → 候选并入 | **bootstrap (LOC=158, 外部=1)** ← 唯一命中 |
| effects/items/commerce 互引 ≥ 5 → 边界候选重画 | 未触发（共 2 处） |
| 数据"健康" → 维持现状 | 余下 11 个子目录全部健康 |

### bootstrap 的处置（明确不合并）

`rules/bootstrap` 唯一外部消费方是 `src/app/`。它是 **app→rules 的明确入口 seam**——把它合并进 `rules/init.lua` 或扁平到其他子目录，会模糊"应用启动 vs 业务规则"的边界。

> 这与 ADR-0001 §D7 保留 host_bridge / infrastructure_runtime_bridges 的处置同型：**有意保留的 seam，不因 LOC 触发整理**。

**结论**：维持 `rules/bootstrap/` 现状。

### 其他子目录评估

- **items (LOC=2632, 外部=27)** 是最大且最被依赖的子目录。其规模反映了道具系统的真实复杂度，不是"agglomerate hub"。无明显聚集或孤岛，维持现状。
- **ports (LOC=168, 外部=47)** 高扇入但 LOC 小，是典型 port surface 模式（接口集合而非实现）。维持现状。
- **board (LOC=900, 外部=16)** 是 board 状态操作的合理聚合。维持现状。
- **commerce (LOC=96, 外部=5)** LOC 小但扇入≥3，是有意保持的小而专注模块。维持现状。
- **choice_handlers (LOC=794, 外部=1)** 外部消费方只有 `choice_handler_factory.lua`，这正是 P1-1 拆分后的 dispatcher 模式入口。该子目录在 P1-1 后已扁平化为 `choice_handlers/{item,land,market}/` 三族 + factory。维持现状。

---

## 后续动作

**无结构性动作建议**。当前 12 个子目录边界清晰，跨目录耦合在阈值之内。

下次扫描建议触发条件（任一）：
1. `items/` LOC 突破 3000（当前 2632，~12% headroom）
2. `effects ↔ items ↔ commerce` 累计互引达 5 处
3. 新增子目录（rules/ 总数从 12 → 13）
4. 单文件 LOC 排名榜（`tools/quality/loc.lua`）出现 rules/ 内 > 600 LOC 的新条目

---

## 工具与命令复现

```bash
# 子目录 LOC + 文件数
for dir in src/rules/*/; do
  name=$(basename "$dir")
  files=$(find "$dir" -name "*.lua" -type f | wc -l)
  loc=$(find "$dir" -name "*.lua" -type f -exec cat {} \; | wc -l)
  printf "%-20s files=%-4s loc=%s\n" "$name" "$files" "$loc"
done

# 跨目录外部引入
for dir in src/rules/*/; do
  subdir=$(basename "$dir")
  ext=$(grep -rl --include='*.lua' -E "require[ (]*['\"]src\\.rules\\.$subdir([.\"'])" src/ \
    | grep -v "^src/rules/$subdir/" | wc -l)
  printf "%-20s external_in=%s\n" "$subdir" "$ext"
done
```

`crap.lua` / `scrap4lua` 受 worktree vendor 子模块未拉取限制本次未跑；如需在主仓跑：

```bash
cd /Users/billyq/Dev/Github/Lua/monopoly
lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json
lua tools/quality/scrap.lua find rules.commerce --out tmp/scrap_commerce.json
```
