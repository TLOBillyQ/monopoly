# Behavior 回归中的 warn 与慢测判读

这份文档只回答两个问题：

1. `lua tests/behavior.lua` 打出来的哪些 `warn` 是预期内的测试噪音。
2. 哪些 `warn` / 慢测信号值得继续追。

> 基线日期：2026-03-21（Asia/Hong_Kong）。这里记录的是当前仓库已知、可解释的输出；如果 behavior lane 出现本文档没列到的新 warn，默认按“可疑”处理。

## 预期 warn 清单

| warn 片段 | 含义 | 真实日志点 | 代表性覆盖 | 默认处理 |
|----------|------|------------|------------|----------|
| `[MarketDebug] apply_navigation rejected: invalid owner_role_id` | 黑市翻页/切页收到无 owner 的 pending choice，导航被拒绝 | `src/rules/market/choice/session.lua` | `tests/suites/presentation/presentation_ui_model_dispatch.lua` 中 market navigation reject 路径 | 预期内；只有数量异常增多才追 |
| `[MarketDebug] apply_navigation rejected: player not found` | 黑市 pending choice 的 owner 找不到玩家实例，导航被拒绝 | `src/rules/market/choice/session.lua` | 同上，导航失败分支 | 预期内；负路径保护日志 |
| `[MarketDebug] apply_navigation rejected: build returned nil` | 黑市导航重建 choice 失败 | `src/rules/market/choice/session.lua` | 同上，apply/build fail 分支 | 预期内；用于确保失败时不偷偷落地脏状态 |
| `market paid purchase blocked:` | 付费购买网关返回失败 / 不可用，购买被拒绝 | `src/rules/market/purchase/core.lua` | `tests/suites/gameplay/gameplay_t4_characterization.lua` 中 `gateway_down` / `payment_gateway_error` 分支 | 预期内；这是付费失败语义的一部分 |
| `choice action missing actor_role_id:` | choice 动作缺少 actor，上下文不完整，被校验器拒绝 | `src/turn/actions/validator.lua` | `tests/suites/gameplay/gameplay_cases.lua` 中 `_test_validate_choice_actor_no_actor_id` | 预期内；属于 actor 校验护栏 |
| `choice action blocked by actor check:` | 非 owner actor 试图提交 choice，被校验器拒绝 | `src/turn/actions/validator.lua` | `tests/suites/presentation/presentation_ui_model_dispatch.lua` 中 non-owner `choice_select` reject 路径 | 预期内；权限保护日志 |
| `auto runner produced no action for runtime pending choice` | 自动玩家遇到 pending choice，但 auto runner 当前没给出动作 | `src/turn/loop/init.lua` | `tests/suites/gameplay/gameplay_cases.lua` 中 `_test_log_missing_auto_choice_action_logs_once` | 预期内；用于暴露自动决策空转，不等于测试失败 |

## 哪些 warn 算可疑

出现下面任一情况，都不要把它当成“测试噪音”跳过：

- 本文档未列出的新 `warn`
- 已列出的 warn 在无关改动后明显增多
- 同一 warn 在大量 suite 中重复刷屏，而不是只出现在对应负路径测试里
- warn 文案还是旧的，但原因字段变了，例如 `market paid purchase blocked:` 后面的 `reason=` 出现新值
- behavior 通过了，但 warn 指向真实主路径，例如正常购买、正常翻页、正常 choice 提交时也打印 reject

## 慢测怎么读

当前 Windows 下，`MONO_TEST_TIMING=1` 的慢测结果要先看计时源，再决定是否真慢。

### 当前已确认的计时假象

- 文件：`tests/support/wall_clock.lua`
- 现状：Windows 分支每次 `start()` / `finish()` 都会起一次 PowerShell 取毫秒时间
- 结果：即使是空测试，单 case 也会多出约 `1.2s-1.3s` 的墙钟成本

本地验证结果：

- `pre_confirm_enter_market_confirm_option_not_found` 单跑约 `1258ms`
- 空测试单跑约 `1256ms`
- 两者计时源都是 `powershell`

因此：

- 当慢测只有 1s 左右，且 `source=powershell` 时，默认先判定为计时开销，不是业务逻辑慢
- 只有当同一 case 明显高于空测试基线，或者计时源不是 `powershell` 时，才值得继续分析 case 本身

## 建议的排查顺序

1. 先看 warn 是否在“预期 warn 清单”里。
2. 再看 warn 是否只出现在对应负路径 suite。
3. 如果是慢测，先确认计时源是不是 `powershell`。
4. 若是 `powershell`，先拿空测试做对照，再决定要不要优化业务逻辑。
5. 若出现新 warn，把文案、来源文件、首个触发 suite 一起补到这份文档。
