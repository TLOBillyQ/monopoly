# 神仙状态卡综合审计报告

## 1. 执行摘要

主路径上，财神、穷神、天使的 apply 写入、5 own turns 生命周期、租金读取、机会卡 cash 类翻倍均为 WORKING。`set_player_deity` / `clear_player_deity` 是运行时写入收敛点，`tick_player_deity` 只在当前玩家回合末递减，富/穷神对租金和机会卡金币流的影响会进入最终扣款或入账。

BROKEN 集中在天使免疫配置和转移语义。`angel_immune=true` 的 item 中，`roadblock` / `share_wealth` / `exile` 没有运行时天使检查；item 维度 3/6 未保护，且 `angel_immune` 字段本身未被运行时代码读取。`invite_deity` 可从空 deity 占位目标转入 `"" / 0`，send→invite 链式场景会覆盖已有穷神；`send_poor` 正常入口会挡住非穷神，但 leaf apply 直调缺少同等契约。

SUSPICIOUS 主要是规格与一致性风险：破产/出局链路未清 deity，扣留/出局回合是否消耗剩余次数需要确认；机会卡 3017/3018 可能损毁自有资产但 `negative=false`，天使不会阻挡；`pay_others` / `collect_from_others` 的翻倍逻辑游离于统一入口；`poor` apply 依赖隐式 duration 回退，内容文案中的 `5回合` 与 `deity_duration_turns = 5` 并列存在。

## 2. 分类表

| 分类 | Apply | Lifecycle | Clear | Rent | Chance | Immunity | Transfer | Consistency |
|---|---|---|---|---|---|---|---|---|
| 财神 | WORKING ✅ | N/A | N/A | WORKING ✅ | WORKING ✅ | N/A | N/A | N/A |
| 穷神 | WORKING ✅ | N/A | N/A | WORKING ✅ | WORKING ✅ | N/A | N/A | N/A |
| 天使 | WORKING ✅ | N/A | N/A | N/A | SUSPICIOUS ⚠️ | BROKEN ❌ | N/A | N/A |
| 送神 | WORKING ✅ | N/A | SUSPICIOUS ⚠️ | N/A | N/A | N/A | BROKEN ❌ | N/A |
| 请神 | SUSPICIOUS ⚠️ | N/A | SUSPICIOUS ⚠️ | N/A | N/A | N/A | BROKEN ❌ | N/A |
| 生命周期 | N/A | WORKING ✅ | WORKING ✅ | N/A | N/A | N/A | N/A | N/A |
| 全局 | SUSPICIOUS ⚠️ | NEEDS-SPEC | SUSPICIOUS ⚠️ | N/A | SUSPICIOUS ⚠️ | DEAD-CONFIG | SUSPICIOUS ⚠️ | SUSPICIOUS ⚠️ |

## 3. 修复 Backlog

1. severity: P0  
   summary: `angel_immune=true` 的 `roadblock` / `share_wealth` / `exile` 没有运行时天使检查，item 维度 3/6 未保护。  
   evidence: [findings/06-immunity-matrix.md](findings/06-immunity-matrix.md), [artifacts/immunity-matrix.md](artifacts/immunity-matrix.md)  
   proposed approach: 统一 item 免疫判定来源，使配置声明与运行时检查一致。

2. severity: P0  
   summary: `invite_deity` 可从空 deity 占位目标转入 `"" / 0`，send→invite 链式场景会覆盖已有穷神。  
   evidence: [findings/07-transfer-semantics.md](findings/07-transfer-semantics.md), [findings/01-apply-sites.md](findings/01-apply-sites.md)  
   proposed approach: 用有效神仙判定约束转移源，并让链式转移保持有效状态语义。

3. severity: P1  
   summary: `send_poor.apply` 直调时缺少穷神类型和剩余次数契约，rich / angel / expired poor 可被按穷神送出。  
   evidence: [findings/07-transfer-semantics.md](findings/07-transfer-semantics.md)  
   proposed approach: 让 leaf apply 与正常道具入口使用同等源状态约束。

4. severity: P1  
   summary: 送神和请神的转移过程缺乏原子性，直调 apply 层还允许 user == target。  
   evidence: [findings/07-transfer-semantics.md](findings/07-transfer-semantics.md), [findings/03-clear-sites.md](findings/03-clear-sites.md)  
   proposed approach: 明确转移前置校验、source / target 顺序和失败语义。

5. severity: P1  
   summary: 破产/出局链路未清 deity，残留状态可能继续参与部分目标选择或展示。  
   evidence: [findings/03-clear-sites.md](findings/03-clear-sites.md), [findings/02-lifecycle.md](findings/02-lifecycle.md)  
   proposed approach: 明确出局后神仙状态语义，并与清算和回合推进保持一致。

6. severity: P1  
   summary: 机会卡 3017/3018 可能损毁自有资产但 `negative=false`，天使不会阻挡。  
   evidence: [findings/05-chance-read.md](findings/05-chance-read.md)  
   proposed approach: 确认 path-asset 效果的负面判定口径，并对齐 `negative` 元数据。

7. severity: P2  
   summary: `pay_others` / `collect_from_others` 手写 deity 翻倍逻辑，未复用统一 chance delta 入口。  
   evidence: [findings/05-chance-read.md](findings/05-chance-read.md)  
   proposed approach: 统一金币 delta 调整口径，或显式记录二者的独立语义。

8. severity: P2  
   summary: `poor` apply 依赖隐式 duration 回退，内容文案 `5回合` 与逻辑常量并列维护。  
   evidence: [findings/01-apply-sites.md](findings/01-apply-sites.md), [findings/08-string-const-consistency.md](findings/08-string-const-consistency.md)  
   proposed approach: 让 duration 来源更显式，并减少持续时间的双源维护。

9. severity: P2  
   summary: 被扣留和已出局回合是否计入 own turn 消耗仍需规格确认。  
   evidence: [findings/02-lifecycle.md](findings/02-lifecycle.md)  
   proposed approach: 明确该两类回合的计数语义，再决定生命周期处理口径。

## 4. 范围声明

本报告仅作审计，不含修复实现；未审 save/load；未审非神仙状态卡；未审 UI 渲染层。

## 5. 附录

- [findings/01-apply-sites.md](findings/01-apply-sites.md)
- [findings/02-lifecycle.md](findings/02-lifecycle.md)
- [findings/03-clear-sites.md](findings/03-clear-sites.md)
- [findings/04-rent-read.md](findings/04-rent-read.md)
- [findings/05-chance-read.md](findings/05-chance-read.md)
- [findings/06-immunity-matrix.md](findings/06-immunity-matrix.md)
- [findings/07-transfer-semantics.md](findings/07-transfer-semantics.md)
- [findings/08-string-const-consistency.md](findings/08-string-const-consistency.md)
- [artifacts/immunity-matrix.md](artifacts/immunity-matrix.md)
