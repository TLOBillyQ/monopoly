---
kind: adr
status: stable
owner: specification
last_verified: 2026-05-23
---
# ADR 0010 — 谢礼皮肤按钮按 stub 现状钉为不可点

**Status**: Stable (2026-05-23, 锁定当前 host gift 集成 stub 现状)
**Trigger**: 完备性审计 `docs/product/design-source/蛋仔策划案--大富翁.docx` 与 `features/v102/skin_shop.feature` 发现冲突项 C1
**Related**: `src/app/host_integrations/gift.lua`, `src/ui/render/skin_panel.lua:41-49`, `features/v102/skin_shop.feature`（"未解锁的赠礼类槽位按钮显示赠礼名并不可点" 场景）

---

## 上下文（Why）

策划案第 322-340 行明确描述谢礼皮肤的产品行为：

> 未获得的谢礼皮肤操作按钮为（谢礼），点击后**跳转到赞助弹窗**。

但当前 `src/app/host_integrations/gift.lua` 是一个 stub：

```lua
local gift = {
  host_pending = true,         -- 显式宣告未接入
  skin_product_id = 5005,
  threshold = 100,
}

-- TODO_HOST_INTEGRATION: connect host gift counter and unlock callback.
function gift.is_unlocked()
  return false                 -- 永远 false
end
```

宿主侧 gift counter / 解锁回调 / 赞助弹窗触发 — 全部未接入。`gift.lua` 的注释 `TODO_HOST_INTEGRATION` 是明示信号。

`render/skin_panel.lua` 因此对 `unlock == "gift"` 的 locked 槽位渲染 `touch_enabled = is_purchase = false`，即不可点。Spec `skin_shop.feature` 现有场景"未解锁的赠礼类槽位按钮显示赠礼名并不可点"如实反映此 stub 现状。

**冲突本质**：策划案描述的是终态产品行为，spec 描述的是当前实现真实行为。两者都是有效契约，但服务于不同时间窗口。

---

## 决策（What）

### D1 — Spec 锁定 stub 现状："谢礼按钮不可点"

`features/v102/skin_shop.feature` 中以下场景保持当前断言不变：

- "未解锁的赠礼类槽位按钮显示赠礼名并不可点"（断言 `按钮不可点` + `按钮文本为"<赠礼名>"`）
- "购买类槽位显示价格图标，赠礼类槽位隐藏价格图标"（赠礼槽位价格图标隐藏）
- "赠礼解锁但保留价格的槽位价格图标仍隐藏"
- 其它 `unlock = "gift"` 路径相关场景

具体来说，spec **不**断言：

- 谢礼按钮点击触发任何外部回调
- 谢礼按钮点击跳转赞助弹窗
- 谢礼皮肤的解锁源自宿主 gift counter

### D2 — 不动 src 现实现

`src/app/host_integrations/gift.lua` 和 `src/ui/render/skin_panel.lua:41-49`（`_button_text_for_locked` 中 `unlock == "gift"` 分支与 `_button_props` 中 `locked → touch_enabled = is_purchase` 计算）保持原状。

### D3 — Mutation 闭合视为现状契约

`render/skin_panel.lua` 的 `_button_props` chunk 已 17/17 mutation killed（manifest 显示 `lastMutationStatus=passed`）。`unlock == "gift"` 分支的 touch_enabled = false 行为是 mutation 锁定的契约，不是偶然实现。

---

## 解除条件（Rescind）

本 ADR 在下列任一条件满足时解除：

1. `host_integrations/gift.lua` 中 `host_pending` 字段移除且 `is_unlocked` 接入真实宿主回调
2. 宿主侧赞助/打赏系统提供可调用接口（`enqueue_sponsor_panel` 或类似），且产品确认该接口路径稳定
3. 用户明确通知"奶龙/水豚嘟嘟谢礼皮肤需要立即可购买"且接受新一轮策划-implementation-spec 同步

解除时需要同步动作：

- 修改 spec：把"赠礼类按钮不可点"改为"点击触发赞助回调"（保留赠礼名文本断言）
- 修改 `render/skin_panel.lua:_button_props` 的 `locked` 分支：`gift` 类应返回 `true`（可点）
- 修改 `coord/skin_panel.lua` 路由：`buy` action 对 `unlock == "gift"` 的槽位走赞助回调而非购买回调
- 此 ADR Status 改为 `Superseded by ADR XXXX`

---

## 拒绝的备选（Alternatives）

### A1 — 按设计回正，引入占位赞助回调

写一个 `_sponsor_callback` 占位函数（同 `purchase_callback` pattern），spec 断言其被调用。

**拒绝原因**：无真实宿主接口形状的情况下，回调签名是凭空猜测；接入真宿主时回调签名 100% 会变；spec 现在锁定的契约会反向阻止正确接入。"按当下能锚定的事实定 spec"优于"按假想终态定 spec"。

### A2 — Spec 留白（既不断言可点也不断言不可点）

**拒绝原因**：mutation 攻击会让"locked → touch_enabled" 行为漂移；`_button_props` 的 17/17 mutation kills 依赖现有 spec 断言；留白等于让 mutation harness 失去保护。

---

## 影响（Impact）

- **正向**：spec 与 src 实现完全一致，acceptance pipeline green；mutation 保持 100% kill rate
- **代价**：策划案中"谢礼按钮跳赞助弹窗"产品行为推迟到宿主接入；本 ADR 必须在解除条件触发时显式回滚
- **检测信号**：若有人在 `host_integrations/gift.lua` 中改 `host_pending` 或 `is_unlocked` 但未触发此 ADR 解除流程，那是问题信号，需要回到本 ADR 重新评估
