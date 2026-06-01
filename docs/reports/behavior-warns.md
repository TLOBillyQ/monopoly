---
kind: report
status: generated
owner: quality
last_verified: 2026-05-14
---
# Behavior 回归中的 warn 与慢测判读

这份文档只回答两个问题：

1. `busted --run behavior` 打出来的哪些 `warn` 是预期内的测试噪音。
2. 哪些 `warn` / 慢测信号值得继续追。

> 基线日期：2026-05-14（Asia/Hong_Kong）。这里记录的是当前仓库已知、可解释的输出；如果 behavior lane 出现本文档没列到的新 warn，默认按”可疑”处理。
>
> **匹配机制**：`spec/log_warns_handler.lua` 会先去掉日志时间与 `[warn]` 前缀，再做前缀匹配。白名单条目只需覆盖共同前缀。单源真值在 `docs/reports/behavior_warns_data.lua`。

## 预期 warn 清单

### 测试环境：Eggy 宿主组件 / 运行时桩不可用

| warn 片段 | 含义 | 默认处理 |
|----------|------|----------|
| `[Eggy]` | 自动玩家未给出动作、runtime pending choice 空转等 | 预期内 |
| `[entity_pool]` | 测试环境无法创建 Eggy 单位 | 预期内 |
| `[tip_output_port] state.show_tip not installed` | 测试未安装 tip presenter，回退到 tip_queue 直发 | 预期内 |
| `[tip_queue] presenter not registered` | 同上 | 预期内 |
| `ctrl_unit missing BuffStateComp:` | 测试桩不包含 Eggy BuffState 组件 | 预期内 |
| `missing Enums.` | 测试环境缺少 Eggy 枚举 | 预期内 |
| `status3d missing remaining-text node:` | 测试未注入 UIManager，ELabel 节点不可用 | 预期内 |
| `status3d unit missing create_scene_ui_bind_unit:` | 同上 | 预期内 |

### 测试环境：音效 / 反馈资源不可用

| warn 片段 | 含义 | 默认处理 |
|----------|------|----------|
| `board_feedback skip play_3d_sound:` | 测试环境无音效资源 | 预期内 |
| `board_feedback skip play_sfx_by_key:` | 同上 | 预期内 |

### 测试环境：黑市购买桩

| warn 片段 | 含义 | 默认处理 |
|----------|------|----------|
| `market paid goods mapping missing:` | 测试未配置商品映射 | 预期内 |
| `market paid purchase blocked:` | 付费网关不可用，购买被拒 | 预期内 |

### 反面测试：故意触发的权限 / 校验拒绝

| warn 片段 | 含义 | 默认处理 |
|----------|------|----------|
| `auto intent missing actor_role_id` | 自动 intent 缺 actor | 预期内 |
| `choice action blocked by actor check:` | 非 owner 提交 choice，校验拒绝 | 预期内 |
| `choice action mismatch:` | choice ID 不匹配 | 预期内 |
| `choice action missing actor_role_id:` | choice 缺 actor | 预期内 |
| `choice action without pending choice:` | 无待决 choice 时提交动作 | 预期内 |
| `choice route fallback to base_inline:` | 测试用 choice kind 无专用路由 | 预期内 |
| `invalid choice option:` | 无效选项 ID | 预期内 |
| `invalid item option:` | 无效道具选项 | 预期内 |
| `item slot denied by availability:` | 道具不可用时被拒 | 预期内 |
| `item_slot click ignored:` | 道具槽点击被忽略 | 预期内 |
| `missing item_id:` | 缺少道具 ID | 预期内 |
| `没有可选择的目标玩家` | 目标玩家道具无候选目标 | 预期内 |
| `目标玩家不在可选列表中:` | 指定 target_id 不在候选列表 | 预期内 |
| `目标玩家无效:` | 指定 target_id 无效 / 自指 / 已淘汰 | 预期内 |
| `remote_select without choice` | 远程选择但无待决 choice | 预期内 |
| `role->player 映射失败` | 无效 role_id 回退到观战 | 预期内 |
| `ui intent rejected:` | UI intent 缺 actor 被拒 | 预期内 |
| `ui_button actor_role_id not mapped:` | 按钮 actor 映射失败 | 预期内 |
| `ui_button blocked by actor check:` | 按钮权限校验拒绝 | 预期内 |
| `ui_button missing actor_role_id:` | 按钮缺 actor | 预期内 |
| `ui_button missing current_role_id:` | 按钮缺 current role | 预期内 |

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
