# 重写大富翁与 SecretOfEscaper 架构摘要可执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角


本任务包含两个可验证成果。第一，将 docs/knowledge/SecretOfEscaper 示例工程的架构做简练总结，写入 docs/reports/knowlege_report.md，形成可复用的架构指南补充；完成后可在文档中看到清晰的入口链路、模块分层与 UI 管理模式。第二，在保持玩法与输出不变的前提下，复用本仓库现有框架重写 src/ 大富翁，实现清晰的 core/gameplay/adapters 分层，并补齐 Eggy 适配层未完成的能力（参考 pilots/14_eggy_adapter_extension_plan.md）。验收方式是通过现有 Lua 测试，并在 Eggy Demo 中完成移动、道具与选择流程且不发生卡死或错位。

## 进度


- [x] (2026-01-29 10:20Z) 创建可执行计划，完成范围确认并定位 SecretOfEscaper 示例与 Eggy 适配层扩展计划。
- [ ] (2026-01-29 10:40Z) 完成 SecretOfEscaper 架构摘要并追加到 docs/reports/knowlege_report.md。
- [ ] (2026-01-29 11:20Z) 梳理现有 src 模块职责与依赖，输出“模块去向清单”，确认哪些复用、哪些合并、哪些删除。
- [ ] (2026-01-29 12:40Z) 按框架顺序重写 core 与 gameplay，并保持行为不变且测试可运行。
- [ ] (2026-01-29 13:40Z) 重写 adapters 并完成 Eggy 适配层扩展（移动动画/道具表现/棋盘选择）。
- [ ] (2026-01-29 14:10Z) 通过测试与手工验收，更新相关设计说明并补齐复盘。

## 意外与发现


docs/reports/knowlege_report.md 已存在且主题是示例工程知识抽取，因此本次只能追加 SecretOfEscaper 架构摘要而不能覆盖原内容。证据：该文件标题为“eggy 示例工程知识抽取（面向 LuaSource_大富翁）”。docs/knowledge/SecretOfEscaper 目录包含完整入口与初始化链路，可直接用于架构总结。证据：docs/knowledge/SecretOfEscaper/main.lua 调用 init 并进入 MapManager.init_level。Eggy 适配层的缺口已经在 pilots/14_eggy_adapter_extension_plan.md 明确列出，需要作为重写的一部分纳入范围。

## 决策日志


决策：将用户所说的 SecrectOfEscape 解释为仓库中的 SecretOfEscaper 示例工程，并以此作为架构指南总结来源。理由：仓库内存在该目录，且是唯一与“SecrectOfEscape”近似的工程名。日期/作者：2026-01-29 / Codex。

决策：重写时保留 core/gameplay/adapters 的框架边界与现有对外接口，优先复用并删除冗余实现，不新增无调用点抽象。理由：符合 .agent/CODING.md 的约束且能降低行为回归风险。日期/作者：2026-01-29 / Codex。

## 结果与复盘


尚未实施，待完成各里程碑后补充真实结果、偏差与经验。

## 背景与导读


仓库入口是根目录 main.lua，当前只安装 Eggy runtime。游戏核心在 src/：core/ 提供棋盘、玩家、仓库、随机数与存档等基础结构，gameplay/ 负责回合推进、道具与落地逻辑，adapters/ 提供跨平台适配层与 Eggy 的 UI/事件实现，config/ 维护静态配置（地图、道具、角色等），util/ 为日志、表操作与 intent 分发工具。适配层设计文档在 docs/reports/adapters_design.md，同步点与等待态规则在 docs/reports/sync_report.md，自动推进与 AI 决策在 docs/reports/auto_runner_agent_design.md，Eggy UI 机制说明在 docs/eggy/ui_manager_lib.md。示例工程 SecretOfEscaper 位于 docs/knowledge/SecretOfEscaper，入口链路为 main.lua -> init.lua -> MapManager.init_level，并通过 Manager/__init.lua 加载各类系统。Eggy API 的检索必须先查 docs/eggy/api/，再按关键词查 docs/eggy/EggyAPI.lua，五次检索未命中视为不存在。

## 工作计划


先阅读架构文档与 SecretOfEscaper 工程入口、初始化与 Manager 组织方式，提炼出本仓库可直接借鉴的架构要点，并将简练摘要追加到 docs/reports/knowlege_report.md。随后对 src/ 当前实现做一次“模块去向清单”，把每个文件归入 core/gameplay/adapters/config/util，并标注需要合并或删除的重复逻辑，确保重写过程以“复用与删减”为先。重写实现按数据结构与规则层优先的顺序推进：先保证 core 的状态与基础能力不变，再重写 gameplay 的回合与道具流程，最后统一适配层的输入/输出通路，并补齐 Eggy 适配层扩展计划中的动画与选择功能。完成后更新 docs/reports/adapters_design.md 中 Eggy 章节与同步点说明，使文档与实现一致。

## 具体步骤


在仓库根目录先执行检索建立依赖与入口清单，输出用于后续“模块去向清单”的素材：

    rg -n "require\\(\"src" src
    rg -n "AdapterLayer|Presenter|Game:dispatch_action|pending_choice" src
    rg -n "eggy_layer|move_anim|action_anim|market_ui" src/adapters/eggy
    rg -n "SecretOfEscaper" docs/knowledge/SecretOfEscaper

阅读并摘录 SecretOfEscaper 架构信息，重点覆盖入口链路、全局初始化、Manager 组织、Config/Data/Library 的职责与 UIManager 使用方式，读取文件至少包含 docs/knowledge/SecretOfEscaper/main.lua、docs/knowledge/SecretOfEscaper/init.lua、docs/knowledge/SecretOfEscaper/Manager/__init.lua、docs/knowledge/SecretOfEscaper/Globals/__init.lua 与一个代表性的 GUI 控制器（例如 MapManager/Lobby/GUI/MainController.lua）。在 docs/reports/knowlege_report.md 末尾新增一个“SecretOfEscaper 架构指南”小节，用短段落描述入口与分层，并点名关键目录与典型调用方式。

然后在 src/ 中逐文件确认职责边界，形成“模块去向清单”，确保每个文件都明确属于 core、gameplay、adapters、config 或 util，并在重写时优先复用已有实现。重点检查 src/game.lua、src/gameplay/composition_root.lua、src/adapters/core/adapter_layer.lua、src/adapters/core/presenter.lua、src/adapters/eggy/eggy_layer.lua，确认输入与输出路径以及等待态同步点。若发现逻辑落在错误层级（例如 gameplay 直接操作 UI 或 adapter 修改规则），将其迁回正确层级并删除旧路径。

按框架顺序重写实现：先维护 core 的数据结构与方法签名（Board/Player/Store/RNG/Tile 等），保证 Store 快照与查询路径不变；再整理 gameplay 的回合阶段（turn_start/turn_roll/turn_move/turn_land/turn_post/turn_end）与道具执行链（item_phase、item_executor、item_*）的调用关系，确保 Game:dispatch_action 与 TurnManager 流程保持一致；最后统一 adapters 的 action 输入与 view 输出，保证 AdapterLayer 的等待态同步逻辑不被绕过。Eggy 侧按 pilots/14_eggy_adapter_extension_plan.md 完成移动动画路径播放、道具表现与棋盘格选择交互，并确保 move_anim_done/action_anim_done 对齐 seq。

完成代码后同步文档：更新 docs/reports/adapters_design.md 中 Eggy 适配层能力说明，并必要时在 docs/reports/sync_report.md 中补充与本次改动相关的同步点说明。最后运行测试并执行手工验收。

## 验证与验收


运行仓库既有测试，必须全部通过：

    lua tests/deps_check.lua
    lua tests/regression.lua

手工验收在 Eggy Demo 中完成：掷骰移动时角色逐格移动且停格一致；使用路障/导弹/怪兽时棋盘表现与日志一致；出现选择时可以点击棋盘格确认或取消，且不会出现卡在 wait_move_anim / wait_action_anim / wait_choice 的情况。若无法启动 Eggy Demo，则至少在日志中确认 move_anim_done 与 action_anim_done 的 seq 与 store.turn 的 seq 一致，并记录证据。

## 可重复性与恢复


本次重写应保持接口与数据路径不变，允许反复运行测试而不改变存档或配置。任何临时调试日志在合并前必须删除。若出现回归，可使用版本管理工具逐文件回退到变更前版本，并重新运行测试验证基线是否恢复。

## 产物与备注


产物包含：更新后的 docs/reports/knowlege_report.md（新增 SecretOfEscaper 架构摘要）、重写后的 src/ 核心与玩法代码、以及补齐的 Eggy 适配层表现与选择逻辑。以下为预期的摘要片段示例（以实际内容为准）：

    ## SecretOfEscaper 架构指南（简要）
    入口链路：main.lua 延迟一帧调用 init.lua，init 负责加载 Globals、Library、UIManager 与 Manager 系统，再由 MapManager.init_level 载入地图与模式。
    分层结构：Config/Data 提供静态数据，Library 提供通用工具与 UI 管理，Components 提供可复用系统，Manager 组织玩法与子系统调度。
    UI 方式：通过 UIManager.Builder 构建节点树，Controller/View 组合负责按钮事件与界面刷新。

## 接口与依赖


重写必须保持以下关键接口稳定，避免破坏已有调用点。Game 层需保留 Game.new、Game:dispatch_action(action)、Game:advance_turn() 与 Game:pending_choice()，并维持 store 的路径结构（turn.pending_choice、turn.move_anim、turn.action_anim）。AdapterLayer 需保留 AdapterLayer.attach、AdapterLayer.step_move_anim、AdapterLayer.step_action_anim、AdapterLayer.step_choice_timeout，确保等待态同步以 seq/choice_id 为准。Eggy 侧需继续通过 EggyRuntime.install 安装，并在 EggyLayer:dispatch_action 与 EggyLayer:refresh_view 中处理 UI 与 game 的双向通路。必要时可增加 EggyLayerBoard.handle_tile_click 或 MoveAnim.play_path 等函数，但必须让调用点落在 adapters/eggy 内部并与 gameplay 解耦。

改动说明：首次创建本计划，记录 SecretOfEscaper 架构摘要与 src 重写的范围、步骤与验收方式，便于后续按计划推进。
