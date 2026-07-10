# 02 代码流诊断：谁把可选行动窗口关死了

Type: research
Status: resolved

## Question

沿 `src/rules/items/use_flow*.lua` → `src/turn/optional_action_completion.lua` / `optional_action_choice.lua` → `src/turn/loop/`、`src/turn/choice/` 追踪「道具使用完成后」的控制流，回答：用完一张非掷骰道具后，流程在哪一步没有回到可选行动窗口、而是直接推进？该行为是哪次重构引入的（重点嫌疑：choice_contract 归一、候选⑤ owner 深模块委托 + 去 double-decide、secondary_confirm 收进 Screen）？

要点：
- 用 /diagnosing-bugs 的纪律推进；无已知好版本，代码流分析优先，必要时对嫌疑 commit 做定向历史 diff（`git log -p` 相关文件）辅证。
- 明确区分：窗口重开逻辑**被删**、条件判断**被改错**、还是 choice 归一后**丢了 re-offer 分支**。
- 顺带记录同根因波及的其它选择流程（建房/拆迁等），只登记不展开（见地图 Out of scope）。
- 产出：诊断报告 markdown（根因 + 引入点 + 受影响面），链接到本票。

## Answer

**未复现 / 行为正常（就票面描述的掷骰前窗口而言）。** 端到端走真实协程回合引擎的复现显示：**pre_action（掷骰前）可选行动窗口对所有非掷骰道具（立即自效果 mine、板面目标 roadblock、玩家目标 exile、以及 remote_dice）用完后都正确重开，回合不推进**——不存在「用完一张即推进」。`stay` 传播链（`_handle_item_phase_passive`/`_resolve_phase_completion` → `reopen_or_finish` → `{stay=true}` → `choice_resolver` → `turn_decision.resolve_choice` → `await._finish_choice_wait` 再 park）在 HEAD 完整，嫌疑重构（choice_contract 归一 / 候选⑤去 double-decide / secondary_confirm）**未破坏它**。

唯一实锤的「用完不重开」缺陷在 **post_action（行动后）窗口 + followup/target 道具**：`src/rules/choice_handlers/item_completions.lua:36-38` 的 `if meta.phase == "post_action" then finish` 早退分支，使目标类道具在行动后窗口单回合只能用一张（立即道具则正常重开）。该分支为**历史遗留**（`995c2fe4` 拆分前即在，`30869772` reset 基线已有），与嫌疑 commit 无关。若报告人实际是在行动后打目标卡，这最可能是被误记为「掷骰前」的真实现象——留给复现票定向验证。

详见报告：[assets/02-root-cause-report.md](../assets/02-root-cause-report.md)。
