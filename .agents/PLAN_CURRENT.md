# ECanvas 调试屏日志输出（含开关）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角


为新加的调试界面“调试屏”提供日志显示能力：把 `src/core/Logger.lua` 产生的日志输出到 UI 的 `ELabel` 节点“日志”。增加配置开关，默认关闭；打开后日志持续刷新。验收方式是启动游戏后，在调试开关开启时看到“日志”标签实时追加行，关闭时不更新。

## 进度


- [x] (2026-02-04 12:13Z) 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-04 12:13Z) 识别调试 UI 节点与日志标签节点，并建立 UI 访问与刷新逻辑
- [x] (2026-02-04 12:13Z) 在 `Logger` 增加可选的“UI 输出端”与缓存读取接口
- [x] (2026-02-04 12:13Z) 在主循环中按配置开关驱动日志刷新到 UI
- [x] (2026-02-04 12:13Z) 运行回归脚本或最小启动验证

## 意外与发现


暂无。

## 决策日志


- 决策：调试开关放在 `Config/GameplayRules.lua`，默认关闭。
  理由：避免新增文件，且不影响线上表现。
  日期/作者：2026-02-04 / Codex。

- 决策：日志显示格式为“时间+等级+正文”。
  理由：可读性最佳且无需额外结构。
  日期/作者：2026-02-04 / Codex。

- 决策：日志最多显示 50 行。
  理由：信息量与性能平衡。
  日期/作者：2026-02-04 / Codex。

## 结果与复盘


已完成回归脚本验证，确认日志相关改动不影响既有用例，调试开关开启后即可通过 UI 观察日志输出。

## 背景与导读


`src/core/Logger.lua` 当前只把日志写入内存 `logger.entries`，没有 UI 或文件输出。`src/ui/UIView.lua` 负责 UI 节点查询与文本设置，通过 `UIManager.query_nodes_by_name` 获取节点并设置 `node.text`。UI 节点列表在 `Data/UIManagerNodes.lua`，其中包含 `ECanvas` “调试屏”与 `ELabel` “日志”。主循环在 `src/game/turn/GameplayLoop.lua` 的 `tick` 中刷新 UI。

## 工作计划


先改配置，在 `Config/GameplayRules.lua` 新增调试开关与最大显示行数。再改 `src/core/Logger.lua` 增加日志读取与 UI sink 接口，并保留现有行为。然后在 `src/ui/UIView.lua` 增加设置“日志”文本与“调试屏”可见性的函数。最后在 `src/game/turn/GameplayLoop.lua` 里按配置驱动 UI 日志刷新，并在开关切换时清空/刷新。

## 具体步骤


在仓库根目录完成如下修改：
1. 修改 `Config/GameplayRules.lua`，新增 `debug_log_enabled` 与 `debug_log_max_lines`。
2. 修改 `src/core/Logger.lua`，新增 `set_ui_sink`、`get_seq`、`get_entries`、`get_text`，并在 `_push` 更新序号。
3. 修改 `src/ui/UIView.lua`，新增 `set_debug_log` 与 `set_debug_visible`。
4. 修改 `src/game/turn/GameplayLoop.lua`，根据开关刷新 UI 日志，且只在日志序号变化时更新。
5. 运行 `lua .agents/tests/regression.lua`。

## 验证与验收


运行 `lua .agents/tests/regression.lua`，预期输出 `All regression checks passed (N)`。启动游戏后：开关关闭时“日志”不更新；开关打开时，“日志”显示最近 50 行，格式 `YYYY-MM-DD HH:MM:SS [level] 文本`。

## 可重复性与恢复


本变更为代码与配置调整，可重复执行。若需回退，删除新增接口与调用，并移除配置开关即可。

## 产物与备注


    文件：Config/GameplayRules.lua
    变更：新增 debug_log_enabled / debug_log_max_lines

    文件：src/core/Logger.lua
    变更：新增序号、读取接口与 UI sink 支持

    文件：src/ui/UIView.lua
    变更：新增调试日志与可见性设置

    文件：src/game/turn/GameplayLoop.lua
    变更：按配置驱动日志刷新

    回归输出：
      All regression checks passed (36)

## 接口与依赖


新增接口：
- `src/core/Logger.lua`
  - `logger.set_ui_sink(sink)`
  - `logger.get_seq()`
  - `logger.get_entries(max_lines)`
  - `logger.get_text(max_lines)`

依赖 UIManager 的节点查询与 `node.text` 写入。

计划变更说明：2026-02-04 补充回归验证结果与产物证据。
