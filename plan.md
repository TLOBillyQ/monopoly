# 托管按钮全角色可点击与按角色独立切换改造计划


本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.github/PLANS.md` 的维护要求。

## 目的 / 全局视角


当前实现里，托管按钮在 UI 表现层仍受“是否本地角色”限制，导致非本地角色视角可能不能点击托管按钮；同时 `auto` 意图在分发层会被重写为本地角色，无法严格表达“谁点击，切谁的托管状态”。这与最新产品期望冲突。

本计划完成后，用户可见行为会变成：任意角色视角在任意时机（包括输入锁开启）都能点击托管按钮；点击只切换该角色自己的 `player.auto`；其他角色状态不受影响。验证方式是跑 UI 交互切片测试与全量回归，且新增用例能稳定证明“全角色可点 + 独立切换 + 缺失 actor_role_id 拒绝”。

## 进度


- [x] (2026-02-24 12:12 +08:00) 完成 `research.md` 结论对齐，明确新产品期望与旧实现冲突点。
- [x] (2026-02-24 12:15 +08:00) 确认测试入口与命令可执行：`lua .github/tests/regression.lua`、`presentation_ui_interaction` 切片命令。
- [ ] 待实施：修改 `UIPanelPresenter`，移除“本地角色匹配”对托管按钮触控的限制。
- [ ] 待实施：修改 `UIIntentDispatcher`，优先保留事件侧传入的 `intent.actor_role_id`，缺失时再回退本地角色解析。
- [ ] 待实施：补充并更新 `presentation_ui` 相关测试，覆盖全角色可点与按角色独立切换。
- [ ] 待实施：执行 UI 切片回归与全量回归，记录通过证据并更新本计划“结果与复盘”。

## 意外与发现


现有回归中已经存在“非本地角色托管按钮应禁用”的断言，这与新产品期望相反。证据是 `.github/tests/suites/presentation_ui.lua` 里 `_test_ui_view_render_by_role_slots_are_isolated` 和 `_test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists` 对非本地角色断言为 `false`。这意味着改造不仅是功能代码改动，还必须同步改测试预期。

在 Windows PowerShell 下执行 `lua .github/tests/regression.lua` 时，命令输出首行会出现 `'[' is not recognized as an internal or external command`，但后续 `All regression checks passed (154)`、`dep_rules ok`、`tick ok` 均正常。该噪声不影响本次行为验证，但要在验收记录里注明，避免误判。

## 决策日志


决策：托管按钮触控权限以产品语义为准，直接定义为“全角色始终可点”，不再让 `UIPanelPresenter` 复用“本地角色匹配”变量。
理由：`allow_touch` 的职责是交互权限，不应混入身份判定语义；输入锁策略也已把托管按钮定义为例外放行。
日期/作者：2026-02-24 / Codex。

决策：`_normalize_auto_intent` 采用“保留上游 actor，再回退本地解析”的顺序。
理由：`UIEventRouter` 已按点击上下文写入 `intent.actor_role_id`，分发层不应无条件覆盖；保留回退是为了兼容缺失上下文的旧调用路径。
日期/作者：2026-02-24 / Codex。

决策：动作层保持现有 `TurnDispatch` 逻辑，不新增 `auto` 的当前回合限制。
理由：新需求是“切换自己的托管状态”，而不是“仅当前回合玩家可切换”；当前 `_resolve_actor_player` 通过 `actor_role_id` 定位玩家即可满足语义。
日期/作者：2026-02-24 / Codex。

## 结果与复盘


本节在代码改造与回归完成后填写。完成标准是：`UIPanelPresenter` 与 `UIIntentDispatcher` 已按计划改动，新增测试通过，且全量回归通过并附关键输出证据。

## 背景与导读


本改造涉及三个层面。第一个层面是 UI 触控呈现，在 `src/presentation/ui/UIPanelPresenter.lua`，函数 `render_auto_controls_for_role` 会给托管按钮和托管文本设置可见性与触控。第二个层面是意图分发，在 `src/presentation/interaction/UIIntentDispatcher.lua`，函数 `_normalize_auto_intent` 会把托管点击意图标准化为动作。第三个层面是动作落地，在 `src/game/flow/turn/TurnDispatch.lua`，`action.id == "auto"` 分支依据 `actor_role_id` 查找玩家并切换 `player.auto`。

这里的“输入锁”是 `state.ui.input_blocked`。输入锁开启时，大多数按钮被禁用，但 `src/presentation/interaction/UIInputLockPolicy.lua` 明确调用 `set_auto_controls_touch(ui, true)`，把托管按钮定义为例外放行。这里的“按角色独立切换”是指：角色 A 点击只改变 A 的 `player.auto`，不会改变角色 B 的 `player.auto`。

测试主入口是 `/.github/tests/regression.lua`。与本需求最相关的切片是 `presentation_ui_interaction`，它从 `.github/tests/suites/presentation_ui.lua` 选取第 28 到 37 个测试，覆盖输入锁、触控策略和 UI 交互。

## 工作计划


里程碑一聚焦 UI 触控语义收敛。先改 `src/presentation/ui/UIPanelPresenter.lua`，把 `allow_touch` 从“本地角色匹配结果”改成恒为 `true`。这一步只解决“能不能点”的问题，不触碰托管状态切换逻辑。里程碑完成后，所有角色视角都应该在 UI 层获得托管按钮点击权限。

里程碑二聚焦动作归属正确性。改 `src/presentation/interaction/UIIntentDispatcher.lua` 的 `_normalize_auto_intent`，先读取 `intent.actor_role_id`，若为空再用 `_resolve_local_role_id()` 兜底。这样可以保证事件路由传来的“点击角色”不会被覆盖，最终由 `TurnDispatch` 正确切换对应玩家状态。里程碑完成后，应能稳定满足“谁点击，切谁自己”。

里程碑三聚焦回归证明。修改 `.github/tests/suites/presentation_ui.lua` 现有断言并新增测试，覆盖三类场景：全角色可点、角色间切换互不影响、缺失 `actor_role_id` 时拒绝切换。随后先跑 UI 切片，再跑全量回归，确认没有引入旧行为回退。

## 具体步骤


在工作目录 `C:\Users\Lzx_8\Desktop\dev\monopoly` 进行以下操作。

先修改 UI 触控逻辑。编辑 `src/presentation/ui/UIPanelPresenter.lua` 的 `render_auto_controls_for_role`，保留标签与可见性逻辑，删除 `allow_touch` 对 `auto_enabled` 的依赖，直接传入恒定 `true` 给 `ui_touch_policy.set_auto_controls_touch`。

再修改意图标准化逻辑。编辑 `src/presentation/interaction/UIIntentDispatcher.lua`，将 `_normalize_auto_intent` 的 `actor_role_id` 解析改为：优先 `intent.actor_role_id`，为空时回退 `_resolve_local_role_id()`，两者都为空则记录警告并返回 `nil`。

然后修改测试。编辑 `.github/tests/suites/presentation_ui.lua`，把“非本地角色托管按钮为 false”的旧断言改为 true。补充至少两条测试：第一条验证两个角色点击托管后各自 `player.auto` 独立变化；第二条验证缺失 `actor_role_id` 的 `auto` 动作返回 `rejected` 且玩家状态不变。

先跑切片回归，定位问题更快。命令与预期如下（缩进块为示例）：

    cd C:\Users\Lzx_8\Desktop\dev\monopoly
    lua -e "package.path=package.path..';./.github/tests/?.lua;./.github/tests/suites/?.lua;./.github/tests/fixtures/?.lua'; local h=require('TestHarness'); h.run_all({require('presentation_ui_interaction')})"

    ..........
    All regression checks passed (10)

切片通过后跑全量回归。命令与预期如下：

    cd C:\Users\Lzx_8\Desktop\dev\monopoly
    lua .github/tests/regression.lua

    ..........................................................................................................................................................
    All regression checks passed (154)
    dep_rules ok
    tick ok

## 验证与验收


验收以“行为可观察”而非“代码已改”为准。第一，输入锁开启时，任意角色视角托管按钮都可点，且托管文本仍不可点。第二，角色 A 点击只切换 A，角色 B 状态保持原值；角色 B 点击后只切换 B。第三，缺失 `actor_role_id` 的 `auto` 输入不会误切换任意玩家，并返回拒绝状态。第四，全量回归通过。

当上述行为同时成立，并且 `lua .github/tests/regression.lua` 输出 `All regression checks passed (154)` 时，视为验收通过。

## 可重复性与恢复


本计划步骤可重复执行，不涉及数据迁移。若中途失败，优先按文件粒度回滚本次改动后重跑切片测试，再跑全量回归。建议每完成一个里程碑就执行一次 `presentation_ui_interaction` 切片，减少一次性排错成本。

若需要恢复到改造前状态，可使用 Git 按文件回退：仅回退 `UIPanelPresenter.lua`、`UIIntentDispatcher.lua` 与 `presentation_ui.lua` 的本次变更，然后重新运行回归确认恢复。

## 产物与备注


本计划实施后应产生三类直接产物：`UIPanelPresenter.lua` 的触控判定收敛修改，`UIIntentDispatcher.lua` 的角色绑定修正，以及 `presentation_ui.lua` 的测试更新与新增。提交说明建议按“功能改动”和“测试改动”分开，便于审查。

终端证据以两段为准：一段是切片回归 `All regression checks passed (10)`，另一段是全量回归 `All regression checks passed (154)`。若 Windows 环境仍出现 `'[' is not recognized ...` 噪声，在证据备注中标注“已复现但不影响结果判断”。

## 接口与依赖


本改造不引入新依赖库。核心接口保持原路径，仅调整实现语义。`src/presentation/ui/UIPanelPresenter.lua` 的 `panel_presenter.render_auto_controls_for_role(ui, ctx, ui_model, local_role_id)` 保持签名不变，但必须保证托管按钮触控始终放行。`src/presentation/interaction/UIIntentDispatcher.lua` 的 `_normalize_auto_intent(intent)` 保持签名不变，但必须保证输出动作 `action.actor_role_id` 优先继承 `intent.actor_role_id`。`src/game/flow/turn/TurnDispatch.lua` 的 `action.id == "auto"` 分支保持现有逻辑，继续以 `actor_role_id` 解析目标玩家。

测试依赖仍使用现有 `TestHarness` 与 `presentation_ui` 套件，不新增测试框架。里程碑结束时，必须能通过现有命令直接复现验收结果，不依赖手工 UI 操作。

## 本次更新说明


本次更新将旧版“托管按钮连续开关问题分析”重写为符合 `/.github/PLANS.md` 的可执行计划，并根据 `research.md` 最新结论纳入“全角色可点击、按角色独立切换”的明确目标。重写原因是旧文档偏结论说明，缺少可执行里程碑、验证命令、回退路径和活文档四个必需章节，无法直接指导无上下文执行者落地。
