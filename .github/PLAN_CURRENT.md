# 编辑器快速测试配置实施计划

本可执行计划是活文档。实施过程中持续维护“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `.github/PLANS.md`。

## 目的 / 全局视角

目标是在不破坏默认玩法的前提下，新增 3 份可快速触发 UI 场景的编辑器配置，并提供一行开关切换。完成后，开发者只需修改 `Config/GameplayRules.lua` 的 `test_profile`，即可在 1~2 回合内触发 Choice/黑市/破产等高耗时场景，显著缩短 UI 手测时间。

## 进度

- [x] (2026-02-20 12:40Z) 新增 profile 路由与地图模块：`Config/Maps/*`、`Config/TestProfiles.lua`、`Config/Map.lua`。
- [x] (2026-02-20 12:45Z) 新增测试加速注入：`src/app/testing/TestProfileBootstrap.lua` 并接入 `src/app/bootstrap/GameStartup.lua`。
- [x] (2026-02-20 12:49Z) 新增回归套件：`.github/tests/suites/test_profiles.lua`，并接入 `.github/tests/regression.lua`。
- [x] (2026-02-20 12:52Z) 回归验证通过：全量 143 绿，UI 专项 62 绿。
- [ ] (pending) 编辑器双端手测回填：按 quick profile 验证 11 屏触发速度与行为。

## 意外与发现

- 观察：并发执行 `mkdir` 与 `cp` 会出现竞态，导致首次复制默认地图失败。  
  证据：终端输出 `cp: ... No such file or directory`。
- 观察：新增 profile 回归后总用例数从 138 提升到 143。  
  证据：`lua .github/tests/regression.lua` 输出 `All regression checks passed (143)`。
- 观察：UI 专项套件计数保持 62，说明本次改动未影响现有 presentation 分片。  
  证据：UI 专项命令输出 `All regression checks passed (62)`。

## 决策日志

- 决策：采用 `GameplayRules.test_profile` 单字段切换。  
  理由：编辑器调试成本最低，不引入额外入口。  
  日期/作者：2026-02-20 / Codex。
- 决策：默认地图迁移到 `Config/Maps/DefaultMap.lua`，`Config/Map.lua` 仅做路由。  
  理由：保证默认行为稳定，降低 profile 扩展成本。  
  日期/作者：2026-02-20 / Codex。
- 决策：测试加速仅在非 `default` profile 生效。  
  理由：防止污染正式配置与默认玩法。  
  日期/作者：2026-02-20 / Codex。

## 结果与复盘

本轮已完成代码与自动化回归改造，交付了 3 份快速测试 profile（`ui_quick_all`、`ui_quick_choice`、`ui_quick_bankruptcy`）及其开局注入机制。默认档未回归，全量与 UI 专项回归均通过。剩余工作是编辑器双端手测回填，用于验证“触发更快”与“屏幕行为一致”。

## 背景与导读

- 地图定义原先集中在 `Config/Map.lua`，被 `GameStartup` 与 UI 模型直接引用。
- UI 手测耗时主要来自：道具获取随机、关键地块触发链过长、破产场景达成慢。
- 本次改造将地图与测试资源配置化：
  - `Config/Maps/*.lua` 提供 default + quick map。
  - `Config/TestProfiles.lua` 定义 profile 到 map/bootstrap 的映射。
  - `TestProfileBootstrap` 在 `game:new()` 后注入玩家资源、道具、地块状态。

## 工作计划

先把地图拆分成“默认地图 + profile 路由 + ring builder”，保证默认流程不变；再在 `GameStartup` 插入测试 profile 注入点，为 quick 档提供开局加速；最后补回归套件验证路由、fallback、注入与地块预置，确保改动可持续维护。

## 具体步骤

1. 路由与地图：新增 `Config/Maps/DefaultMap.lua`、`RingMapBuilder.lua` 与 3 份 quick map，重写 `Config/Map.lua` 路由。  
2. profile 配置：新增 `Config/TestProfiles.lua`，固化 3 份 quick 档。  
3. 运行时注入：新增 `src/app/testing/TestProfileBootstrap.lua`，并在 `GameStartup.game_factory` 里调用。  
4. 回归：新增 `.github/tests/suites/test_profiles.lua`，并在 `.github/tests/regression.lua` 注册。  
5. 验证命令：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua -e 'package.path=package.path..";./.github/tests/?.lua;./.github/tests/suites/?.lua;./.github/tests/fixtures/?.lua"; local h=require("TestHarness"); h.run_all({require("presentation_ui_timing_anim"),require("presentation_ui_model_dispatch"),require("presentation_ui_interaction"),require("presentation_ui_popup_market"),require("presentation_ui_action_status"),require("presentation_ui_action_anim")})'

## 验证与验收

- 自动化验收：
  - `regression.lua` 全绿，输出 `All regression checks passed (143)`、`dep_rules ok`、`tick ok`。
  - UI 专项输出 `All regression checks passed (62)`。
- 行为验收：
  - `test_profile=default` 时保留原 45 格地图。
  - `test_profile` 切换到 3 个 quick 档时，地图路径与开局注入按 profile 生效。

## 可重复性与恢复

- 所有改动可重复执行；profile 切换仅需改 `GameplayRules.test_profile` 并重进对局。
- 回退到默认行为只需设为 `default`。
- 若需彻底回滚代码，按 git 常规回退本轮改动文件即可。

## 产物与备注

- 新增：
  - `Config/Maps/DefaultMap.lua`
  - `Config/Maps/RingMapBuilder.lua`
  - `Config/Maps/UIQuickAll.lua`
  - `Config/Maps/UIQuickChoice.lua`
  - `Config/Maps/UIQuickBankruptcy.lua`
  - `Config/TestProfiles.lua`
  - `src/app/testing/TestProfileBootstrap.lua`
  - `.github/tests/suites/test_profiles.lua`
- 修改：
  - `Config/Map.lua`
  - `Config/GameplayRules.lua`
  - `src/app/bootstrap/GameStartup.lua`
  - `.github/tests/regression.lua`

## 接口与依赖

- 配置接口：`GameplayRules.test_profile`。
- Profile 解析：`Config.TestProfiles.resolve(profile_name)`。
- 运行时注入：`TestProfileBootstrap.apply(game, opts?)`。
- 依赖模块：`ItemInventory`、`GameStateOps`（cash/balance/tile owner/level）。

## 更新记录

- 2026-02-20：新建“编辑器快速测试配置”可执行计划并完成首轮实现与回归验证。原因：当前地图手测触发链过长，影响 UI 验证效率。
