# 首轮相机不跟随的定位计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角


目标是在不改动行为的前提下，确认“前 4 回合相机不跟随”的直接原因。实现后应当能够通过日志判断 `_refresh_view` 是否被调用、`follow_camera` 事件是否触发以及相机目标是否有效，并据此明确原因归属。

## 进度


- [x] (2026-02-04T11:36Z) 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-04T11:36Z) 在 `src/game/turn/GameplayLoop.lua` 中记录相机跟随触发条件与回合信息
- [x] (2026-02-04T11:36Z) 在 `src/runtime/ECA.lua` 中记录相机目标查询结果
- [x] (2026-02-04T11:36Z) 在 `src/game/turn/TurnStart.lua` 与 `src/game/turn/TurnManager.lua` 中记录回合与玩家切换信息
- [ ] (2026-02-04T11:36Z) 在编辑器侧核对 `follow_camera` 事件注册与加载屏相机状态
- [ ] (2026-02-04T11:36Z) 运行游戏观察日志并汇总结论

## 意外与发现


暂无。

## 决策日志


暂无。

## 结果与复盘


尚未完成。需要在观察日志后补充具体原因与修复建议。

## 背景与导读


相机跟随事件的触发入口位于 `src/game/turn/GameplayLoop.lua` 的 `_refresh_view`，它在 UI 刷新时设置 `camera_helper.target_role_id` 并触发 `TriggerCustomEvent(eca_event.camera.follow)`。相机目标的解析在 `src/runtime/ECA.lua` 的 `get_camera_target`。回合推进与玩家切换由 `src/game/turn/TurnStart.lua` 和 `src/game/turn/TurnManager.lua` 驱动。现象是首轮前 4 回合不跟随，第 5 回合开始正常。

## 工作计划


先补充最小日志来确认 `_refresh_view` 是否在回合 1 到 4 期间被调用，以及 `follow_camera` 事件是否可用并触发。随后在 `get_camera_target` 中确认 `camera_helper.target_role_id` 是否能解析到有效 Role。再记录回合与玩家切换，确保回合推进符合预期。最后在编辑器侧核对 `follow_camera` 事件注册与相机状态是否被加载流程覆盖。

## 具体步骤


在仓库根目录完成代码改动后，运行回归脚本做基础语法检查：

    工作目录：c:\Users\Lzx_8\Desktop\dev\monopoly
    命令：lua .agents/tests/regression.lua

随后在蛋仔编辑器中启动游戏，观察日志输出的“相机跟随检查”“相机目标查询”“回合开始”“切换玩家”等字段是否覆盖回合 1 到 4。

## 验证与验收


验收方式为人工观察日志。回合 1 到 4 期间应能看到相机跟随检查日志与相机目标查询日志，并明确是否触发了 `follow_camera`。如果日志显示 `_refresh_view` 未触发或事件不可用，则判定为刷新或事件问题；如果事件触发但目标无效，则判定为目标映射问题；若事件注册缺失或被覆盖，则判定为编辑器侧配置问题。

## 可重复性与恢复


本变更仅添加日志，行为不变。若需要回退，删除新增日志并恢复原文件即可。再次运行回归脚本确认无语法错误。

## 产物与备注


关键日志样例将以以下前缀输出，便于在编辑器控制台检索：

    [Eggy] 相机跟随检查: 回合 <n> 玩家索引 <i> 玩家ID <id> 事件可用 <true/false>
    [Eggy] 相机目标查询: role_id <id> role_ok <true/false>
    [Eggy] 回合开始: turn_count <n> current_player_index <i> player_id <id>
    [Eggy] 切换玩家: 回合 <n> current_index <i> next_index <j>

## 接口与依赖


不新增对外接口。新增日志依赖现有 `src/core/Logger`，并复用已有的 `TriggerCustomEvent` 与 `camera_helper`。

计划变更说明：2026-02-04 清空旧计划并写入首轮相机不跟随定位计划，因为用户请求执行该新任务。
