# 规约：EditorCLI 端到端 profile 车道

specifier handoff name: **e2e-profile-lane**

## 0. 背景（已存在，不重做）

- EditorCLI 桥已接入：`tools/bridge/editor_cli/{client,escape,result_capture}.lua`
  （`run-game/stop-game/exec/game_exec/*_capture/status/logs/clear-logs/is_available`，
  通过 `__E2E_RESULT__:` 日志 marker 捞回 `exec` 返回值）。
- e2e busted 车道已声明：`.busted` 的 `e2e`（ROOT `spec/e2e`，helper `spec/e2e/helper.lua`，
  `busted --run e2e`）。
- 夹具 `spec/e2e/support/editor_fixture.lua`：`with_play_mode/with_edit_mode/skip_if_unavailable`
  —— **非 Windows 且无 `EDITOR_CLI_FORCE` → pending；编辑器不可达 → pending**。
- boot 链路已通：`startup.profile_name → src.app.profile_source.resolve_bootstrap →
  test_profile_resolver.resolve_bootstrap → profile.bootstrap`。

缺口只有三个：profile 没有预期输出；没有“遍历所有 profile”的驱动；没有“启用即全跑”的触发。

## 1. 边界（硬约束）

- 本车道依赖**活的 Eggy 编辑器 + EditorCLI**，属宪法定义的“环境不适配模块”。
- **不得**进入 `make verify` / `make acceptance` / 任何无头管线，**不得**参与 mutation /
  CRAP / coverage / Gherkin acceptance mutation。
- 因此本规约**不写成 APS pipeline feature**（写成 feature 会么不可无头运行=假绿，
  么污染 acceptance 套件）。它是 `spec/e2e/` 下的 busted 驱动 + profile 数据契约。

## 2. 车道行为契约（验收标准）

> “profile” 指 `src.app.testing.test_profile_resolver.names()` 返回的、带 `expect` 字段的条目。
> phase 1 只要求 `solo_missile` 一条；其余 profile 暂无 `expect` 时应被**显式跳过并计数**
> （不可静默漏跑——参照 ADR 0015 的假绿教训）。

1. **可达性**：非 Windows 且无 `EDITOR_CLI_FORCE` → 整条车道 pending；编辑器不可达 → pending。
   （复用现有 fixture，不新造跳过逻辑。）
2. **枚举**：车道遍历所有带 `expect` 的 profile（phase 1 = `{solo_missile}`）。
3. **每条 profile**：
   1. 编辑器进 play mode，boot 进该 profile 的 `bootstrap` 初始态（经
      `startup.profile_name`，机制由 coder 定，需可经 `editor-cli exec` 设置）。
   2. **确定性推进恰好一回合**：以固定种子（`seed=1`）让回合引擎/AI 推进该 profile
      acting player 的一个完整回合（含其落地结算与道具阶段）。同一 profile 多次运行结果必须一致。
   3. 经 `game_exec_capture` 捞回观测态（落地后的 tile / player / 事件）。
   4. 断言观测态 == 该 profile 的 `expect`。
4. **判定**：任一字段不符 → 该 profile 失败，错误信息须含 profile 名 + 期望值 vs 实际值。
   车道汇总所有 profile 的 通过/失败/跳过 计数。
5. **无 `expect` 的 profile**：计入 skipped，并在车道尾部 `log` 出被跳过的清单（不假绿）。

## 3. `expect` 字段约定（复用现有 busted 不变量）

- `expect` 写在 `src/config/test_profiles.lua` 各 profile 内，是**对该 profile 已对应的
  `spec/behavior` 设计真值不变量的镜像**——不新发明断言，只把同一不变量搬到活编辑器上跑。
- 字段是观测态的**最小充分集**：能区分“规则正确执行”与“未执行/执行错”即可，
  避免镜像无关的实现细节（否则等同 golden 快照，违背用户选择）。
- 形态（建议，coder 可微调命名）：
  ```lua
  expect = {
    source_spec = "spec/behavior/rules/demolish_closure_spec.lua",  -- 不变量出处，可追溯
    tiles   = { [11] = { level = 0 } },          -- 设计真值断言
    players = { [2] = { in_hospital = true } },
    events  = { { kind = "demolish" } },          -- 至少发生一次
  }
  ```

## 4. Phase 1 切片：`solo_missile`

bootstrap（现状）：p1 持导弹于格 40（chance_inner）；p2 站格 11；`tiles[11].owner=2,level=2`。
对应不变量来自 `spec/behavior/rules/demolish_closure_spec.lua`（导弹命中己方建筑分支）：

```lua
solo_missile.expect = {
  source_spec = "spec/behavior/rules/demolish_closure_spec.lua",
  tiles   = { [11] = { level = 0 } },        -- 建筑被摧毁（level 2 → 0）
  players = { [2] = { in_hospital = true } }, -- 占据者 p2 送医，stay_turns > 0
  events  = { { kind = "demolish" } },        -- 发布一次 demolish 事件
}
```

验收：编辑器可达时，`busted --run e2e` 中 `solo_missile` 这条端到端绿；
不可达 / 非 Windows 时整条 pending。

## 5. 触发（启用即全跑）

- 触发即 `busted --run e2e`（lane 已存在）。coder 可加 `make e2e` 薄封装指向它。
- **不**接入 `make verify`。可在文档/CLAUDE.md 注明这是 operator 车道。

## 6. Phase 2（本次不做，留接口）

fan-out 时按 §3 约定为其余 ~36 profile 逐个补 `expect`（镜像各自 `spec/behavior` 不变量）。
§2 的车道契约已对“N 条 profile”泛化，phase 2 只加数据，不改驱动。

## 7. 角色分工（交付边界）

- specifier（本规约）：车道行为契约、`expect` 约定、phase-1 `solo_missile` 期望值。
- coder：profile `expect` 字段落地；boot-profile-into-live-editor 的 exec 入口；
  确定性单回合驱动 + 固定种子；`spec/e2e/gameplay/` 下遍历 profile 的驱动 spec；
  可选 `make e2e`。需更新受影响文件的 mutate4lua-manifest（test_profiles.lua 等）。
- 验证：本车道 `busted --run e2e`（环境不适配，不入 verify）；
  若改动触及 `test_profile_resolver` 等无头模块，另跑其 `busted --run behavior`。
