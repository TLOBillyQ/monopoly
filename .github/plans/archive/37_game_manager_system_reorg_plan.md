# GameManager/System 职责重整计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


目标是把 Manager/GameManager 与 Manager/System 中职责混杂的函数按“行为/责任”重新归位到更恰当的目录（如 Components、Config、Globals 以及对应的 *Manager），让读者可以凭目录名判断模块用途，并且保持用户可见行为完全不变。可观察结果是：重构后游戏仍能按原流程运行；`lua .github/tests/regression.lua` 通过；并且 `rg -n "Manager/System"` 只命中确实属于平台适配与底层事件桥接的文件，其余逻辑已回到更匹配的目录。


## 进度


- [x] (2026-01-31 15:15Z) 创建可执行计划并确定目标范围
- [x] (2026-01-31 15:22Z) 盘点 Manager/GameManager 与 Manager/System 文件的实际职责并形成迁移映射（GameplayLoop/Chance/Player mixin/常量/EventHandlers）
- [x] (2026-01-31 15:22Z) 按映射拆分/迁移函数并更新 require 路径
- [x] (2026-01-31 15:22Z) 删除空壳/过时文件并完成回归脚本验证（场景验证待补充）


## 意外与发现


观察：当前 Manager/System 目录只包含 EventHandlers.lua 与 __init.lua，范围比预期小。证据：rg --files Manager/System 返回仅两项。
观察：PlayerEffects/PlayerVehicle 实际是 Player mixin，并由 CompositionRoot 注入。证据：Manager/GameManager/CompositionRoot.lua 通过 for key, fn in pairs(...) 混入到 Player。


## 决策日志


决策：优先移动函数到已有目录与模块，只有在出现至少两个明确调用点且无法归并时才新增文件。理由：遵守最少代码与最少概念的约束，避免引入“为未来准备”的新层。日期/作者：2026-01-31 / Codex。

决策：迁移以“行为归属”为第一准则，文件名或历史位置不作为保留理由。理由：本次重构目标是职责清晰与路径可推断性。日期/作者：2026-01-31 / Codex。

决策：GameplayLoop 归入 TurnManager，EventHandlers 归入 TurnManager/GUI。理由：两者均是回合驱动与界面事件桥接，不属于 GameManager 核心或 System 平台层。日期/作者：2026-01-31 / Codex。

决策：Chance 模块独立为 ChanceManager，Gameplay 常量迁入 Config。理由：机会卡是独立子域，常量属于配置数据而非管理逻辑。日期/作者：2026-01-31 / Codex。

决策：PlayerEffects/PlayerVehicle 合并进 Components/Player。理由：它们是 Player 方法集合，直接放入组件可消除混入层。日期/作者：2026-01-31 / Codex。


## 结果与复盘


已完成：GameplayLoop 迁入 TurnManager，EventHandlers 迁入 TurnManager/GUI，Chance 系统迁入 ChanceManager，Gameplay 常量迁入 Config，Player mixin 合并到 Components/Player；旧路径清理完成，回归脚本通过。
待补充：Eggy 场景验证 UI 与回合推进行为。


## 背景与导读


当前需要整理的目录是 Manager/GameManager 与 Manager/System。重整后，GameManager 仅保留核心游戏协作模块，例如 `Manager/GameManager/Game.lua`、`Manager/GameManager/CompositionRoot.lua`、`Manager/GameManager/GameState.lua`、`Manager/GameManager/GameVictory.lua` 与 AI 相关模块；GameplayLoop 已迁到 `Manager/TurnManager/GameplayLoop.lua`，Chance 系统迁到 `Manager/ChanceManager/Chance.lua` 与 `Manager/ChanceManager/ChanceRegistry.lua`，Gameplay 常量迁到 `Config/GameplayConstants.lua`，事件桥接迁到 `Manager/TurnManager/GUI/EventHandlers.lua`。其它目录已有明确职责，比如 Components 存放基础数据结构，Config 存放配置数据，Globals 存放全局常量或事件名，而各 *Manager 目录负责具体子系统（例如 TurnManager、BoardManager、MarketManager）。本计划的目标是在不改变行为的前提下，把上述模块中“职责不匹配”的函数拆分并归位。


## 里程碑


第一个里程碑是“职责盘点与映射完成”。完成后会有一份清晰的迁移映射，列出每个函数或子模块的目标位置，并且能说明它为何属于该目录。验证方式是执行一次全量搜索并在计划中记录映射与依据。

第二个里程碑是“迁移落地与回归通过”。完成后所有迁移已落地，旧路径不再被引用，`lua .github/tests/regression.lua` 通过，并且 `rg -n "Manager/System"` 只剩平台适配或事件桥接的少量文件。


## 工作计划


先对 Manager/GameManager 与 Manager/System 全量盘点，逐个文件阅读并标注每个函数的实际行为归属。归属规则采用“行为优先”：纯数据与常量归入 Config 或 Globals；纯数据结构与状态操作归入 Components；与具体子系统相关的规则与服务归入对应的 *Manager（例如机会卡执行逻辑归入 Chance 或 Effect 相关目录，UI 刷新与交互归入 GUI 相关目录）；平台或框架级的事件桥接、时间循环和系统初始化归入 System。盘点完成后在计划里写出映射清单，并说明每个迁移的理由。

映射确定后按“最小步迁移”实施：每次只迁移一个文件或一个明确的函数集合，先把代码移动到目标位置，再更新 require 引用，最后删除原位置。对存在多种职责的文件，先提取最不匹配的函数到新位置，并保留原 API 入口，通过薄适配层过渡到新位置，等所有调用点完成切换后删除适配层。整个过程保持行为不变，不引入新的抽象层或多余封装。

迁移完成后清理空壳文件与无用模块，确保 Manager/GameManager 与 Manager/System 只保留与其目录职责一致的内容，并运行回归脚本与场景验证作为最终证明。


## 具体步骤


在仓库根目录执行盘点与映射。运行以下命令，记录输出与每个文件的职责判断，并在计划中补充迁移映射与理由。

  rg --files Manager/GameManager Manager/System

随后逐个打开上述文件，标注每个函数的行为归属，并写入本计划的“映射段落”。当映射完成后，按映射逐一迁移。每次迁移都需要运行一次全量引用搜索以确认旧路径无残留。

  rg -n "Manager.GameManager|Manager.System" Manager Globals Components Config

迁移完成后运行回归脚本。

  lua .github/tests/regression.lua

预期输出包含连续的点号以及结尾：

  All regression checks passed (30)


## 验证与验收


执行 `lua .github/tests/regression.lua`，预期全部通过并输出 “All regression checks passed (30)”。在 Eggy 场景中启动游戏，确认 GAME_INIT 后 UI 正常显示，点击“下一步”可推进回合，自动模式与弹窗行为保持不变。若无法运行 Eggy 场景，则至少通过日志验证 GameplayLoop 仍在驱动帧循环且 UI 刷新被触发。


## 可重复性与恢复


迁移以小步可重复执行为原则，每次迁移前后都能通过 `rg -n` 检查引用路径一致性。若需要回退，使用版本管理工具逐文件恢复即可；迁移过程中不进行批量删除，确保可以在任意步骤恢复到上一步的稳定状态。


## 产物与备注


最终应出现的关键信息示例（仅示意，具体内容随迁移映射更新）：

  rg -n "Manager/System" Manager Globals Components Config
  （无输出）

以及回归输出：

  ..............................
  All regression checks passed (30)


## 接口与依赖


迁移后的模块仍需保持现有对外接口不变，尤其是 gameplay 驱动、事件触发与 UI 刷新相关的调用点。若某函数被拆分到新位置，原调用点必须通过更新 require 路径直接指向新位置，避免保留转发层。依赖关系必须清晰且单向：Components 不依赖 Manager；Config 与 Globals 不依赖 Manager；System 只依赖必要的平台 API 与 Globals 事件定义。当前关键路径调整为：`Manager/TurnManager/GameplayLoop.lua`、`Manager/TurnManager/GUI/EventHandlers.lua`、`Manager/ChanceManager/Chance.lua`、`Manager/ChanceManager/ChanceRegistry.lua`、`Config/GameplayConstants.lua`。


更新记录：创建可执行计划，明确重整范围、迁移原则与验证方式，以便后续按映射执行迁移。
更新记录：完成职责盘点与迁移，将 GameplayLoop/Chance/EventHandlers/Player mixin/Gameplay 常量归位，并记录回归脚本通过情况，确保路径与验证信息可追溯。
更新记录：更新背景段落为当前模块路径，避免读者按照旧结构理解计划。
