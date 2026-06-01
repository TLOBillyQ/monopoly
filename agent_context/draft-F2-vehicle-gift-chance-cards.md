# 草稿（作废）— F2：机会表 6 张「更换座驾」卡

**状态：CANCELLED (2026-05-30) — 用户裁定整体拆除座驾功能，F2 不实现。本草稿作废，仅留档。详见 [[vehicle-teardown-context]] 与 docs/decisions/0011 修订段。**

---
原 PENDING 草稿内容（已不再适用）：

批准后处理：把下列增量并入 `features/game/chance.feature`（目录场景加 6 行 + 新增更换座驾行为场景），
按 specifier 四阶段走，commit 到 main，handoff 名 `chance-vehicle-gift`，notify coder。
manifest 头由 mutator 重新生成（不手写）。座驾资源 id 4001-4006 已在 `runtime_refs`，
座驾等级见座驾表（4001-4003=lvl1，4004-4006=lvl2）。

---

## 增量 1 — 扩充「策划案机会卡目录完整」Examples（+6 行）

```
  | 3014 | change_vehicle            | self | 4001 | false |
  | 3015 | change_vehicle            | self | 4002 | false |
  | 3016 | change_vehicle            | self | 4003 | false |
  | 3035 | change_vehicle            | self | 4004 | false |
  | 3036 | change_vehicle            | self | 4005 | false |
  | 3037 | change_vehicle            | self | 4006 | false |
```

（效果键 `change_vehicle` 为建议名，coder 可定最终键；权重 3014-3016=200 / 3035-3037=100，
权重不在目录场景断言列内，与现有卡一致。）

## 增量 2 — 新增更换座驾行为场景

```
场景大纲: 更换座驾卡按座驾等级决定是否替换
  假如 玩家当前座驾为<当前座驾>
  并且 玩家抽到更换座驾卡赠予<赠予座驾>
  当 机会卡效果结算
  那么 玩家座驾为<结果座驾>

例子:
  | 当前座驾 | 赠予座驾 | 结果座驾 |
  | 无       | 滑板     | 滑板     |
  | 滑板     | 路虎     | 路虎     |
  | 路虎     | 滑板     | 路虎     |
  | 路虎     | 法拉利   | 法拉利   |
```

规则（策划案机会表 3035 备注）：无座驾→直接装备赠予座驾；已有座驾且**赠予等级 ≥ 当前等级**
→ 顶掉换为赠予；**赠予等级 < 当前等级**→保留当前、不更换。
（滑板 lvl1 < 路虎 lvl2；法拉利 lvl2 = 路虎 lvl2 → 等级相等时按"否则顶掉"替换。备注原文：
"若已有座驾等级**大于**更换的座驾，则不执行更换，否则顶掉原座驾"——故等级相等仍替换。）

边界：负面标记 false（赠予类正面）；目标 self；本卡无天使免疫问题（作用于自身）。

## 风险/确认点

- 等级相等时是否替换：按备注字面"大于才不换"→相等替换（已体现于"路虎+法拉利→法拉利"行）。若策划另有意图需用户确认。
- `change_vehicle` 效果需 coder 在 `src/rules/chance/handlers.lua` 新增 handler + 座驾装备/等级查询（座驾系统已存在）。
