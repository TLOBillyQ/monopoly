# Tests 清单与遗留/过时测试待清理计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md`，后续每次修改都必须按其中规则维护。

## 目的 / 全局视角


本仓库的 `tests/` 目录里同时存在“可执行测试”“静态审计脚本”“手工/实验性测试”。目前没有一份“唯一可信的测试清单”，也没有明确哪些脚本应当进入默认测试入口、哪些属于遗留/过时应当删除或归档。

本计划的目标是：先把当前所有测试脚本完整列出来并记录其现状（是否被 `tests/acceptance.lua` 收录、是否能在纯 Lua 下运行、是否已被替代），再给出一套清理动作的顺序与验收方式。完成清理后，默认入口 `lua tests/acceptance.lua` 应稳定通过；遗留/过时脚本要么被修复并纳入默认入口，要么被明确标注为“手动运行”并移出默认路径，要么被删除/归档。

## 进度


- [x] (2026-01-31 12:34Z) 列出 `tests/` 目录当前全部 Lua 脚本，并整理其职责、入口关系与大致风险点。
- [x] (2026-01-31 12:34Z) 在本机纯 Lua（Lua 5.4.3）逐个执行测试脚本，记录通过/失败与关键输出。
- [x] (2026-01-31 12:38Z) 定义“默认入口/手动测试/遗留待退役”的判定标准，并完成全部脚本归类（遗留为空）。
- [x] (2026-01-31 12:38Z) 迁移 `RuntimeLoop/RuntimeUI` 到 `Manager/System/GUI` 并更新引用，`tests/deps_check.lua` 恢复通过。
- [x] (2026-01-31 12:38Z) 在 `tests/test_bootstrap.lua` 补齐 `LuaAPI.rand`，`tests/flow_control_test.lua` 通过并纳入默认入口。
- [x] (2026-01-31 12:38Z) 确认无遗留脚本需归档/删除，`tests/acceptance.lua` 列表已更新。

## 意外与发现


- 观察：当前环境为 Lua 5.4.3（不是 Lua 5.1），部分历史测试如果隐式依赖 5.1 行为，存在潜在不兼容风险。
  证据：
    Lua 5.4.3  Copyright (C) 1994-2021 Lua.org, PUC-Rio

- 观察：`tests/acceptance.lua` 当前会在第一步执行 `tests/deps_check.lua` 时失败，原因是“非 GUI 的运行时代码 require 了 GUI 模块”。
  证据（节选）：
    [acceptance] tests/deps_check.lua
    Dependency rule violations (4):
    - Manager/System/RuntimeLoop.lua: gameplay must not require GUI/runtime: require("Manager.BoardManager.GUI.MoveAnim")
    - Manager/System/RuntimeLoop.lua: gameplay must not require GUI/runtime: require("Manager.BoardManager.GUI.ActionAnim")
    - Manager/System/RuntimeUI.lua: gameplay must not require GUI/runtime: require("Manager.TurnManager.GUI.MainView")
    - Manager/System/RuntimeUI.lua: gameplay must not require GUI/runtime: require("Manager.TurnManager.GUI.Presenter")

- 观察：`tests/flow_control_test.lua` 当前失败，根因是运行到落地效果逻辑时触发 `Utils.choice_weight_list()`，但测试环境未提供 `LuaAPI.rand()`。
  证据（节选）：
    lua: ./Library/Utils.lua:508: attempt to index a nil value (global 'LuaAPI')
      ./Library/Utils.lua:508: in field 'choice_weight_list'
      ./Manager/LandManager/Land/Landing.lua:59: in field 'apply'

- 观察：`tests/ui_missing_impl_audit.lua` 会输出 `MissingInAdapter` 列表，但当前不失败退出（只要 `MissingInUiData` 不阻塞）。
  证据（节选）：
    [ui-missing] MissingInUiData:
    [ui-missing] MissingInAdapter:
      - backgroud_loading (EImage)

- 观察：迁移 `RuntimeLoop/RuntimeUI` 后，`tests/deps_check.lua` 恢复通过。
  证据：
    Dependency self-check passed

- 观察：补齐 `LuaAPI.rand` 后，`tests/flow_control_test.lua` 通过并输出 13 项测试完成。
  证据：
    All flow control tests passed (13)

- 观察：`tests/acceptance.lua` 已恢复通过，回归与审计脚本在默认入口全部执行完毕。
  证据（节选）：
    ok - acceptance suite

## 决策日志


- 决策：把 `tests/acceptance.lua` 定义为唯一“默认必须通过”的入口；未被它收录的测试默认视为“手动/实验性”，除非有明确理由升级为默认入口。
  理由：避免维护成本扩散；同时给“遗留/过时测试退役”一个可执行的边界。
  日期/作者：2026-01-31 / Codex。

- 决策：`tests/deps_check.lua` 的依赖方向规则继续作为硬门槛；优先通过移动/拆分代码来满足规则，而不是给 `deps_check` 增加更多豁免。
  理由：规则是为了长期防止 GUI 反向污染玩法层；豁免会迅速失控。
  日期/作者：2026-01-31 / Codex。

- 决策：把 “遗留/过时测试” 的初步判定标准定为：未被默认入口收录且长期不跑；或当前已稳定失败且缺少维护者；或与现有脚本功能重复且被更现代脚本替代。
  理由：需要一个可落地的、可操作的清理准绳，避免清理变成主观争论。
  日期/作者：2026-01-31 / Codex。

- 决策：将 `Manager/System/RuntimeLoop.lua` 与 `Manager/System/RuntimeUI.lua` 迁到 `Manager/System/GUI/`，并同步更新所有 require。
  理由：它们本质是运行时 UI/动画桥接，属于 GUI 层；迁移后符合 `tests/deps_check.lua` 的依赖方向规则。
  日期/作者：2026-01-31 / Codex。

- 决策：在 `tests/test_bootstrap.lua` 补齐 `LuaAPI.rand`，并把 `tests/flow_control_test.lua` 纳入默认入口。
  理由：最小改动即可让流程控制测试稳定可跑，且覆盖高价值的中断/恢复路径。
  日期/作者：2026-01-31 / Codex。

- 决策：当前未发现符合“遗留/过时”标准的脚本，清理阶段不删除任何测试文件。
  理由：所有脚本在纯 Lua 下均可运行或有明确用途，且无重复的旧入口需要退役。
  日期/作者：2026-01-31 / Codex。

## 结果与复盘


本计划已完成清单与归类、修复依赖方向违规、补齐测试桩并把 `flow_control_test` 纳入默认入口。当前 `lua tests/acceptance.lua` 与 `lua tests/deps_check.lua` 均通过；遗留/过时脚本为空。

## 背景与导读


本仓库的测试以“可直接 `lua <script>` 运行”的单文件脚本为主，集中在 `tests/` 目录。`tests/test_bootstrap.lua` 提供少量引擎函数桩，避免纯 Lua 环境因缺失 `math.Vector3` 等导致加载失败。`tests/acceptance.lua` 是当前唯一聚合入口，会顺序 `dofile()` 一组脚本并在末尾打印 `ok - acceptance suite`。

下面是 `tests/` 目录当前脚本清单（含用途、是否纳入默认入口、以及本次在 Lua 5.4.3 下的执行结果）。其中“纳入默认入口”以 `tests/acceptance.lua` 的 `scripts` 列表为准。

- `tests/acceptance.lua`：默认入口；当前通过。
- `tests/test_bootstrap.lua`：测试引导/桩；不单独作为测试运行。
- `tests/test_utils.lua`：测试断言工具；被 `tests/regression.lua` 与 `tests/flow_control_test.lua` 使用；可单独运行但无意义。

- `tests/deps_check.lua`：依赖方向自检（审计）；已纳入默认入口；通过。
- `tests/eggy_memory_audit.lua`：Eggy 相关用法审计（如冒号调用、整数字面量 Vector3/Quaternion 等）；已纳入默认入口；通过。
- `tests/eggy_event_names_test.lua`：事件名存在性校验；已纳入默认入口；通过。
- `tests/ui_missing_impl_audit.lua`：UI 节点“使用侧 vs Data 配置”差异审计；已纳入默认入口；通过但会输出 `MissingInAdapter` 列表。
- `tests/registry_extension_test.lua`：ChanceRegistry 可扩展注册验证；已纳入默认入口；通过。
- `tests/classutils_refactor_test.lua`：基础组件 smoke（Flow/Inventory/Store/Tile）验证；已纳入默认入口；通过。
- `tests/entry_smoke_test.lua`：入口可加载验证（Entry.install 存在）；已纳入默认入口；通过。
- `tests/regression.lua`：偏集成的回归脚本（覆盖移动、落地、道具、效果链等）；已纳入默认入口；通过（本次输出 30 项通过）。

- `tests/lua_env_audit.lua`：Lua 运行环境合规审计（禁止 io/os/package/debug/math.random 等）；未纳入默认入口；通过。
- `tests/ui_manager_test.lua`：UIManager（Library/UIManager）单元测试（含大量桩与事件/计时器验证）；未纳入默认入口；通过（输出 36 项断言通过）。
- `tests/flow_control_test.lua`：流程控制/恢复机制测试（偏集成，覆盖中断与恢复）；已纳入默认入口；通过（输出 13 项测试通过）。

## 工作计划


清理工作已按“先恢复默认入口可用，再处理边缘脚本”的顺序完成，避免在默认入口本身已坏的情况下做大规模删改导致回归成本变高。

已完成的分类结果如下：

1) 默认入口（必须始终通过）：`tests/acceptance.lua` 中列出的脚本集合（已新增 `tests/flow_control_test.lua`）。
2) 手动测试（可选但有价值）：`tests/lua_env_audit.lua`、`tests/ui_manager_test.lua`。
3) 遗留/过时（待退役）：当前为空，无需删除/归档。

修复路径已落地：把 `RuntimeLoop/RuntimeUI` 迁到 `Manager/System/GUI` 以满足依赖方向规则；在 `tests/test_bootstrap.lua` 补齐 `LuaAPI.rand` 以支持流程控制测试。

## 具体步骤


以下步骤均在仓库根目录执行。

1) 生成“测试清单现状快照”（本计划已完成，但后续变更时要可重复复验）：

    find tests -type f -maxdepth 1 -name "*.lua" -print
    lua -v

2) 验证默认入口现状（当前预期通过）：

    lua tests/acceptance.lua

   预期：输出包含 `ok - acceptance suite`。

3) 单独验证手动测试脚本（用于定期手工复核）：

    lua tests/lua_env_audit.lua
    lua tests/ui_manager_test.lua
   当前预期：两者通过。`tests/flow_control_test.lua` 已纳入默认入口，如需单独验证可运行 `lua tests/flow_control_test.lua`。

## 验证与验收


完成清理后，最小验收标准是：

1) `lua tests/acceptance.lua` 通过，并输出 `ok - acceptance suite`。
2) `lua tests/deps_check.lua` 通过，并输出 `Dependency self-check passed`。
3) `tests/` 目录中每个脚本都有明确归类（默认入口/手动/已退役），且没有“没人知道为什么还在”的文件。

4) `lua tests/flow_control_test.lua` 通过，并输出 `All flow control tests passed`（已被默认入口覆盖，可单独复核）。

## 可重复性与恢复


本计划后续涉及的清理主要是移动/删除测试脚本与重构少量依赖路径。所有操作应通过 git 追踪，任何一步需要回退时都可以用 `git checkout -- <path>` 或 `git restore <path>` 恢复到上一个稳定状态。

## 产物与备注


本计划阶段性证据（节选）：

    lua tests/eggy_event_names_test.lua
    ok - eggy event names

    lua tests/regression.lua
    ..............................
    All regression checks passed (30)

    lua tests/acceptance.lua
    ok - acceptance suite

## 接口与依赖


测试运行依赖：

1) 本机 `lua` 可执行文件（本次为 Lua 5.4.3）。
2) 本机可用 `rg`（ripgrep），被 `tests/eggy_memory_audit.lua` / `tests/lua_env_audit.lua` 等脚本通过 `io.popen` 调用。
3) 仓库本身提供的测试桩：`tests/test_bootstrap.lua`。

改动说明：首次创建计划，落盘当前 tests 清单、默认入口阻断点（deps_check 失败）与遗留脚本（flow_control_test 失败）的可复验证据，为后续清理做准备。
改动说明：执行清理与修复：迁移 RuntimeLoop/RuntimeUI 到 GUI、补齐 LuaAPI.rand、纳入 flow_control_test，并更新验收与证据。
