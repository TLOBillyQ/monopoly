# 重构版本计划入口（Prompt）

## 最终目标

交付一系列嵌套的可执行计划到 `Refactoring/plans/`，指导实现一个 `LuaSource_大富翁` 的重构版本，根目录为 `./Refactoring`，作为 monopoly 项目的 Eggy 适配最终版本。

## 需求基线

需求必须以 `design/` 为唯一来源，完整对照已写入 `plans/prepare_plan.md`。后续计划应以该文件作为需求清单与差异追踪基线。

## 重构版本总体方向

利用原版中的尝试（`move.lua`, `macro.lua`, `init.lua`, `eca.lua`）与数据（`ui_data.lua`, `refs.lua`），并结合生存割草/汉堡 UI/商城道具知识完成适配。入口初始化仿照生存割草的 `main.lua` 流程，保留原版 UI 管理器并完善 `UINodes.lua` 中的面板名称对照；`init.lua` 中“道具槽位”与 `src/gameplay` 的 5 槽背包对应；`eca.lua` 负责把 Lua 事件转发给 Eggy 触发器；`move.lua` 负责移动动画。

## 计划链（依赖顺序）

0. `Refactoring/plans/00-master-plan.md`：重构总控执行计划（长期运行）。
1. `Refactoring/plans/01-structure-bootstrap.md`：重构目录与基线骨架。
2. `Refactoring/plans/02-data-config-port.md`：设计数据与配置同步。
3. `Refactoring/plans/03-entry-flow.md`：主入口与回合流程接线。
4. `Refactoring/plans/04-ui-nodes-manager.md`：UIManager 接入与 UI 数据统一。
5. `Refactoring/plans/05-gameplay-items-chance.md`：玩法与道具/机会系统接入。
6. `Refactoring/plans/06-eca-bridge.md`：ECA 触发器桥接。
7. `Refactoring/plans/07-visual-timeout-anim.md`：表现层等待、动画与超时补齐。
8. `Refactoring/plans/08-ai-behavior.md`：AI 行为与自动操作完整性。
9. `Refactoring/plans/09-land-ownership.md`：地块购买与租金结算完整性。
10. `Refactoring/plans/10-land-upgrade.md`：地块加盖与建筑表现。
11. `Refactoring/plans/11-market-blackshop.md`：黑市与商城购买逻辑。
12. `Refactoring/plans/12-item-active-usage.md`：主动使用类道具卡。

## 注意

本计划链以“需求完整性优先”为原则，不新增并行实现；所有计划必须遵循 `.agent/PLANS.md` 的 ExecPlan 规范与 CodingDiscipline。
