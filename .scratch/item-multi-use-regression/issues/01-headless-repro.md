# 01 无头复现：钉住「用完道具后回合直接推进」的失败用例

Type: task
Status: resolved

## Question

在无头测试套件（`spec/support/scenario_suites/turn_flow/`、`spec/behavior/rules/item_spec.lua` 一带）构造最小复现：玩家在可选行动窗口使用一张**非掷骰类**道具（如路障/地雷/偷窃卡）后，断言窗口应重新开放、可继续使用另一张不同组的合法道具——预期该用例在当前 main 上**失败**，从而把症状钉成可执行的回归测试。

要点：
- 至少覆盖两类组合：非掷骰道具 → 再用另一张非掷骰道具；确认遥控骰子推进不误报。
- 用例先以失败形态存在（pending/标记均可），它就是后续修复的红灯。
- 若套件表达不了「窗口重新开放」这一断言，或无头环境根本复现不了，把卡点写进 Answer——这会触发地图上「实机复现矩阵」从雾里毕业。
- 产出：失败用例的分支/diff 链接 + 实际观察到的推进路径（哪个 phase/handler 把回合推走了）。

## Answer

无头复现**成功**，红灯已钉住——但不在票面猜的位置。用例文件：`spec/behavior/turn/item_window_multi_use_spec.lua`（未提交，工作区内），4 条用例：

1. **绿 pin ×3**（回归保护，随修复一起提交）：
   - 真实回合机 pre_action 窗口，连用两张立即道具（地雷→天使）正常重开；
   - 真实回合机 pre_action 窗口，followup 道具（路障→选格子）完成后正常重开；
   - 合成 wait_choice 子链（dispatch→resolve→reopen）正常。
2. **红灯 ×1**（`pending` 形态保 CI 绿，修复时换回 `it`）：**post_action 窗口 + followup 道具（路障）完成后窗口不重开、回合直接推进**——`flow.resumed == true` 处红，与 02 指认的 `src/rules/choice_handlers/item_completions.lua:36-38` `phase=="post_action"` 早退分支吻合。

推进路径观察：followup 完成走 `_resolve_followup_completion → _resolve_phase_completion`，命中 `meta.phase == "post_action"` 早退 `finish_choice`，跳过 `reopen_or_finish`；回合随 resume_next_state 推进。pre_action 分支则走 `_resume_pre_action_phase` 正常重开。

附注：票面假设「掷骰前窗口坏」未成立（三条链全绿，与 02 端到端结论互证）；实测症状最可能发生在**行动后**窗口使用目标类道具时。用户目击是否即此缺陷，留给 03 与人确认。验证：单文件 3 ok（1 pending），`verify --smoke` 6/6 PASS（曾在并行 worker 暴露状态污染，已按仓库惯例加 `config_reset.reset_all()`）。
