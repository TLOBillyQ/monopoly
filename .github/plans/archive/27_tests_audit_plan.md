# Tests 审计与清理计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md`，后续每次修改都必须按其中规则维护。

## 目的 / 全局视角


现有 .github/tests 覆盖面在扩展，但部分脚本在纯 Lua 环境下会因缺少引擎内置函数而失败，且存在与当前代码重复或过时的审计脚本。本计划的目标是让 .github/tests 在本仓库当前结构下稳定可跑，删掉已经被更现代审计脚本替代的遗留测试，并把 acceptance 入口更新为当前应当执行的测试集合。完成后运行 `lua .github/tests/acceptance.lua` 应该返回 `ok - acceptance suite`，并且回归测试通过。

## 进度


- [x] (2026-01-31 01:51Z) 审计 .github/tests 目录与 acceptance 入口，确认回归测试在纯 Lua 下因 Vector3/Quaternion 缺失失败。
- [x] (2026-01-31 01:51Z) 增加测试引导脚本 `.github/tests/test_bootstrap.lua` 并让全部测试在启动时加载。
- [x] (2026-01-31 01:51Z) 删除重复的 `.github/tests/ui_nodes_audit.lua`，用 `.github/tests/ui_missing_impl_audit.lua` 作为唯一 UI 节点审计，并更新 acceptance 列表。
- [x] (2026-01-31 01:51Z) 运行 `lua .github/tests/acceptance.lua` 验证通过。
- [x] (2026-01-31 01:52Z) 复跑 `lua .github/tests/acceptance.lua` 并记录最新输出。

## 意外与发现


观察：`.github/tests/regression.lua` 在纯 Lua 运行时因 `math.Vector3` / `math.Quaternion` 缺失导致 `Globals/Macro.lua` 报错。
证据：`field 'Vector3' is not callable (a nil value)`。

观察：`.github/tests/ui_missing_impl_audit.lua` 仍输出 `MissingInAdapter` 列表，但不影响 acceptance 通过。
证据：`[ui-missing] MissingInAdapter:` 随后列出节点清单。

## 决策日志


- 决策：新增 `.github/tests/test_bootstrap.lua`，在测试入口统一补齐 `math.tofixed`、`math.Vector3`、`math.Quaternion` 的最小桩实现。
  理由：不改运行时代码，避免破坏引擎环境，只在测试环境兜底。
  日期/作者：2026-01-31 / Codex。

- 决策：删除 `.github/tests/ui_nodes_audit.lua`，用 `.github/tests/ui_missing_impl_audit.lua` 作为 UI 节点审计来源。
  理由：`ui_nodes_audit` 是硬编码清单，维护成本高且与 `UIState.build_ui_state()` 重复；`ui_missing_impl_audit` 直接对齐当前 UI 适配器实现。
  日期/作者：2026-01-31 / Codex。

- 决策：在 `.github/tests/acceptance.lua` 中加入 `.github/tests/eggy_event_names_test.lua`、`.github/tests/ui_missing_impl_audit.lua`、`.github/tests/entry_smoke_test.lua`。
  理由：这些测试覆盖最新事件命名、UI 节点完整性与入口加载，应作为当前入口的基础校验。
  日期/作者：2026-01-31 / Codex。

## 结果与复盘


已完成测试引导与 acceptance 更新，回归与基础审计可在纯 Lua 环境运行。当前未处理 UI 节点“MissingInAdapter”清单，只做输出保留；如需进一步清理可另立计划。

本次复验确认 `lua .github/tests/acceptance.lua` 仍通过，输出包含 `ok - acceptance suite` 与 `All regression checks passed`。

## 背景与导读


.github/tests 目录包含多个单文件脚本，`.github/tests/acceptance.lua` 作为统一入口按顺序执行。当前运行环境不具备 Eggy 引擎内置的 `math.Vector3` 与 `math.Quaternion`，导致 `Globals/Macro.lua` 无法加载。UI 节点审计原先有 `.github/tests/ui_nodes_audit.lua` 与 `.github/tests/ui_missing_impl_audit.lua` 两个脚本，前者依赖手工清单，后者基于 `Manager/TurnManager/GUI/UIState.lua` 与 `Manager/MarketManager/GUI/MarketUI.lua` 的实际使用情况。

## 工作计划


先新增 `.github/tests/test_bootstrap.lua`，提供最小引擎函数桩并确保仅在测试环境生效；然后为 .github/tests 下所有脚本在文件开头加载该 bootstrap。随后删除 `.github/tests/ui_nodes_audit.lua`，并更新 `.github/tests/acceptance.lua` 的脚本列表，加入事件名审计、UI 缺失审计与入口烟雾测试。最后运行 acceptance 入口确认输出。

## 具体步骤


在仓库根目录创建测试引导脚本：

    cat <<'EOF' > .github/tests/test_bootstrap.lua
    if not math.tofixed then
      function math.tofixed(value)
        return value
      end
    end

    if not math.Vector3 then
      function math.Vector3(x, y, z)
        return { x = x, y = y, z = z }
      end
    end

    if not math.Quaternion then
      function math.Quaternion(x, y, z)
        return { x = x, y = y, z = z }
      end
    end
    EOF

为所有 .github/tests 脚本添加引导加载：

    dofile(".github/tests/test_bootstrap.lua")

删除 `.github/tests/ui_nodes_audit.lua`，并更新 `.github/tests/acceptance.lua` 的脚本列表。

## 验证与验收


在仓库根目录运行：

    lua .github/tests/acceptance.lua

预期输出包含 `ok - acceptance suite`，并且 `All regression checks passed`。

## 可重复性与恢复


本次改动为测试脚本变更，删除或回滚 `.github/tests/test_bootstrap.lua` 并移除每个测试文件顶部的 `dofile` 即可恢复到原始状态。如需恢复 `.github/tests/ui_nodes_audit.lua`，请从版本历史或备份中取回。

## 产物与备注


新增文件：`.github/tests/test_bootstrap.lua`。

测试脚本顶部新增如下引导语句：

    dofile(".github/tests/test_bootstrap.lua")

## 接口与依赖


测试引导仅依赖 Lua 标准库与 `math` 表，新增的三个函数桩仅用于测试环境：`math.tofixed`、`math.Vector3`、`math.Quaternion`。acceptance 入口需要能执行 `lua` 与 `rg`（已被现有审计脚本使用）。

改动说明：首次创建计划并记录已执行的审计、清理与验证步骤，确保计划与当前实际改动一致。
改动说明：追加复验进度与最新发现，补充验收输出说明。
