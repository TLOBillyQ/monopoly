---
kind: report
status: generated
owner: quality
last_verified: 2026-05-08
---
# Behavior 回归中的 warn 与慢测判读

这份文档只回答两个问题：

1. `busted --run behavior` 打出来的哪些 `warn` 是预期内的测试噪音。
2. 哪些 `warn` / 慢测信号值得继续追。

> 基线日期：2026-05-08（Asia/Hong_Kong）。这里记录的是当前仓库已知、可解释的输出；如果 behavior lane 出现本文档没列到的新 warn，默认按“可疑”处理。

## 预期 warn 清单

| warn 片段 | 含义 | 真实日志点 | 代表性覆盖 | 默认处理 |
|----------|------|------------|------------|----------|
| `[MarketDebug] apply_navigation rejected: invalid owner_role_id` | 黑市翻页/切页收到无 owner 的 pending choice，导航被拒绝 | `src/rules/market/choice/session.lua` | `spec/behavior/presentation/presentation_ui_model_dispatch_spec.lua` 中 market navigation reject 路径 | 预期内；只有数量异常增多才追 |
| `[MarketDebug] apply_navigation rejected: player not found` | 黑市 pending choice 的 owner 找不到玩家实例，导航被拒绝 | `src/rules/market/choice/session.lua` | 同上，导航失败分支 | 预期内；负路径保护日志 |
| `[MarketDebug] apply_navigation rejected: build returned nil` | 黑市导航重建 choice 失败 | `src/rules/market/choice/session.lua` | 同上，apply/build fail 分支 | 预期内；用于确保失败时不偷偷落地脏状态 |
| `market paid purchase blocked:` | 付费购买网关返回失败 / 不可用，购买被拒绝 | `src/rules/market/purchase/core.lua` | `spec/behavior/gameplay/choices/purchase_spec.lua` 中 `gateway_down` 分支 | 预期内；这是付费失败语义的一部分 |
| `choice action missing actor_role_id:` | choice 动作缺少 actor，上下文不完整，被校验器拒绝 | `src/turn/actions/validator.lua` | `spec/behavior/gameplay/turn_flow/phase_transitions_spec.lua` 中 no-actor reject 路径 | 预期内；属于 actor 校验护栏 |
| `choice action blocked by actor check:` | 非 owner actor 试图提交 choice，被校验器拒绝 | `src/turn/actions/validator.lua` | `spec/behavior/presentation/presentation_ui_model_dispatch_spec.lua` 中 non-owner `choice_select` reject 路径 | 预期内；权限保护日志 |
| `auto runner produced no action for runtime pending choice` | 自动玩家遇到 pending choice，但 auto runner 当前没给出动作 | `src/turn/loop/init.lua` | `spec/behavior/gameplay/turn_flow/phase_transitions_spec.lua` 中 auto pending choice 空转路径 | 预期内；用于暴露自动决策空转，不等于测试失败 |
| `status3d missing remaining-text node:` | status3d 在测试中未注入 UIManager 时，剩余回合 ELabel 节点查不到，文本同步降级为不写入 | `src/ui/render/status3d/scene.lua` | `spec/behavior/presentation/_presentation_action_status_status3d_spec.lua` 大多数旧用例（不补 UIManager 桩）即触发 | 预期内；优雅降级日志，不影响可见性逻辑 |

## 哪些 warn 算可疑

出现下面任一情况，都不要把它当成“测试噪音”跳过：

- 本文档未列出的新 `warn`
- 已列出的 warn 在无关改动后明显增多
- 同一 warn 在大量 suite 中重复刷屏，而不是只出现在对应负路径测试里
- warn 文案还是旧的，但原因字段变了，例如 `market paid purchase blocked:` 后面的 `reason=` 出现新值
- behavior 通过了，但 warn 指向真实主路径，例如正常购买、正常翻页、正常 choice 提交时也打印 reject

## 慢测怎么读

`MONO_TEST_TIMING=1`（`tools/quality/shared/test_harness.lua`）与 busted handler（`spec/log_warns_handler.lua`）都用 `os.clock() * 1000` 取毫秒，计时源在 `case_times[].timer_source` 里固定为 `"os.clock"`。

behavior 套件是纯 Lua 计算、没有真实 sleep / I/O 等待，CPU 时间约等于墙钟时间，慢测信号可以直接当业务时间读。慢测阈值默认 500ms（`MONO_TEST_SLOW_MS` 可调），Windows 下 `clock()` 量化粒度约 16ms，对 500ms 阈值不构成干扰。

> 未来如果 spec 引入 `os.execute("ping ...")` / 真实 socket 等待，CPU 时间会少计入等待时间，慢测信号会偏低；届时再考虑加 `MONO_TEST_TIMING_PRECISE=1` 之类的 opt-in 墙钟开关，重新引入 `spec/support/wall_clock.lua` 的高精度路径。

## 建议的排查顺序

1. 先看 warn 是否在“预期 warn 清单”里。
2. 再看 warn 是否只出现在对应负路径 suite。
3. 慢测先和同套件其他 case 横向对比；只有同 case 明显高于同套件中位数才值得继续分析 case 本身。
4. 若出现新 warn，把文案、来源文件、首个触发 suite 一起补到这份文档，并同步 `docs/reports/behavior_warns_data.lua` 白名单。
